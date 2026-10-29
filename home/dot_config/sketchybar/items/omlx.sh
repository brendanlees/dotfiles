#!/bin/bash

# Stay hidden until local activity responds; keep polling to detect service startup.
# Token counters are fetched only while the menu is open.
sketchybar --add event omlx_toggle \
    --add item omlx right \
    --set omlx \
    drawing=off \
    icon="" \
    icon.color="$MUTED" \
    icon.padding_right=4 \
    label="Qwen · Checking" \
    label.font="$FONT:Regular:11.0" \
    label.padding_left=4 \
    background.border_color="$SURFACE" \
    padding_left="$ITEM_PADDING" \
    padding_right="$((ITEM_PADDING + GROUP_GAP))" \
    popup.align=right \
    popup.height=26 \
    update_freq=3 \
    updates=on \
    script="source \"$CONFIG_DIR/colors.sh\"; \"$PLUGIN_DIR/omlx.py\"" \
    --subscribe omlx mouse.clicked omlx_toggle mouse.exited.global system_woke

for row in model requests tokens cached scope; do
    sketchybar --add item "omlx.$row" popup.omlx \
        --set "omlx.$row" \
        icon.drawing=off \
        background.drawing=off \
        label="Checking…" \
        label.font="$FONT:Regular:12.0" \
        label.color="$WHITE" \
        label.padding_left=12 \
        label.padding_right=12
done
sketchybar --set omlx.scope label.color="$MUTED"
