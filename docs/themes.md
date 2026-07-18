# themes

a single `theme` key in `.chezmoidata/defaults.yml` drives colors across ghostty, pi, herdr, tmux, nvim, btop, bat, starship, glow, zed, espanso, Sketchybar, and yabai borders.

## switching

```sh
theme                    # interactive picker (gum)
theme tokyonight-night   # switch directly
theme --list             # list available themes (active marked)
theme --current          # print active theme
```

the script writes the choice to `.chezmoidata/local.yml`, runs `chezmoi apply`, and live-reloads tmux, ghostty, herdr, borders, Sketchybar, nvim (over its socket), and espanso.

a few apps need a manual restart to pick up the new theme:

- btop, mactop, zed, vscode
- `bat` re-reads its config on next invocation

## pi

pi uses a chezmoi-generated theme named `chezmoi` at `~/.pi/agent/themes/chezmoi.json` plus a powerline footer override at `~/.pi/agent/extensions/powerline-footer/theme.json`.

`pi-ghostty-theme-sync` is not the source of truth for pi colors. The package may remain installed, but its startup extension is disabled so it cannot replace the active pi theme with a `ghostty-sync-*` theme.

After switching themes, restart or reload pi if the running session does not hot-reload the generated theme files.

Pending and successful Pi tool blocks share each palette's hand-tuned `tool_neutral_bg`; failed tool blocks use the restrained `tool_error_bg`. This keeps normal tool calls visually quiet while preserving error emphasis. Pi's global semantic status colors remain unchanged.

## herdr

herdr uses a chezmoi-generated config at `~/.config/herdr/config.toml`. The template maps the active semantic palette directly onto herdr's custom theme tokens, with the host terminal theme as the fallback.

`theme` reloads the default running herdr server after `chezmoi apply`. Named herdr sessions use separate sockets and are not reloaded automatically in the initial evaluation setup.

## where it's stored

| file                            | role                                                                  |
| ------------------------------- | --------------------------------------------------------------------- |
| `.chezmoidata/defaults.yml`     | tracked default — falls back here if no override                      |
| `.chezmoidata/local.yml`        | gitignored, host-local override — `theme` writes here                 |
| `.chezmoidata/themes.yml`       | registry: palette + per-app theme names                               |
| `.chezmoitemplates/pi-theme.json.tmpl` | shared source for the generated Pi TUI theme |
| `dot_config/herdr/config.toml.tmpl` | tmux-compatible herdr keys and generated custom palette |
| `.chezmoiscripts/run_onchange_after_configure-pi-theme.py.tmpl` | POSIX atomic writer for `~/.pi/agent/themes/chezmoi.json` after the `.pi` external sync |
| `.chezmoiscripts/windows/run_onchange_after_configure-pi-theme.ps1.tmpl` | Windows atomic writer for the same generated runtime theme |
| `~/.pi/agent/themes/chezmoi.json` | ignored generated runtime output; never edit or track directly |

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
