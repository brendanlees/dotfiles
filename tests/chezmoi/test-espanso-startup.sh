#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

chezmoi execute-template --source "$repo_root" \
  --override-data '{"chezmoi":{"homeDir":"/Users/test"}}' \
  <"$repo_root/home/Library/LaunchAgents/com.federicoterzi.espanso.plist.tmpl" >"$tmp/agent.plist"

python3 - "$tmp/agent.plist" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as file:
    agent = plistlib.load(file)
assert agent["RunAtLoad"] is True
assert agent["EnvironmentVariables"]["ESPANSO_CONFIG_DIR"] == "/Users/test/.config/espanso"
assert agent["ProgramArguments"] == ["/bin/sh", "/Users/test/.config/espanso/start.sh"]
PY

# Exercise the launcher with a fake app, including after its cache is cleared.
mkdir -p "$tmp/home"
cat >"$tmp/espanso" <<'SH'
#!/bin/sh
[ "$*" = launcher ]
[ "$(cat "$HOME/Library/Caches/espanso/kvs/has_displayed_welcome")" = true ]
# Suppressing the tutorial must not claim setup or permissions were completed.
[ ! -e "$HOME/Library/Caches/espanso/kvs/has_completed_wizard" ]
[ ! -e "$HOME/Library/Caches/espanso/kvs/has_selected_auto_start_option" ]
printf 'started\n' >>"$HOME/starts"
SH
chmod +x "$tmp/espanso"
python3 - "$repo_root" "$tmp" <<'PY'
from pathlib import Path
import sys

repo, tmp = map(Path, sys.argv[1:])
script = (repo / "home/dot_config/espanso/start.sh").read_text()
script = script.replace("/Applications/Espanso.app/Contents/MacOS/espanso", str(tmp / "espanso"))
(tmp / "start.sh").write_text(script)
PY

for _ in 1 2; do
  HOME="$tmp/home" env -u ESPANSO_RUNTIME_DIR sh "$tmp/start.sh"
  rm -rf "$tmp/home/Library/Caches/espanso"
done
[[ $(wc -l <"$tmp/home/starts" | tr -d ' ') == 2 ]]

echo 'Espanso login startup suppresses only the tutorial, including after cache cleanup'
