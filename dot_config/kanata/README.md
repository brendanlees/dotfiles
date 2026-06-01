# kanata configuration

used for re-mapping internal laptop keyboards.

## keybindings

### homerow mods (tap/hold)

| key    | tap | hold  |
| ------ | --- | ----- |
| `a`    | a   | cmd   |
| `s`    | s   | alt   |
| `d`    | d   | shift |
| `f`    | f   | ctrl  |
| `j`    | j   | ctrl  |
| `k`    | k   | shift |
| `l`    | l   | alt   |
| `;`    | ;   | cmd   |
| `caps` | esc | hyper |
| `lmet` | bspc | cmd  |

**positional disambiguation (timeless homerow mods).** the eight letter HRMs (a/s/d/f/j/k/l/`;`) use `tap-hold-release-keys` so:

- **opposite-hand press+release** commits the mod-tap to *hold* instantly — `Ctrl+B` (tmux), `Cmd+C`, `Cmd+V` fire without racing the timer.
- **same-hand press** forces *tap* — fast rolls like `asdf`, `kalil`, `sales` come out as letters.
- **same-hand deliberate mod** still works via the timer: hold A past `$hold-timeout` (200ms), then press S → `Cmd+S`.

hand groupings live in `(defvar left-hand-keys ...)` / `right-hand-keys` and must cover every alpha column in `defsrc` — see `docs/timeless-hrm.md` for the full rationale and the `$tap-keys` polarity gotcha.

`caps` (esc/hyper) and `lmet` (bspc/cmd) remain plain timing-based tap-hold — not homerow letters, no roll concern.

tap-timeout: 300ms, hold-timeout: 200ms.

### bottom-row tap-dance macros (tap/hold)

mirrors QMK tap-dance + macro setup on z/x/c/v/b. hold fires once via `(macro ...)` so the OS doesn't auto-repeat the command on long hold.

| key | tap | hold               |
| --- | --- | ------------------ |
| `z` | z   | Cmd+Z (undo)       |
| `x` | x   | Cmd+X (cut)        |
| `c` | c   | Cmd+C (copy)       |
| `v` | v   | Cmd+V (paste)      |
| `b` | b   | Cmd+A (select all) |

timeout matches homerow mods (300ms tap, 200ms hold).

### persist media function keys

| key   | action          |
| ----- | --------------- |
| `f1`  | brightness down |
| `f2`  | brightness up   |
| `f7`  | previous track  |
| `f8`  | play/pause      |
| `f9`  | next track      |
| `f10` | mute            |
| `f11` | volume down     |
| `f12` | volume up       |

### chords

| chord       | output  |
| ----------- | ------- |
| `w` + `e`   | `-`     |
| `x` + `c`   | `_`     |
| `q` + `w`   | `` ` `` |
| `tab` + `q` | `~`     |

### space-hold layer (arrows)

hold `space` to activate the arrows layer. synced from QMK Layer 1 (Iris split keyboard).

**number row — screenshot shortcuts:**

| key | output      |
| --- | ----------- |
| 2   | Cmd+Shift+2 |
| 3   | Cmd+Shift+3 |

mirrors `SGUI(KC_2)` / `SGUI(KC_3)` from QMK Layer 1 (macOS screenshot-style shortcuts).

**qwerty row — shifted symbols:**

| key | output |
| --- | ------ |
| tab | `~`    |
| q   | `!`    |
| w   | `@`    |
| e   | `#`    |
| r   | `$`    |
| t   | `%`    |
| y   | `^`    |
| u   | `&`    |
| i   | `*`    |
| o   | `(`    |
| p   | `)`    |

**home row — brackets, arrows, navigation:**

| key  | output         |
| ---- | -------------- |
| caps | tab            |
| a    | OSM(Shift+Cmd) |
| s    | `(`            |
| d    | `)`            |
| f    | `{`            |
| g    | `}`            |
| h    | left           |
| j    | down           |
| k    | up             |
| l    | right          |
| ;    | transparent    |
| '    | PgUp           |

**bottom row — quantum keys, brackets, symbols, math, navigation:**

