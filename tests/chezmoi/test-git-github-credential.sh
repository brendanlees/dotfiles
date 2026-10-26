#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
chezmoi_bin=$(command -v chezmoi)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Git over HTTPS to GitHub must use the gh login when gh is installed, and must
# not fall back to an earlier helper such as osxkeychain.
config_file="$tmpdir/chezmoi.toml"
printf '%s\n' '[data]' 'personal = false' 'work = false' >"$config_file"
mkdir -p "$tmpdir/source" "$tmpdir/home"

# A fake gh stands in for the real CLI, so no account or token is touched.
fake_bin="$tmpdir/bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/gh" <<'EOF'
#!/bin/sh
[ "$*" = 'auth git-credential get' ] || exit 0
cat >/dev/null
printf 'username=fixture-user\npassword=fixture-token\n'
EOF
chmod +x "$fake_bin/gh"

render() {
  PATH="$1" HOME="$tmpdir/home" "$chezmoi_bin" execute-template --no-tty \
    --source "$tmpdir/source" --config "$config_file" \
    <"$repo_root/home/dot_config/git/config.tmpl" >"$2"
}

render "$fake_bin:/usr/bin:/bin" "$tmpdir/with-gh"
# Version managers such as mise move gh on upgrade; the rendered config must
# keep working without another chezmoi apply.
moved_bin="$tmpdir/moved-bin"
mkdir -p "$moved_bin"
mv "$fake_bin/gh" "$moved_bin/gh"
username=$(printf 'protocol=https\nhost=github.com\n\n' |
  PATH="$moved_bin:/usr/bin:/bin" HOME="$tmpdir/home" GIT_CONFIG_GLOBAL="$tmpdir/with-gh" \
    GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 git credential fill 2>/dev/null |
  sed -n 's/^username=//p') || true
if [[ "$username" != fixture-user ]]; then
  echo 'GitHub HTTPS credentials do not come from gh' >&2
  exit 1
fi

# CI runners ship gh in /usr/bin, so hide every system tool from this render.
mkdir -p "$tmpdir/no-tools"
render "$tmpdir/no-tools" "$tmpdir/without-gh"
if git config --file "$tmpdir/without-gh" --get-all credential.https://github.com.helper >/dev/null; then
  echo 'GitHub credential helper rendered without gh installed' >&2
  exit 1
fi
echo 'git github credential helper ok'
