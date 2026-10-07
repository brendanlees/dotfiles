#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG="$ROOT/home/dot_config/aerospace/aerospace.toml"

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
