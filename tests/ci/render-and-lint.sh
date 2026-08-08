#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
config=${CHEZMOI_CONFIG_FILE:?CHEZMOI_CONFIG_FILE must name an initialized config}
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
cd "$repo_root"

require() {
  command -v "$1" >/dev/null || {
    echo "missing required tool: $1" >&2
    exit 1
  }
}
for tool in chezmoi shellcheck yamllint taplo python3; do
  require "$tool"
done

chezmoi_bin=$(command -v chezmoi)
render_path=''
IFS=: read -r -a path_entries <<<"$PATH"
for path_entry in "${path_entries[@]}"; do
  [[ -n $path_entry ]] || continue
  [[ -x $path_entry/bw ]] && continue
  render_path=${render_path:+$render_path:}$path_entry
done

is_init_only() {
  case "$1" in
    .chezmoi.toml.tmpl | .chezmoiexternal.toml.tmpl) return 0 ;;
    .chezmoitemplates/*) return 0 ;; # caller-context partials have focused tests
    *) return 1 ;;
  esac
}

fails=0
while IFS= read -r template; do
  relative=${template#"$source_root/"}
  if is_init_only "$relative"; then
    printf 'SKIP %s (caller or init context)\n' "$relative"
    continue
  fi

  output="$staging/${relative%.tmpl}"
  mkdir -p "$(dirname "$output")"
  if ! rendered=$(PATH="$render_path" "$chezmoi_bin" execute-template \
      --source "$repo_root" --config "$config" <"$template"); then
    printf 'FAIL %s\n' "$template" >&2
    fails=$((fails + 1))
    continue
  fi
  if [[ -z $rendered ]]; then
    continue
  fi
  printf '%s\n' "$rendered" >"$output"
  if [[ $template == *.sh.tmpl ]] && [[ $(head -n1 "$output") != '#!'* ]]; then
    printf 'FAIL %s (missing first-line shebang)\n' "$template" >&2
    fails=$((fails + 1))
  fi
  printf 'OK   %s\n' "$template"
done < <(find "$source_root" -type f -name '*.tmpl' | sort)

mapfile -d '' rendered_shell < <(find "$staging" -type f -name '*.sh' -print0)
((${#rendered_shell[@]} == 0)) || shellcheck -e SC1091 "${rendered_shell[@]}"

mapfile -d '' rendered_yaml < <(
  find "$staging" -type f \( -name '*.yml' -o -name '*.yaml' \) -print0
)
yaml_config='{extends: relaxed, rules: {line-length: disable, trailing-spaces: disable, empty-lines: disable, document-start: disable, comments: disable, truthy: disable}}'
((${#rendered_yaml[@]} == 0)) || yamllint -d "$yaml_config" "${rendered_yaml[@]}"

mapfile -d '' rendered_toml < <(find "$staging" -type f -name '*.toml' -print0)
((${#rendered_toml[@]} == 0)) || taplo lint --no-schema "${rendered_toml[@]}"

python3 - "$staging" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
excluded_jsonc = {"dot_config/zed/private_settings.json"}
paths = [
    path
    for path in sorted(root.rglob("*.json"))
    if path.relative_to(root).as_posix() not in excluded_jsonc
]
for path in paths:
    try:
        json.loads(path.read_text())
    except json.JSONDecodeError as error:
        raise SystemExit(f"{path}: invalid rendered JSON: {error}") from error
print(f"validated {len(paths)} rendered JSON files; skipped 1 documented JSONC file")
PY

((fails == 0))
