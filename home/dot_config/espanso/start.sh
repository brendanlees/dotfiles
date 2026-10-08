#!/bin/sh
set -eu

# Espanso keeps this preference in its disposable runtime cache. Set it at
# login so cache cleanup cannot bring back the tutorial. Leave setup and
# Accessibility checks to the regular launcher.
runtime_dir="${ESPANSO_RUNTIME_DIR:-$HOME/Library/Caches/espanso}"
mkdir -p "$runtime_dir/kvs"
printf 'true' >"$runtime_dir/kvs/has_displayed_welcome"

exec /Applications/Espanso.app/Contents/MacOS/espanso launcher
