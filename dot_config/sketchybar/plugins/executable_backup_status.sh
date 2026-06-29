#!/bin/bash

# shellcheck disable=SC1091
source "$CONFIG_DIR/colors.sh"

arq_active=false
timemachine_active=false

if tmutil status 2>/dev/null | grep -q 'Running = 1'; then
  timemachine_active=true
fi

arq_cmd="/Applications/Arq.app/Contents/Resources/arqc"
if [ -x "$arq_cmd" ]; then
  while IFS= read -r uuid; do
    [ -n "$uuid" ] || continue
    if "$arq_cmd" latestBackupActivityJSON "$uuid" 2>/dev/null | python3 -c '
import json, sys
raw = sys.stdin.read()
start = raw.find("{")
if start < 0:
    raise SystemExit(1)
try:
    data = json.loads(raw[start:])
except Exception:
    raise SystemExit(1)
message = str(data.get("message") or "").lower()
finished = data.get("finishedTime")
idleish = ("idle", "finished", "complete", "completed", "paused", "waiting")
active = (
    str(data.get("type") or "").lower() == "backup"
    and not data.get("aborted", False)
    and (finished in (None, 0, "0"))
    and not any(word in message for word in idleish)
)
raise SystemExit(0 if active else 1)
'; then
      arq_active=true
      break
    fi
  done <<EOF
$("$arq_cmd" listBackupPlans 2>/dev/null | sed -n 's/^UUID=\([^[:space:]]*\).*/\1/p')
EOF
fi

if [ "$arq_active" = true ] || [ "$timemachine_active" = true ]; then
  arq_color="$GREY"
  timemachine_color="$GREY"
  border_color="$GREY"

  if [ "$arq_active" = true ]; then
    arq_color="$BLUE"
    border_color="$BLUE"
  fi
  if [ "$timemachine_active" = true ]; then
    timemachine_color="$GREEN"
    border_color="$GREEN"
  fi
  if [ "$arq_active" = true ] && [ "$timemachine_active" = true ]; then
    border_color="$CYAN"
  fi

  sketchybar \
    --set backup_status drawing=on \
    --set backup_dot_arq drawing=on icon.color="$arq_color" \
    --set backup_dot_timemachine drawing=on icon.color="$timemachine_color" \
    --set backup_status_group background.drawing=on background.border_color="$border_color"
else
  sketchybar \
    --set backup_status drawing=off \
    --set backup_dot_arq drawing=off \
    --set backup_dot_timemachine drawing=off \
    --set backup_status_group background.drawing=off
fi
