#!/bin/bash

CONFIG_DIR="${CONFIG_DIR:-${HOME}/.config/sketchybar}"
# shellcheck source=dot_config/sketchybar/colors.sh
source "$CONFIG_DIR/colors.sh"

aerospace_bin="$(command -v aerospace || true)"
if [ -z "$aerospace_bin" ] && [ -x /opt/homebrew/bin/aerospace ]; then
  aerospace_bin=/opt/homebrew/bin/aerospace
fi

workspace="${1:-}"
if [ -z "$workspace" ]; then
  exit 0
fi

focused_workspace="${FOCUSED_WORKSPACE:-}"
if [ -z "$focused_workspace" ] && [ -n "$aerospace_bin" ]; then
  focused_workspace="$($aerospace_bin list-workspaces --focused 2>/dev/null || true)"
fi

item_name="${NAME:-space.$workspace}"

if [ "$workspace" = "$focused_workspace" ]; then
  BG_DRAWING=on
  IC_COLOR="$WHITE"
else
  BG_DRAWING=off
  IC_COLOR="$GREY"
fi

representative_app() {
  local target_workspace=$1

  if [ "$target_workspace" = "$focused_workspace" ] && [ -n "${INFO:-}" ]; then
    printf '%s\n' "$INFO"
    return 0
  fi

  if [ -z "$aerospace_bin" ]; then
    return 0
  fi

  "$aerospace_bin" list-windows --workspace "$target_workspace" --json 2>/dev/null \
    | /usr/bin/python3 -c '
import json
import sys
try:
    windows = json.load(sys.stdin)
except Exception:
    windows = []
for window in windows:
    app = window.get("app-name", "")
    if app:
        print(app)
        break
'
}

app_name="$(representative_app "$workspace" || true)"

if [ -n "$app_name" ]; then
  icon_map="$CONFIG_DIR/plugins/icon_map.sh"
  app_icon=":default:"
  if [ -x "$icon_map" ]; then
    app_icon="$($icon_map "$app_name" 2>/dev/null || printf ':default:')"
  fi
  if [ -z "$app_icon" ]; then
    app_icon=":default:"
  fi

  sketchybar --set "$item_name" \
    background.drawing="$BG_DRAWING" \
    icon.color="$IC_COLOR" \
    label="$app_icon" \
    label.color="$IC_COLOR" \
    label.drawing=on
else
  sketchybar --set "$item_name" \
    background.drawing="$BG_DRAWING" \
    icon.color="$IC_COLOR" \
    label="" \
    label.drawing=off
fi
