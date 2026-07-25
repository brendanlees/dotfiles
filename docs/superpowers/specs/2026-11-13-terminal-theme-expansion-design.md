# Terminal Theme Registry Expansion Design

## Goal

Expand `.chezmoidata/themes.yml` with the requested dark terminal themes while preserving the registry's complete semantic palette and per-application mapping contract.

## Scope

Add 28 kebab-case theme entries:

- Black Metal and its ten named variants: Bathory, Burzum, Dark Funeral, Gorgoroth, Immortal, Khold, Marduk, Mayhem, Nile, and Venom
- Batman
- Darkmatrix
- Embers Dark
- Fahrenheit
- Flatland
- Japanesque
- Kanso Ink and Kanso Zen
- Miasma
- Mona Lisa
- Nvim Dark
- Sleepy Hollow
- Synthwave, Synthwave Alpha, and Synthwave Everything
- Twilight
- Wryan

Kanso Mist and Pearl and Darkermatrix are explicitly out of scope.

## Palette Sources and Mapping

Use the Ghostty themes bundled with the installed application as the authoritative source for theme names, backgrounds, foregrounds, cursor colors, and ANSI palettes. Map those colors into every semantic registry field, preserving each theme's character while ensuring readable contrast.

Use source background and foreground colors directly where practical. Select semantic accent, primary, secondary, success, warning, error, info, and orange values from the source ANSI palette. Derive surfaces, borders, muted text, comments, and quiet Pi tool backgrounds conservatively from source colors when the source does not define direct equivalents.

## Application Mappings

Set `apps.ghostty` to the exact bundled Ghostty theme name. For applications that have a matching installed theme, use its exact identifier. Otherwise, select the closest existing, known-good fallback by palette family, following the registry's current practice. Every entry must define all existing `apps` keys and use `dark` for `nvim_background`.

## Validation

Verification must:

1. Parse `.chezmoidata/themes.yml` as YAML.
2. Confirm all 28 requested keys exist and are unique.
3. Confirm every new entry has exactly the complete palette and app key sets used by existing entries.
4. Confirm every configured Ghostty theme exists in the bundled Ghostty theme directory.
5. Run the Pi theme template test.
6. Render representative chezmoi templates or run a source-state verification that exercises the registry.

No scripts, generators, application packages, or unrelated configuration will be added.
