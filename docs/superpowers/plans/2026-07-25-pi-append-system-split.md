# Pi Append-System Instruction Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep shared agent instructions harness-neutral and load all Pi-specific policy through Pi's supported global `APPEND_SYSTEM.md` mechanism.

**Architecture:** Dotfiles owns `agents/AGENTS.md` and `agents/pi/APPEND_SYSTEM.md`. Pi continues tracking its relative `AGENTS.md` link and adds a relative `APPEND_SYSTEM.md` link. Pi documentation validation reads both files as one instruction policy while preserving their prompt-level separation.

**Tech Stack:** Markdown context/system files, Git symlinks, chezmoi source-owned agents home, Python validation, Bash tests

## Global Constraints

- Work in isolated Worktrunk worktrees; never mutate source/config on `main` before reviewed integration.
- Merge and expose the dotfiles target before creating or validating the Pi symlink.
- Keep Prime Directive plus generic isolation, verification, Fallow, and Conventional Commit guidance in shared `AGENTS.md`.
- Move Pi tool routing, browser-session routing, Pi config obligations, model, handoff, RTK, and orchestration rules to `agents/pi/APPEND_SYSTEM.md` without changing their substance beyond scoping language.
- Do not modify Claude configuration.
- Do not stage, restore, stash, or clean the unrelated live `~/.pi/agent/npm/package.json` modification.
- Add no synchronization scripts, extensions, model changes, or provider-backed verification.
- Update Pi feature documentation, index, and changelog and run `python3 scripts/validate-config-docs.py` from `~/.pi/agent`.

---

### Task 1: Split shared and Pi-specific content in dotfiles

**Files:**
- Modify: `agents/AGENTS.md`
- Create: `agents/pi/APPEND_SYSTEM.md`
- Modify: `docs/file-tracking.md`
- Create: `tests/chezmoi/test-agents-instruction-split.sh`

**Interfaces:**
- Consumes: the current combined `agents/AGENTS.md` policy.
- Produces: exact neutral shared instructions and a canonical Pi append-system file at `~/.agents/pi/APPEND_SYSTEM.md`.

- [ ] **Step 1: Confirm the dotfiles design worktree is clean and the live source matches it**

Run:

```bash
cd ~/.local/share/chezmoi.docs-pi-append-system-split
git status --short --branch
cmp agents/AGENTS.md ~/.agents/AGENTS.md
test ! -e agents/pi/APPEND_SYSTEM.md
```

Expected: branch `docs/pi-append-system-split`, no uncommitted changes, shared file matches live source, and no Pi append file exists.

- [ ] **Step 2: Write the failing split contract test**

Create executable `tests/chezmoi/test-agents-instruction-split.sh`:

```bash
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
```

Run:

```bash
chmod +x tests/chezmoi/test-agents-instruction-split.sh
bash tests/chezmoi/test-agents-instruction-split.sh
```

Expected: FAIL because the current shared file is larger than the expected neutral file and `agents/pi/APPEND_SYSTEM.md` is absent.

- [ ] **Step 3: Replace the shared file with the approved neutral policy**

Write this exact content to `agents/AGENTS.md`:

```markdown
## Prime Directive

- Be concise, useful, and evidence-led; user instructions and explicit model/tool overrides win.
- Separate planning from execution: inspect/ask/plan first; mutate only after approval or clear implementation intent.
- If a request bundles unrelated work, stop and confirm scope. Prefer the simplest working solution.

## Safe Execution

- Before source/config mutation, verify workspace isolation. Never edit on `main`/`master`; use Worktrunk (`git-wt` on Windows, `wt` elsewhere), with raw `git worktree` only as fallback.
- Run relevant verification before claiming work is complete. For TS/JS changed since main, use `fallow audit --changed-since main`.
- Use Conventional Commits; keep commit bodies minimal unless context is essential.
```

- [ ] **Step 4: Create the exact Pi append-system policy**

Create `agents/pi/APPEND_SYSTEM.md`:

