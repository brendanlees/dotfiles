#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
fixture="$tmpdir/source"
mkdir -p "$fixture/.chezmoiscripts/darwin" "$tmpdir/bin"
cp "$repo_root/home/.chezmoiignore" "$fixture/"
cp "$repo_root"/home/.chezmoiscripts/darwin/run_onchange_after_configure-defaults.sh* \
  "$fixture/.chezmoiscripts/darwin/"

# Record typed writes, never call macOS defaults or restart live applications.
cat >"$tmpdir/bin/defaults" <<'PY'
#!/usr/bin/env python3
import json
import os
import plistlib
import sys
from pathlib import Path

_, action, domain, key, flag, *args = sys.argv
assert action == 'write'
state = Path(os.environ['PREFS_STATE'])
data = json.loads(state.read_text()) if state.exists() else {}
values = data.setdefault(domain, {})
if flag == '-bool':
    value = args[0].lower() in ('true', 'yes', '1')
elif flag == '-int':
    value = int(args[0])
elif flag == '-float':
    value = float(args[0])
elif flag == '-string':
    value = args[0]
elif flag == '-array':
    value = [plistlib.loads(f'<plist>{arg}</plist>'.encode(), fmt=plistlib.FMT_XML) for arg in args]
elif flag == '-dict-add':
    value = values.get(key, {})
    for name, xml in zip(args[::2], args[1::2]):
        value[name] = plistlib.loads(f'<plist>{xml}</plist>'.encode(), fmt=plistlib.FMT_XML)
else:
    raise AssertionError(flag)
values[key] = value
state.write_text(json.dumps(data))
PY
cat >"$tmpdir/bin/killall" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"$PREFS_RESTARTS"
SH
chmod +x "$tmpdir/bin/"*

check_scope() {
  local name=$1 os=$2 personal=$3 work=$4 headless=$5 eligible=$6
  local home="$tmpdir/$name home" config="$tmpdir/$name.toml"
  mkdir -p "$home"
  printf '[data]\npersonal=%s\nwork=%s\nhomelab=false\nephemeral=false\nheadless=%s\n' \
    "$personal" "$work" "$headless" >"$config"
  HOME="$home" PATH="$tmpdir/bin:$PATH" PREFS_STATE="$home/preferences.json" \
    PREFS_RESTARTS="$home/restarts" chezmoi apply --source "$fixture" --destination "$home" \
    --config "$config" --persistent-state "$home/state.boltdb" \
    --override-data "{\"chezmoi\":{\"os\":\"$os\"}}" --no-tty
  python3 - "$home" "$eligible" <<'PY'
import json
import sys
from pathlib import Path
home = Path(sys.argv[1])
state = home / 'preferences.json'
data = json.loads(state.read_text()) if state.exists() else {}
if sys.argv[2] != 'true':
    assert 'com.apple.finder' not in data
    assert 'com.apple.HIToolbox' not in data
    assert 'com.apple.mouse.scaling' not in data.get('-g', {})
    raise SystemExit()

global_ = data['-g']
assert global_['KeyRepeat'] == 2 and global_['InitialKeyRepeat'] == 15
assert global_['AppleKeyboardUIMode'] == 1
assert global_['com.apple.mouse.scaling'] == 0.875
assert global_['com.apple.scrollwheel.scaling'] == 0.5
assert global_['com.apple.trackpad.scaling'] == 1.5
assert global_['com.apple.swipescrolldirection'] is False
assert global_['com.apple.keyboard.fnState'] is False
finder = data['com.apple.finder']
assert finder['FXPreferredViewStyle'] == finder['FXPreferredSearchViewStyle'] == 'clmv'
assert finder['FXDefaultSearchScope'] == 'SCcf'
assert finder['NewWindowTarget'] == 'PfLo'
assert finder['NewWindowTargetPath'] == (home / 'Downloads').as_uri() + '/'
assert finder['CreateDesktop'] is False and finder['ShowPathbar'] is True
assert finder['_FXSortFoldersFirst'] is True
assert finder['StandardViewOptions']['ColumnViewOptions']['ShowPreview'] is True
assert finder['StandardViewOptions']['ColumnViewOptions']['FontSize'] == 13.0
for domain in ('com.apple.AppleMultitouchTrackpad', 'com.apple.driver.AppleBluetoothMultitouch.trackpad'):
    assert data[domain]['Clicking'] is True
    assert data[domain]['TrackpadThreeFingerDrag'] is True
    assert data[domain]['TrackpadRightClick'] is True
    assert data[domain]['TrackpadThreeFingerHorizSwipeGesture'] == 0
for domain in ('com.apple.AppleMultitouchMouse', 'com.apple.driver.AppleBluetoothMultitouch.mouse'):
    assert data[domain]['MouseButtonMode'] == 'OneButton'
    assert data[domain]['MouseMomentumScroll'] is True
keyboard = data['com.apple.HIToolbox']
assert keyboard['AppleCurrentKeyboardLayoutInputSourceID'] == 'com.apple.keylayout.Australian'
layout = keyboard['AppleEnabledInputSources'][0]
assert layout['KeyboardLayout Name'] == 'Australian'
assert type(layout['KeyboardLayout ID']) is int and layout['KeyboardLayout ID'] == 15
assert keyboard['AppleSelectedInputSources'][-1] == layout
# Never snapshot history, device identities or unrelated shortcut ownership.
assert not {'FXRecentFolders', 'GoToFieldHistory', 'FXDesktopVolumePositions', 'WindowState'} & finder.keys()
assert 'AppleInputSourceHistory' not in keyboard
assert 'com.apple.symbolichotkeys' not in data
PY
}

check_scope personal darwin true false false true
check_scope work darwin false true false true
check_scope headless darwin true false true false
check_scope unscoped darwin false false false false
check_scope linux linux true true false false
check_scope windows windows true true false false

echo 'macOS Finder and input preferences: typed values, portable paths and role/OS routing ok'
