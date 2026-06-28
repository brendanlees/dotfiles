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
    IC_COLOR=$WHITE
  else
    IC_COLOR=$MUTED
  fi

  sketchybar --add item space."$workspace" left \
    --set space."$workspace" \
      icon="$num" \
      icon.font="$FONT:Bold:13.0" \
      icon.color="$IC_COLOR" \
      icon.padding_left=6 \
      icon.padding_right=2 \
      background.drawing=off \
      label.drawing=off \
      label.font="$APP_FONT:Regular:14.0" \
      label.color="$IC_COLOR" \
      label.padding_left=2 \
      label.padding_right=6 \
      update_freq=60 \
      script="$PLUGIN_DIR/aerospace.sh $workspace" \
      click_script="aerospace workspace $workspace" \
    --subscribe space."$workspace" aerospace_workspace_change front_app_switched system_woke
done <<< "$WORKSPACES"

# consolidate spaces into a single shared pill
sketchybar --add bracket spaces '/space\..*/' \
  --set spaces \
    background.drawing=on \
    background.color="$PILL_BG" \
    background.border_color="$SPACES_COLOR" \
    background.border_width=1 \
    background.corner_radius=12 \
    background.height=26 \
    background.padding_left=4 \
    background.padding_right=4 \
    blur_radius=0
