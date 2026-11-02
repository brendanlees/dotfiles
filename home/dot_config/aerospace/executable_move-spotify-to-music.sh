#!/bin/sh
set -eu

if [ "${1:-}" = "--delay" ]; then
  sleep "${2:-1}"
fi

if ! command -v aerospace >/dev/null 2>&1; then
  exit 0
fi

aerospace list-windows --all --format '%{window-id}|%{app-bundle-id}' \
  | awk -F'|' '$2 == "com.spotify.client" { print $1 }' \
  | while IFS= read -r wid; do
      [ -n "$wid" ] || continue
      aerospace move-node-to-workspace --window-id "$wid" 9-music >/dev/null 2>&1 || true
    done
