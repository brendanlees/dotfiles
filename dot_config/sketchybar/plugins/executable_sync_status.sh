#!/bin/bash

# shellcheck disable=SC1091
source "$CONFIG_DIR/colors.sh"

STATE_DIR="${TMPDIR:-/tmp}/sketchybar-sync-status"
mkdir -p "$STATE_DIR"

syncthing_color="$GREY"
mutagen_color="$GREY"

have() {
  command -v "$1" >/dev/null 2>&1
}

syncthing_running() {
  pgrep -x syncthing >/dev/null 2>&1 || pgrep -f '/syncthing( |$)' >/dev/null 2>&1
}

syncthing_total_bytes() {
  syncthing cli show connections 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    total = data.get("total") or {}
    print(int(total.get("inBytesTotal") or 0) + int(total.get("outBytesTotal") or 0))
except Exception:
    sys.exit(1)
'
}

if syncthing_running; then
  syncthing_color="$GREEN"
  if have syncthing && bytes="$(syncthing_total_bytes)"; then
    previous_file="$STATE_DIR/syncthing-bytes"
    previous="$(cat "$previous_file" 2>/dev/null || true)"
    if [ -n "$previous" ] && [ "$bytes" != "$previous" ]; then
      syncthing_color="$YELLOW"
    fi
    printf '%s\n' "$bytes" > "$previous_file"
  fi
else
  rm -f "$STATE_DIR/syncthing-bytes"
fi

if have mutagen; then
  if mutagen_json="$(mutagen sync list --template '{{ json . }}' 2>/dev/null)"; then
    mutagen_color="$(printf '%s' "$mutagen_json" | python3 -c '
import json, sys
try:
    sessions = json.load(sys.stdin)
except Exception:
    print("GREY")
    raise SystemExit

if not sessions:
    print("GREY")
    raise SystemExit

active = [s for s in sessions if not s.get("paused")]
if not active:
    print("GREY")
    raise SystemExit

for s in active:
    if not (s.get("alpha") or {}).get("connected", True) or not (s.get("beta") or {}).get("connected", True):
        print("RED")
        raise SystemExit
    status = str(s.get("status") or "").lower()
    if any(word in status for word in ("problem", "error", "conflict", "halt", "disconnect")):
        print("RED")
        raise SystemExit

for s in active:
    status = str(s.get("status") or "").lower()
    if status and status not in ("watching", "idle"):
        print("YELLOW")
        raise SystemExit

print("GREEN")
')"
    case "$mutagen_color" in
      RED) mutagen_color="$RED" ;;
      YELLOW) mutagen_color="$YELLOW" ;;
      GREEN) mutagen_color="$GREEN" ;;
      *) mutagen_color="$GREY" ;;
    esac
  elif pgrep -x mutagen >/dev/null 2>&1; then
    mutagen_color="$RED"
  fi
fi

border_color="$GREY"
if [ "$syncthing_color" = "$RED" ] || [ "$mutagen_color" = "$RED" ]; then
  border_color="$RED"
elif [ "$syncthing_color" = "$YELLOW" ] || [ "$mutagen_color" = "$YELLOW" ]; then
  border_color="$YELLOW"
elif [ "$syncthing_color" = "$GREEN" ] || [ "$mutagen_color" = "$GREEN" ]; then
  border_color="$GREEN"
fi

sketchybar \
  --set sync_dot_syncthing icon.color="$syncthing_color" \
  --set sync_dot_mutagen icon.color="$mutagen_color" \
  --set sync_status_group background.border_color="$border_color"
