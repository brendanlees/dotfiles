#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$repo_root"

require() {
  command -v "$1" >/dev/null || {
    echo "missing required tool: $1" >&2
    exit 1
  }
}
for tool in actionlint shellcheck yamllint taplo python3; do
  require "$tool"
done

SHELLCHECK_OPTS=${SHELLCHECK_OPTS:--e SC1091,SC2001} actionlint

# Generic repository policy owns managed dotfiles, CI, the installer, and
# tests. Skill content is validated at its distribution boundary by SkillSpector.
shellcheck_filespecs=(
  '.github/**/*.sh'
  '.github/**/*.zsh'
  'home/**/*.sh'
  'home/**/*.zsh'
  'tests/**/*.sh'
  'tests/**/*.zsh'
  'install.sh'
)
yaml_filespecs=(
  '.github/**/*.yml'
  '.github/**/*.yaml'
  'home/**/*.yml'
  'home/**/*.yaml'
  'tests/**/*.yml'
  'tests/**/*.yaml'
)
toml_filespecs=(
  '.github/**/*.toml'
  'home/**/*.toml'
  'tests/**/*.toml'
)
policy_filespecs=(
  "${shellcheck_filespecs[@]}"
  '.github/**/*.tmpl'
  '.github/**/*.yml'
  '.github/**/*.yaml'
  '.github/**/*.toml'
  'home/**/*.tmpl'
  'home/**/*.yml'
  'home/**/*.yaml'
  'home/**/*.toml'
  'tests/**/*.tmpl'
  'tests/**/*.yml'
  'tests/**/*.yaml'
  'tests/**/*.toml'
)
remote_script_filespecs=(
  '.github/**/*.sh'
  '.github/**/*.tmpl'
  '.github/**/*.yml'
  '.github/**/*.yaml'
  'home/**/*.sh'
  'home/**/*.tmpl'
  'home/**/*.yml'
  'home/**/*.yaml'
  'tests/**/*.sh'
  'tests/**/*.tmpl'
  'tests/**/*.yml'
  'tests/**/*.yaml'
  'install.sh'
)

tracked_existing_files() {
  local path
  while IFS= read -r -d '' path; do
    if [[ -f $path ]]; then
      printf '%s\0' "$path"
    fi
  done < <(git ls-files -z -- "$@")
}

mapfile -d '' shell_files < <(tracked_existing_files "${shellcheck_filespecs[@]}")
((${#shell_files[@]} == 0)) || shellcheck -e SC1091 "${shell_files[@]}"

yaml_config='{extends: relaxed, rules: {line-length: disable, trailing-spaces: disable, empty-lines: disable, document-start: disable, comments: disable, truthy: disable}}'
mapfile -d '' yaml_files < <(tracked_existing_files "${yaml_filespecs[@]}")
((${#yaml_files[@]} == 0)) || yamllint -d "$yaml_config" "${yaml_files[@]}"

mapfile -d '' toml_files < <(
  tracked_existing_files "${toml_filespecs[@]}" ':!home/.chezmoitemplates/**'
)
((${#toml_files[@]} == 0)) || taplo lint --no-schema "${toml_files[@]}"

python3 - <<'PY'
import json
import subprocess
from pathlib import Path

excluded_jsonc = {
    "home/dot_config/zed/keymap.json",
    "home/dot_config/zed/tasks.json",
}
paths = [
    path
    for path in subprocess.check_output(
        ["git", "ls-files", "--", "home/**/*.json", "agents/.skill-lock.json"],
        text=True,
    ).splitlines()
    if path not in excluded_jsonc and Path(path).is_file()
]
for path in paths:
    try:
        json.loads(Path(path).read_text())
    except json.JSONDecodeError as error:
        raise SystemExit(f"{path}: invalid JSON: {error}") from error
print(f"validated {len(paths)} static JSON files; skipped 2 documented JSONC files")
PY

if grep -nrE 'uses:[[:space:]]+[^[:space:]#]+@[^[:space:]#]+' .github/workflows \
  | grep -vE '@[0-9a-f]{40}([[:space:]]+#.*)?$'; then
  echo 'GitHub Action references must use full commit SHAs' >&2
  exit 1
fi

fails=0
if git grep -nE 'chmod[[:space:]]+(-[Rr][[:space:]]+)?777\b' -- \
    "${policy_filespecs[@]}"; then
  echo 'world-writable mode found' >&2
  fails=$((fails + 1))
fi

is_approved_chezmoi_installer() {
  grep -qxE '[[:space:]]*curl[[:space:]]+(-[A-Za-z0-9]+[[:space:]]+)*(https?://)?get\.chezmoi\.io[[:space:]]*\|[[:space:]]*sh[[:space:]]*' \
    <<<"$1"
}

is_approved_mise_installer() {
  local file=$1 line_no=$2 line=$3 current='' current_no=0 url_line=0 confirm_line=0
  # shellcheck disable=SC2016 # Match the literal installer variable name.
  if ! grep -qxE '[[:space:]]*curl[[:space:]]+"\$mise_install_url"[[:space:]]*\|[[:space:]]*sh[[:space:]]*' \
      <<<"$line"; then
    return 1
  fi
  while IFS= read -r current; do
    current_no=$((current_no + 1))
    ((current_no < line_no)) || break
    if grep -qE '^[[:space:]]*mise_install_url=' <<<"$current"; then
      ((confirm_line == 0)) || return 1
      if grep -qxE '^[[:space:]]*mise_install_url="https://mise\.run"[[:space:]]*$' \
          <<<"$current"; then
        url_line=$current_no
      else
        url_line=0
      fi
    fi
    # shellcheck disable=SC2016 # Match the literal installer variable name.
    if grep -qxE '^[[:space:]]*confirm_remote_script[[:space:]]+"mise"[[:space:]]+"\$mise_install_url"[[:space:]]*$' \
        <<<"$current"; then
      ((url_line > 0)) || return 1
      confirm_line=$current_no
    fi
  done <"$file"
  ((url_line > 0 && confirm_line > url_line))
}

unsafe=''
while IFS=: read -r file line_no line; do
  is_approved_chezmoi_installer "$line" && continue
  is_approved_mise_installer "$file" "$line_no" "$line" && continue
  printf -v unsafe '%s%s:%s:%s\n' "$unsafe" "$file" "$line_no" "$line"
done < <(
  git grep -nE 'curl[^|]+\|[[:space:]]*(sh|bash)\b' -- \
    "${remote_script_filespecs[@]}" || true
)
if [[ -n $unsafe ]]; then
  printf '%s' "$unsafe" >&2
  echo 'curl pipe found outside approved allowlist' >&2
  fails=$((fails + 1))
fi

((fails == 0))
