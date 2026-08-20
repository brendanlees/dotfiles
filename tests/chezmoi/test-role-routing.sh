#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

render_ignore() {
  local name=$1 data=$2
  chezmoi execute-template --source "$repo_root" --override-data "$data" \
    <"$source_root/.chezmoiignore" >"$tmpdir/$name.ignore"
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

render_scope_templates() {
  local name=$1 data=$2
  chezmoi execute-template --source "$repo_root" --override-data "$data" \
    <"$source_root/.chezmoiexternal.toml.tmpl" >"$tmpdir/$name.external"
  chezmoi execute-template --source "$repo_root" --override-data "$data" \
    <"$source_root/.chezmoiremove.tmpl" >"$tmpdir/$name.remove"
  chezmoi execute-template --source "$repo_root" --override-data "$data" \
    <"$source_root/dot_config/mise/config.toml.tmpl" >"$tmpdir/$name.mise"
}

personal_data='{"personal":true,"work":false,"homelab":false,"ephemeral":false,"headless":false,"chezmoi":{"os":"linux","username":"test"}}'
personal_work_data='{"personal":true,"work":true,"homelab":false,"ephemeral":false,"headless":false,"chezmoi":{"os":"linux","username":"test"}}'
work_data='{"personal":false,"work":true,"homelab":false,"ephemeral":false,"headless":false,"chezmoi":{"os":"linux","username":"test"}}'
homelab_data='{"personal":false,"work":false,"homelab":true,"ephemeral":false,"headless":true,"chezmoi":{"os":"linux","username":"test"}}'

render_scope_templates personal "$personal_data"
render_scope_templates personal-work "$personal_work_data"
render_scope_templates work "$work_data"
render_scope_templates homelab "$homelab_data"

assert_file_has() { grep -Fq "$2" "$1"; }
assert_file_lacks() { if grep -Fq "$2" "$1"; then return 1; fi; }
pi_remove=$(printf '%s/%s' '~' '.pi')

for scope in personal personal-work; do
  assert_file_has "$tmpdir/$scope.external" '[".pi"]'
  assert_file_lacks "$tmpdir/$scope.remove" "$pi_remove"
  assert_file_has "$tmpdir/$scope.mise" 'infisical = "latest"'
done

assert_file_has "$tmpdir/work.remove" "$pi_remove"
assert_file_has "$tmpdir/homelab.remove" "$pi_remove"
assert_file_lacks "$tmpdir/work.external" '[".pi"]'
assert_file_lacks "$tmpdir/homelab.external" '[".pi"]'
assert_file_lacks "$tmpdir/work.mise" 'infisical = "latest"'
assert_file_has "$tmpdir/homelab.mise" 'infisical = "latest"'

echo 'role routing matrix ok'
