#!/bin/bash

WORKSPACES=$(aerospace list-workspaces --all)
FOCUSED=$(aerospace list-workspaces --focused)

while read -r workspace; do
  num="${workspace%%-*}"

  if [ "$workspace" = "$FOCUSED" ]; then
    BG_DRAWING=on
    IC_COLOR=$WHITE
  else
    BG_DRAWING=off
    IC_COLOR=$GREY
  fi

  sketchybar --add item space."$workspace" left \
    --set space."$workspace" \
      icon="$num" \
      icon.font="$FONT:Bold:13.0" \
      icon.color=$IC_COLOR \
      icon.padding_left=8 \
      icon.padding_right=8 \
      background.color=$BLUE \
      background.corner_radius=5 \
      background.height=22 \
      background.drawing=$BG_DRAWING \
      label.drawing=off \
      script="$PLUGIN_DIR/aerospace.sh $workspace" \
      click_script="aerospace workspace $workspace" \
    --subscribe space."$workspace" aerospace_workspace_change
done <<< "$WORKSPACES"
