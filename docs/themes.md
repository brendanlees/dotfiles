# themes

a single `theme` key in `home/.chezmoidata/defaults.yml` drives colors across ghostty, pi, herdr, tmux, nvim, btop, bat, starship, glow, zed, atuin and sketchybar. the tracked default is `moonfly`; an existing host-local override still takes precedence.

## switching

```sh
theme                    # fuzzy interactive picker (fzf)
theme tokyonight-night   # switch directly
theme --list             # list available themes (active marked)
theme --current          # print active theme
```

type to fuzzy-filter theme names, then press Enter to select. Escape or Ctrl-C cancels without changing files or applying configuration. the picker requires the already-provisioned [fzf](https://github.com/junegunn/fzf#usage); direct selection does not.

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

## obsidian palette bridge

Personal, non-headless macOS machines generate `~/.config/chezmoi-theme/obsidian.css`. The stylesheet is dark-only and renders its tokens from the active chezmoi palette, while Minimal remains the UI framework. It owns Minimal's dark core, semantic, highlight, frame, overlay, surface and granular colour tokens; layout and typography remain local. It also supplies the palette's derived HSL components so existing snippets that use Minimal's `--base-*` or `--accent-*` variables do not silently retain the selected Minimal preset.

The public `theme` workflow refreshes this neutral file during `chezmoi apply`. It then invokes the optional executable `~/.config/chezmoi-theme/obsidian-sync` when present, passing the generated stylesheet path as its only argument. That adapter is deliberately not managed by this repository: it reads one absolute vault path from `~/.config/chezmoi-theme/obsidian-vault` (or `OBSIDIAN_THEME_VAULT_CONFIG`), then atomically updates only `.obsidian/snippets/chezmoi-theme.css`. It never edits `appearance.json`, enables snippets, replaces existing snippets, or touches personal overrides such as `[me] my-custom-css.css`.

Enable `chezmoi-theme` manually once in Obsidian and keep `[me] my-custom-css` after it in the enabled snippet order when it should win selector-based rules. The bridge has no `!important` declarations or element rules, so explicit personal rules - including important custom-property overrides - remain overrides. When Style Settings is active, its generated `body.theme-dark.css-settings-manager` rule is deliberately lower-specificity than the bridge; non-colour Style Settings choices such as layout and typography remain local. See [Minimal's custom color scheme guidance](https://minimal.guide/color-schemes) and [Obsidian's CSS snippet instructions](https://help.obsidian.md/snippets).

Do not use an in-vault symlink ([Obsidian symlink limitations](https://help.obsidian.md/symlinks)). A synced vault should have one deliberate writer for this generated file; separate device themes otherwise create last-writer-wins conflicts. On another device, install a private adapter only if that device is intended to regenerate the shared snippet. Rendering tests validate dynamic palette and derived HSL output plus routing, but not Obsidian's live reload or visual cascade.

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

## github palette provenance and app fallbacks

the GitHub imports cover the upstream dark styles except Colorblind and Tritanopia; light styles are excluded. Palette values come from [github-nvim-theme at `c106c9472154d6b2c74b74565616b877ae8ed31d`](https://github.com/projekt0n/github-nvim-theme/tree/c106c9472154d6b2c74b74565616b877ae8ed31d), the upstream `main` revision checked for this import (newer than release `v1.1.2`, commit `8db454eb272eabb349209ec62ceb63b8eea5f011`). This is palette provenance, not a plugin version change.

values were evaluated from the upstream [palette modules and Primer primitives](https://github.com/projekt0n/github-nvim-theme/tree/c106c9472154d6b2c74b74565616b877ae8ed31d/lua/github-theme/palette), using the [spec API](https://github.com/projekt0n/github-nvim-theme/blob/c106c9472154d6b2c74b74565616b877ae8ed31d/lua/github-theme/spec.lua): `bg`, `surface`, `surface_alt` use spec `bg1`, `bg2`, `bg3`; foreground/muted use `fg1`/`fg2`; comments use `syntax.comment`. Border/accent use palette `border.default`/`accent.fg`; primary/alternate/secondary use `blue.base`/`blue.bright`/`magenta.base`; success uses `success.fg`, warning/error/info use diagnostics, and info-alt/orange use `cyan.base`/`orange`. Tool backgrounds use upstream `neutral.subtle`/`danger.subtle`, including its own blend rounding. These are semantic mappings, not a complete copy of Neovim syntax highlighting or an app-wide accessibility guarantee.

- Neovim selects each exact upstream colorscheme through the existing plugin. `nvim-dark` remains unchanged: its palette is Nvim Dark, with only its Neovim mapping pointing to `github_dark`.
- Ghostty uses the corresponding bundled [GitHub terminal ports](https://github.com/mbadolato/iTerm2-Color-Schemes/tree/752a9c079396cc9939b86e893578ed81e80c140f/ghostty), not semantic recolouring. These are family matches, not exact Neovim palettes: notably “GitHub Dark” has background `#101216` and foreground `#8b949e`, versus Neovim's `#30363d`/`#e6edf3`. Default, Dimmed and High Contrast match the main background/foreground but differ in terminal accents, selections and ANSI colors.
- bat and btop retain the shipped `tokyonight_night` fallback; tmux-ukiyo uses `tokyonight/night` with the existing semantic overrides; Zed uses the existing “Tokyo Night” fallback, not a GitHub palette. No new app assets or plugins are installed.
- Starship palettes are generated from the registry. Glow's `auto` mapping selects the generated `chezmoi.json` style, not a built-in GitHub theme. Other semantic consumers, including Pi, use the imported colors through their existing templates.

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
