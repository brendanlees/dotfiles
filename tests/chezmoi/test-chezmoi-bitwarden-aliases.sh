#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
aliases_file="$repo_root/home/dot_config/zsh/exact_aliases.d/chezmoi.zsh.tmpl"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

fake_bin="$tmpdir/bin"
fixture_source="$tmpdir/source"
bw_log="$tmpdir/bw.log"
chezmoi_log="$tmpdir/chezmoi.log"
mkdir -p "$fake_bin"
git init --quiet "$fixture_source"

cat >"$fake_bin/bw" <<'BW'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "${BW_LOG:?}"
if [[ "$*" != 'unlock --raw' ]]; then
  echo "unexpected bw invocation: $*" >&2
  exit 64
fi
printf 'fixture-session\n'
BW
chmod +x "$fake_bin/bw"

cat >"$fake_bin/chezmoi" <<'CHEZMOI'
#!/usr/bin/env bash
set -euo pipefail

printf '%s|%s\n' "$*" "${BW_SESSION-<unset>}" >> "${CHEZMOI_LOG:?}"
case "${1-}" in
  source-path)
    printf '%s\n' "${CHEZMOI_SOURCE:?}"
    ;;
  purge|init)
    ;;
  *)
    echo "unexpected chezmoi invocation: $*" >&2
    exit 64
    ;;
esac
CHEZMOI
chmod +x "$fake_bin/chezmoi"

# shellcheck disable=SC2016 # Expanded by the isolated zsh process, not bash.
printf 'yes\n' | env -u BW_SESSION \
  PATH="$fake_bin:$PATH" \
  ALIASES_FILE="$aliases_file" \
  BW_LOG="$bw_log" \
  CHEZMOI_LOG="$chezmoi_log" \
  CHEZMOI_SOURCE="$fixture_source" \
  zsh -fc '
    source "$ALIASES_FILE"
    cz-bw-r
    if [[ -n "${BW_SESSION-}" ]]; then
      print -u2 "cz-bw-r leaked BW_SESSION into the caller"
      exit 1
    fi
  '

[[ $(<"$bw_log") == 'unlock --raw' ]]
[[ $(wc -l <"$chezmoi_log" | tr -d '[:space:]') == 3 ]]
grep -Fxq "source-path|fixture-session" "$chezmoi_log"
grep -Fxq "purge --force|fixture-session" "$chezmoi_log"
grep -Fxq "init --apply brendanlees|fixture-session" "$chezmoi_log"

echo 'Bitwarden reinit alias passes one session to czr'
