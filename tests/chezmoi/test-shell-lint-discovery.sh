#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
source "$repo_root/tests/ci/shell-files.sh"

# Extensionless managed commands and rendered templates must reach ShellCheck.
printf '#!/usr/bin/env bash\necho ok\n' >"$tmpdir/executable_theme"
printf '#!/bin/sh\necho ok\n' >"$tmpdir/bordersrc"
printf 'echo ok\n' >"$tmpdir/fragment.sh"
printf '#!/usr/bin/env bash\n{{ .theme }}\n' >"$tmpdir/unrendered.tmpl"
printf '#!/usr/bin/env python3\nprint("ok")\n' >"$tmpdir/python-command"
printf 'plain text\n' >"$tmpdir/notes"
printf '#!/usr/bin/env zsh\nsetopt autocd\n' >"$tmpdir/unsupported.zsh"

mapfile -d '' actual < <(printf '%s\0' "$tmpdir"/* | shell_files)
expected=("$tmpdir/bordersrc" "$tmpdir/executable_theme" "$tmpdir/fragment.sh")
[[ ${#actual[@]} -eq ${#expected[@]} ]]
for i in "${!expected[@]}"; do
  [[ ${actual[$i]} == "${expected[$i]}" ]]
done

echo 'shell lint discovery ok'
