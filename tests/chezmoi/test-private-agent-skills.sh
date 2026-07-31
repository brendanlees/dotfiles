#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
tmpdir=$(cd "$tmpdir" && pwd -P)
trap 'rm -rf "$tmpdir"' EXIT
real_git=$(command -v git)
chezmoi_bin=$(command -v chezmoi)

runtime_id=$(printf '%s-%s-%s' "$RANDOM" "$$" "$(date +%s)")
remote="git@fixture-${runtime_id}.invalid:owner-${runtime_id}/repo-${runtime_id}.git"
first_skill="skill-${runtime_id}"
second_skill="second-${runtime_id}"
third_skill="third-${runtime_id}"
fourth_skill="fourth-${runtime_id}"
fifth_skill="fifth-${runtime_id}"
private_content="content-${runtime_id}"

# The init config template accepts the generic values from noninteractive data
# and emits them only into the machine-local configuration.
init_input=$(jq -nc --arg remote "$remote" --arg checkout "$tmpdir/config-checkout" \
  '{private_agent_skills:{remote:$remote,checkout:$checkout},chezmoi:{os:"darwin"}}')
printf '[data]\n' >"$tmpdir/init-input.toml"
mkdir -p "$tmpdir/init-bin"
cat >"$tmpdir/init-bin/scutil" <<'EOF'
#!/usr/bin/env bash
printf 'synthetic-host\n'
EOF
chmod +x "$tmpdir/init-bin/scutil"
CHEZMOI_ROLE=personal PATH="$tmpdir/init-bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  "$chezmoi_bin" execute-template --init --source "$repo_root" \
  --config "$tmpdir/init-input.toml" --override-data "$init_input" \
  <"$repo_root/.chezmoi.toml.tmpl" >"$tmpdir/rendered-init.toml"
grep -Fxq '[data.private_agent_skills]' "$tmpdir/rendered-init.toml"
grep -Fxq "  remote = \"$remote\"" "$tmpdir/rendered-init.toml"
grep -Fxq "  checkout = \"$tmpdir/config-checkout\"" "$tmpdir/rendered-init.toml"

init_repo() {
  local path=$1
  mkdir -p "$path"
  "$real_git" -C "$path" init -q
  "$real_git" -C "$path" config user.name 'Synthetic Fixture'
  "$real_git" -C "$path" config user.email 'fixture@invalid.example'
}

private_seed="$tmpdir/private-seed"
init_repo "$private_seed"
mkdir -p \
  "$private_seed/skills/$first_skill" \
  "$private_seed/skills/draft-$runtime_id" \
  "$private_seed/skills/nested-$runtime_id/child-$runtime_id"
printf -- '---\nname: %s\n---\n%s\n' "$first_skill" "$private_content" >"$private_seed/skills/$first_skill/SKILL.md"
printf '%s\n' "$private_content" >"$private_seed/skills/draft-$runtime_id/README.md"
printf -- '---\nname: nested\n---\n' >"$private_seed/skills/nested-$runtime_id/child-$runtime_id/SKILL.md"
"$real_git" -C "$private_seed" add .
"$real_git" -C "$private_seed" commit -qm 'test: initialize synthetic private fixture'

public_root="$tmpdir/public"
init_repo "$public_root"
mkdir -p "$public_root/agents/skills/public-fixture" "$public_root/agents/state"
printf -- '---\nname: public-fixture\n---\n' >"$public_root/agents/skills/public-fixture/SKILL.md"
printf 'unrelated\n' >"$public_root/unrelated.txt"
printf '/agents/state/\n' >"$public_root/.gitignore"
"$real_git" -C "$public_root" add .
"$real_git" -C "$public_root" commit -qm 'test: initialize synthetic public fixture'

checkout="$tmpdir/private-checkout"
config_file="$tmpdir/chezmoi.toml"
printf '[data]\npersonal = true\n\n[data.private_agent_skills]\nremote = "%s"\ncheckout = "%s"\n' \
  "$remote" "$checkout" >"$config_file"

render_helper() {
  local source=$1 config=$2 output=$3 override=${4:-}
  [[ -n $override ]] || override='{"chezmoi":{"os":"darwin"}}'
  chezmoi execute-template --source "$source" --config "$config" --override-data "$override" \
    <"$repo_root/dot_local/bin/executable_cz-private-agent-skills.tmpl" >"$output"
  chmod +x "$output"
}

helper="$tmpdir/cz-private-agent-skills"
render_helper "$public_root" "$config_file" "$helper"
grep -Fq "TEMPLATE_PERSONAL='true'" "$helper"
grep -Fq "TEMPLATE_OS='darwin'" "$helper"
grep -Fq "CONFIGURED_REMOTE='$remote'" "$helper"
grep -Fq "CONFIGURED_CHECKOUT='$checkout'" "$helper"

