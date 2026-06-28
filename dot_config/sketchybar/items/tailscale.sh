#!/bin/bash

# Item starts hidden; the plugin reveals it only when Tailscale is running.
# Icon is the `:tailscale:` token rendered by sketchybar-app-font (matches the
# icon library used by spaces.sh / front_app.sh / spotify.sh).
sketchybar --add item tailscale right \
    --set tailscale \
    drawing=off \
    icon=":tailscale:" \
    icon.font="sketchybar-app-font:Regular:16.0" \
    label.font="$FONT:Regular:13.0" \
    label.color="$WHITE" \
    background.color="$PILL_BG" \
    background.border_color="$GREY" \
    background.border_width=1 \
    background.corner_radius=8 \
    background.height=26 \
    background.drawing=on \
    padding_left=8 \
    padding_right=8 \
    update_freq=30 \
    script="$PLUGIN_DIR/tailscale.sh" \
    --subscribe tailscale system_woke
