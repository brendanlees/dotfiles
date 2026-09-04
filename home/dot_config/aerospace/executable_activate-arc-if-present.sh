#!/bin/sh
set -eu

aerospace_bin=$(command -v aerospace || true)
if [ -z "$aerospace_bin" ] && [ -x /opt/homebrew/bin/aerospace ]; then
  aerospace_bin=/opt/homebrew/bin/aerospace
fi
if [ -z "$aerospace_bin" ]; then
  exit 0
fi

arc_window_count=$(
  "$aerospace_bin" list-windows \
    --workspace 1-browser \
    --app-bundle-id company.thebrowser.Browser \
    --count 2>/dev/null || printf '0'
)

if [ "$arc_window_count" -gt 0 ]; then
  open -a Arc
fi