```markdown
# Pi-Specific Instructions

These instructions supplement the shared global `AGENTS.md` defaults for Pi sessions.

## Pi Tool Routing

- **Tool routing hierarchy.** Prefer cwd-scoped Serena symbolic reads for supported code structure and references; never redirect Serena to another checkout. Use `fffind`/`ffgrep` for path and literal repo search, then scoped Bash commands and bounded `read` calls for unsupported languages, commands, files, logs, tests/builds, APIs/docs, JSON/data, git, MCP output, and browser snapshots.
- **Code exploration is symbolic-first.** Do not use whole-file reads or grep for structure/usages when symbolic tools are available. Use FFF for fuzzy paths and exact literals, configs, errors, and TODOs; fall back to built-in `find`/`grep` or `rg` when FFF or symbolic support is unavailable.
- **Bulk-output discipline.** Keep potentially large output constrained with command filters, limits, focused summaries, and bounded file reads. Write large artifacts to files when useful, then inspect only relevant excerpts instead of dumping raw output into the conversation.
- Serena onboarding, memories, and symbolic edits are disabled in Pi. Prefer `Edit` for TS/JS changes and verify with `git diff`.
- Web/browser routing is capability-aware: use available research tools for evidence gathering, `gh` for GitHub operations, and the matching available browser tool or skill for interactive automation, deterministic E2E, diagnostics, or profiling.
- Delegation is explicit-only: selecting `orchestration` exposes tools but never authorizes a launch. When the current user requests delegation or a named child role, use `pi-orchestration` for supported launch, cleanliness, and writer-isolation rules.

## Pi Safety Additions

- Browser isolation: one browser owner per root Pi session; use the `browser-session-discipline` skill for lease, serialization, and scoped-cleanup procedures. Never bypass an unhealthy lease or kill unrelated browser processes.

## Pi Config Changes

- Durable Pi config includes: `settings.json`, `mcp.json`, `extensions/`, `npm/package*.json`, `docs/`, `AGENTS.md`, `APPEND_SYSTEM.md`, `prompts/`, `agents/`.
- After any durable Pi config change, update: relevant `docs/features/<slug>.md`, `docs/index.json`, and `docs/changelog.md`; follow `prompts/xb-doc-meta-feature.md` for feature records.
- For non-trivial or multi-session harness changes, follow the documented `harness-config-workflow`; keep durable task state only when warranted.
- Before editing shared instructions, confirm `AGENTS.md` is the Pi-tracked link to `~/.agents/AGENTS.md`; keep Pi-specific policy in `APPEND_SYSTEM.md`.
- Do not update `~/.claude` for Pi-only changes. Claude paths are reference inputs only, except explicit bridge features; inactive Claude features are historic/reference-only.
- Before saying docs are current, run `python3 scripts/validate-config-docs.py` from `~/.pi/agent` and fix errors.
- Runtime/sensitive/cache files (`auth.json`, MCP caches/OAuth, `sessions/`, `npm/node_modules/`) are not documentation targets and should not be overwritten casually.

## Pi Defaults

- Models: primary direct `openai-codex/gpt-5.6-sol` under plain `pi`.
- Handoffs: `/handoff-export` for durable artifacts; `/handoff-session` for a clean linked session.
- RTK command rewriting is automatic when enabled; invoke `rtk` directly only for its analytics/debugging commands, and read `RTK.md` when maintaining RTK behavior.
```

The only substantive addition is listing `APPEND_SYSTEM.md` as durable Pi config and replacing the obsolete Pi-local `AGENTS.md` edit check with the new ownership rule.

- [ ] **Step 5: Document the Pi-specific canonical file in dotfiles**

Append this paragraph to the existing `shared agents home` section in `docs/file-tracking.md`:

```markdown
`agents/AGENTS.md` contains harness-neutral defaults. Pi-specific system policy lives in `agents/pi/APPEND_SYSTEM.md` and is exposed through the Pi repository's `~/.pi/agent/APPEND_SYSTEM.md` symlink; Claude does not load that file.
```

- [ ] **Step 6: Run focused verification and static analysis**

Run:

```bash
bash tests/chezmoi/test-agents-instruction-split.sh
bash tests/chezmoi/test-agents-home.sh
git diff --check
fallow audit --changed-since main
```

Expected: both tests pass, `git diff --check` is silent, and Fallow reports no findings.

- [ ] **Step 7: Commit the dotfiles split**

Run:

```bash
git add agents/AGENTS.md agents/pi/APPEND_SYSTEM.md \
  docs/file-tracking.md tests/chezmoi/test-agents-instruction-split.sh
git commit -m "refactor(agents): separate Pi system policy"
```

Expected: only the shared split, canonical Pi file, documentation, and test are committed.

---

### Task 2: Integrate the dotfiles target before Pi references it

**Files/runtime:**
- Fast-forward dotfiles `main` to the reviewed feature branch.
- Expose the canonical target through the existing live `~/.agents` directory link.

**Interfaces:**
- Consumes: Task 1's canonical `agents/pi/APPEND_SYSTEM.md`.
- Produces: an existing live `~/.agents/pi/APPEND_SYSTEM.md` target required by Task 3.

