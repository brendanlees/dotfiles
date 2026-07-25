#!/usr/bin/env bash
set -uo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
if (($#)); then
  tests=("$@")
else
  shopt -s nullglob
  tests=("$repo_root"/tests/chezmoi/test-*.sh)
fi

if ((${#tests[@]} == 0)); then
  echo 'FAIL no chezmoi tests found' >&2
  exit 1
fi

passed=0
failed=0
failed_names=()
suite_start=$SECONDS
for test_file in "${tests[@]}"; do
  start=$SECONDS
  printf 'RUN  %s\n' "$test_file"
  if bash "$test_file"; then
    passed=$((passed + 1))
    printf 'PASS %s (%ss)\n' "$test_file" "$((SECONDS - start))"
  else
    status=$?
    failed=$((failed + 1))
    failed_names+=("$test_file")
    printf 'FAIL %s (exit %s, %ss)\n' "$test_file" "$status" "$((SECONDS - start))" >&2
  fi
done

printf 'SUMMARY: %s passed, %s failed (%ss)\n' \
  "$passed" "$failed" "$((SECONDS - suite_start))"
if ((failed)); then
  printf 'FAILED TESTS:\n' >&2
  printf '  %s\n' "${failed_names[@]}" >&2
  exit 1
fi
