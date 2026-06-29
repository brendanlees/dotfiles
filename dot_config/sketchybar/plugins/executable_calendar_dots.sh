#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${CONFIG_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

if [ -f "$CONFIG_DIR/colors.sh" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_DIR/colors.sh"
fi

if [ -z "${TMPDIR:-}" ] || [ ! -d "$TMPDIR" ]; then
    export TMPDIR=/tmp
fi

DOT_PINK="0xffE36BA0"
: "${ORANGE:=0xffffa500}"
: "${GREEN:=0xff00ff00}"
: "${GREY:=0xff808080}"
: "${WHITE:=0xffffffff}"
: "${CALENDAR_COLOR:=${CYAN:-$WHITE}}"

set_calendar_border() {
    if [ "$#" -eq 0 ]; then
        sketchybar --set calendar_group background.border_color="$GREY"
        return
    fi

    if [ "$#" -gt 1 ]; then
        local gradient_value
        local IFS=,
        gradient_value="$*"

        if sketchybar --set calendar_group background.border_color="$gradient_value" 2>/dev/null; then
            return
        fi
    fi

    sketchybar --set calendar_group background.border_color="$1"
}

set_calendar_state() {
    local icon_color="$1"
    shift

    sketchybar --set calendar icon.color="$icon_color" \
        --set calendar_event_clock icon.color="$icon_color"
    set_calendar_border "$@"
}

if ! calendar_names="$(CALENDAR_DOTS_TIMEOUT_SECONDS="${CALENDAR_DOTS_TIMEOUT_SECONDS:-12}" /usr/bin/python3 <<'PY' 2>/dev/null
import os
import subprocess
import sys

swift_source = r'''
import Foundation
import EventKit

let store = EKEventStore()
let sem = DispatchSemaphore(value: 0)
var granted = false

if #available(macOS 14.0, *) {
    store.requestFullAccessToEvents { ok, _ in
        granted = ok
        sem.signal()
    }
} else {
    store.requestAccess(to: .event) { ok, _ in
        granted = ok
        sem.signal()
    }
}

if sem.wait(timeout: .now() + 8) == .timedOut {
    exit(3)
}

if !granted {
    exit(2)
}

let calendar = Calendar.current
let start = calendar.startOfDay(for: Date())
let end = calendar.date(byAdding: .day, value: 1, to: start)!
let wanted = Set([
    "The Couple Calendar",
    "brendan@steadydigital.co",
    "Operations",
    "mail@brendans.cloud",
    "Calendar",
    "Kalacoma",
])
let eventCalendars = store.calendars(for: .event).filter { wanted.contains($0.title) }
let predicate = store.predicateForEvents(withStart: start, end: end, calendars: eventCalendars)
let events = store.events(matching: predicate)

for event in events {
    print(event.calendar.title)
}
'''

timeout = float(os.environ.get("CALENDAR_DOTS_TIMEOUT_SECONDS", "12"))
try:
    result = subprocess.run(
        ["/usr/bin/swift", "-"],
        input=swift_source,
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )
except Exception:
    sys.exit(124)

if result.returncode != 0:
    sys.exit(result.returncode)

sys.stdout.write(result.stdout)
PY
)"; then
    set_calendar_state "$CALENDAR_COLOR" "$CALENDAR_COLOR"
    exit 0
fi

fam=off
work=off
per=off

while IFS= read -r calendar_name; do
    case "$calendar_name" in
        "The Couple Calendar") fam=on ;;
        "brendan@steadydigital.co"|"Operations") work=on ;;
        "mail@brendans.cloud"|"Calendar"|"Kalacoma") per=on ;;
    esac
done <<EOF_NAMES
$calendar_names
EOF_NAMES

active_colors=()
[ "$fam" = on ] && active_colors+=("$DOT_PINK")
[ "$work" = on ] && active_colors+=("$ORANGE")
[ "$per" = on ] && active_colors+=("$GREEN")

if [ "${#active_colors[@]}" -eq 0 ]; then
    set_calendar_state "$CALENDAR_COLOR" "$CALENDAR_COLOR"
else
    set_calendar_state "${active_colors[0]}" "${active_colors[@]}"
fi