- [ ] **Step 1: Re-run the dotfiles tests immediately before integration**

Run:

```bash
cd ~/.local/share/chezmoi.docs-pi-append-system-split
bash tests/chezmoi/test-agents-instruction-split.sh
bash tests/chezmoi/test-agents-home.sh
git status --short --branch
```

Expected: both tests pass and the feature worktree is clean.

- [ ] **Step 2: Fast-forward dotfiles main and verify the live target**

Run:

```bash
git -C ~/.local/share/chezmoi status --short --branch
git -C ~/.local/share/chezmoi merge --ff-only docs/pi-append-system-split
test -f ~/.agents/pi/APPEND_SYSTEM.md
cmp ~/.agents/pi/APPEND_SYSTEM.md ~/.local/share/chezmoi/agents/pi/APPEND_SYSTEM.md
```

Expected: dotfiles main is clean before the merge, fast-forwards, and the live target resolves to the merged source file. Stop before Task 3 if it does not.

---

### Task 3: Add the Pi append-system link and combined-policy validation

**Files:**
- Create: `~/.pi/agent/APPEND_SYSTEM.md` symlink to `../../.agents/pi/APPEND_SYSTEM.md`
- Modify: `~/.pi/agent/scripts/validate-config-docs.py`
- Create: `~/.pi/agent/scripts/test-validate-agent-instructions.py`
- Modify: `~/.pi/agent/docs/features/pi-agent-instructions.md`
- Modify: `~/.pi/agent/docs/index.json`
- Modify: `~/.pi/agent/docs/changelog.md`

**Interfaces:**
- Consumes: live `~/.agents/pi/APPEND_SYSTEM.md` from Task 2.
- Produces: Pi's supported global append-system resource and a validator that treats shared plus Pi append instructions as the complete policy.

- [ ] **Step 1: Snapshot unrelated Pi dirt and create an isolated worktree**

Run:

```bash
git -C ~/.pi status --short --untracked-files=all > /tmp/pi-status-before-append-system
wt -C ~/.pi switch --create refactor/append-system-instructions --no-hooks --no-cd --yes
pi_wt=~/.pi.refactor-append-system-instructions
git -C "$pi_wt" status --short --branch
```

Expected: the primary status snapshot contains the unrelated `agent/npm/package.json` modification, while the new worktree is clean. If Worktrunk reports a different path, use that path.

- [ ] **Step 2: Add and verify the tracked Pi symlink**

Run:

```bash
cd "$pi_wt/agent"
ln -s ../../.agents/pi/APPEND_SYSTEM.md APPEND_SYSTEM.md
test -f APPEND_SYSTEM.md
test "$(readlink APPEND_SYSTEM.md)" = '../../.agents/pi/APPEND_SYSTEM.md'
git add APPEND_SYSTEM.md
test "$(git ls-files -s APPEND_SYSTEM.md | awk '{print $1}')" = 120000
git reset -q APPEND_SYSTEM.md
```

Expected: the symlink resolves and Git records mode `120000` when staged.

- [ ] **Step 3: Write the failing validator unit test**

Create `scripts/test-validate-agent-instructions.py`:

```python
#!/usr/bin/env python3
import importlib.util
import sys
import tempfile
from pathlib import Path

SCRIPT = Path(__file__).with_name("validate-config-docs.py")
spec = importlib.util.spec_from_file_location("validate_config_docs", SCRIPT)
assert spec and spec.loader
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)

with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    (root / "AGENTS.md").write_text("## Prime Directive\n")
    (root / "APPEND_SYSTEM.md").write_text(
        "docs/index.json docs/changelog.md docs/features/<slug>.md "
        "prompts/xb-doc-meta-feature.md inactive\n"
    )
    module.ROOT = root
    findings = []
    module.validate_agents_guidance(findings)
    assert findings == [], findings

with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    (root / "AGENTS.md").write_text("## Prime Directive\n")
    module.ROOT = root
    findings = []
    module.validate_agents_guidance(findings)
    assert any(
        finding.severity == "ERROR" and "APPEND_SYSTEM.md" in finding.message
        for finding in findings
    ), findings

print("Combined agent instruction validation ok")
```

Run:

```bash
python3 scripts/test-validate-agent-instructions.py
```

Expected: FAIL because `validate_agents_guidance()` currently inspects only `AGENTS.md` and does not require or combine `APPEND_SYSTEM.md`.

- [ ] **Step 4: Update validation to inspect both instruction layers**

Replace the beginning of `validate_agents_guidance()` in `scripts/validate-config-docs.py`:

