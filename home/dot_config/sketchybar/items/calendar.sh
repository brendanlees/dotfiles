#!/bin/bash

DATO_CLICK="osascript -e 'tell application \"System Events\" to keystroke \"c\" using {control down, option down}' || open -a Dato"

# Clear obsolete event indicators when reloading an already-running bar.
for old_item in cal_dot_neutral cal_dot_per cal_dot_work cal_dot_fam calendar_event_clock; do
    if sketchybar --query "$old_item" >/dev/null 2>&1; then
        sketchybar --remove "$old_item"
    fi
done

# Right-side items render right-to-left. Add time first for date, then time.
sketchybar --add item calendar_time right \
    --set calendar_time \
    icon.font="$FONT:Regular:13.0" \
    icon.color="$WHITE" \
    icon.padding_left=2 \
    icon.padding_right=4 \
    label.drawing=off \
    background.drawing=off \
    padding_left="$ITEM_PADDING" \
    padding_right="$ITEM_PADDING" \
    update_freq=0 \
    click_script="$DATO_CLICK"

sketchybar --add item calendar right \
    --set calendar \
    icon="$ICON_CALENDAR" \
    icon.font="$FONT:Regular:18.0" \
    icon.color="$CALENDAR_COLOR" \
    icon.padding_left=6 \
    icon.padding_right=4 \
    label.font="$FONT:Regular:13.0" \
    label.color="$WHITE" \
    label.padding_left=4 \
    label.padding_right=12 \
    background.drawing=off \
    padding_left=4 \
    padding_right=0 \
    update_freq=15 \
    script="$PLUGIN_DIR/calendar.sh" \
    click_script="$DATO_CLICK" \
    --subscribe calendar system_woke

sketchybar --add bracket calendar_group '/calendar$/' '/calendar_time$/' \
    --set calendar_group \
    background.drawing=on \
    background.color="$PILL_BG" \
    background.border_color="$SURFACE" \
    background.border_width=1 \
    background.corner_radius="$BORDER_RADIUS" \
    background.height="$PILL_HEIGHT" \
    blur_radius=0
