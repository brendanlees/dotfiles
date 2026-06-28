# SketchyBar Tailscale status — design

Date: 2026-06-28
Status: Approved (pre-implementation)
Branch: feat/sketchybar-tailscale-status

## Goal

Add a signal-only Tailscale status item to the right side of the SketchyBar,
grouped with system-status items (battery, date). It is hidden when Tailscale
is healthy and not routing through an exit node, and visible whenever something
is worth glancing at: stopped, unhealthy, needs-login, offline, or an exit node
is in use.

## Scope

In scope:

- A single SketchyBar item + plugin backed by `tailscale status --json`.
- Right-side placement adjacent to battery.
- Signal-only visibility (hidden in the boring healthy state, except exit node).
- A distinct, always-visible state when an exit node is active.
- Two bash tests under `tests/chezmoi/`.

Out of scope:

- Non-Tailscale system VPNs. `scutil --nc` is noisy (a Bluetooth headset
  enumerates as a PPP "VPN"), and all of this user's network tooling is
  Tailscale. Parsing generic macOS VPN state is not worth the risk.
- Generic network/DNS health checks.
- Click actions / popups beyond toggling visibility of the item. (A click
  action such as `tailscale up`/`tailscale down` is left to a later slice if
  dogfooding shows it is wanted.)

## Source of truth

`tailscale status --json` is the sole source. It is structured and
machine-parseable. Key fields used (verified against tailscale 1.98.5):

- `BackendState` — `Running`, `Stopped`, `NeedsLogin`, `NeedsMachineAuth`, ...
- `HaveNodeKey` — whether the node is logged in at all.
- `Health` — array of human strings; empty means healthy.
- `Self.Online` — bool, whether the local node is online.
- `Self.ExitNode` / `Self.ExitNodeOption` — exit-node flags on the self node.
- `CurrentTailnet.Name` — tailnet name shown in the healthy connected state.
- `Peer` — map of peer nodes; each peer has `HostName`, `Online`, `ExitNode`,
  `ExitNodeOption`. A peer with `ExitNode == true` is the currently selected
  exit node.

`scutil --nc list` is NOT used. The Tailscale system-extension row there can
read "Connected" while the CLI reports `Stopped`, so the CLI is authoritative.

## Architecture / components

Mirrors the existing item/plugin split (e.g. `battery.sh` item +
`executable_battery.sh` plugin; `spotify.sh` + `executable_spotify.sh`).

### `dot_config/sketchybar/items/tailscale.sh`

Wires the item into the bar. No icon/label/drawing defaults here — the plugin
controls all of those so each state sets exactly the fields it needs.

```bash
#!/bin/bash

# Item starts hidden; the plugin reveals it only when Tailscale is running.
sketchybar --add item tailscale right \
    --set tailscale \
    drawing=off \
    icon.font="$FONT:Bold:14.0" \
    label.font="$FONT:Regular:13.0" \
    label.color="$WHITE" \
    background.color="$PILL_BG" \
    background.border_color="$GREY" \
    background.border_width=1 \
    background.corner_radius=8 \
    background.height=26 \
    background.drawing=on \
    padding_left=8 \
    padding_right=8 \
    update_freq=30 \
    script="$PLUGIN_DIR/tailscale.sh" \
    --subscribe tailscale system_woke
```

Pill defaults mirror `battery.sh` / `calendar.sh` (`PILL_BG` background, 1px border,
height 26, corner_radius 8). The plugin recolors `background.border_color` on each
refresh so the frame tracks the semantic state.

`update_freq=30` — Tailscale state changes are slow (up/down, exit node toggle);
30s is responsive enough for a signal-only item without hammering the CLI.
`system_woke` subscription refreshes state after sleep, matching `battery.sh`.

### `dot_config/sketchybar/plugins/executable_tailscale.sh`

