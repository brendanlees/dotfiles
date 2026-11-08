#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
template="$source_root/.chezmoitemplates/claude-theme.json.tmpl"
posix_writer="$source_root/.chezmoiscripts/run_onchange_after_configure-claude-theme.py.tmpl"
windows_writer="$source_root/.chezmoiscripts/windows/run_onchange_after_configure-claude-theme.ps1.tmpl"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Exercise the writer with a synthetic theme, not a required palette or inventory.
chezmoi data --source "$repo_root" --format json >"$tmpdir/data.json"
override=$(python3 - "$tmpdir/data.json" <<'PY'
import json
import sys
from pathlib import Path
sample = next(iter(json.loads(Path(sys.argv[1]).read_text())["themes"].values()))
print(json.dumps({
    "theme": "fixture", "themes": {"fixture": sample},
    "personal": True, "ssh": {"bw_manifest_item": ""},
}))
PY
)
chezmoi execute-template --source "$repo_root" --override-data "$override" \
  --file "$template" >"$tmpdir/expected.json"
chezmoi execute-template --source "$repo_root" --override-data "$override" \
  --file "$posix_writer" >"$tmpdir/writer.py"

config_dir="$tmpdir/claude-config"
mkdir -p "$config_dir/themes"
printf '{"theme":"my-choice","custom":true}\n' >"$config_dir/settings.json"
printf '{"name":"local-theme"}\n' >"$config_dir/themes/local.json"
cp "$config_dir/settings.json" "$tmpdir/settings.before"
cp "$config_dir/themes/local.json" "$tmpdir/local.before"

for _ in 1 2; do
  CLAUDE_CONFIG_DIR="$config_dir" python3 "$tmpdir/writer.py"
  python3 - "$tmpdir/expected.json" "$config_dir/themes/chezmoi.json" <<'PY'
import json
import sys
from pathlib import Path
assert json.loads(Path(sys.argv[1]).read_text()) == json.loads(Path(sys.argv[2]).read_text())
PY
  cmp "$tmpdir/settings.before" "$config_dir/settings.json"
  cmp "$tmpdir/local.before" "$config_dir/themes/local.json"
done

for os in linux windows; do
  writer="$posix_writer"
  [[ $os != windows ]] || writer="$windows_writer"
  rendered=$(chezmoi execute-template --source "$repo_root" \
    --override-data "{\"personal\":false,\"chezmoi\":{\"os\":\"$os\"}}" --file "$writer")
  [[ -z $rendered ]] || { echo "Claude Code theme writer must be personal-only ($os)" >&2; exit 1; }
done

echo 'Claude Code theme writer preserves settings and local themes and respects role gating'
