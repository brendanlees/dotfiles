#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# $1 = workspace name set at creation time
# $FOCUSED_WORKSPACE set by sketchybar on aerospace_workspace_change
# On initial run FOCUSED_WORKSPACE is empty, query aerospace directly
if [ -z "$FOCUSED_WORKSPACE" ]; then
  FOCUSED_WORKSPACE=$(aerospace list-workspaces --focused)
fi

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
  sketchybar --set "$NAME" background.drawing=on icon.color=$WHITE
else
  sketchybar --set "$NAME" background.drawing=off icon.color=$GREY
fi