Calls `tailscale status --json`, parses with `python3` (consistent with the
spotify plugin, which uses `/usr/bin/python3` for label truncation), and emits
the final `sketchybar --set "$NAME" ...` call. Sources `colors.sh` for the
palette and defines glyphs locally.

Behavior, by precedence (first match wins):

1. `tailscale` binary missing, or `tailscale status --json` exits non-zero, or
   JSON is unparseable → `drawing=off`, exit 0. Never spam the bar on a broken
   environment.
2. `HaveNodeKey == false`, or `BackendState` in `{NeedsLogin, Stopped, ""}` →
   `drawing=off` (the pill is hidden while Tailscale is off or inactive).
4. `BackendState == Running`:
   - Any peer with `ExitNode == true` →
     `drawing=on, icon=exit-glyph, color=BLUE, label=<HostName truncated
     before first ".">`. Exit node takes precedence over health warnings
     because "you are routing all traffic through an exit node" is the
     most privacy-relevant signal and the easiest to forget.
   - Else if `Health` is non-empty →
     `drawing=on, icon=alert, color=YELLOW, label=<first health string
     truncated to ~20 chars>`.
   - Else if `Self.Online == false` →
     `drawing=on, icon=alert, color=RED, label="offline"`.
   - Else (healthy, online, no exit node) →
     `drawing=on, icon=shield, color=GREEN, label=<tailnet name from CurrentTailnet.Name, or "connected" if missing, truncated to ~20 chars>`. The item is a persistent connected indicator, not signal-only.
5. Any other `BackendState` (e.g. `NeedsMachineAuth`, `Starting`) →
   `drawing=on, icon=alert, color=YELLOW, label=<state lowercase, ~12 chars>`.

### `dot_config/sketchybar/executable_sketchybarrc`

Source `tailscale.sh` between `battery.sh` and `spotify.sh`:

```bash
  source "$ITEM_DIR/calendar.sh"
  source "$ITEM_DIR/battery.sh"
  source "$ITEM_DIR/tailscale.sh"
  # source "$ITEM_DIR/app_soundsource.sh" # shelved for now
  source "$ITEM_DIR/spotify.sh"
```

SketchyBar right items render reverse-ish (source-order = right-to-left visual).
This yields visual order (right→left): `calendar | battery | tailscale |
spotify`, so date stays far-right (the documented anchor) and tailscale sits
visually adjacent to battery.

## State matrix

| Precedence | Condition | Drawing | Icon | Color | Label |
|---|---|---|---|---|---|
| 1 | tailscale missing / status error / bad JSON | off | — | — | — |
| 2 | NeedsLogin / no node key / empty state | off | — | — | — (hidden) |
| 3 | Stopped (has key) | off | — | — | — (hidden) |
| 4a | Running, exit node in use | on | exit | BLUE | exit-node host (before first `.`) |
| 4b | Running, Health non-empty | on | alert | YELLOW | health (~20 chars) |
| 4c | Running, Self.Online=false | on | alert | RED | `offline` |
| 4d | Running, healthy, online, no exit node | on | shield (green) | GREEN | tailnet name (or `connected` if unknown) |
| 5 | Other BackendState | on | alert | YELLOW | state (~12 chars) |

The same semantic `<color>` drives both `icon.color` and `background.border_color`,
so the pill frame tracks state (matching the existing battery/calendar/spaces pills,
which each color the border by their semantic state). The item definition sets a
neutral `GREY` border up front until the first plugin refresh recolors it.

## Visual / icons

No Nerd-Font Tailscale brand glyph exists, so use generic semantic glyphs
(shield/lock/exit/alert). Exact glyph codepoints are chosen during
implementation but belong to the Nerd Font Symbols range. Final glyph rendering
is verified during dogfooding (`chezmoi apply && sketchybar --reload`, swap any
tofu glyph). Colors reuse `$BLUE $YELLOW $RED $GREY` from `colors.sh`; no new
palette entries needed.

## Data flow

