#!/bin/bash

if ! command -v aerospace >/dev/null 2>&1; then
    exit 0
fi

# SketchyBar arrangement IDs for the primary and secondary bars.
PRIMARY_DISPLAY=1
SECONDARY_DISPLAY=2
WORKSPACES=$(aerospace list-workspaces --all | sort -t- -k1,1n -k2,2)
FOCUSED=$(aerospace list-workspaces --focused)
APP_FONT="sketchybar-app-font"
SPACE_ITEMS=()

# Rebuild spaces from scratch on reload so SketchyBar cannot preserve a stale
# runtime order from previous restarts/hotloads.
sketchybar --remove spaces >/dev/null 2>&1 || true
sketchybar --remove secondary_space_indicator_group >/dev/null 2>&1 || true

existing_space_items=$(sketchybar --query bar 2>/dev/null | /usr/bin/python3 -c '
import json
import sys
try:
    items = json.load(sys.stdin).get("items", [])
except Exception:
    items = []
for item in items:
    if item.startswith("space.") or item == "secondary_space_indicator":
        print(item)
' || true)

while IFS= read -r existing_space_item; do
    [ -n "$existing_space_item" ] || continue
    sketchybar --remove "$existing_space_item" >/dev/null 2>&1 || true
done <<<"$existing_space_items"

# Returns success (0) if the given workspace currently contains any windows.
workspace_has_windows() {
    aerospace list-windows --workspace "$1" --json 2>/dev/null |
        /usr/bin/python3 -c '
import json, sys
try:
    windows = json.load(sys.stdin)
except Exception:
    windows = []
sys.exit(0 if windows else 1)
'
}

while IFS= read -r workspace; do
    [ -n "$workspace" ] || continue

    num="${workspace%%-*}"

    if [ "$workspace" = "$FOCUSED" ]; then
        IC_COLOR=$WHITE
        SPACE_BG_Drawing=on
    else
        IC_COLOR=$MUTED
        SPACE_BG_Drawing=off
    fi

    if [ "$workspace" = "$FOCUSED" ] || workspace_has_windows "$workspace"; then
        SPACE_Drawing=on
    else
        SPACE_Drawing=off
    fi

    SPACE_ITEMS+=("space.$workspace")

    sketchybar --add item space."$workspace" left \
        --set space."$workspace" \
        drawing="$SPACE_Drawing" \
        display="$PRIMARY_DISPLAY" \
        icon="$num" \
        icon.font="$FONT:Regular:16.0" \
        icon.color="$IC_COLOR" \
        icon.padding_left="$ITEM_PADDING" \
        icon.padding_right="$ITEM_PADDING" \
        background.color="$SURFACE" \
        background.border_width=1 \
        background.corner_radius=0 \
        background.height="$PILL_HEIGHT" \
        background.drawing="$SPACE_BG_Drawing" \
        label.drawing=off \
        label.font="$APP_FONT:Regular:11.0" \
        label.color="$IC_COLOR" \
        label.padding_left=4 \
        label.padding_right="$ITEM_PADDING" \
        update_freq=60 \
        script="$PLUGIN_DIR/aerospace.sh $workspace" \
        click_script="aerospace workspace $workspace" \
        --subscribe space."$workspace" aerospace_workspace_change display_change front_app_switched system_woke
done <<<"$WORKSPACES"

# consolidate spaces into a single shared pill
sketchybar --add bracket spaces '/space\..*/' \
    --set spaces \
    display="$PRIMARY_DISPLAY" \
    background.drawing=on \
    background.color="$PILL_BG" \
    background.border_color="$TRANSPARENT" \
    background.border_width=1 \
    background.corner_radius="$BORDER_RADIUS" \
    background.height="$PILL_HEIGHT" \
    background.padding_left=0 \
    background.padding_right=0 \
    blur_radius=0

secondary_workspace=$(aerospace list-workspaces \
    --monitor all --visible \
    --format '%{monitor-is-main}%{tab}%{workspace}' 2>/dev/null |
    awk -F '\t' '$1 == "false" { print $2; exit }' || true)
secondary_num="${secondary_workspace%%-*}"
secondary_drawing=off
secondary_click_script=:
if [ -n "$secondary_workspace" ]; then
    secondary_drawing=on
    secondary_click_script="aerospace workspace $secondary_workspace"
fi

sketchybar --add item secondary_space_indicator left \
    --set secondary_space_indicator \
    drawing="$secondary_drawing" \
    display="$SECONDARY_DISPLAY" \
    icon="$secondary_num" \
    icon.font="$FONT:Regular:16.0" \
    icon.color="$MUTED" \
    icon.padding_left="$ITEM_PADDING" \
    icon.padding_right="$ITEM_PADDING" \
    background.color="$SURFACE" \
    background.border_width=1 \
    background.corner_radius=0 \
    background.height="$PILL_HEIGHT" \
    background.drawing=off \
    label.drawing=off \
    label.font="$APP_FONT:Regular:11.0" \
    label.color="$MUTED" \
    label.padding_left=4 \
    label.padding_right="$ITEM_PADDING" \
    update_freq=60 \
    script="$PLUGIN_DIR/aerospace.sh secondary" \
    click_script="$secondary_click_script" \
    --subscribe secondary_space_indicator aerospace_workspace_change display_change front_app_switched system_woke

sketchybar --add bracket secondary_space_indicator_group '/^secondary_space_indicator$/' \
    --set secondary_space_indicator_group \
    display="$SECONDARY_DISPLAY" \
    background.drawing=on \
    background.color="$PILL_BG" \
    background.border_color="$TRANSPARENT" \
    background.border_width=1 \
    background.corner_radius="$BORDER_RADIUS" \
    background.height="$PILL_HEIGHT" \
    background.padding_left=0 \
    background.padding_right=0 \
    blur_radius=0

if [ "${#SPACE_ITEMS[@]}" -gt 0 ]; then
    sketchybar --reorder "${SPACE_ITEMS[@]}"
fi
