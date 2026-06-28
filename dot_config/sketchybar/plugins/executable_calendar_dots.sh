#!/bin/bash

set_dots() {
    sketchybar --set cal_dot_fam drawing="$1" \
        --set cal_dot_work drawing="$2" \
        --set cal_dot_per drawing="$3" \
        --set cal_dot_neutral drawing="$4"
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
        ["swift", "-"],
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
    set_dots off off off on
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

if [ "$fam" = off ] && [ "$work" = off ] && [ "$per" = off ]; then
    neutral=on
else
    neutral=off
fi

set_dots "$fam" "$work" "$per" "$neutral"
