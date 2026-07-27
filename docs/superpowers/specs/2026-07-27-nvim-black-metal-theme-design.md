# Neovim Black Metal Theme Integration Design

## Goal

Make Neovim use the dedicated Black Metal colorscheme selected by the chezmoi global theme registry. With `black-metal-bathory` active, Neovim must load `bathory` rather than the current `monokai-pro` approximation.

## Architecture

Chezmoi remains the single source of truth:

1. `.chezmoidata/local.yml` selects the global theme.
2. `.chezmoidata/themes.yml` maps that theme to an application-specific Neovim colorscheme.
3. `dot_config/chezmoi-theme/active.lua.tmpl` renders the mapping to `~/.config/chezmoi-theme/active.lua`.
4. Neovim's `lua/plugins/astroui.lua` reads the bridge and asks AstroUI to load its `colorscheme` value.
5. lazy.nvim supplies the matching colorscheme through `metalelf0/black-metal-theme-neovim`.

No theme-name translation or palette duplication will be added to Neovim.

## Registry mappings

Map the generic `black-metal` entry to `bathory`, the plugin default. Map every band-specific registry entry supported by the plugin to its corresponding colorscheme name:

- `black-metal-bathory` to `bathory`
- `black-metal-burzum` to `burzum`
- `black-metal-dark-funeral` to `dark-funeral`
- `black-metal-gorgoroth` to `gorgoroth`
- `black-metal-immortal` to `immortal`
- `black-metal-khold` to `khold`
- `black-metal-marduk` to `marduk`
- `black-metal-mayhem` to `mayhem`
- `black-metal-nile` to `nile`
- `black-metal-venom` to `venom`

Other global themes retain their existing Neovim mappings.

## Neovim plugin configuration

Install `metalelf0/black-metal-theme-neovim` as a lazy-loadable colorscheme dependency alongside the other theme plugins. Individual `colors/<name>.lua` files initialize the plugin defaults and load the requested band, so no separate setup block is required.

The existing AstroUI bridge reader and live-reload command remain unchanged.

## Failure behavior

The existing AstroUI fallback remains `tokyonight-night` when the generated bridge is missing or invalid. lazy.nvim's normal colorscheme loading behavior handles a missing plugin. No new fallback or duplicated registry is introduced.

## Verification

- Extend the chezmoi theme-registry test to assert all Black Metal Neovim mappings.
- Render the active bridge and verify Bathory emits `colorscheme = "bathory"`.
- Sync/install Neovim plugins, then start Neovim headlessly and assert:
  - `vim.g.colors_name == "bathory"`
  - `Normal` uses the dedicated theme's black background.
- Run the existing chezmoi theme tests and Neovim configuration checks.
