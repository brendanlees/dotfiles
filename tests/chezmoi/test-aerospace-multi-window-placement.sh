#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG="$ROOT/home/dot_config/aerospace/aerospace.toml"

python3 - "$CONFIG" <<'PY'
import pathlib
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
rules = {rule['if']['app-id']: rule['run'] for rule in parsed['on-window-detected']}
for app, workspace in expected.items():
    assert rules[app] == f'move-node-to-workspace {workspace}', (
        f'{app} should route every matching window to {workspace} without a helper'
    )
assert 'app.zen-browser.zen' not in rules, 'Dia replaces Zen'
for app in ('com.nickustinov.itsyhome', 'dev.kdrag0n.MacVirt'):
    assert rules[app] == ['layout floating']
PY
