#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
template="$repo_root/.chezmoiscripts/run_onchange_after_install-herdr-plugins.sh.tmpl"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

[[ -f "$template" ]] || { echo "missing Herdr plugin reconciler: $template" >&2; exit 1; }

rendered="$tmpdir/install-herdr-plugins.sh"
chezmoi execute-template --source "$repo_root" <"$template" >"$rendered"
chmod +x "$rendered"

fakebin="$tmpdir/bin"
mkdir -p "$fakebin" "$tmpdir/home" "$tmpdir/state/chezmoi" "$tmpdir/plugin-config"
cat >"$fakebin/herdr" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"$HERDR_TEST_LOG"
if [ "$*" = "plugin config-dir worktrunk" ]; then
  printf '%s\n' "$HERDR_TEST_CONFIG_DIR"
fi
SH
chmod +x "$fakebin/herdr"

cat >"$tmpdir/state/chezmoi/herdr-plugins.txt" <<'STATE'
old-plugin|example/old-plugin|old-ref
third774.last-workspace|third774/herdr-last-workspace|8b55ebf15deaa52b49ff1c2500aab0c19c729420
persiyanov.reviewr|persiyanov/herdr-reviewr|f1dd491e47ef55410eca7c73daebe3726f06bda0
STATE

HERDR_TEST_LOG="$tmpdir/herdr.log" \
HERDR_TEST_CONFIG_DIR="$tmpdir/plugin-config" \
HOME="$tmpdir/home" \
XDG_STATE_HOME="$tmpdir/state" \
PATH="$fakebin:/usr/bin:/bin" \
  "$rendered"

nav_ref='53e318c772c4d3b7fbd904ac43bcf3e5b5d8b244'
plus_ref='f32b0825f12543c1d03e54fb10d1741c40d66cdc'
worktrunk_ref='e9131c0b576fd68635194c758c9691dbfb778b61'
file_viewer_ref='96fcc0a2bdd2727ec88c38f8c8806f97b7ca0ea0'
browser_ref='be6888b71cf4eb5939ee79a746bd1a1c22ade046'
navigator_ref='03b803a00341d58382b6cda70a7cd618af5b8806'
grep -Fxq "plugin install paulbkim-dev/vim-herdr-navigation --ref $nav_ref --yes" "$tmpdir/herdr.log"
grep -Fxq "plugin install cloudmanic/herdr-plus --ref $plus_ref --yes" "$tmpdir/herdr.log"
grep -Fxq "plugin install devashish2203/herdr-worktrunk --ref $worktrunk_ref --yes" "$tmpdir/herdr.log"
grep -Fxq "plugin install smarzban/herdr-file-viewer --ref $file_viewer_ref --yes" "$tmpdir/herdr.log"
grep -Fxq "plugin install ogulcancelik/herdr-browser --ref $browser_ref --yes" "$tmpdir/herdr.log"
grep -Fxq "plugin install thanhdat77/herdr-navigator --ref $navigator_ref --yes" "$tmpdir/herdr.log"
grep -Fxq 'plugin uninstall old-plugin' "$tmpdir/herdr.log"
grep -Fxq 'plugin uninstall third774.last-workspace' "$tmpdir/herdr.log"
grep -Fxq 'plugin uninstall persiyanov.reviewr' "$tmpdir/herdr.log"
grep -Fxq "vim-herdr-navigation|paulbkim-dev/vim-herdr-navigation|$nav_ref" \
  "$tmpdir/state/chezmoi/herdr-plugins.txt"
grep -Fxq "cloudmanic.herdr-plus|cloudmanic/herdr-plus|$plus_ref" \
  "$tmpdir/state/chezmoi/herdr-plugins.txt"
grep -Fxq "worktrunk|devashish2203/herdr-worktrunk|$worktrunk_ref" \
  "$tmpdir/state/chezmoi/herdr-plugins.txt"
grep -Fxq "herdr-file-viewer|smarzban/herdr-file-viewer|$file_viewer_ref" \
  "$tmpdir/state/chezmoi/herdr-plugins.txt"
grep -Fxq "official.browser|ogulcancelik/herdr-browser|$browser_ref" \
  "$tmpdir/state/chezmoi/herdr-plugins.txt"
grep -Fxq "herdr-navigator|thanhdat77/herdr-navigator|$navigator_ref" \
  "$tmpdir/state/chezmoi/herdr-plugins.txt"
grep -Fxq 'open_mode = "workspace"' "$tmpdir/plugin-config/config.toml"
for removed_plugin in old-plugin third774.last-workspace persiyanov.reviewr; do
  if grep -Fq "$removed_plugin" "$tmpdir/state/chezmoi/herdr-plugins.txt"; then
    echo "stale managed plugin remained in state ledger: $removed_plugin" >&2
    exit 1
  fi
done

navigator_config="$repo_root/dot_config/herdr/plugins/config/herdr-navigator/config.toml"
file_viewer_template="$repo_root/dot_config/herdr/plugins/config/herdr-file-viewer/config.toml.tmpl"
file_viewer_config="$tmpdir/file-viewer-config.toml"
chezmoi execute-template \
  --source "$repo_root" \
  --override-data '{"theme":"black-metal-bathory"}' \
  <"$file_viewer_template" >"$file_viewer_config"
python3 - "$navigator_config" "$file_viewer_config" <<'PY'
import sys
import tomllib
from pathlib import Path

navigator = tomllib.loads(Path(sys.argv[1]).read_text())
assert navigator == {
    "picker": {"check_updates": True},
    "jump_back": {"enabled": True, "pin_previous": True},
    "roots": [
        {"path": "~/Code", "max_depth": 3},
        {"path": "~/src", "max_depth": 3},
    ],
}

file_viewer = tomllib.loads(Path(sys.argv[2]).read_text())
assert file_viewer == {
    "editor": "nvim",
    "update_check": True,
    "markdown": f'glow -s "{Path.home()}/.config/glow/chezmoi.json" -w 0 -',
    "diff": 'delta --syntax-theme="Monokai Extended"',
    "syntax": (
        'bat --theme="Monokai Extended" --color=always --style=numbers '
        '--paging=never --file-name={name} -'
    ),
    "tree_position": "right",
}
PY

reviewr_config="$repo_root/dot_config/herdr/plugins/config/persiyanov.reviewr/config.toml"
[[ ! -e "$reviewr_config" ]] || { echo "stale managed Reviewr config: $reviewr_config" >&2; exit 1; }

echo "Herdr plugin reconciliation ok"
