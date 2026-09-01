#!/bin/sh
set -eu

aerospace_bin=$(command -v aerospace || true)
if [ -z "$aerospace_bin" ] && [ -x /opt/homebrew/bin/aerospace ]; then
  aerospace_bin=/opt/homebrew/bin/aerospace
fi

window_id=${AEROSPACE_WINDOW_ID:-}
app_id=${1:-}
target_workspace=${2:-}
if [ -z "$aerospace_bin" ] || [ -z "$window_id" ] || [ -z "$app_id" ] || [ -z "$target_workspace" ]; then
  exit 0
fi

other_window_count=$("$aerospace_bin" list-windows \
  --all \
  --app-bundle-id "$app_id" \
  --format '%{window-id}' 2>/dev/null |
  awk -v current="$window_id" '$0 != current && $0 != "" { count++ } END { print count + 0 }')

if [ "$other_window_count" -eq 0 ]; then
  "$aerospace_bin" move-node-to-workspace \
    --window-id "$window_id" "$target_workspace"
fi
