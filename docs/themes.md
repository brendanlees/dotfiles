# themes

a single `theme` key in `home/.chezmoidata/defaults.yml` drives colors across ghostty, pi, herdr, tmux, nvim, btop, bat, starship, glow, zed and sketchybar.

## switching

```sh
theme                    # interactive picker (gum)
theme tokyonight-night   # switch directly
theme --list             # list available themes (active marked)
theme --current          # print active theme
```

the script writes the choice to `home/.chezmoidata/local.yml`, runs `chezmoi apply`, and live-reloads tmux, ghostty, herdr, borders, skeychbar and nvim (over its socket).

a few apps need a manual restart to pick up the new theme:

- btop, mactop, zed, vscode
- `bat` re-reads its config on next invocation

## harness integrations

### pi

pi uses a chezmoi-generated theme named `chezmoi` at `~/.pi/agent/themes/chezmoi.json` plus a custom powerline footer override at `~/.pi/agent/extensions/powerline-footer/theme.json`.

### herdr

herdr uses a chezmoi-generated config at `~/.config/herdr/config.toml`. The template maps the active semantic palette directly onto herdr's custom theme tokens, with the host terminal theme as the fallback.

## file overview

| file                                                                          | role                                                                                    |
| ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `home/.chezmoidata/defaults.yml`                                              | tracked default - falls back here if no override                                        |
| `home/.chezmoidata/local.yml`                                                 | gitignored, host-local override - `theme` writes here                                   |
| `home/.chezmoidata/themes.yml`                                                | registry: palette + per-app theme names                                                 |
| `home/.chezmoitemplates/pi-theme.json.tmpl`                                   | shared source for the generated pi theme                                                |
| `home/dot_config/herdr/config.toml.tmpl`                                      | tmux-compatible herdr keys and generated custom palette                                 |
| `home/.chezmoiscripts/run_onchange_after_configure-pi-theme.py.tmpl`          | posix atomic writer for `~/.pi/agent/themes/chezmoi.json` after the `.pi` external sync |
| `home/.chezmoiscripts/windows/run_onchange_after_configure-pi-theme.ps1.tmpl` | windows atomic writer for the same generated runtime theme                              |
| `~/.pi/agent/themes/chezmoi.json`                                             | pi generated runtime output (gitignored)                                                |

chezmoi merges `home/.chezmoidata/*.yml` 'lexicographically', so `local.yml` beats `defaults.yml`.

## adding a theme

edit `home/.chezmoidata/themes.yml` and add a new entry under `themes:` with both blocks fully populated:

```yaml
themes:
  my-theme:
    palette:
      bg: "#..."
      # ...every key listed in existing themes
    apps:
      ghostty: "Theme Name"
      btop: "theme_name"
      # ...every app listed in existing themes
```

then `theme my-theme` to switch.
