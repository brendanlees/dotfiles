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
| `caps` | esc | —     |
| `lmet` | bspc | cmd  |

tap-timeout: 300ms, hold-timeout: 200ms.

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
| c    | Cmd+Shift+Space |
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
