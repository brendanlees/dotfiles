#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

render_ignore() {
  local name=$1 data=$2
  chezmoi execute-template --source "$repo_root" --override-data "$data" \
    <"$repo_root/.chezmoiignore" >"$tmpdir/$name.ignore"
}

assert_has() { grep -Fxq "$2" "$tmpdir/$1.ignore"; }
assert_lacks() { ! grep -Fxq "$2" "$tmpdir/$1.ignore"; }

render_ignore ephemeral '{"personal":false,"work":false,"homelab":false,"ephemeral":true,"headless":true,"chezmoi":{"os":"linux"}}'
render_ignore personal  '{"personal":true,"work":false,"homelab":false,"ephemeral":false,"headless":false,"chezmoi":{"os":"darwin"}}'
render_ignore work      '{"personal":false,"work":true,"homelab":false,"ephemeral":false,"headless":false,"chezmoi":{"os":"linux"}}'
render_ignore homelab   '{"personal":false,"work":false,"homelab":true,"ephemeral":false,"headless":true,"chezmoi":{"os":"linux"}}'
render_ignore windows   '{"personal":true,"work":false,"homelab":false,"ephemeral":false,"headless":false,"chezmoi":{"os":"windows"}}'

personal_project='.config/herdr/plugins/config/cloudmanic.herdr-plus/projects/personal-*.toml'
work_project='.config/herdr/plugins/config/cloudmanic.herdr-plus/projects/work-*.toml'
homelab_project='.config/herdr/plugins/config/cloudmanic.herdr-plus/projects/homelab-*.toml'

assert_has ephemeral '.config/ghostty'
assert_has ephemeral "$personal_project"
assert_has ephemeral "$work_project"
assert_has ephemeral "$homelab_project"

assert_lacks personal "$personal_project"
assert_has personal "$work_project"
assert_has personal "$homelab_project"

assert_has work "$personal_project"
assert_lacks work "$work_project"
assert_has work "$homelab_project"

assert_has homelab "$personal_project"
assert_has homelab "$work_project"
assert_lacks homelab "$homelab_project"

posix_private_helper='.local/bin/cz-private-agent-skills'
windows_private_helper='.local/bin/cz-private-agent-skills.ps1'
posix_private_apply='.chezmoiscripts/darwin/**'
windows_private_apply='.chezmoiscripts/windows/**'

assert_lacks personal "$posix_private_helper"
assert_lacks personal "$posix_private_apply"
assert_has personal "$windows_private_helper"
assert_has personal "$windows_private_apply"

assert_lacks windows "$windows_private_helper"
assert_lacks windows "$windows_private_apply"
assert_has windows "$posix_private_helper"
assert_has windows "$posix_private_apply"

assert_has homelab "$posix_private_helper"
assert_has homelab "$windows_private_helper"
assert_has homelab "$posix_private_apply"
assert_has homelab "$windows_private_apply"

echo 'role routing matrix ok'