fake_bin="$tmpdir/bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/git" <<'FAKE_GIT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${1:-}" >>"$FIXTURE_GIT_LOG"
if [[ ${1:-} == clone ]]; then
  if [[ ${FIXTURE_FAIL_CLONE:-false} == true ]]; then exit 1; fi
  destination=${!#}
  remote_index=$(($# - 1))
  requested_remote=${!remote_index}
  "$REAL_GIT" clone --quiet "$FIXTURE_PRIVATE_SEED" "$destination"
  "$REAL_GIT" -C "$destination" remote set-url origin "$requested_remote"
  exit 0
fi
exec "$REAL_GIT" "$@"
FAKE_GIT
chmod +x "$fake_bin/git"
export REAL_GIT="$real_git"
export FIXTURE_PRIVATE_SEED="$private_seed"
export FIXTURE_GIT_LOG="$tmpdir/git-operations.log"
export PATH="$fake_bin:$PATH"

assert_no_integration() {
  local root=$1 absent_checkout=$2
  [[ ! -e $absent_checkout ]]
  [[ ! -e "$root/agents/state/private-agent-skills.json" ]]
  [[ -z $(find "$root/agents/skills" -mindepth 1 -maxdepth 1 ! -name public-fixture -print -quit) ]]
  ! grep -Fq 'agents/skills/skill-' "$root/.git/info/exclude"
}

# Eligibility is exactly personal macOS/Windows. Blank, non-personal, and Linux data are no-ops.
negative_root="$tmpdir/negative-public"
init_repo "$negative_root"
mkdir -p "$negative_root/agents/skills/public-fixture"
printf 'public\n' >"$negative_root/agents/skills/public-fixture/SKILL.md"
printf '/agents/state/\n' >"$negative_root/.gitignore"
"$real_git" -C "$negative_root" add .
"$real_git" -C "$negative_root" commit -qm 'test: initialize negative fixture'
negative_checkout="$tmpdir/negative-checkout"
negative_config="$tmpdir/negative.toml"
printf '[data]\npersonal = false\n\n[data.private_agent_skills]\nremote = "%s"\ncheckout = "%s"\n' "$remote" "$negative_checkout" >"$negative_config"
negative_helper="$tmpdir/negative-helper"
render_helper "$negative_root" "$negative_config" "$negative_helper"
"$negative_helper" --fail reconcile
assert_no_integration "$negative_root" "$negative_checkout"

blank_config="$tmpdir/blank.toml"
printf '[data]\npersonal = true\n\n[data.private_agent_skills]\nremote = ""\ncheckout = ""\n' >"$blank_config"
render_helper "$negative_root" "$blank_config" "$negative_helper"
"$negative_helper" --fail reconcile
assert_no_integration "$negative_root" "$negative_checkout"

linux_data=$(jq -nc --arg remote "$remote" --arg checkout "$negative_checkout" \
  '{personal:true,homelab:true,headless:true,private_agent_skills:{remote:$remote,checkout:$checkout},chezmoi:{os:"linux"}}')
render_helper "$negative_root" "$negative_config" "$negative_helper" "$linux_data"
"$negative_helper" --fail reconcile
assert_no_integration "$negative_root" "$negative_checkout"

# Bootstrap clones once, composes only direct valid skills, and leaves public Git clean.
"$helper" --fail reconcile
[[ -d $checkout/.git ]]
[[ -L "$public_root/agents/skills/$first_skill" ]]
[[ $(readlink "$public_root/agents/skills/$first_skill") == "$checkout/skills/$first_skill" ]]
[[ ! -e "$public_root/agents/skills/draft-$runtime_id" ]]
[[ ! -e "$public_root/agents/skills/nested-$runtime_id" ]]
state_file="$public_root/agents/state/private-agent-skills.json"
exclude_file="$public_root/.git/info/exclude"
jq -e '.schema_version == 1 and (.entries | length == 1) and (.decommission_pending == false)' "$state_file" >/dev/null
[[ $(grep -Fxc "agents/skills/$first_skill" "$exclude_file") -eq 1 ]]
[[ -z $("$real_git" -C "$public_root" status --porcelain) ]]
[[ $(grep -c '^clone$' "$FIXTURE_GIT_LOG") -eq 1 ]]

state_hash=$(shasum -a 256 "$state_file" | cut -d' ' -f1)
exclude_hash=$(shasum -a 256 "$exclude_file" | cut -d' ' -f1)
"$helper" --fail reconcile
[[ $(shasum -a 256 "$state_file" | cut -d' ' -f1) == "$state_hash" ]]
[[ $(shasum -a 256 "$exclude_file" | cut -d' ' -f1) == "$exclude_hash" ]]
[[ $(grep -c '^clone$' "$FIXTURE_GIT_LOG") -eq 1 ]]
if grep -Eq '^(fetch|pull|reset|clean|switch|checkout)$' "$FIXTURE_GIT_LOG"; then
  echo 'helper performed forbidden Git maintenance' >&2
  exit 1
fi

# Editing through the unified link dirties only private Git.
printf '%s\n' "$private_content-edited" >>"$public_root/agents/skills/$first_skill/SKILL.md"
[[ -n $("$real_git" -C "$checkout" status --porcelain) ]]
[[ -z $("$real_git" -C "$public_root" status --porcelain) ]]

# Ordinary dirty state allows direct inventory additions.
mkdir -p "$checkout/skills/$second_skill"
printf -- '---\nname: %s\n---\n' "$second_skill" >"$checkout/skills/$second_skill/SKILL.md"
"$helper" --fail reconcile
[[ -L "$public_root/agents/skills/$second_skill" ]]

# Interrupted Git operations preserve current composition and pause additions.
mkdir -p "$checkout/skills/$third_skill"
printf -- '---\nname: %s\n---\n' "$third_skill" >"$checkout/skills/$third_skill/SKILL.md"
printf 'synthetic\n' >"$checkout/.git/MERGE_HEAD"
if "$helper" --fail reconcile >/dev/null 2>&1; then
  echo 'interrupted Git operation unexpectedly reconciled' >&2
  exit 1
fi
[[ ! -e "$public_root/agents/skills/$third_skill" ]]
[[ -L "$public_root/agents/skills/$first_skill" ]]
rm "$checkout/.git/MERGE_HEAD"

# Collisions remain untouched, then reconciliation succeeds after operator recovery.
printf 'collision\n' >"$public_root/agents/skills/$third_skill"
if "$helper" --fail reconcile >/dev/null 2>&1; then
  echo 'destination collision unexpectedly reconciled' >&2
  exit 1
fi
grep -Fxq collision "$public_root/agents/skills/$third_skill"
rm "$public_root/agents/skills/$third_skill"
"$helper" --fail reconcile
[[ -L "$public_root/agents/skills/$third_skill" ]]

# Missing owned entries are repaired.
rm "$public_root/agents/skills/$second_skill"
"$helper" --fail reconcile
[[ -L "$public_root/agents/skills/$second_skill" ]]

# Stale owned links and exact excludes are removed without deleting source content.
printf 'preserve\n' >"$checkout/skills/$second_skill/preserve.txt"
rm "$checkout/skills/$second_skill/SKILL.md"
"$helper" --fail reconcile
[[ ! -e "$public_root/agents/skills/$second_skill" ]]
[[ -f "$checkout/skills/$second_skill/preserve.txt" ]]
if grep -Fqx "agents/skills/$second_skill" "$exclude_file"; then
  echo 'stale exact exclude was not removed' >&2
  exit 1
fi

# Malformed state, remote mismatch, and uncertain ownership all fail closed.
cp "$state_file" "$tmpdir/state.valid"
printf '{not-json\n' >"$state_file"
mkdir -p "$checkout/skills/$fourth_skill"
printf -- '---\nname: %s\n---\n' "$fourth_skill" >"$checkout/skills/$fourth_skill/SKILL.md"
if "$helper" --fail reconcile >/dev/null 2>&1; then exit 1; fi
[[ ! -e "$public_root/agents/skills/$fourth_skill" ]]
mv "$tmpdir/state.valid" "$state_file"

"$real_git" -C "$checkout" remote set-url origin "git@wrong-$runtime_id.invalid:wrong/repo.git"
mkdir -p "$checkout/skills/$fifth_skill"
printf -- '---\nname: %s\n---\n' "$fifth_skill" >"$checkout/skills/$fifth_skill/SKILL.md"
if "$helper" --fail reconcile >/dev/null 2>&1; then exit 1; fi
[[ ! -e "$public_root/agents/skills/$fifth_skill" ]]
"$real_git" -C "$checkout" remote set-url origin "$remote"

rm "$public_root/agents/skills/$first_skill"
ln -s "$checkout/skills/$third_skill" "$public_root/agents/skills/$first_skill"
if "$helper" --fail reconcile >/dev/null 2>&1; then exit 1; fi
[[ $(readlink "$public_root/agents/skills/$first_skill") == "$checkout/skills/$third_skill" ]]
rm "$public_root/agents/skills/$first_skill"
ln -s "$checkout/skills/$first_skill" "$public_root/agents/skills/$first_skill"
"$helper" --fail reconcile

# Default mode isolates integration failure so unrelated work can continue.
"$real_git" -C "$checkout" remote set-url origin "git@unavailable-$runtime_id.invalid:none/repo.git"
"$helper" reconcile >/dev/null 2>&1
printf 'applied\n' >"$tmpdir/unrelated-applied"
grep -Fxq applied "$tmpdir/unrelated-applied"
"$real_git" -C "$checkout" remote set-url origin "$remote"

# A failed initial clone leaves no partial checkout or integration state.
clone_fail_root="$tmpdir/clone-fail-public"
init_repo "$clone_fail_root"
mkdir -p "$clone_fail_root/agents/skills/public-fixture"
printf 'public\n' >"$clone_fail_root/agents/skills/public-fixture/SKILL.md"
printf '/agents/state/\n' >"$clone_fail_root/.gitignore"
"$real_git" -C "$clone_fail_root" add .
"$real_git" -C "$clone_fail_root" commit -qm 'test: initialize clone failure fixture'
clone_fail_checkout="$tmpdir/clone-fail-checkout"
clone_fail_config="$tmpdir/clone-fail.toml"
printf '[data]\npersonal = true\n\n[data.private_agent_skills]\nremote = "%s"\ncheckout = "%s"\n' "$remote" "$clone_fail_checkout" >"$clone_fail_config"
clone_fail_helper="$tmpdir/clone-fail-helper"
render_helper "$clone_fail_root" "$clone_fail_config" "$clone_fail_helper"
FIXTURE_FAIL_CLONE=true "$clone_fail_helper" reconcile >/dev/null 2>&1
assert_no_integration "$clone_fail_root" "$clone_fail_checkout"
[[ -z $(find "$tmpdir" -maxdepth 1 -name '.clone-fail-checkout.cz-private-agent-skills.*.tmp' -print -quit) ]]

# Deactivation is reversible and finalization requires explicit confirmation.
checkout_tree_hash=$(find "$checkout/skills" -type f -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256 | cut -d' ' -f1)
"$helper" --fail deactivate
jq -e '.decommission_pending == true and .checkout_deleted == false' "$state_file" >/dev/null
[[ -d $checkout ]]
[[ -z $(find "$public_root/agents/skills" -mindepth 1 -maxdepth 1 ! -name public-fixture -print -quit) ]]
[[ $(find "$checkout/skills" -type f -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256 | cut -d' ' -f1) == "$checkout_tree_hash" ]]

"$helper" --fail reconcile
[[ -L "$public_root/agents/skills/$first_skill" ]]
jq -e '.decommission_pending == false' "$state_file" >/dev/null
"$helper" --fail deactivate
if "$helper" --fail finalize >/dev/null 2>&1; then
  echo 'unconfirmed finalization unexpectedly succeeded' >&2
  exit 1
fi
[[ -d $checkout ]]
mv "$config_file" "$tmpdir/chezmoi.real.toml"
ln -s "$tmpdir/chezmoi.real.toml" "$config_file"
if "$helper" --fail finalize --confirm-delete >/dev/null 2>&1; then
  echo 'finalization unexpectedly ignored a configuration-clear failure' >&2
  exit 1
fi
[[ ! -e $checkout ]]
jq -e '.decommission_pending == true and .checkout_deleted == true' "$state_file" >/dev/null
rm "$config_file"
mv "$tmpdir/chezmoi.real.toml" "$config_file"
"$helper" --fail finalize --confirm-delete
[[ ! -e $state_file ]]
if grep -Fqx '[data.private_agent_skills]' "$config_file"; then
  echo 'finalization did not clear machine-local configuration' >&2
  exit 1
fi
[[ -z $(find "$public_root/agents/skills" -mindepth 1 -maxdepth 1 ! -name public-fixture -print -quit) ]]

# Runtime confidentiality values never enter tracked source, history, or tracked inventory.
git -C "$repo_root" log -p --all --format= >"$tmpdir/public-history"
"$real_git" -C "$public_root" ls-files >"$tmpdir/public-inventory"
for value in "$remote" "$checkout" "$first_skill" "$private_content"; do
  if git -C "$repo_root" grep -Fq -- "$value" ||
     grep -Fq -- "$value" "$tmpdir/public-history" ||
     grep -Fq -- "$value" "$tmpdir/public-inventory"; then
    echo 'runtime confidentiality value crossed the public boundary' >&2
    exit 1
  fi
done
[[ -z $("$real_git" -C "$public_root" status --porcelain) ]]

echo 'private agent skills POSIX lifecycle ok'
