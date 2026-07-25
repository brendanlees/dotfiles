#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="${TMPDIR:-/tmp}/sketchybar-calendar-dots-test-$$"
CONFIG="$TMP/config"
BIN="$TMP/bin"
mkdir -p "$CONFIG/plugins" "$BIN"
trap 'rm -rf "$TMP"' EXIT

cp "$ROOT/dot_config/sketchybar/plugins/executable_calendar.sh" "$CONFIG/plugins/calendar.sh"
cp "$ROOT/dot_config/sketchybar/plugins/executable_calendar_dots.sh" "$CONFIG/plugins/calendar_dots.sh" 2>/dev/null || : > "$CONFIG/plugins/calendar_dots.sh"
chmod +x "$CONFIG/plugins/calendar.sh" "$CONFIG/plugins/calendar_dots.sh"

cat > "$BIN/sketchybar" <<'SB'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$SKETCHYBAR_STUB_LOG"
SB
chmod +x "$BIN/sketchybar"

cat > "$BIN/date" <<'DATE'
#!/usr/bin/env sh
case "$1" in
  '+%d/%m') printf '29/06\n' ;;
  '+%I:%M %p') printf '06:14 AM\n' ;;
  '+%d/%m %I:%M %p') printf '29/06 06:14 AM\n' ;;
  *) /bin/date "$@" ;;
esac
DATE
chmod +x "$BIN/date"

cat > "$BIN/swift" <<'SWIFT'
#!/usr/bin/env sh
if [ -n "${OSA_SLEEP:-}" ]; then
  sleep "$OSA_SLEEP"
fi
if [ "${OSA_EXIT:-0}" != "0" ]; then
  printf 'Calendar permission denied\n' >&2
  exit "$OSA_EXIT"
fi
printf '%s' "${OSA_OUTPUT:-}"
SWIFT
chmod +x "$BIN/swift"

python3 - "$CONFIG/plugins/calendar_dots.sh" "$BIN/swift" <<'PY'
import sys
from pathlib import Path

plugin = Path(sys.argv[1])
swift = sys.argv[2]
text = plugin.read_text()
plugin.write_text(text.replace('["/usr/bin/swift", "-"]', f'[{swift!r}, "-"]'))
PY

fail() { echo "FAIL: $*" >&2; exit 1; }

run_clock() {
  local log="$TMP/clock.log"
  : > "$log"
  SKETCHYBAR_STUB_LOG="$log" PATH="$BIN:$PATH" NAME=calendar \
    bash "$CONFIG/plugins/calendar.sh"
  grep -q -- '--set calendar label=29/06 --set calendar_time icon=06:14 AM' "$log" \
    || fail "clock split did not set calendar date + calendar_time: $(cat "$log")"
}

run_dots_case() {
  local scenario="$1" output="$2"
  local log="$TMP/$scenario.log"
  : > "$log"
  SKETCHYBAR_STUB_LOG="$log" OSA_OUTPUT="$output" OSA_EXIT="${OSA_EXIT:-0}" \
    PATH="$BIN:$PATH" NAME=cal_dot_work \
    bash "$CONFIG/plugins/calendar_dots.sh"
  echo "--- $scenario ---"
  cat "$log"
}

assert_color() {
  local scenario="$1" want="$2"
  local log="$TMP/$scenario.log"
  grep -q -- "--set calendar icon.color=$want --set calendar_event_clock icon.color=$want" "$log" \
    || fail "$scenario: expected calendar icon color $want in $(cat "$log")"
}

echo '# calendar date/time split'
run_clock

echo '# calendar event-color matrix'
run_dots_case none ''
assert_color none 0xffffffff

run_dots_case family $'The Couple Calendar\n'
assert_color family 0xffE36BA0

run_dots_case work $'Operations\nbrendan@steadydigital.co\n'
assert_color work 0xffffa500

run_dots_case personal $'mail@brendans.cloud\nCalendar\nKalacoma\n'
assert_color personal 0xff00ff00

run_dots_case mixed $'The Couple Calendar\nOperations\nCalendar\nHolidays in Australia\n'
assert_color mixed 0xffE36BA0

run_dots_case unmapped $'Holidays in Australia\nAustralian Holidays\nTodoist\nTodoist - #work\nScheduled Reminders\nSiri Suggestions\n'
assert_color unmapped 0xffffffff

OSA_EXIT=5 run_dots_case error ''
assert_color error 0xffffffff

start=$(python3 - <<'PY'
import time
print(time.monotonic())
PY
)
OSA_SLEEP=3 CALENDAR_DOTS_TIMEOUT_SECONDS=1 run_dots_case timeout ''
end=$(python3 - <<'PY'
import time
print(time.monotonic())
PY
)
python3 - "$start" "$end" <<'PY'
import sys
start=float(sys.argv[1])
end=float(sys.argv[2])
if end - start >= 2.5:
    raise SystemExit(f'timeout case took too long: {end - start:.2f}s')
PY
assert_color timeout 0xffffffff

echo 'ALL CASES PASSED'
