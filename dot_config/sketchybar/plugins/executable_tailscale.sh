#!/bin/bash

# shellcheck source=../colors.sh
source "$CONFIG_DIR/colors.sh"

# State colors (VPN secured): green=connected, yellow=health warning or transient,
# red=running-but-offline. The icon is the static `:tailscale:` token set by the
# item; this plugin only toggles drawing and recolors icon + pill border.
export TS_COLOR_GREY="$GREY" TS_COLOR_YELLOW="$YELLOW" TS_COLOR_RED="$RED" TS_COLOR_GREEN="$GREEN"

hide_item() {
  sketchybar --set "$NAME" drawing=off label=""
  exit 0
}

# Off / inactive / broken-machine: hide the pill entirely.
if ! command -v tailscale >/dev/null 2>&1; then
  hide_item
fi

status_json="$(tailscale status --json 2>/dev/null)" || hide_item

# Defensive: python3 is part of the expected toolchain (spotify plugin uses it too).
if [ ! -x /usr/bin/python3 ]; then
  hide_item
fi

# TSV from python: drawing\tcolor\tlabel. drawing is "on" or "off".
result="$(/usr/bin/python3 - "$status_json" <<'PY'
import json
import os
import sys

def env(name):
    return os.environ.get(name, "")

GREEN, YELLOW, RED = env("TS_COLOR_GREEN"), env("TS_COLOR_YELLOW"), env("TS_COLOR_RED")

def trunc(s, n):
    s = s or ""
    if len(s) > n:
        s = s[: n - 1] + "…"
    return s

def on(color, label):
    return "on\t" + color + "\t" + label

def off():
    return "off\t\t"

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

# Off / inactive states are hidden: no node key, needs-login, stopped, or unknown.
if not have_key or state in ("NeedsLogin", "Stopped", ""):
    print(off())
    raise SystemExit(0)

if state != "Running":
    # Starting / NeedsMachineAuth / other transient states: surface as a warning.
    print(on(YELLOW, trunc(state.lower(), 12)))
    raise SystemExit(0)

# Running: visible in every sub-state so the pill always shows while connected.
if health:
    print(on(YELLOW, trunc(health[0], 20)))
elif not online:
    print(on(RED, "offline"))
else:
    tailnet = ((d.get("CurrentTailnet") or {}).get("Name", "")) or "connected"
    print(on(GREEN, trunc(tailnet, 20)))
PY
)"

IFS=$'\t' read -r drawing color label <<< "$result"

if [ "$drawing" = "off" ]; then
  sketchybar --set "$NAME" drawing=off label=""
else
  sketchybar --set "$NAME" \
    drawing=on \
    icon.color="$color" \
    background.border_color="$color" \
    label="$label" \
    label.color="$LABEL_COLOR"
fi
