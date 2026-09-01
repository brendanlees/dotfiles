#!/bin/bash

sketchybar_bin="$(command -v sketchybar || true)"
aerospace_bin="$(command -v aerospace || true)"

if [ -z "$sketchybar_bin" ] && [ -x /opt/homebrew/bin/sketchybar ]; then
  sketchybar_bin=/opt/homebrew/bin/sketchybar
fi

if [ -z "$aerospace_bin" ] && [ -x /opt/homebrew/bin/aerospace ]; then
  aerospace_bin=/opt/homebrew/bin/aerospace
fi

if [ -z "$sketchybar_bin" ]; then
  exit 0
fi

focused_workspace="${AEROSPACE_FOCUSED_WORKSPACE:-}"
previous_workspace="${AEROSPACE_PREV_WORKSPACE:-}"
focused_monitor_is_main="${FOCUSED_MONITOR_IS_MAIN:-}"

if [ -n "$aerospace_bin" ]; then
  if [ -z "$focused_workspace" ]; then
    focused_workspace="$($aerospace_bin list-workspaces --focused 2>/dev/null || true)"
  fi
  if [ -z "$focused_monitor_is_main" ]; then
    focused_monitor_is_main="$($aerospace_bin list-workspaces --focused --format '%{monitor-is-main}' 2>/dev/null || true)"
  fi
fi

"$sketchybar_bin" --trigger aerospace_workspace_change \
  FOCUSED_WORKSPACE="$focused_workspace" \
  PREV_WORKSPACE="$previous_workspace" \
  FOCUSED_MONITOR_IS_MAIN="$focused_monitor_is_main"
