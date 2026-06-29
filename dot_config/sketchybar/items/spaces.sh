#!/bin/bash

if ! command -v aerospace >/dev/null 2>&1; then
    exit 0
fi

WORKSPACES=$(aerospace list-workspaces --all)
FOCUSED=$(aerospace list-workspaces --focused)
APP_FONT="sketchybar-app-font"

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

    # Only show spaces that hold windows, plus the focused space (so you never
    # lose track of where you are). Empty non-focused spaces stay hidden until
    # a window appears; aerospace.sh keeps `drawing` in sync on later events.
    if [ "$workspace" = "$FOCUSED" ] || workspace_has_windows "$workspace"; then
        SPACE_Drawing=on
    else
        SPACE_Drawing=off
    fi

    sketchybar --add item space."$workspace" left \
        --set space."$workspace" \
        drawing="$SPACE_Drawing" \
        icon="$num" \
        icon.font="$FONT:Regular:14.0" \
        icon.color="$IC_COLOR" \
        icon.padding_left="$ITEM_PADDING" \
        icon.padding_right="$ITEM_PADDING" \
        background.color="$SPACE_ACTIVE_BG" \
        background.border_width=1 \
        background.corner_radius="$BORDER_RADIUS" \
        background.height="$PILL_HEIGHT" \
        background.drawing="$SPACE_BG_Drawing" \
        label.drawing=off \
        label.font="$APP_FONT:Regular:13.0" \
        label.color="$IC_COLOR" \
        label.padding_left=3 \
        label.padding_right="$ITEM_PADDING" \
        update_freq=60 \
        script="$PLUGIN_DIR/aerospace.sh $workspace" \
        click_script="aerospace workspace $workspace" \
        --subscribe space."$workspace" aerospace_workspace_change front_app_switched system_woke
done <<<"$WORKSPACES"

# consolidate spaces into a single shared pill
sketchybar --add bracket spaces '/space\..*/' \
    --set spaces \
    background.drawing=on \
    background.color="$PILL_BG" \
    background.border_color="$SPACES_COLOR" \
    background.border_width=1 \
    background.corner_radius="$BORDER_RADIUS" \
    background.height="$PILL_HEIGHT" \
    background.padding_left=0 \
    background.padding_right=0 \
    blur_radius=0
