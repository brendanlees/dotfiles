#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_ROOT="$ROOT/home"
TMP=$(mktemp -d)
BIN="$TMP/bin"
LOG="$TMP/sketchybar.log"
mkdir -p "$BIN"
trap 'rm -rf "$TMP"' EXIT

cat > "$BIN/sketchybar" <<'SB'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$SKETCHYBAR_STUB_LOG"
SB
cat > "$BIN/date" <<'DATE'
#!/usr/bin/env sh
case "$1" in
  '+%d/%m') printf '29/06\n' ;;
  '+%I:%M %p') printf '06:14 AM\n' ;;
  *) exit 1 ;;
esac
DATE
cat > "$BIN/osascript" <<'OSA'
#!/usr/bin/env sh
printf 'osascript %s\n' "$*" >> "$CLICK_LOG"
exit "${OSA_EXIT:-0}"
OSA
cat > "$BIN/open" <<'OPEN'
#!/usr/bin/env sh
printf 'open %s\n' "$*" >> "$CLICK_LOG"
OPEN
chmod +x "$BIN/"*

# Use the rendered palette so this contract also owns the subdued neutral color.
chezmoi execute-template --source "$ROOT" \
  <"$SOURCE_ROOT/dot_config/sketchybar/colors.sh.tmpl" >"$TMP/colors.sh"
# shellcheck source=/dev/null
source "$TMP/colors.sh"
[[ $CALENDAR_COLOR == "0x80${MUTED#0xff}" ]]

export PATH="$BIN:$PATH" SKETCHYBAR_STUB_LOG="$LOG"
FONT="JetBrainsMono Nerd Font Mono" ICON_CALENDAR=CAL \
  PILL_HEIGHT=36 BORDER_RADIUS=8 ITEM_PADDING=8 PLUGIN_DIR=/tmp/plugins \
  bash "$SOURCE_ROOT/dot_config/sketchybar/items/calendar.sh"

python3 - "$LOG" "$CALENDAR_COLOR" "$WHITE" <<'PY'
from pathlib import Path
import sys

lines = Path(sys.argv[1]).read_text().splitlines()
for name in ['calendar', 'calendar_time']:
    assert any(line.startswith(f'--add item {name} right ') for line in lines)
for old in ['cal_dot_fam', 'cal_dot_work', 'cal_dot_per', 'cal_dot_neutral', 'calendar_event_clock']:
    assert f'--remove {old}' in lines
assert not any('--add item calendar_event_clock' in line for line in lines)
assert not any('calendar_dots.sh' in line for line in lines)
calendar = next(line for line in lines if line.startswith('--add item calendar right '))
assert f'icon.color={sys.argv[2]}' in calendar
assert f'label.color={sys.argv[3]}' in calendar
assert 'icon=CAL' in calendar and 'script=/tmp/plugins/calendar.sh' in calendar
assert 'update_freq=15' in calendar and '--subscribe calendar system_woke' in calendar
assert any(line.startswith('--add bracket calendar_group /calendar$/ /calendar_time$/ ') for line in lines)
click = calendar.split('click_script=', 1)[1].split(' --subscribe', 1)[0]
assert 'Itsycal' not in click
Path(sys.argv[1] + '.click').write_text(click)
PY

# Clicking sends the same toggle shortcut; Dato is only the failure fallback.
export CLICK_LOG="$TMP/click.log"
bash -c "$(<"$LOG.click")"
grep -Fxq 'osascript -e tell application "System Events" to keystroke "c" using {control down, option down}' "$CLICK_LOG"
[[ $(wc -l <"$CLICK_LOG") -eq 1 ]]
OSA_EXIT=1 bash -c "$(<"$LOG.click")"
grep -Fxq 'open -a Dato' "$CLICK_LOG"

: > "$LOG"
bash "$SOURCE_ROOT/dot_config/sketchybar/plugins/executable_calendar.sh"
grep -Fxq -- '--set calendar label=29/06 --set calendar_time icon=06:14 AM' "$LOG"

# A retired managed plugin is removed on apply, not left behind on existing hosts.
mkdir -p "$TMP/source" "$TMP/home/.config/sketchybar/plugins"
cp "$SOURCE_ROOT/.chezmoiremove.tmpl" "$TMP/source/"
printf 'retired\n' >"$TMP/home/.config/sketchybar/plugins/calendar_dots.sh"
printf 'keep\n' >"$TMP/home/.config/sketchybar/plugins/calendar.sh"
printf '[data]\npersonal=true\n' >"$TMP/config.toml"
chezmoi apply --source "$TMP/source" --destination "$TMP/home" --config "$TMP/config.toml" \
  --persistent-state "$TMP/state.boltdb" --override-data '{"chezmoi":{"os":"darwin"}}' --no-tty
[[ ! -e "$TMP/home/.config/sketchybar/plugins/calendar_dots.sh" ]]
grep -Fxq keep "$TMP/home/.config/sketchybar/plugins/calendar.sh"

echo 'calendar sourcing, Dato toggle, neutral color, date/time, and retired plugin cleanup ok'