| key  | output      |
| ---- | ----------- |
| lsft | Shift+Tab   |
| z    | LCtrl       |
| x    | Cmd+Shift+C |
| c    | keypad dot      |
| v    | `[`         |
| b    | `]`         |
| n    | `\`         |
| m    | `\|`        |
| ,    | `-`         |
| .    | `+`         |
| /    | `=`         |
| rsft | PgDn        |

## setup

```sh
brew install kanata
sudo ~/.config/kanata/scripts/setup-mac-service.sh
```

then grant **Input Monitoring** permission in System Settings > Privacy & Security > Input Monitoring.

## service management

| action             | command                                          |
| ------------------ | ------------------------------------------------ |
| check status       | `sudo launchctl list \| grep kanata`             |
| start / restart    | `sudo launchctl kickstart -k system/xbxd.kanata` |
| stop               | `sudo launchctl kill TERM system/xbxd.kanata`    |
| disable auto-start | `sudo launchctl disable system/xbxd.kanata`      |
| enable auto-start  | `sudo launchctl enable system/xbxd.kanata`       |
| unload             | `sudo launchctl bootout system/xbxd.kanata`      |

logs are at `/Library/Logs/Kanata/`.

## raycast integration

add `~/.config/kanata/scripts/raycast/` as a script directory in `Raycast Preferences > Extensions > Script Commands`.

| script              | action                               |
| ------------------- | ------------------------------------ |
| `kanata-start.sh`   | start (with auto-restart)            |
| `kanata-stop.sh`    | temporarily stop (will auto-restart) |
| `kanata-disable.sh` | disable completely — no auto-restart |
| `kanata-enable.sh`  | re-enable after disable              |
| `kanata-status.sh`  | show status and recent logs          |

## customization

tap-hold timing is set in `config.kbd` via the `tap-timeout` and `hold-timeout` variables. increase to reduce accidental modifier triggers, decrease for faster response.

to reload after any change:

```sh
sudo launchctl kickstart -k system/xbxd.kanata
```

## windows setup

windows uses a parallel config `config-windows.kbd` (cmd-style shortcuts retranslated to ctrl, screenshot row uses Win+Shift+S). device filtering requires the [Interception](https://github.com/oblitum/Interception) kernel driver — scoop's `kanata` package only ships the LLHOOK build which cannot scope to a single keyboard.

### one-time install

both steps are automated by chezmoi scripts under `.chezmoiscripts/windows/`:

```powershell
chezmoi apply    # downloads kanata_wintercept.exe + installs Interception (UAC prompt)
# REBOOT — Interception only attaches after a restart
```

### discover the laptop keyboard hwid

after reboot, list Interception-visible devices:

```powershell
& "$HOME\.local\bin\kanata_wintercept.exe" --list
```

**warning: `--list` is misleading.** it prints the device *path* (e.g. `\\?\ACPI#LEN0071#...`), but kanata's runtime matching uses the device's `HardwareID` property — a totally different value. paste the `--list` byte array and matching silently fails (`is intercepted: false`).

**correct discovery method:** stop the auto-start task, then run kanata in the foreground with debug logging:

```powershell
Stop-ScheduledTask -TaskName xbxd.kanata
& "$HOME\.local\bin\kanata_wintercept.exe" -c "$HOME\.config\kanata\config-windows.kbd" -d
```

(it'll error on parse if the placeholder is empty; that's fine -- we just need it loaded.) press a key on the laptop keyboard. it'll log something like:

```
[INFO] include check - res 90; device #1 is intercepted: false; hwid [65, 0, 67, 0, 80, 0, 73, 0, ...]
```

the array after `hwid` is what kanata's matcher compares against -- equality on the full 1024-byte buffer (`HWID_ARR_SZ` in kanata's source). copy the non-zero prefix (everything up to the long run of trailing zeros) into `windows-interception-keyboard-hwids (...)` in `dot_config/kanata/config-windows.kbd`. **syntax must be `N,N,N` -- bare commas, no spaces, no brackets, no surrounding parens.** kanata's parser accepts space-separated numbers too but treats each as a separate single-byte entry, so matching never fires.

decode every other byte as ASCII to verify visually -- on ThinkPads this typically reveals a `REG_MULTI_SZ` containing `ACPI\VEN_LEN&DEV_0071`, `ACPI\LEN0071`, and `*LEN0071` separated by `\0`.

then:

```powershell
chezmoi apply    # pushes the updated config + registers the Scheduled Task (UAC prompt)
```

### service management

| action       | command                                                   |
| ------------ | --------------------------------------------------------- |
| status       | `Get-ScheduledTask -TaskName xbxd.kanata \| Get-ScheduledTaskInfo` |
| start        | `Start-ScheduledTask -TaskName xbxd.kanata`               |
| stop         | `Stop-ScheduledTask -TaskName xbxd.kanata`                |
| restart      | `Stop-ScheduledTask xbxd.kanata; Start-ScheduledTask xbxd.kanata` |
| disable      | `Disable-ScheduledTask -TaskName xbxd.kanata`             |
| enable       | `Enable-ScheduledTask -TaskName xbxd.kanata`              |
| unregister   | `Unregister-ScheduledTask -TaskName xbxd.kanata -Confirm:$false` |

logs are appended to `%LOCALAPPDATA%\Kanata\kanata.log`.

### powershell helpers / raycast integration

mirrors the macOS Raycast scripts. live under `~\.config\kanata\scripts\windows\` with the same `@raycast.*` comment-directives as the Mac side, so Raycast for Windows can index them as Script Commands.

| script                | action                                                |
| --------------------- | ----------------------------------------------------- |
| `kanata-start.ps1`    | start the task (will NOT auto-restart on this OS)     |
| `kanata-stop.ps1`     | stop the running instance; task remains enabled       |
| `kanata-disable.ps1`  | stop + prevent the task from triggering at next logon |
| `kanata-enable.ps1`   | re-enable a disabled task and start it                |
| `kanata-status.ps1`   | show task state, process, and recent log lines        |

invoke from any PowerShell:

```powershell
& "$HOME\.config\kanata\scripts\windows\kanata-status.ps1"
```

start/stop/enable/disable do NOT require an elevated shell because we own the task; the actions just call `Start-ScheduledTask` / `Stop-ScheduledTask` etc. against the user's own task store.

to expose them in Raycast: open `Raycast Settings > Extensions > Script Commands > Add Script Directory` and point it at `%USERPROFILE%\.config\kanata\scripts\windows` -- the five commands appear under the "Kanata" package, mirroring the Mac UX. alternatively bind hotkeys via PowerToys Keyboard Manager or AutoHotkey.

### external keyboards

usb / bluetooth keyboards (Iris, etc.) are intentionally unaffected — only the HWID listed in `windows-interception-keyboard-hwids` is intercepted. all other inputs pass through to windows untouched, so qmk/vial layouts on external boards keep their native behavior.
