#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
tmpdir=$(mktemp -d)
tmpdir=$(cd "$tmpdir" && pwd -P)
trap 'rm -rf "$tmpdir"' EXIT
real_git=$(command -v git)
chezmoi_bin=$(command -v chezmoi)

remote='git@fixture.invalid:owner/private-skills.git'
first_skill='alpha-skill'
second_skill='beta-skill'
third_skill='gamma-skill'

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
  "$private_seed/skills/draft-skill" \
  "$private_seed/skills/nested-skill/child"
printf -- '---\nname: %s\n---\nprivate fixture\n' "$first_skill" >"$private_seed/skills/$first_skill/SKILL.md"
printf 'draft\n' >"$private_seed/skills/draft-skill/README.md"
printf -- '---\nname: nested\n---\n' >"$private_seed/skills/nested-skill/child/SKILL.md"
"$real_git" -C "$private_seed" add .
"$real_git" -C "$private_seed" commit -qm 'test: initialize private fixture'

public_root="$tmpdir/public"
init_repo "$public_root"
mkdir -p "$public_root/home" "$public_root/agents/skills/public-fixture"
printf 'home\n' >"$public_root/.chezmoiroot"
printf 'public\n' >"$public_root/agents/skills/public-fixture/SKILL.md"
printf '/agents/state/\n' >"$public_root/.gitignore"
"$real_git" -C "$public_root" add .
"$real_git" -C "$public_root" commit -qm 'test: initialize public fixture'

checkout="$tmpdir/private-checkout"
config_file="$tmpdir/chezmoi.toml"
helper="$tmpdir/cz-private-agent-skills"

render_helper() {
  local personal=$1 output=$2
  printf '[data]\npersonal = %s\n\n[data.private_agent_skills]\nremote = "%s"\ncheckout = "%s"\n' \
    "$personal" "$remote" "$checkout" >"$config_file"
  "$chezmoi_bin" execute-template \
    --source "$public_root" \
    --config "$config_file" \
    --override-data '{"chezmoi":{"os":"darwin"}}' \
    <"$source_root/dot_local/bin/executable_cz-private-agent-skills.tmpl" >"$output"
  chmod +x "$output"
}

fake_bin="$tmpdir/bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/git" <<'FAKE_GIT'
#!/usr/bin/env bash
set -euo pipefail
operation=${1:-}
[[ $operation != -C ]] || operation=${3:-}
printf '%s\n' "$operation" >>"$FIXTURE_GIT_LOG"
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

state_file="$public_root/agents/state/private-agent-skills.json"
exclude_file="$public_root/.git/info/exclude"
first_destination="$public_root/agents/skills/$first_skill"
second_destination="$public_root/agents/skills/$second_skill"
third_destination="$public_root/agents/skills/$third_skill"

# Negative eligibility and clone failure reuse the same untouched public fixture.
render_helper false "$helper"
"$helper" --fail reconcile
[[ ! -e $checkout && ! -e $state_file && ! -e $first_destination ]]

render_helper true "$helper"
FIXTURE_FAIL_CLONE=true "$helper" reconcile >/dev/null 2>&1
[[ ! -e $checkout && ! -e $state_file && ! -e $first_destination ]]
[[ -z $(find "$tmpdir" -maxdepth 1 -name '.private-checkout.cz-private-agent-skills.*.tmp' -print -quit) ]]
: >"$FIXTURE_GIT_LOG"

# Bootstrap clones once, composes direct skills, and writes exact excludes.
"$helper" --fail reconcile
[[ -d $checkout/.git ]]
[[ -L $first_destination ]]
[[ $(readlink "$first_destination") == "$checkout/skills/$first_skill" ]]
[[ ! -e "$public_root/agents/skills/draft-skill" ]]
[[ ! -e "$public_root/agents/skills/nested-skill" ]]
jq -e '.schema_version == 1 and (.entries | length == 1)' "$state_file" >/dev/null
[[ $(grep -Fxc "agents/skills/$first_skill" "$exclude_file") -eq 1 ]]
[[ -z $("$real_git" -C "$public_root" status --porcelain) ]]

