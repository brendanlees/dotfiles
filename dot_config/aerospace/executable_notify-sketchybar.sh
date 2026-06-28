#!/bin/bash

sketchybar_bin="$(command -v sketchybar || true)"

if [ -z "$sketchybar_bin" ] && [ -x /opt/homebrew/bin/sketchybar ]; then
  sketchybar_bin=/opt/homebrew/bin/sketchybar
fi

if [ -z "$sketchybar_bin" ]; then
  exit 0
fi

"$sketchybar_bin" --trigger aerospace_workspace_change \
  FOCUSED_WORKSPACE="${AEROSPACE_FOCUSED_WORKSPACE:-}" \
  PREV_WORKSPACE="${AEROSPACE_PREV_WORKSPACE:-}"
