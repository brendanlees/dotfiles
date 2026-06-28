#!/bin/bash

# shellcheck source=../colors.sh
source "$CONFIG_DIR/colors.sh"

# Nerd Font glyphs (present in JetBrainsMono Nerd Font Mono).
ICON_TS_LOCK=󰌾
ICON_TS_EXIT=󰢷
ICON_TS_ALERT=󰂚
ICON_TS_SHIELD=$'\xEF\x8F\xBD'    # fa-shield_alt (U+F3ED)

export TS_COLOR_GREY="$GREY" TS_COLOR_BLUE="$BLUE" TS_COLOR_YELLOW="$YELLOW" TS_COLOR_RED="$RED" TS_COLOR_GREEN="$GREEN"
export TS_ICON_LOCK="$ICON_TS_LOCK" TS_ICON_EXIT="$ICON_TS_EXIT" TS_ICON_ALERT="$ICON_TS_ALERT" TS_ICON_SHIELD="$ICON_TS_SHIELD"

hide_item() {
  sketchybar --set "$NAME" drawing=off label=""
  exit 0
}

# Off/inactive, broken-machine, or no-tailscale: hide the pill entirely.
if ! command -v tailscale >/dev/null 2>&1; then
  hide_item
fi

status_json="$(tailscale status --json 2>/dev/null)" || hide_item

# Defensive: python3 is part of the expected toolchain (spotify plugin uses it too).
if [ ! -x /usr/bin/python3 ]; then
  hide_item
fi

# JSON is passed as argv[1]; the program comes from the heredoc on stdin
# (same pattern as the spotify plugin). Output TSV: drawing\ticon\tcolor\tlabel.
# The same semantic <color> drives icon.color AND background.border_color so the
# pill frame tracks state (green=connected, blue=exit node, yellow/red=alert).
result="$(/usr/bin/python3 - "$status_json" <<'PY'
import json
import os
import sys

def env(name):
    return os.environ.get(name, "")

GREY, BLUE, YELLOW, RED, GREEN = (env("TS_COLOR_GREY"), env("TS_COLOR_BLUE"),
                                  env("TS_COLOR_YELLOW"), env("TS_COLOR_RED"),
                                  env("TS_COLOR_GREEN"))
ICON_LOCK, ICON_EXIT, ICON_ALERT, ICON_SHIELD = (env("TS_ICON_LOCK"), env("TS_ICON_EXIT"),
                                                  env("TS_ICON_ALERT"), env("TS_ICON_SHIELD"))

def trunc(s, n):
    s = s or ""
    if len(s) > n:
        s = s[: n - 1] + "…"
    return s

def on(icon, color, label):
    return "on\t" + icon + "\t" + color + "\t" + label

def off():
    return "off\t\t\t"

try:
    d = json.loads(sys.argv[1])
except Exception:
    print(off())
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

# Off / inactive states are hidden: no node key, needs-login, stopped, or unknown.
if not have_key or state in ("NeedsLogin", "Stopped", ""):
    print(off())
    raise SystemExit(0)

if state != "Running":
    # Starting / NeedsMachineAuth / other transient states: surface as a warning.
    print(on(ICON_ALERT, YELLOW, trunc(state.lower(), 12)))
    raise SystemExit(0)

# Running: visible in every sub-state so the pill always shows while connected.
if exit_host:
    print(on(ICON_EXIT, BLUE, trunc(exit_host.split(".", 1)[0], 20)))
elif health:
    print(on(ICON_ALERT, YELLOW, trunc(health[0], 20)))
elif not online:
    print(on(ICON_ALERT, RED, "offline"))
else:
    tailnet = ((d.get("CurrentTailnet") or {}).get("Name", "")) or "connected"
    print(on(ICON_SHIELD, GREEN, trunc(tailnet, 20)))
PY
)"

IFS=$'\t' read -r drawing icon color label <<< "$result"

if [ "$drawing" = "off" ]; then
  sketchybar --set "$NAME" drawing=off label=""
else
  sketchybar --set "$NAME" \
    drawing=on \
    icon="$icon" \
    icon.color="$color" \
    background.border_color="$color" \
    label="$label" \
    label.color="$LABEL_COLOR"
fi
