# themes

a single `theme` key in `.chezmoidata/defaults.yml` drives colors across ghostty, pi, tmux, nvim, btop, bat, starship, glow, zed, espanso, Sketchybar, and yabai borders.

## switching

```sh
theme                    # interactive picker (gum)
theme tokyonight-night   # switch directly
theme --list             # list available themes (active marked)
theme --current          # print active theme
```

the script writes the choice to `.chezmoidata/local.yml`, runs `chezmoi apply`, and live-reloads tmux, ghostty, borders, Sketchybar, nvim (over its socket), and espanso.

a few apps need a manual restart to pick up the new theme:

- btop, mactop, zed, vscode
- `bat` re-reads its config on next invocation

## pi

pi uses a chezmoi-generated theme named `chezmoi` at `~/.pi/agent/themes/chezmoi.json` plus a powerline footer override at `~/.pi/agent/extensions/powerline-footer/theme.json`.

`pi-ghostty-theme-sync` is not the source of truth for pi colors. The package may remain installed, but its startup extension is disabled so it cannot replace the active pi theme with a `ghostty-sync-*` theme.

After switching themes, restart or reload pi if the running session does not hot-reload the generated theme files.

## where it's stored

| file                            | role                                                                  |
| ------------------------------- | --------------------------------------------------------------------- |
| `.chezmoidata/defaults.yml`     | tracked default — falls back here if no override                      |
| `.chezmoidata/local.yml`        | gitignored, host-local override — `theme` writes here                 |
| `.chezmoidata/themes.yml`       | registry: palette + per-app theme names                               |
| `dot_pi/agent/themes/chezmoi.json.tmpl` | pi TUI theme generated from the active palette                         |
| `dot_pi/agent/extensions/powerline-footer/theme.json.tmpl` | pi powerline/status chrome generated from the active palette            |

chezmoi merges `.chezmoidata/*.yml` lexicographically, so `local.yml` beats `defaults.yml`.

## adding a theme

edit `.chezmoidata/themes.yml` and add a new entry under `themes:` with both blocks fully populated:

```yaml
themes:
  my-theme:
    palette:
      bg: "#..."
      # ...every key listed in existing themes
    apps:
      ghostty:    "Theme Name"
      btop:       "theme_name"
      # ...every app listed in existing themes
```

then `theme my-theme` to switch.
