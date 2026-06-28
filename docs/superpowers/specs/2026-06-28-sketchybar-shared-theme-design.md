# Sketchybar shared theme design

## Goal

Make Sketchybar use the same active theme state as the rest of the chezmoi-managed UI configuration. The active theme remains selected by `.chezmoidata/defaults.yml` with optional host-local override in `.chezmoidata/local.yml`, and palette values continue to come from `.chezmoidata/themes.yml`.

## Current state

Most theme-aware configs already template from `(index .themes .theme).palette`. Sketchybar currently sources `~/.config/sketchybar/colors.sh`, but the chezmoi source file `dot_config/sketchybar/colors.sh` is hard-coded to Tokyo Night colors, so it does not follow the active `.theme` value.

## Design

Convert `dot_config/sketchybar/colors.sh` into `dot_config/sketchybar/colors.sh.tmpl`. The rendered target remains `~/.config/sketchybar/colors.sh`, so `executable_sketchybarrc` can keep sourcing `$CONFIG_DIR/colors.sh` unchanged.

The template maps shared semantic palette keys to Sketchybar shell variables:

- `fg` drives `WHITE`, `ICON_COLOR`, and `LABEL_COLOR`.
- `bg` drives `BLACK`, `BAR_COLOR`, and `POPUP_BACKGROUND_COLOR`.
- `surface` drives `BAR_BORDER_COLOR` and `POPUP_BORDER_COLOR`.
- `error`, `success`, `primary`, `warn`, `orange`, `secondary`, `info`, and `border` drive the remaining accent variables.

Sketchybar colors use `0xAARRGGBB`, so the template converts palette `#RRGGBB` values by trimming `#`, lowercasing, and prefixing an alpha channel. Solid colors use `0xff`; bar and popup backgrounds keep the existing translucent `0xcc`; `TRANSPARENT` remains `0x00000000`.

## Theme switching behavior

Update `dot_local/bin/executable_theme` so after `chezmoi apply` it reloads Sketchybar when Sketchybar is running. This makes `theme <name>` propagate to the bar without requiring a manual restart.

## Documentation

Update `docs/themes.md` to list Sketchybar as a theme-driven app and document that the theme switcher live-reloads it.

## Verification

- Render the Sketchybar template with `chezmoi execute-template`.
- Run `bash -n` against the rendered `colors.sh` and the theme switcher.
- Run a targeted `chezmoi apply --dry-run` or equivalent render check if practical.
