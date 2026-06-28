#!/bin/bash

if ! command -v aerospace >/dev/null 2>&1; then
  exit 0
fi

WORKSPACES=$(aerospace list-workspaces --all)
FOCUSED=$(aerospace list-workspaces --focused)
APP_FONT="sketchybar-app-font"

while IFS= read -r workspace; do
  [ -n "$workspace" ] || continue

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
      icon.color="$IC_COLOR" \
      icon.padding_left=8 \
      icon.padding_right=4 \
      background.color="$BLUE" \
      background.corner_radius=5 \
      background.height=22 \
      background.drawing="$BG_DRAWING" \
      label.drawing=off \
      label.font="$APP_FONT:Regular:14.0" \
      label.color="$IC_COLOR" \
      label.padding_left=0 \
      label.padding_right=8 \
      update_freq=60 \
      script="$PLUGIN_DIR/aerospace.sh $workspace" \
      click_script="aerospace workspace $workspace" \
    --subscribe space."$workspace" aerospace_workspace_change front_app_switched system_woke
done <<< "$WORKSPACES"
