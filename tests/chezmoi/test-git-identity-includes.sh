#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Each forge's identity include must apply to every remote URL form git accepts.
config_file="$tmpdir/chezmoi.toml"
printf '%s\n' '[data]' 'personal = true' 'work = false' \
  '[data.bw_github]' 'name = "Fixture"' 'email = "default@fixture"' >"$config_file"
mkdir -p "$tmpdir/source" "$tmpdir/home/.config/git"
HOME="$tmpdir/home" chezmoi execute-template --no-tty \
  --source "$tmpdir/source" --config "$config_file" \
  <"$repo_root/home/dot_config/git/config.tmpl" >"$tmpdir/gitconfig"
printf '[user]\n  email = forgejo@fixture\n' >"$tmpdir/home/.config/git/forgejo"
printf '[user]\n  email = github@fixture\n' >"$tmpdir/home/.config/git/github"

email_for() {
  local repo
  repo=$(mktemp -d "$tmpdir/repo.XXXXXX")
  git -C "$repo" init -q
  git -C "$repo" remote add origin "$1"
  HOME="$tmpdir/home" GIT_CONFIG_GLOBAL="$tmpdir/gitconfig" GIT_CONFIG_NOSYSTEM=1 \
    git -C "$repo" config --get user.email || echo none
}

check() {
  local actual
  actual=$(email_for "$1")
  if [[ "$actual" != "$2" ]]; then
    echo "$1: expected $2, got $actual" >&2
    exit 1
  fi
}

check ssh://git@git.lab.brendans.cloud/xbxd/claude-config.git forgejo@fixture
check git@git.lab.brendans.cloud:xbxd/skills-vault.git forgejo@fixture
check https://git.lab.brendans.cloud/xbxd/skills-vault.git forgejo@fixture
check git@github.com:brendanlees/dotfiles.git github@fixture
check https://github.com/brendanlees/dotfiles.git github@fixture
# The default identity depends on whether bw is installed, so only check the include is skipped.
if [[ "$(email_for git@gitea.lab.brendans.cloud:xbxd/old.git)" == forgejo@fixture ]]; then
  echo 'gitea.lab remote matched the git.lab identity include' >&2
  exit 1
fi
echo 'git identity includes ok'
