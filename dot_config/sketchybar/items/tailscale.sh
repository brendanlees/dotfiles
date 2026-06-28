#!/bin/bash

sketchybar --add item tailscale right \
  --set tailscale \
    update_freq=30 \
    script="$PLUGIN_DIR/tailscale.sh" \
  --subscribe tailscale system_woke
