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

role_projects=(
  personal-hass-config
  personal-homelab
  personal-pi-config
  personal-claude-config
  personal-hermes-config
  personal-hermes-folder
  work-steady-servers
  homelab-home
  homelab-docker
  homelab-opt
)
for file in "${role_projects[@]}"; do
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
expected = {
    "personal-hass-config": ("hass-config", "~/Code/_homelab/home-assistant-config/", "agent", "claude --agent homelab:hass-config --dangerously-allow-permissions"),
    "personal-homelab": ("homelab", "~/Code/_homelab/ansible-playbooks/homelab", "ansible", "ansible-playbook update-servers.yml"),
    "personal-pi-config": ("pi-config", "~/.pi", "agent", "pi"),
    "personal-claude-config": ("claude-config", "~/.claude", "agent", "claude"),
    "personal-hermes-config": ("hermes-config", "~/Code/_homelab/local-stdy01-docker", "shell", None),
    "personal-hermes-folder": ("hermes-folder", "~/Documents/Sync/hermes-agent/", "shell", None),
    "work-steady-servers": ("steady-servers", "~/Code/_work/ansible-playbooks/steady-servers", "ansible", "tailscale switch steadydigital.co && tailscale up && ansible-playbook update-servers.yml && tailscale down"),
    "homelab-home": ("home", "~", "shell", None),
    "homelab-opt": ("opt", "/opt", "shell", None),
}
for filename, (name, working_dir, tab_name, command) in expected.items():
    doc = tomllib.loads((root / f"{filename}.toml").read_text())
    assert doc["name"] == name
    assert doc["working_dir"] == working_dir
    expected_tab = {"name": tab_name}
    if command is not None:
        expected_tab["command"] = command
    assert doc["tabs"] == [expected_tab]

docker = tomllib.loads((root / "homelab-docker.toml").read_text())
assert docker["name"] == "docker"
assert docker["working_dir"] in {"/opt/docker", "~/docker/compose"}
assert docker["tabs"] == [{"name": "shell"}]
PY

no_roles_ignore="$tmpdir/no-roles-ignore"
all_roles_ignore="$tmpdir/all-roles-ignore"
chezmoi execute-template --source "$repo_root" \
  --override-data '{"personal":false,"work":false,"homelab":false}' \
  <"$repo_root/.chezmoiignore" >"$no_roles_ignore"
chezmoi execute-template --source "$repo_root" \
  --override-data '{"personal":true,"work":true,"homelab":true}' \
  <"$repo_root/.chezmoiignore" >"$all_roles_ignore"
for pattern in personal work homelab; do
  target=".config/herdr/plugins/config/cloudmanic.herdr-plus/projects/$pattern-*.toml"
  grep -Fxq "$target" "$no_roles_ignore"
  if grep -Fxq "$target" "$all_roles_ignore"; then
    echo "active role project pattern remained ignored: $target" >&2
    exit 1
  fi
done

echo "Herdr Plus projects ok"
