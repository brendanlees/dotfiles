#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
shared="$repo_root/agents/AGENTS.md"
pi_append="$repo_root/agents/pi/APPEND_SYSTEM.md"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/expected-shared.md" <<'EOF'
## Prime Directive

- Be concise, useful, and evidence-led; user instructions and explicit model/tool overrides win.
- Separate planning from execution: inspect/ask/plan first; mutate only after approval or clear implementation intent.
- If a request bundles unrelated work, stop and confirm scope. Prefer the simplest working solution.

## Safe Execution

- Before source/config mutation, verify workspace isolation. Never edit on `main`/`master`; use Worktrunk (`git-wt` on Windows, `wt` elsewhere), with raw `git worktree` only as fallback.
- Run relevant verification before claiming work is complete. For TS/JS changed since main, use `fallow audit --changed-since main`.
- Use Conventional Commits; keep commit bodies minimal unless context is essential.
EOF

cmp "$tmpdir/expected-shared.md" "$shared"
[[ -f "$pi_append" ]]

required=(
  'Prefer cwd-scoped Serena'
  'fffind'
  'browser-session-discipline'
  'pi-orchestration'
  'docs/features/<slug>.md'
  'harness-config-workflow'
  'gpt-5.6-sol'
  'RTK command rewriting is automatic'
)
for marker in "${required[@]}"; do
  grep -Fq "$marker" "$pi_append" || {
    echo "missing Pi policy marker: $marker" >&2
    exit 1
  }
  if grep -Fq "$marker" "$shared"; then
    echo "Pi policy leaked into shared instructions: $marker" >&2
    exit 1
  fi
done

for heading in '## Pi Tool Routing' '## Pi Safety Additions' '## Pi Config Changes' '## Pi Defaults'; do
  grep -Fxq "$heading" "$pi_append"
done

if grep -Fq 'Use Conventional Commits' "$pi_append" || grep -Fq 'verify workspace isolation' "$pi_append"; then
  echo 'generic shared policy was duplicated into Pi append instructions' >&2
  exit 1
fi

echo 'Agent instruction split ok'
