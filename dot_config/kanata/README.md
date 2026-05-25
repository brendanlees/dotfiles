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

find the entry matching the built-in keyboard (on Lenovo ThinkPads, this is the `ACPI#LEN...` device; other vendors use similar `ACPI#<vendor-id>` patterns or `HID#VID_<oem>`). copy the **byte array** kanata prints for that device (not the path string) into the `windows-interception-keyboard-hwids (...)` block in `dot_config/kanata/config-windows.kbd`. byte arrays are preferred over escaped strings because ACPI paths often contain bytes that don't round-trip through `\\` escaping. then:

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

### external keyboards

usb / bluetooth keyboards (Iris, etc.) are intentionally unaffected — only the HWID listed in `windows-interception-keyboard-hwids` is intercepted. all other inputs pass through to windows untouched, so qmk/vial layouts on external boards keep their native behavior.
