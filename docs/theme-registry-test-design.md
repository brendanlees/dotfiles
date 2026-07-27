# Flexible theme registry test

## Problem

`tests/chezmoi/test-theme-registry.sh` duplicates the complete theme inventory in a hard-coded `expected` mapping. Removing a valid theme from `.chezmoidata/themes.yml` therefore fails the suite until the test inventory is manually updated. Theme membership is expected to change frequently, so membership itself is not a stable contract.

## Design

Discover themes directly from the rendered `themes` registry and validate every current entry. Keep the existing strict contracts for:

- exact `palette` and `apps` blocks;
- exact required palette and app keys;
- six-digit hexadecimal palette colors;
- dark Neovim background mode;
- distinct neutral and error tool surfaces; and
- optional existence of each configured Ghostty theme file when `GHOSTTY_THEME_DIR` is provided.

Require the registry to be a non-empty object. Derive Ghostty filenames from each current theme's `apps.ghostty` value instead of maintaining a second name mapping. Adding or removing a structurally valid theme will then require no test edit, while malformed current themes still fail.

## Verification

The existing focused test must move from its current `missing requested themes` failure to passing against the present registry. Static checks and the complete repository suite must also pass.

## Scope

Modify only `tests/chezmoi/test-theme-registry.sh` on a branch separate from the Hermes wrapper work. No target files or production systems are changed.
