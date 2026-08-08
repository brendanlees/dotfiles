#!/bin/bash

sketchybar_bin="$(command -v sketchybar || true)"

if [ -z "$sketchybar_bin" ] && [ -x /opt/homebrew/bin/sketchybar ]; then
  sketchybar_bin=/opt/homebrew/bin/sketchybar
fi

if [ -z "$sketchybar_bin" ]; then
  exit 0
fi

config_file="${HOME}/.config/sketchybar/sketchybarrc"
log_file="${TMPDIR:-/tmp}/sketchybar-aerospace-start.log"

if ! pgrep -x sketchybar >/dev/null 2>&1; then
  "$sketchybar_bin" --config "$config_file" >"$log_file" 2>&1 &
  sleep 1
fi

# Re-run the config so the AeroSpace workspace items and subscriptions exist.
"$sketchybar_bin" --reload "$config_file" >/dev/null 2>&1 || true

# Sync selected workspace state immediately after startup/reload.
"${HOME}/.config/aerospace/notify-sketchybar.sh" >/dev/null 2>&1 || true