```
sketchybar timer (30s) / system_woke
        ↓
items/tailscale.sh wired plugin = plugins/executable_tailscale.sh
        ↓
tailscale status --json  (subprocess)
        ↓
python3 parses JSON, applies precedence above, prints:
   <drawing>\t<icon>\t<color>\t<label>
        ↓
plugin reads fields, calls: sketchybar --set "$NAME" drawing=.. icon=.. icon.color=.. label=.. label.color=..
```

The python helper prints TSV to keep the shell side trivial and the parsing
logic unit-testable (the tests feed canned JSON to the python parser directly).

## Error handling

- `tailscale` not on PATH → hide, exit 0.
- `tailscale status --json` non-zero exit, or stdout not valid JSON → hide,
  exit 0. (E.g. when the daemon is mid-restart.)
- python3 not available → hide, exit 0. (Defensive; python3 is in the repo's
  expected toolchain and used by the spotify plugin.)
- Any `sketchybar --set` failure → ignored (plugin exits; next tick retries).
- Never write to stderr loudly from the plugin (prefix only on a hidden
  debug hook) to avoid noise in the SketchyBar log.

## Testing

Two bash tests under `tests/chezmoi/`, following the existing harness style
(see `test-sketchybar-spotify-now-playing.sh`, `test-sketchybar-right-anchor-polish.sh`):

1. `test-sketchybar-tailscale-status.sh` — exercises the plugin's state matrix:
   - Stub `tailscale` to emit canned JSON for each state (needs-login, stopped,
     running-healthy-boring, running-exit-node, running-unhealthy,
     running-offline, other-state).
   - Stub `sketchybar` to capture `--set` calls.
   - Assert the captured `drawing/icon/icon.color/label/label.color` per state
     row match the matrix above.
   - Assert the "tailscale missing" and "bad JSON" paths hide the item.
   - Assert exit-node label uses the peer `HostName` truncated before the first
     `.`.
2. Extend `test-sketchybar-right-anchor-polish.sh` (or add a focused
   `test-sketchybar-tailscale-sourcing.sh`) to assert `executable_sketchybarrc`
   sources `tailscale.sh` and that the source order yields
   `calendar, battery, tailscale, spotify` for right items.

Standard verification alongside the tests:

```bash
  shellcheck -e SC1091 \
    dot_config/sketchybar/items/tailscale.sh \
    dot_config/sketchybar/plugins/executable_tailscale.sh \
    dot_config/sketchybar/executable_sketchybarrc
  CHEZMOI_ROLE=ephemeral,headless chezmoi init --source="$PWD" \
    --config=/tmp/chezmoi-ci.toml --apply=false
  CHEZMOI_ROLE=ephemeral,headless chezmoi apply --source "$PWD" \
    --config=/tmp/chezmoi-ci.toml --dry-run --verbose --exclude=externals
  git diff --check
```

## Risks / open questions

- **Exit-node flag semantics**: `ExitNode == true` on a peer is intended to mean
  "this is the currently selected exit node". This is not yet verified with a
  live exit node (Tailscale was Stopped during design). The plugin type and the
  tests use it as specified; dogfooding will toggle an exit node on to confirm.
  If the flag does not behave as expected, fall back to parsing
  `tailscale exit-node list` for the in-use exit node. The test uses canned
  JSON so it is independent of this risk.
- **Glyph tofu**: a chosen Nerd Font codepoint may not render in
  `JetBrainsMono Nerd Font Mono`. Mitigated by dogfood verification and trivial
  glyph swaps.
- **JSON format warning**: `tailscale status --json` docs warn the format is
  subject to change. The parser only reads the documented fields above and
  fails closed (hide) on malformed output, so a future change degrades to
  "hidden" rather than a broken bar.

## Non-goals / future slices

- Click action (`tailscale up`/`down` or a popup with peers).
- Generic macOS/system VPN surfacing.
- A popup listing tailnet peers with online/offline state.
