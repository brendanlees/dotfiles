#!/bin/bash

CONFIG_DIR="${CONFIG_DIR:-${HOME}/.config/sketchybar}"
# shellcheck source=dot_config/sketchybar/colors.sh
source "$CONFIG_DIR/colors.sh"

workspace="${1:-}"
if [ -z "$workspace" ]; then
  exit 0
fi

# FOCUSED_WORKSPACE is provided by AeroSpace via SketchyBar's custom event.
# On initial/manual runs, fall back to querying AeroSpace directly.
focused_workspace="${FOCUSED_WORKSPACE:-}"
if [ -z "$focused_workspace" ] && command -v aerospace >/dev/null 2>&1; then
  focused_workspace="$(aerospace list-workspaces --focused 2>/dev/null || true)"
fi

if [ -z "$focused_workspace" ]; then
  exit 0
fi

item_name="${NAME:-space.$workspace}"

if [ "$workspace" = "$focused_workspace" ]; then
  sketchybar --set "$item_name" background.drawing=on icon.color="$WHITE"
else
  sketchybar --set "$item_name" background.drawing=off icon.color="$GREY"
fi
