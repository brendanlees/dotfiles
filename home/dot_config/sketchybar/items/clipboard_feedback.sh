#!/bin/bash

# Fixed label width keeps CUT/COPY/PASTE the same size so the balance item can
# mirror it exactly and the focused-app pill stays centered while it flashes.
clipboard_feedback=(
    drawing=off
    icon.drawing=off
    label.font="$FONT:Bold:13.0"
    label.width=48
    label.align=center
    label.padding_left="$ITEM_PADDING"
    label.padding_right="$ITEM_PADDING"
    padding_left=3
    padding_right=3
)

# Leftmost invisible counterweight, toggled with the pill by Hammerspoon.
add_clipboard_balance() {
    sketchybar --add item clipboard_balance center \
        --set clipboard_balance "${clipboard_feedback[@]}" \
        label=" " \
        label.color="$TRANSPARENT" \
        background.drawing=off
}

# Rightmost pill, after the microphone circle when it is showing.
add_clipboard_feedback() {
    sketchybar --add item clipboard_feedback center \
        --set clipboard_feedback "${clipboard_feedback[@]}" \
        label.color="$GREEN" \
        background.color="$PILL_BG" \
        background.border_color="$SURFACE" \
        background.border_width=1 \
        background.corner_radius="$BORDER_RADIUS" \
        background.height="$PILL_HEIGHT" \
        background.drawing=on
}
