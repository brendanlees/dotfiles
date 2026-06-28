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

assert_dot() {
  local scenario="$1" dot="$2" want="$3"
  local log="$TMP/$scenario.log"
  grep -q -- "--set $dot drawing=$want" "$log" \
    || fail "$scenario: expected $dot drawing=$want in $(cat "$log")"
}

assert_case() {
  local scenario="$1" fam="$2" work="$3" per="$4" neutral="$5"
  assert_dot "$scenario" cal_dot_fam "$fam"
  assert_dot "$scenario" cal_dot_work "$work"
  assert_dot "$scenario" cal_dot_per "$per"
  assert_dot "$scenario" cal_dot_neutral "$neutral"
}

echo '# calendar date/time split'
run_clock

echo '# calendar today-dot bucket matrix'
run_dots_case none ''
assert_case none off off off on

run_dots_case family $'The Couple Calendar\n'
assert_case family on off off off

run_dots_case work $'Operations\nbrendan@steadydigital.co\n'
assert_case work off on off off

run_dots_case personal $'mail@brendans.cloud\nCalendar\nKalacoma\n'
assert_case personal off off on off

run_dots_case mixed $'The Couple Calendar\nOperations\nCalendar\nHolidays in Australia\n'
assert_case mixed on on on off

run_dots_case unmapped $'Holidays in Australia\nAustralian Holidays\nTodoist\nTodoist - #work\nScheduled Reminders\nSiri Suggestions\n'
assert_case unmapped off off off on

OSA_EXIT=5 run_dots_case error ''
assert_case error off off off on

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
assert_case timeout off off off on

echo 'ALL CASES PASSED'
