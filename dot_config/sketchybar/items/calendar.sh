#!/bin/bash

ITSYCAL_CLICK="osascript -e 'tell application \"System Events\" to keystroke \"c\" using {control down, option down}' || open -a Itsycal"

# Remove old dot items from already-running SketchyBar sessions when this config
# is re-sourced after the dot-to-border migration.
for old_dot in cal_dot_neutral cal_dot_per cal_dot_work cal_dot_fam; do
    if sketchybar --query "$old_dot" >/dev/null 2>&1; then
        sketchybar --remove "$old_dot"
    fi
done

# Right-side items render right-to-left as they are added. Add the time first so
# the group reads left-to-right as: calendar/date, event clock, time.
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
    click_script="$ITSYCAL_CLICK"

sketchybar --add item calendar_event_clock right \
    --set calendar_event_clock \
    icon="$ICON_CLOCK" \
    icon.font="$FONT:Regular:16.0" \
    icon.color="$CALENDAR_COLOR" \
    icon.padding_left=4 \
    icon.padding_right=2 \
    label.drawing=off \
    background.drawing=off \
    padding_left=-2 \
    padding_right=-2 \
    script="$PLUGIN_DIR/calendar_dots.sh" \
    update_freq=300 \
    click_script="$ITSYCAL_CLICK" \
    --subscribe calendar_event_clock system_woke

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

sketchybar --add bracket calendar_group '/calendar$/' '/calendar_event_clock$/' '/calendar_time$/' \
    --set calendar_group \
    background.drawing=on \
    background.color="$PILL_BG" \
    background.border_color="$CALENDAR_COLOR" \
    background.border_width=1 \
    background.corner_radius="$BORDER_RADIUS" \
    background.height="$PILL_HEIGHT" \
    blur_radius=0

"$PLUGIN_DIR/calendar_dots.sh" >/dev/null 2>&1 &
