# homerow mods — timeless tuning (kanata side)

inspired by [urob's timeless homerow mods](https://github.com/urob/zmk-config#timeless-homerow-mods) (zmk; ported to qmk via runtime Chordal-Hold, ported to kanata via positional `tap-hold-release-keys`). same goal as the iris/qmk doc: cross-hand mod combos commit instantly via **positional priority**, same-hand rolls keep tapping cleanly via the timer. no more `Ctrl+B` (tmux) flubbing, no more flaky `Cmd+C` mid-typing.

this doc is the laptop-keyboard companion to [`iris-lm-config/docs/homerow-mods.md`](https://github.com/brendan/iris-lm-config/blob/main/docs/homerow-mods.md) — same behaviour model, different mechanism.

## the setup

| key | tap | hold |
|---|---|---|
| `a` | a | Cmd / Win (lmet) |
| `s` | s | Alt (lalt) |
| `d` | d | Shift (lsft) |
| `f` | f | Ctrl (lctl) |
| `j` | j | Ctrl (rctl) |
| `k` | k | Shift (rsft) |
| `l` | l | Alt (lalt) |
| `;` | ; | Cmd / Win (rmet) |

defined in `config.kbd` (macOS) and `config-windows.kbd` via `tap-hold-release-keys` aliases (`a_cmd`, `s_alt`, …). tap-vs-hold disambiguation happens in kanata at the keyboard layer, before any OS receives input.

## the knobs that matter

| setting | value | role |
|---|---|---|
| **alias action** | `tap-hold-release-keys` | the positional variant. fires `$hold-action` early if **any other input key** is pressed and released, except for keys listed in `$tap-keys`. |
| **`$tap-keys`** | `$left-hand-keys` for left HRMs, `$right-hand-keys` for right HRMs | the **protect-as-tap list**. keys in here force `$tap-action` immediately if pressed during the wait window — preserves rolls. |
| **`$tap-timeout`** | `300` ms | tap-repress timeout — rapid press+release+press within this window holds the tap action. |
| **`$hold-timeout`** | `200` ms | same-hand fallback. how long to hold an HRM before it auto-promotes to `$hold-action`. cross-hand commits early via the press+release path and doesn't consult this. |

variant signature (from [kanata config.adoc v1.11.0](https://github.com/jtroo/kanata/blob/v1.11.0/docs/config.adoc)):

```
(tap-hold-release-keys $tap-repress-timeout $hold-timeout $tap-action $hold-action $tap-keys)
```

aliases land like:

```
;; left HRMs — same-hand list = left
a_cmd (tap-hold-release-keys $tap-timeout $hold-timeout a lmet $left-hand-keys)

;; right HRMs — same-hand list = right
j_ctl (tap-hold-release-keys $tap-timeout $hold-timeout j rctl $right-hand-keys)
```

hand groupings:

```
(defvar
  left-hand-keys  (q w e r t a s d f g z x c v b)
  right-hand-keys (y u i o p h j k l ; n m , . /)
)
```

## behaviour predictions

| scenario | result |
|---|---|
| right-J ctrl + left-B (tmux `C-b`) | instant `Ctrl+B` — left-B is not in J's `$tap-keys` (right-hand list), so its press+release triggers default early hold |
| right-`;` cmd + left-C (`Cmd+C`) | instant `Cmd+C`, same mechanism |
| fast same-hand roll: "as", "kl", "asdf" | letters; same-hand key is in `$tap-keys`, force-taps immediately |
| deliberate same-hand mod: hold A past 200 ms, press S | `Cmd+S` — A auto-promotes to hold at `$hold-timeout`, then S press fires under it |
| co-press of chord keys (`we`/`xc`/`qw`/`tab+q`) while holding HRM | HRM force-taps (chord keys are in left-hand list), then chord fires. e.g. holding `f` + chording `we` → `f-`. acceptable; you almost never want to hold a HRM while chord-typing |
| external keyboard (Iris, etc.) | unaffected — `macos-dev-names-include` / `windows-interception-keyboard-hwids` scope kanata to the built-in keyboard only |

## the pitfall (read this before editing the defvars)

**polarity gotcha:** `tap-hold-release-keys` default behaviour is "press+release of any other key → early hold." the `$tap-keys` parameter is an **opt-out** list — keys in it force *tap*, not hold. so the same-hand list goes in `$tap-keys`, **not** the opposite-hand list.

this is the inverse of the QMK Chordal-Hold mental model (where you think "opposite-hand triggers hold"). it's also the inverse of a naive read of the variant name (`release-keys` doesn't mean "keys that release into hold" — it means "tap-hold whose hold fires on release of another key, with a tap-override keys list").

the upshot: if `left-hand-keys` and `right-hand-keys` get swapped between left/right HRMs, you'll get the **opposite** of timeless behaviour — same-hand rolls flub to mods, cross-hand combos always tap. easy to spot in verification step 1.

**incomplete hand lists:** every alpha column in `defsrc` must appear in exactly one hand list. if you add a new key to `defsrc` (e.g. apostrophe was missing from `right-hand-keys` in the first pass — see commit log), it needs adding here too or its press won't force-tap during a same-hand roll. cross-reference against `defsrc`'s alpha block periodically.

**chord-v2 + HRM interaction:** `chords-v2-min-idle 50` and `chord-timeout 30` mean chord detection runs before tap-hold resolution. holding an HRM while chord-pressing co-located keys force-taps the HRM (chord keys are in the same-hand list) before the chord fires. for `(w e) → -` etc. this just means `f-` instead of waiting for a hold decision. fine in practice.

## where the settings live

unlike Vial (which writes to EEPROM and overrides `config.h`), kanata has **no runtime override layer** — the `.kbd` files are the truth. on macOS:

1. **chezmoi source** — `~/.local/share/chezmoi/dot_config/kanata/config.kbd`. version-controlled, edited via `chezmoi edit` or directly.
2. **deployed copy** — `~/.config/kanata/config.kbd`. propagated by `chezmoi apply`. this is what kanata reads. its own gitea-tracked repo for separate publishing.
3. **running kanata** — re-reads the file on `sudo launchctl kickstart -k system/xbxd.kanata`. no live reload; restart required.

Windows mirrors the same layout (`config-windows.kbd`, propagated via `chezmoi apply` on Windows, kanata reload via scheduled task restart).

## verification (smoke tests)

run on the **internal laptop keyboard** (kanata's device filter scopes to it). in this order — highest-risk regression first:

1. **same-hand rolls don't regress**
   - fast-type `the quick brown fox jumps over the lazy dog`, then `asdf jkl;`, then `kalil`, then `sales`
   - every character must be a letter; no stray Cmd/Ctrl/Alt/Shift firing
2. **cross-hand fixes land**
   - in tmux: `Ctrl+B` (right-J + left-B) ten times in a row mid-command — prefix every time
   - in any app: `Cmd+C` (right-`;` + left-C), `Cmd+V`, `Cmd+T`
3. **same-hand deliberate mod still possible**
   - hold left-A past 200ms, then press S → `Cmd+S` save dialog
4. **external keyboards unaffected**
   - type same drills on the Iris; QMK-driven HRMs behave per `iris-lm-config/docs/homerow-mods.md`
   - `macos-dev-names-include ("Apple Internal Keyboard / Trackpad")` should already exclude it

if step 1 regresses: hand lists are inverted or incomplete. re-check that `left-hand-keys` contains left-half alphas and `right-hand-keys` the right half, and that every alpha column in `defsrc` appears in exactly one.

if step 2 still flubs: opposite-hand key not released fast enough before the typist moves on. try bumping `$hold-timeout` down to 180. last-resort: switch to `tap-hold-press` semantics (commits on opposite-hand press, no list protection) — loses same-hand roll protection so don't go here unless desperate.

## revert

swap the eight HRM aliases back to plain `tap-hold`:

```
a_cmd (tap-hold $tap-timeout $hold-timeout a lmet)
;; ... etc
```

`left-hand-keys` / `right-hand-keys` defvars can stay (unused → no error) or be removed for cleanliness.

then:

```sh
chezmoi apply
sudo launchctl kickstart -k system/xbxd.kanata
```

no EEPROM analogue, no separate Vial state — kanata reload fully restores prior behaviour.

## references

- urob's original (ZMK): <https://github.com/urob/zmk-config#timeless-homerow-mods>
- kanata config reference (`tap-hold-release-keys` and variants): <https://github.com/jtroo/kanata/blob/v1.11.0/docs/config.adoc>
- kanata port writeup (reddit): <https://www.reddit.com/r/ErgoMechKeyboards/comments/1qosvc0/a_try_on_urobs_timeless_home_row_mods_for_kanata/>
- qmk port writeup (reddit): <https://www.reddit.com/r/ErgoMechKeyboards/comments/1q1jo3c/urobs_zmk_timeless_home_row_mods_ported_to_native/>
- iris/qmk companion: `~/Code/iris-lm-config/docs/homerow-mods.md`