```python
def validate_agents_guidance(findings: list[Finding]) -> None:
    agents = ROOT / "AGENTS.md"
    if not agents.exists():
        findings.append(Finding("ERROR", "missing AGENTS.md"))
        return
    text = agents.read_text()
```

with:

```python
def validate_agents_guidance(findings: list[Finding]) -> None:
    agents = ROOT / "AGENTS.md"
    append_system = ROOT / "APPEND_SYSTEM.md"
    missing = [path.name for path in (agents, append_system) if not path.exists()]
    if missing:
        for name in missing:
            findings.append(Finding("ERROR", f"missing {name}"))
        return
    text = agents.read_text() + "\n" + append_system.read_text()
```

Do not change the existing marker checks below this block.

- [ ] **Step 5: Verify the validator unit and complete config docs**

Run:

```bash
python3 scripts/test-validate-agent-instructions.py
python3 scripts/validate-config-docs.py
```

Expected: unit test prints `Combined agent instruction validation ok`; config docs report 0 errors and 0 warnings.

- [ ] **Step 6: Rewrite the Pi instruction feature architecture and verification**

Update `docs/features/pi-agent-instructions.md` so it states:

- `AGENTS.md` is the tracked link to neutral shared context.
- `APPEND_SYSTEM.md` is the tracked link to dotfiles-owned Pi system policy.
- the shared file owns Prime Directive and generic Safe Execution;
- the append file owns Pi Tool Routing, Pi Safety Additions, Pi Config Changes, and Pi Defaults;
- Pi 0.81.1 appends the latter to its default system prompt;
- Claude loads only the shared file.

Replace the verification command with:

```bash
test -L /Users/brendan/.pi/agent/AGENTS.md && test "$(readlink /Users/brendan/.pi/agent/AGENTS.md)" = "../../.agents/AGENTS.md" && test -L /Users/brendan/.pi/agent/APPEND_SYSTEM.md && test "$(readlink /Users/brendan/.pi/agent/APPEND_SYSTEM.md)" = "../../.agents/pi/APPEND_SYSTEM.md" && grep -E "^## (Prime Directive|Safe Execution)" /Users/brendan/.pi/agent/AGENTS.md && grep -E "^## Pi (Tool Routing|Safety Additions|Config Changes|Defaults)" /Users/brendan/.pi/agent/APPEND_SYSTEM.md && grep -F "Prefer cwd-scoped Serena" /Users/brendan/.pi/agent/APPEND_SYSTEM.md && grep -F "browser-session-discipline" /Users/brendan/.pi/agent/APPEND_SYSTEM.md && grep -F "pi-orchestration" /Users/brendan/.pi/agent/APPEND_SYSTEM.md && grep -F "docs/features/<slug>.md" /Users/brendan/.pi/agent/APPEND_SYSTEM.md && grep -F "gpt-5.6-sol" /Users/brendan/.pi/agent/APPEND_SYSTEM.md && grep -F "RTK command rewriting is automatic" /Users/brendan/.pi/agent/APPEND_SYSTEM.md && ! grep -F "Prefer cwd-scoped Serena" /Users/brendan/.pi/agent/AGENTS.md
```

Update the expected result and revert procedure to cover both links and moving Pi policy back into shared `AGENTS.md` for a full revert.

- [ ] **Step 7: Update Pi feature metadata and changelog**

From `$pi_wt/agent`, run:

```bash
python3 - <<'PY'
import json
from pathlib import Path

path = Path('docs/index.json')
doc = json.loads(path.read_text())
doc['last_updated'] = '2026-07-25'
feature = doc['features']['pi-agent-instructions']
feature['modified'] = '2026-07-25'
for tag in ('append-system', 'shared-context'):
    if tag not in feature['tags']:
        feature['tags'].append(tag)
for filename in (
    'AGENTS.md',
    'APPEND_SYSTEM.md',
    'scripts/validate-config-docs.py',
    'scripts/test-validate-agent-instructions.py',
    'docs/features/pi-agent-instructions.md',
    'docs/index.json',
    'docs/changelog.md',
):
    if filename not in feature['files_touched']:
        feature['files_touched'].append(filename)
path.write_text(json.dumps(doc, indent=2) + '\n')
PY
```

Insert after `# Changelog` in `docs/changelog.md`:

