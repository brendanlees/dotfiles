# themes

a single `theme` key in `home/.chezmoidata/defaults.yml` drives colors across ghostty, pi, herdr, tmux, nvim, btop, bat, starship, glow, zed, atuin and sketchybar.

## switching

```sh
theme                    # interactive picker (gum)
theme tokyonight-night   # switch directly
theme --list             # list available themes (active marked)
theme --current          # print active theme
```

the script writes the choice to `home/.chezmoidata/local.yml`, applies configuration with `--exclude=scripts,externals`, then runs only the Pi and Spicetify theme hooks for the current OS. It does not install packages, update plugins or sync private repositories.

tmux, ghostty, herdr, borders, sketchybar and nvim are live-reloaded where available.

a few apps need a manual restart to pick up the new theme:

- btop, mactop, zed, vscode
- `bat` re-reads its config on next invocation

## harness integrations

### pi

on personal machines, dotfiles generate one theme named `chezmoi` at `~/.pi/agent/themes/chezmoi.json`. select it with `/theme` in Pi, or set `"theme": "chezmoi"` in the private harness settings.

the private Pi repository owns settings, packages and extensions. dotfiles do not rewrite those choices or generate a separate footer override. the theme writer runs after the external checkout because chezmoi cannot also manage ordinary files inside an external Git repository.

### herdr

herdr uses a chezmoi-generated config at `~/.config/herdr/config.toml`. The template maps the active semantic palette directly onto herdr's custom theme tokens, with the host terminal theme as the fallback.

### atuin

Atuin selects the generated `chezmoi` theme at `~/.config/atuin/themes/chezmoi.toml`. The template maps the active shared palette to Atuin's semantic colors and inherits any future meanings from Atuin's built-in `autumn` theme.

## file overview

| file                                                                          | role                                                                                    |
| ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `home/.chezmoidata/defaults.yml`                                              | tracked default - falls back here if no override                                        |
| `home/.chezmoidata/local.yml`                                                 | gitignored, host-local override - `theme` writes here                                   |
| `home/.chezmoidata/themes.yml`                                                | registry: palette + per-app theme names                                                 |
| `home/.chezmoitemplates/pi-theme.json.tmpl`                                   | shared source for the generated pi theme                                                |
| `home/dot_config/atuin/themes/chezmoi.toml.tmpl`                              | generated Atuin theme using the active shared palette                                   |
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
