#!/bin/bash

sketchybar --add item spotify right \
    --set spotify \
    drawing=off \
    icon=":spotify:" \
    icon.font="sketchybar-app-font:Regular:14.0" \
    icon.color="$SPOTIFY_COLOR" \
    label.font="$FONT:Regular:13.0" \
    label.color="$WHITE" \
    background.color="$PILL_BG" \
    background.border_color="$SPOTIFY_COLOR" \
    background.border_width=1 \
    background.corner_radius="$BORDER_RADIUS" \
    background.height="$PILL_HEIGHT" \
    background.drawing=on \
    padding_left="$ITEM_PADDING" \
    padding_right="$ITEM_PADDING" \
    update_freq=15 \
    script="$PLUGIN_DIR/spotify.sh" \
    click_script="$PLUGIN_DIR/spotify_control.sh popup" \
    popup.align=right \
    popup.horizontal=on \
    popup.height="$PILL_HEIGHT" \
    popup.background.color="$PILL_BG" \
    popup.background.border_color="$SPOTIFY_COLOR" \
    popup.background.border_width=1 \
    popup.background.corner_radius="$BORDER_RADIUS" \
    --subscribe spotify spotify_change media_change

spotify_control_item() {
  local name="$1"
  local icon="$2"
  local action="$3"

  sketchybar --add item "spotify.$name" popup.spotify \
      --set "spotify.$name" \
      icon="$icon" \
      icon.font="$FONT:Regular:14.0" \
      icon.color="$WHITE" \
      icon.align=center \
      label.drawing=off \
      background.drawing=off \
      width=28 \
      padding_left=2 \
      padding_right=2 \
      click_script="$PLUGIN_DIR/spotify_control.sh $action"
}

spotify_control_item previous "⏮" previous
spotify_control_item toggle "⏯" toggle
spotify_control_item next "⏭" next
spotify_control_item open "↗" activate
