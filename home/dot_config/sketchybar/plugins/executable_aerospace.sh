#!/bin/bash

CONFIG_DIR="${CONFIG_DIR:-${HOME}/.config/sketchybar}"
# shellcheck source=dot_config/sketchybar/colors.sh
source "$CONFIG_DIR/colors.sh"

aerospace_bin="$(command -v aerospace || true)"
if [ -z "$aerospace_bin" ] && [ -x /opt/homebrew/bin/aerospace ]; then
  aerospace_bin=/opt/homebrew/bin/aerospace
fi
secondary_muted_color="${SECONDARY_MUTED:-$MUTED}"

workspace_selector="${1:-}"
if [ -z "$workspace_selector" ]; then
  exit 0
fi

is_secondary_indicator=false
workspace="$workspace_selector"
workspace_is_secondary=false
if [ "$workspace_selector" = "secondary" ]; then
  is_secondary_indicator=true
  workspace="${2:-}"
fi
if [ -z "$workspace" ]; then
  exit 0
fi

if [ -n "$aerospace_bin" ]; then
  workspace_is_secondary="$("$aerospace_bin" list-workspaces \
    --monitor all \
    --format '%{monitor-is-main}%{tab}%{workspace}' 2>/dev/null |
    awk -F '\t' -v target="$workspace" \
      '$1 == "false" && $2 == target { print "yes"; exit }' || true)"
fi

focused_workspace="${FOCUSED_WORKSPACE:-}"
if [ -z "$focused_workspace" ] && [ -n "$aerospace_bin" ]; then
  focused_workspace="$($aerospace_bin list-workspaces --focused 2>/dev/null || true)"
fi

item_name="${NAME:-space.$workspace}"

if [ "$is_secondary_indicator" = true ]; then
  sketchybar --set "$item_name" \
    icon="${workspace%%-*}" \
    click_script="aerospace workspace $workspace"
  if [ "$workspace_is_secondary" != yes ]; then
    sketchybar --set "$item_name" \
      drawing=off \
      icon.color="$MUTED" \
      background.drawing=off \
      label="" \
      label.drawing=off
    exit 0
  fi
fi

# Focus is conveyed by icon/label color plus a highlight block drawn behind
# the focused space item, inside its shared spaces pill.
if [ "$workspace" = "$focused_workspace" ]; then
  IC_COLOR="$WHITE"
  SPACE_BG_Drawing=on
elif [ "$is_secondary_indicator" = false ] && [ "$workspace_is_secondary" = yes ]; then
  IC_COLOR="$secondary_muted_color"
  SPACE_BG_Drawing=off
else
  IC_COLOR="$MUTED"
  SPACE_BG_Drawing=off
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

if [ -n "$app_name" ] || [ "$workspace" = "$focused_workspace" ]; then
  SPACE_Drawing=on
else
  SPACE_Drawing=off
fi

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
    drawing="$SPACE_Drawing" \
    icon.color="$IC_COLOR" \
    background.drawing="$SPACE_BG_Drawing" \
    label="$app_icon" \
    label.color="$IC_COLOR" \
    label.drawing=on
else
  sketchybar --set "$item_name" \
    drawing="$SPACE_Drawing" \
    icon.color="$IC_COLOR" \
    background.drawing="$SPACE_BG_Drawing" \
    label="" \
    label.drawing=off
fi
