#!/bin/bash

DOT_PINK="0xffE36BA0"
ITSYCAL_CLICK="osascript -e 'tell application \"System Events\" to keystroke \"c\" using {control down, option down}' || open -a Itsycal"

# Right-side items render right-to-left as they are added. Add the time first so
# the group reads left-to-right as: calendar/date, dots, time.
sketchybar --add item calendar_time right \
    --set calendar_time \
    icon.font="$FONT:Regular:13.0" \
    icon.color="$WHITE" \
    icon.padding_left=2 \
    icon.padding_right=4 \
    label.drawing=off \
    background.drawing=off \
    padding_left="$PADDINGS" \
    padding_right="$PADDINGS" \
    update_freq=0 \
    click_script="$ITSYCAL_CLICK"

for dot in cal_dot_neutral cal_dot_per cal_dot_work cal_dot_fam; do
    sketchybar --add item "$dot" right \
        --set "$dot" \
        icon="●" \
        icon.font="$FONT:Regular:12.0" \
        icon.padding_left=4 \
        icon.padding_right=2 \
        label.drawing=off \
        background.drawing=off \
        padding_left=-2 \
        padding_right=-2 \
        click_script="$ITSYCAL_CLICK"
done

sketchybar --set cal_dot_fam icon.color="$DOT_PINK" drawing=off \
    --set cal_dot_work icon.color="$ORANGE" drawing=off script="$PLUGIN_DIR/calendar_dots.sh" update_freq=300 \
    --set cal_dot_per icon.color="$GREEN" drawing=off \
    --set cal_dot_neutral icon.color="$GREY" drawing=on \
    --subscribe cal_dot_work system_woke

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
    click_script="$ITSYCAL_CLICK" \
    --subscribe calendar system_woke

sketchybar --add bracket calendar_group '/calendar$/' '/cal_dot_.*/' '/calendar_time$/' \
    --set calendar_group \
    background.drawing=on \
    background.color="$PILL_BG" \
    background.border_color="$CALENDAR_COLOR" \
    background.border_width=1 \
    background.corner_radius="$BORDER_RADIUS" \
    background.height=26 \
    blur_radius=0
