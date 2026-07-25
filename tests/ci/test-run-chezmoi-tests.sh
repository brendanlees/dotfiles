#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/pass.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat >"$tmpdir/fail-one.sh" <<'SH'
#!/usr/bin/env bash
echo 'first failure' >&2
exit 3
SH
cat >"$tmpdir/fail-two.sh" <<'SH'
#!/usr/bin/env bash
echo 'second failure' >&2
exit 7
SH
chmod +x "$tmpdir"/*.sh

set +e
output=$("$repo_root/tests/ci/run-chezmoi-tests.sh" \
  "$tmpdir/pass.sh" "$tmpdir/fail-one.sh" "$tmpdir/fail-two.sh" 2>&1)
status=$?
set -e

[[ $status -eq 1 ]]
grep -Fq "PASS $tmpdir/pass.sh" <<<"$output"
grep -Fq "FAIL $tmpdir/fail-one.sh (exit 3" <<<"$output"
grep -Fq "FAIL $tmpdir/fail-two.sh (exit 7" <<<"$output"
grep -Fq 'SUMMARY: 1 passed, 2 failed' <<<"$output"

echo 'aggregate runner behavior ok'
