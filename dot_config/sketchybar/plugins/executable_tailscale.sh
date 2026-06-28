#!/bin/bash

# shellcheck source=../colors.sh
source "$CONFIG_DIR/colors.sh"

# Nerd Font glyphs (dogfood-verify rendering in JetBrainsMono Nerd Font Mono).
ICON_TS_LOCK=󰌾
ICON_TS_EXIT=󰢷
ICON_TS_ALERT=󰂚

export TS_COLOR_GREY="$GREY" TS_COLOR_BLUE="$BLUE" TS_COLOR_YELLOW="$YELLOW" TS_COLOR_RED="$RED"
export TS_ICON_LOCK="$ICON_TS_LOCK" TS_ICON_EXIT="$ICON_TS_EXIT" TS_ICON_ALERT="$ICON_TS_ALERT"

if ! command -v tailscale >/dev/null 2>&1; then
  sketchybar --set "$NAME" drawing=off label=""
  exit 0
fi

status_json="$(tailscale status --json 2>/dev/null)" || {
  sketchybar --set "$NAME" drawing=off label=""
  exit 0
}

# Defensive: python3 is part of the expected toolchain (spotify plugin uses it too).
if [ ! -x /usr/bin/python3 ]; then
  sketchybar --set "$NAME" drawing=off label=""
  exit 0
fi

# JSON is passed as argv[1]; the program comes from the heredoc on stdin
# (same pattern as the spotify plugin). Output is TSV: drawing\ticon\tcolor\tlabel.
result="$(/usr/bin/python3 - "$status_json" <<'PY'
import json
import os
import sys

def env(name):
    return os.environ.get(name, "")

GREY, BLUE, YELLOW, RED = env("TS_COLOR_GREY"), env("TS_COLOR_BLUE"), env("TS_COLOR_YELLOW"), env("TS_COLOR_RED")
ICON_LOCK, ICON_EXIT, ICON_ALERT = env("TS_ICON_LOCK"), env("TS_ICON_EXIT"), env("TS_ICON_ALERT")

def trunc(s, n):
    s = s or ""
    if len(s) > n:
        s = s[: n - 1] + "…"
    return s

try:
    d = json.loads(sys.argv[1])
except Exception:
    print("off\t\t\t")
    raise SystemExit(0)

state = d.get("BackendState", "")
have_key = bool(d.get("HaveNodeKey", False))
self_node = d.get("Self") or {}
online = bool(self_node.get("Online", False))
health = d.get("Health") or []
peers = d.get("Peer") or {}
exit_host = ""
for n in peers.values():
    if n.get("ExitNode"):
        exit_host = n.get("HostName", "") or ""
        break

if not have_key or state == "NeedsLogin":
    print("on\t" + ICON_LOCK + "\t" + GREY + "\tlogin")
elif state == "Stopped":
    print("on\t" + ICON_LOCK + "\t" + GREY + "\toff")
elif state == "Running":
    if exit_host:
        print("on\t" + ICON_EXIT + "\t" + BLUE + "\t" + trunc(exit_host.split(".", 1)[0], 20))
    elif health:
        print("on\t" + ICON_ALERT + "\t" + YELLOW + "\t" + trunc(health[0], 20))
    elif not online:
        print("on\t" + ICON_ALERT + "\t" + RED + "\toffline")
    else:
        print("off\t\t\t")
else:
    print("on\t" + ICON_ALERT + "\t" + YELLOW + "\t" + trunc(state.lower(), 12))
PY
)"

IFS=$'\t' read -r drawing icon color label <<< "$result"

if [ "$drawing" = "off" ]; then
  sketchybar --set "$NAME" drawing=off label=""
else
  sketchybar --set "$NAME" drawing=on icon="$icon" icon.color="$color" label="$label" label.color="$LABEL_COLOR"
fi
