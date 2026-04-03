# font management

fonts are managed via chezmoi externals. on apply, configured fonts are downloaded from nerd fonts releases and installed to the appropriate system directory. ephemeral machines (ci, containers) are excluded.

## configuration

two values in `~/.config/chezmoi/chezmoi.toml` control font behaviour:

| key | purpose |
| --- | ------- |
| `active_font` | font family name used in terminal and editor configs |
| `fonts_installed` | array of nerd fonts archive names to install |

## adding a font

1. find the archive name on the [nerd fonts releases page](https://github.com/ryanoasis/nerd-fonts/releases) (e.g. `FiraCode`, `Hack`, `Monaspace`)
2. add it to `fonts_installed` in `~/.config/chezmoi/chezmoi.toml`:
   ```toml
   fonts_installed = ["JetBrainsMono", "Monaspace", "FiraCode"]
   ```
3. run `chezmoi apply`

## switching the active font

change `active_font` in `~/.config/chezmoi/chezmoi.toml` to the full font family name:

```toml
active_font = "Monaspace Nerd Font Mono"
```

then run `chezmoi apply` — all templated configs (ghostty, etc.) will update.

## offline / bundled fonts

for machines without internet access, fonts can be stored in the chezmoi source:

1. download the zip from the [nerd fonts releases page](https://github.com/ryanoasis/nerd-fonts/releases) (e.g. `JetBrainsMono.zip`)
2. place it at `fonts/JetBrainsMono.zip` in the chezmoi source directory
3. un-ignore it in `.chezmoiignore`:
   ```
   !fonts/JetBrainsMono.zip
   ```
4. commit and push — the local file will be used instead of downloading

## font directories

| os | directory |
| -- | --------- |
| macOS | `~/Library/Fonts/NerdFonts/{FontName}/` |
| Linux | `~/.local/share/fonts/NerdFonts/{FontName}/` |

on linux, `fc-cache -f` is run automatically after apply to register new fonts.
