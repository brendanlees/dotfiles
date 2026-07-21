#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
projects="$repo_root/dot_config/herdr/plugins/config/cloudmanic.herdr-plus/projects"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

render_project() {
  local source=$1 output=$2 override=${3:-'{"chezmoi_dir":".local/share/chezmoi","code_dir":"Code"}'}
  chezmoi execute-template --source "$repo_root" --override-data "$override" \
    <"$projects/$source" >"$output"
}

for file in base-dotfiles base-nvim-config base-tmux-config; do
  [[ -f "$projects/$file.toml.tmpl" ]] || {
    echo "missing Herdr Plus project: $file" >&2
    exit 1
  }
  render_project "$file.toml.tmpl" "$tmpdir/$file.toml"
done

python3 - "$tmpdir" <<'PY'
import sys
import tomllib
from pathlib import Path

root = Path(sys.argv[1])
def load(name):
    return tomllib.loads((root / f"{name}.toml").read_text())

assert load("base-dotfiles") == {
    "name": "dotfiles",
    "working_dir": "~/.local/share/chezmoi",
    "tabs": [{"name": "shell"}],
}
assert load("base-nvim-config") == {
    "name": "nvim-config",
    "working_dir": "~/.config/nvim",
    "tabs": [{"name": "shell"}],
}
assert load("base-tmux-config") == {
    "name": "tmux-config",
    "working_dir": "~/.local/share/chezmoi/dot_config/tmux",
    "tabs": [{"name": "editor", "command": "nvim tmux.conf.tmpl"}],
}
PY

echo "Herdr Plus projects ok"
