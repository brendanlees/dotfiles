#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG="$ROOT/home/dot_config/aerospace/aerospace.toml"
HELPER="$ROOT/home/dot_config/aerospace/executable_move-spotify-to-music.sh"

python3 - "$CONFIG" <<'PY'
import pathlib
import re
import sys
import tomllib

parsed = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
bindings = parsed['mode']['main']['binding']
assert bindings['alt-1'] == ['workspace 1-browser']
assert bindings['alt-b'] == ['workspace 1-browser', 'exec-and-forget open -a Dia']

expected = {
    'company.thebrowser.Browser': '1-browser',
    'company.thebrowser.dia': '1-browser',
    'com.microsoft.VSCode': '2-code',
    'dev.zed.Zed': '2-code',
    'com.mimestream.Mimestream': '3-email',
    'notion.id': '3-email',
    'com.invoiceninja.app': '3-email',
    'com.apple.finder': '4-files',
    'com.figma.Desktop': '5-docs',
    'asc.onlyoffice.ONLYOFFICE': '5-docs',
    'com.hnc.Discord': '6-misc1',
    'com.nousresearch.hermes': '6-misc1',
    'md.obsidian': '8-notes',
    'com.todoist.mac.Todoist': '8-notes',
}
rules = {}
for rule in parsed['on-window-detected']:
    condition = rule['if']
    assert isinstance(condition, str), (
        f'window rule should use the non-deprecated app-bundle-id test syntax: {condition}'
    )
    match = re.match(r'^test %\{app-bundle-id\} = ([^\s&]+)', condition)
    assert match is not None, (
        f'window rule should use the non-deprecated app-bundle-id test syntax: {condition}'
    )
    rules[match.group(1)] = rule['run']
for app, workspace in expected.items():
    assert rules[app] == f'move-node-to-workspace {workspace}', (
        f'{app} should route every matching window to {workspace} without a helper'
    )
spotify_commands = rules.get('com.spotify.client', [])
assert spotify_commands and spotify_commands[0] == 'move-node-to-workspace 9-music', (
    'Spotify must route immediately to workspace 9'
)
assert spotify_commands[1:] == [
    'exec-and-forget /bin/bash -lc "$HOME/.config/aerospace/move-spotify-to-music.sh --delay 1"',
], 'Spotify must recheck placement after late-created windows appear'
todoist_condition = next(
    rule['if'] for rule in parsed['on-window-detected']
    if rule['if'].startswith('test %{app-bundle-id} = com.todoist.mac.Todoist')
)
assert 'test %{window-title} ~= ' in todoist_condition
assert r'^(Today|Upcoming|Inbox|Filters & Labels|.*\(Todoist\))$' in todoist_condition
assert 'app.zen-browser.zen' not in rules, 'Dia replaces Zen'
for app in ('com.nickustinov.itsyhome', 'dev.kdrag0n.MacVirt'):
    assert rules[app] == ['layout floating']
PY

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
mkdir -p "$TEMP_DIR/bin"
cat >"$TEMP_DIR/bin/sleep" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >"$DELAY_FILE"
SH
cat >"$TEMP_DIR/bin/aerospace" <<'SH'
#!/bin/sh
set -eu
case "$1" in
  list-windows)
    # Discover the windows after the delay, not before it.
    test -f "$DELAY_FILE"
    test "$*" = 'list-windows --all --format %{window-id}|%{app-bundle-id}'
    printf '%s\n' '42|com.spotify.client' '99|dev.zed.Zed' '100|com.spotify.client'
    ;;
  move-node-to-workspace)
    printf '%s\n' "$*" >>"$MOVES_FILE"
    # A window closing during placement must not block the remaining windows.
    test "$3" != 42
    ;;
  *) exit 1 ;;
esac
SH
chmod +x "$TEMP_DIR/bin/sleep" "$TEMP_DIR/bin/aerospace"
PATH="$TEMP_DIR/bin:$PATH" MOVES_FILE="$TEMP_DIR/moves" DELAY_FILE="$TEMP_DIR/delay" \
  "$HELPER" --delay 1
[[ $(<"$TEMP_DIR/delay") == 1 ]]
printf '%s\n' \
  'move-node-to-workspace --window-id 42 9-music' \
  'move-node-to-workspace --window-id 100 9-music' >"$TEMP_DIR/expected"
cmp "$TEMP_DIR/expected" "$TEMP_DIR/moves"
echo 'AeroSpace routing and delayed Spotify placement ok'