"$helper" --fail reconcile
[[ $(grep -c '^clone$' "$FIXTURE_GIT_LOG") -eq 1 ]]
if grep -Eq '^(fetch|pull|reset|clean|switch|checkout)$' "$FIXTURE_GIT_LOG"; then
  echo 'helper performed forbidden Git maintenance' >&2
  exit 1
fi

# Dirty private state can reconcile additions, but interrupted operations cannot.
printf 'edited\n' >>"$first_destination/SKILL.md"
mkdir -p "$checkout/skills/$second_skill"
printf -- '---\nname: %s\n---\n' "$second_skill" >"$checkout/skills/$second_skill/SKILL.md"
"$helper" --fail reconcile
[[ -L $second_destination ]]
[[ -n $("$real_git" -C "$checkout" status --porcelain) ]]
[[ -z $("$real_git" -C "$public_root" status --porcelain) ]]

mkdir -p "$checkout/skills/$third_skill"
printf -- '---\nname: %s\n---\n' "$third_skill" >"$checkout/skills/$third_skill/SKILL.md"
printf 'synthetic\n' >"$checkout/.git/MERGE_HEAD"
if "$helper" --fail reconcile >/dev/null 2>&1; then
  echo 'interrupted Git operation unexpectedly reconciled' >&2
  exit 1
fi
[[ ! -e $third_destination && -L $first_destination ]]
rm "$checkout/.git/MERGE_HEAD"

# Destination collisions and uncertain owned-link targets fail closed.
printf 'collision\n' >"$third_destination"
if "$helper" --fail reconcile >/dev/null 2>&1; then exit 1; fi
grep -Fxq collision "$third_destination"
rm "$third_destination"
"$helper" --fail reconcile
[[ -L $third_destination ]]

rm "$first_destination"
ln -s "$checkout/skills/$third_skill" "$first_destination"
if "$helper" --fail reconcile >/dev/null 2>&1; then exit 1; fi
[[ $(readlink "$first_destination") == "$checkout/skills/$third_skill" ]]
rm "$first_destination"
ln -s "$checkout/skills/$first_skill" "$first_destination"

# Stale links and excludes are removed without deleting private content.
printf 'preserve\n' >"$checkout/skills/$second_skill/preserve.txt"
rm "$checkout/skills/$second_skill/SKILL.md"
"$helper" --fail reconcile
[[ ! -e $second_destination ]]
[[ -f "$checkout/skills/$second_skill/preserve.txt" ]]
if grep -Fqx "agents/skills/$second_skill" "$exclude_file"; then exit 1; fi

# Legacy ledger fields are accepted. Deactivate preserves checkout and config.
legacy_state="$tmpdir/state.legacy"
jq --arg checkout "$checkout" '. + {
  decommission_pending: false,
  recorded_checkout: null,
  checkout_deleted: false,
  legacy_checkout_hint: $checkout
}' "$state_file" >"$legacy_state"
mv "$legacy_state" "$state_file"
jq -r '.entries[].exclude' "$state_file" >"$tmpdir/owned-excludes"
printf 'keep/exclude\n' >>"$exclude_file"
printf 'checkout marker\n' >"$checkout/preserve-private-checkout.txt"
config_before=$(shasum -a 256 "$config_file" | cut -d' ' -f1)

"$helper" --fail deactivate
[[ -f "$checkout/preserve-private-checkout.txt" ]]
[[ ! -e $state_file ]]
[[ -z $(find "$public_root/agents/skills" -mindepth 1 -maxdepth 1 ! -name public-fixture -print -quit) ]]
[[ $(shasum -a 256 "$config_file" | cut -d' ' -f1) == "$config_before" ]]
grep -Fxq 'keep/exclude' "$exclude_file"
while IFS= read -r exclude; do
  if grep -Fqx "$exclude" "$exclude_file"; then exit 1; fi
done <"$tmpdir/owned-excludes"

# Deactivate is idempotent and the preserved checkout can reconcile again.
"$helper" --fail deactivate
[[ -f "$checkout/preserve-private-checkout.txt" && ! -e $state_file ]]
"$helper" --fail reconcile
[[ -L $first_destination ]]
[[ $(shasum -a 256 "$config_file" | cut -d' ' -f1) == "$config_before" ]]
[[ -z $("$real_git" -C "$public_root" status --porcelain) ]]

echo 'private agent skills POSIX integration ok'