```markdown

## 2026-07-25 — Pi-specific policy moved to append system prompt

- `pi-agent-instructions` modified: Kept neutral defaults in the dotfiles-owned shared `AGENTS.md`, added a Pi-tracked `APPEND_SYSTEM.md` link for Pi tool, safety, config, and default policy, and taught config-doc validation to inspect both instruction layers.
  Files: `AGENTS.md`, `APPEND_SYSTEM.md`, `scripts/validate-config-docs.py`, `scripts/test-validate-agent-instructions.py`, `docs/features/pi-agent-instructions.md`, `docs/index.json`, `docs/changelog.md`
```

- [ ] **Step 8: Verify the Pi change and untouched primary checkout**

Run:

```bash
cd "$pi_wt/agent"
python3 scripts/test-validate-agent-instructions.py
python3 scripts/validate-config-docs.py
cd ..
fallow audit --changed-since main
git diff --check
git -C ~/.pi status --short --untracked-files=all > /tmp/pi-status-after-append-system
cmp /tmp/pi-status-before-append-system /tmp/pi-status-after-append-system
```

Expected: tests and validation pass, Fallow reports no findings, and the primary Pi dirty-state snapshot is byte-identical.

- [ ] **Step 9: Commit the Pi link, validator, and documentation**

Run:

```bash
cd "$pi_wt"
git add agent/APPEND_SYSTEM.md \
  agent/scripts/validate-config-docs.py \
  agent/scripts/test-validate-agent-instructions.py \
  agent/docs/features/pi-agent-instructions.md \
  agent/docs/index.json agent/docs/changelog.md
git commit -m "refactor(agent): append Pi-specific system policy"
```

Expected: the commit excludes `agent/npm/package.json` and contains exactly the Pi link, combined validator, test, and feature documentation.

---

### Task 4: Integrate Pi and verify prompt resources

**Files/runtime:**
- Fast-forward Pi `main` to the reviewed feature branch.
- Reload a Pi session without making a provider request.

**Interfaces:**
- Consumes: Task 3's clean Pi feature commit and Task 2's live canonical target.
- Produces: active shared context plus Pi-specific appended system policy.

- [ ] **Step 1: Re-run clean-worktree verification immediately before merge**

Run:

```bash
pi_wt=~/.pi.refactor-append-system-instructions
cd "$pi_wt/agent"
python3 scripts/test-validate-agent-instructions.py
python3 scripts/validate-config-docs.py
cd ..
fallow audit --changed-since main
git status --short --branch
```

Expected: all checks pass and the feature worktree is clean.

- [ ] **Step 2: Merge without touching the unrelated primary modification**

Run:

```bash
git -C ~/.pi diff --quiet -- agent/APPEND_SYSTEM.md agent/scripts agent/docs
git -C ~/.pi merge --ff-only refactor/append-system-instructions
test -L ~/.pi/agent/APPEND_SYSTEM.md
test "$(readlink ~/.pi/agent/APPEND_SYSTEM.md)" = '../../.agents/pi/APPEND_SYSTEM.md'
cmp ~/.pi/agent/APPEND_SYSTEM.md ~/.agents/pi/APPEND_SYSTEM.md
```

Expected: fast-forward succeeds, the link resolves, and the unrelated `agent/npm/package.json` modification remains present and unstaged.

- [ ] **Step 3: Run final deterministic checks on merged mains**

Run:

```bash
bash ~/.local/share/chezmoi/tests/chezmoi/test-agents-instruction-split.sh
bash ~/.local/share/chezmoi/tests/chezmoi/test-agents-home.sh
cd ~/.pi/agent
python3 scripts/test-validate-agent-instructions.py
python3 scripts/validate-config-docs.py
cd ~/.pi
fallow audit --changed-since origin/main
```

Expected: both dotfiles tests pass, both Pi validators pass with 0 errors and warnings, and Fallow reports no findings attributable to this feature. If primary-checkout Fallow includes the unrelated package modification, rerun against the clean feature worktree and report that distinction rather than modifying the unrelated file.

- [ ] **Step 4: Verify Pi resource loading without provider traffic**

Start or focus a Pi process, run `/reload`, and inspect the startup/resource notification. Confirm it reports both global context and append-system resources without errors. Do not submit a model prompt solely for this check.

If person-observed interaction is unavailable, stop and request the user's confirmation rather than claiming runtime verification.

- [ ] **Step 5: Review repository state before publishing**

Run:

```bash
git -C ~/.local/share/chezmoi status --short --branch
git -C ~/.pi status --short --branch
git -C ~/.claude status --short --branch
```

Expected: dotfiles contains only the intended ahead commits, Pi contains the intended ahead commit plus the pre-existing unstaged `agent/npm/package.json`, and Claude is unchanged. Push only with explicit user approval.
