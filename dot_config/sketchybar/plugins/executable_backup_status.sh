#!/bin/bash

# shellcheck disable=SC1091
source "$CONFIG_DIR/colors.sh"

tint_color() {
  case "$1" in
    0x????????) printf '0x88%s\n' "${1#0x??}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

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
  status_color="$GREY"

  if [ "$arq_active" = true ]; then
    status_color="$BLUE"
  fi
  if [ "$timemachine_active" = true ]; then
    status_color="$GREEN"
  fi
  if [ "$arq_active" = true ] && [ "$timemachine_active" = true ]; then
    status_color="$CYAN"
  fi

  background_color="$(tint_color "$status_color")"

  sketchybar \
    --set backup_status drawing=on \
    --set backup_status_group background.drawing=on background.color="$background_color" background.border_color="$status_color"
else
  sketchybar \
    --set backup_status drawing=off \
    --set backup_status_group background.drawing=off background.color="$PILL_BG" background.border_color="$GREY"
fi
