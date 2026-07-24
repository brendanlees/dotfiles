# Shared Agents Home Symlink Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Track the portable `~/.agents` home directly in the dotfiles repository while retaining local runtime directories and sharing the Pi-authored global instructions with Pi and Claude through repository-tracked symlinks.

**Architecture:** The dotfiles source gains a canonical `agents/` directory and renders `~/.agents` as a symlink to it. Git ignores `agents/state/` and `agents/backups/`, while chezmoi ignores `agents` as an ordinary target. The Pi and Claude repositories replace their instruction files with relative links to `~/.agents/AGENTS.md`.

**Tech Stack:** chezmoi templates, Git symlinks, Bash tests, Worktrunk/Git worktrees

## Global Constraints

- Work only in isolated worktrees until the explicit integration task.
- Seed `agents/AGENTS.md` from the current Pi `~/.pi/agent/AGENTS.md`; do not merge the current Claude instructions.
- Preserve `~/.agents/state/` and `~/.agents/backups/` locally but never add them to Git.
- Add no synchronization command, lifecycle hook, Bitwarden integration, SOPS/age integration, or automatic repair.
- Do not modify or clean unrelated dirty files in `~/.claude`.
- Do not silently replace an unexpected regular file during live migration.
- Keep a timestamped migration backup until all verification has passed.

---

### Task 1: Add the canonical agents home to dotfiles

**Files:**
- Create: `agents/AGENTS.md`
- Create: `agents/.skill-lock.json`
- Create: `agents/skills/**`
- Create: `symlink_dot_agents.tmpl`
- Modify: `.gitignore`
- Modify: `.chezmoiignore`
- Modify: `.chezmoiexternal.toml.tmpl`
- Modify: `docs/file-tracking.md`
- Create: `tests/chezmoi/test-agents-home.sh`

**Interfaces:**
- Consumes: the live `~/.agents/.skill-lock.json`, live `~/.agents/skills/`, and current Pi `~/.pi/agent/AGENTS.md`.
- Produces: a source-owned `agents/` tree and a rendered `~/.agents -> {{ .chezmoi.sourceDir }}/agents` link used by both harness repositories.

- [ ] **Step 1: Confirm the implementation worktree and live inputs are safe to snapshot**

Run:

```bash
cd ~/.local/share/chezmoi.docs-agents-home-symlink-design
git status --short --branch
test -f ~/.pi/agent/AGENTS.md
test -f ~/.agents/.skill-lock.json
test -d ~/.agents/skills
test ! -e agents
```

Expected: the branch is `docs/agents-home-symlink-design`, only intended plan/spec state is present, all three live inputs exist, and `agents/` does not yet exist.

- [ ] **Step 2: Write the failing isolated chezmoi test**

Create `tests/chezmoi/test-agents-home.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

for path in \
  "$repo_root/agents/AGENTS.md" \
  "$repo_root/agents/.skill-lock.json" \
  "$repo_root/agents/skills" \
  "$repo_root/symlink_dot_agents.tmpl"; do
  [[ -e "$path" ]] || {
    echo "missing agents source path: $path" >&2
    exit 1
  }
done

grep -Fxq '/agents/state/' "$repo_root/.gitignore"
grep -Fxq '/agents/backups/' "$repo_root/.gitignore"

rendered_ignore="$tmpdir/ignore"
chezmoi execute-template \
  --source "$repo_root" \
  --override-data '{"personal":true,"work":false,"homelab":false,"headless":false}' \
  <"$repo_root/.chezmoiignore" >"$rendered_ignore"
grep -Fxq 'agents' "$rendered_ignore"
if grep -Fq '"*/*.md"' "$repo_root/.chezmoiexternal.toml.tmpl"; then
  echo 'broad Markdown external exclusion would omit harness links' >&2
  exit 1
fi

minimal_source="$tmpdir/source"
home_dir="$tmpdir/home"
config_file="$tmpdir/chezmoi.toml"
mkdir -p "$minimal_source/agents/skills" "$home_dir"
printf '# canonical\n' >"$minimal_source/agents/AGENTS.md"
printf '{}\n' >"$minimal_source/agents/.skill-lock.json"
printf 'agents\n' >"$minimal_source/.chezmoiignore"
cp "$repo_root/symlink_dot_agents.tmpl" "$minimal_source/symlink_dot_agents.tmpl"
printf '[data]\n' >"$config_file"

chezmoi apply \
  --source "$minimal_source" \
  --config "$config_file" \
  --destination "$home_dir" \
  --no-tty

[[ -L "$home_dir/.agents" ]]
[[ "$(readlink "$home_dir/.agents")" == "$minimal_source/agents" ]]
[[ ! -e "$home_dir/agents" ]]
printf '# edited through target\n' >"$home_dir/.agents/AGENTS.md"
grep -Fxq '# edited through target' "$minimal_source/agents/AGENTS.md"

if git -C "$repo_root" check-ignore -q agents/AGENTS.md; then
  echo 'portable AGENTS.md must be tracked' >&2
  exit 1
fi
git -C "$repo_root" check-ignore -q agents/state/example
git -C "$repo_root" check-ignore -q agents/backups/example

echo 'Agents home symlink ok'
```

Make it executable:

```bash
chmod +x tests/chezmoi/test-agents-home.sh
```

- [ ] **Step 3: Run the test and verify it fails for the missing production paths**

Run:

```bash
bash tests/chezmoi/test-agents-home.sh
```

Expected: FAIL with `missing agents source path`.

- [ ] **Step 4: Snapshot the portable agents content and add the symlink declaration**

Run from the dotfiles worktree:

```bash
mkdir -p agents
cp ~/.pi/agent/AGENTS.md agents/AGENTS.md
cp ~/.agents/.skill-lock.json agents/.skill-lock.json
cp -a ~/.agents/skills agents/skills
printf '{{ .chezmoi.sourceDir }}/agents' > symlink_dot_agents.tmpl
```

Do not copy `~/.agents/state` or `~/.agents/backups` into this disposable worktree; they are migrated into the primary source checkout only in Task 4.

- [ ] **Step 5: Add the exact ignore and external-filter changes**

Append these Git ignores to `.gitignore`:

```gitignore

# agents CLI runtime state lives under the source-owned agents home
/agents/state/
/agents/backups/
```

Append this target ignore to `.chezmoiignore` before the final documentation ignores:

```text
# agents/ is source-owned and reached through ~/.agents
agents
```

In both `.claude` and `.pi` external definitions, remove only this broad member exclusion:

```toml
  "*/*.md",
```

Retain the existing editor, GitHub, and Git metadata exclusions. This allows fresh external installations to retain the tracked instruction symlinks.

- [ ] **Step 6: Document the direct-source editing behavior**

Append this section to `docs/file-tracking.md`:

```markdown
## shared agents home

`~/.agents` is a symlink to `agents/` in the chezmoi source repository. Changes made by agents or the skills CLI to `AGENTS.md`, `.skill-lock.json`, or `skills/` therefore appear directly in the dotfiles Git working tree and do not need `chezmoi re-add`.

`agents/state/` and `agents/backups/` are local runtime directories ignored by Git. Because they physically live in the source checkout, destructive commands such as `git clean -fdx` can remove them. Do not treat either directory as an independent backup.
```

- [ ] **Step 7: Run focused and repository verification**

Run:

```bash
bash tests/chezmoi/test-agents-home.sh
git check-ignore agents/state/example agents/backups/example
git check-ignore -v agents/AGENTS.md && exit 1 || true
git diff --check
```

Expected: the test prints `Agents home symlink ok`; only the two runtime examples are ignored; `agents/AGENTS.md` is not ignored; `git diff --check` is silent.

Run the primary changed-file audit:

```bash
fallow audit --changed-since main
```

Expected: PASS with no blocking findings.

- [ ] **Step 8: Commit the dotfiles implementation**

Run:

```bash
git add .gitignore .chezmoiignore .chezmoiexternal.toml.tmpl \
  symlink_dot_agents.tmpl agents docs/file-tracking.md \
  tests/chezmoi/test-agents-home.sh
git commit -m "feat(agents): track shared agents home"
```

Expected: the commit includes portable agents files but no `agents/state/` or `agents/backups/` content.

---

### Task 2: Replace the Pi instruction file with a tracked relative symlink

**Files:**
- Replace: `~/.pi/agent/AGENTS.md` with symlink `../../.agents/AGENTS.md`
- Modify: `~/.pi/agent/docs/features/pi-agent-instructions.md`
- Modify: `~/.pi/agent/docs/index.json`
- Modify: `~/.pi/agent/docs/changelog.md`

**Interfaces:**
- Consumes: the canonical instruction content created by Task 1.
- Produces: Pi’s global instruction path as a repository-tracked relative symlink.

- [ ] **Step 1: Create an isolated Pi worktree without touching runtime state**

Run:

```bash
wt -C ~/.pi switch --create feat/shared-agents-instructions --no-hooks --no-cd --yes
pi_wt=~/.pi.feat-shared-agents-instructions
git -C "$pi_wt" status --short --branch
```

Expected: a clean feature worktree. If Worktrunk reports a different path, set `pi_wt` to the reported path instead.

- [ ] **Step 2: Verify the source file still matches the canonical seed**

Run:

```bash
cmp ~/.pi/agent/AGENTS.md \
  ~/.local/share/chezmoi.docs-agents-home-symlink-design/agents/AGENTS.md
```

Expected: exit status 0. If it differs, stop and resolve whether the live Pi file changed after Task 1; do not replace it silently.

- [ ] **Step 3: Replace the worktree file with the relative symlink**

Run:

```bash
rm "$pi_wt/agent/AGENTS.md"
ln -s ../../.agents/AGENTS.md "$pi_wt/agent/AGENTS.md"
```

- [ ] **Step 4: Verify Git records a symlink with the intended target**

Run:

```bash
test "$(readlink "$pi_wt/agent/AGENTS.md")" = '../../.agents/AGENTS.md'
test "$(git -C "$pi_wt" ls-files -s agent/AGENTS.md | awk '{print $1}')" = 120000
git -C "$pi_wt" diff --check
git -C "$pi_wt" diff -- agent/AGENTS.md
```

Expected: mode `120000`, target `../../.agents/AGENTS.md`, and no whitespace errors.

- [ ] **Step 5: Update the Pi instruction feature record for neutral ownership**

From `$pi_wt/agent`, update `docs/features/pi-agent-instructions.md` with these exact semantic changes:

```markdown
## Status

active — `AGENTS.md` is a repository-tracked symlink to the neutral `~/.agents/AGENTS.md` router owned by dotfiles.
```

Replace the first `Pi Implementation` bullet with:

```markdown
- `AGENTS.md`: Pi-tracked relative symlink to `../../.agents/AGENTS.md`. The neutral target is owned by the dotfiles repository, seeded from the former Pi-local router, and shared with Claude; it must not point into `~/.claude`.
```

Replace the verification command’s initial regular-file assertion:

```bash
test -f /Users/brendan/.pi/agent/AGENTS.md && ! test -L /Users/brendan/.pi/agent/AGENTS.md
```

with:

```bash
test -L /Users/brendan/.pi/agent/AGENTS.md && test "$(readlink /Users/brendan/.pi/agent/AGENTS.md)" = "../../.agents/AGENTS.md"
```

Change the verification expectation from `confirms AGENTS.md is a regular Pi-local file` to `confirms AGENTS.md is the Pi-tracked link to the neutral shared router`.

Replace Revert / Cleanup step 1 with:

```markdown
1. Replace the `AGENTS.md` symlink with a reviewed regular Pi-local copy of `~/.agents/AGENTS.md`.
```

- [ ] **Step 6: Update the Pi feature index and changelog**

Run from `$pi_wt/agent`:

```bash
python3 - <<'PY'
import json
from pathlib import Path

path = Path('docs/index.json')
doc = json.loads(path.read_text())
doc['last_updated'] = '2026-07-25'
feature = doc['features']['pi-agent-instructions']
feature['modified'] = '2026-07-25'
for tag in ('shared-instructions', 'dotfiles-owned'):
    if tag not in feature['tags']:
        feature['tags'].append(tag)
for filename in (
    'AGENTS.md',
    'docs/features/pi-agent-instructions.md',
    'docs/index.json',
    'docs/changelog.md',
):
    if filename not in feature['files_touched']:
        feature['files_touched'].append(filename)
path.write_text(json.dumps(doc, indent=2) + '\n')
PY
```

Insert immediately after `# Changelog` in `docs/changelog.md`:

```markdown

## 2026-07-25 — Global instructions moved to neutral agents home

- `pi-agent-instructions` modified: Replaced the Pi-local regular instruction file with a repository-tracked relative link to the dotfiles-owned `~/.agents/AGENTS.md`, preserving the former Pi router as the shared canonical content rather than importing Claude-specific instructions.
  Files: `AGENTS.md`, `docs/features/pi-agent-instructions.md`, `docs/index.json`, `docs/changelog.md`
```

- [ ] **Step 7: Validate Pi documentation, audit, and commit**

Run:

```bash
cd "$pi_wt/agent"
python3 scripts/validate-config-docs.py
fallow audit --changed-since main
git diff --check
git add AGENTS.md docs/features/pi-agent-instructions.md docs/index.json docs/changelog.md
git commit -m "refactor(agent): share global instructions"
```

Expected: documentation validation and audit pass; the commit contains the instruction symlink and its required feature metadata only.

---

### Task 3: Replace the Claude instruction file with a tracked relative symlink

**Files:**
- Replace: `~/.claude/CLAUDE.md` with symlink `../.agents/AGENTS.md`

**Interfaces:**
- Consumes: the canonical Pi-authored instruction content created by Task 1.
- Produces: Claude’s global instruction path as a repository-tracked relative symlink.

- [ ] **Step 1: Record unrelated dirty state and create an isolated Claude worktree**

Run:

```bash
git -C ~/.claude status --short --untracked-files=all > /tmp/claude-status-before-agents-link
wt -C ~/.claude switch --create feat/shared-agents-instructions --no-hooks --no-cd --yes
claude_wt=~/.claude.feat-shared-agents-instructions
git -C "$claude_wt" status --short --branch
```

Expected: the primary checkout remains dirty exactly as recorded, while the feature worktree is clean. If Worktrunk reports a different path, use that reported path.

- [ ] **Step 2: Preserve the old Claude instructions in Git history and replace only the worktree file**

Run:

```bash
rm "$claude_wt/CLAUDE.md"
ln -s ../.agents/AGENTS.md "$claude_wt/CLAUDE.md"
```

Do not copy or merge the old Claude content into the canonical file; the approved design selects the Pi content.

- [ ] **Step 3: Verify the symlink and confirm the primary dirty state was untouched**

Run:

```bash
test "$(readlink "$claude_wt/CLAUDE.md")" = '../.agents/AGENTS.md'
test "$(git -C "$claude_wt" ls-files -s CLAUDE.md | awk '{print $1}')" = 120000
git -C "$claude_wt" diff --check
git -C ~/.claude status --short --untracked-files=all > /tmp/claude-status-after-agents-link
cmp /tmp/claude-status-before-agents-link /tmp/claude-status-after-agents-link
```

Expected: mode `120000`, the intended target, no whitespace errors, and byte-identical before/after status snapshots for the primary Claude checkout.

- [ ] **Step 4: Run available static analysis and commit**

Run:

```bash
cd "$claude_wt"
fallow audit --changed-since main
git add CLAUDE.md
git commit -m "refactor(agent): share global instructions"
```

Expected: audit passes and exactly the `CLAUDE.md` type change is committed.

---

### Task 4: Integrate branches and migrate the live agents home

**Files/runtime:**
- Merge the approved dotfiles, Pi, and Claude feature branches.
- Replace live `~/.agents` with the chezmoi-managed source link.
- Populate ignored runtime directories beneath the primary dotfiles source.

**Interfaces:**
- Consumes: all three reviewed feature branches from Tasks 1–3.
- Produces: a functioning live shared agents home with recoverable migration backups.

- [ ] **Step 1: Establish a durable migration backup before any merge or replacement**

Run:

```bash
stamp=$(date +%Y%m%d-%H%M%S)
backup="$HOME/.local/state/agents-migration-backup-$stamp"
mkdir -p "$backup"
cp -a ~/.agents "$backup/dot-agents"
cp -a ~/.pi/agent/AGENTS.md "$backup/pi-AGENTS.md"
cp -a ~/.claude/CLAUDE.md "$backup/claude-CLAUDE.md"
printf '%s\n' "$backup" > /tmp/agents-migration-backup-path
```

Expected: all three copies exist beneath the printed backup path. Keep this backup after verification.

- [ ] **Step 2: Recheck portable drift before integration**

Run:

```bash
dotfiles_wt=~/.local/share/chezmoi.docs-agents-home-symlink-design
cmp ~/.pi/agent/AGENTS.md "$dotfiles_wt/agents/AGENTS.md"
cmp ~/.agents/.skill-lock.json "$dotfiles_wt/agents/.skill-lock.json"
diff -qr ~/.agents/skills "$dotfiles_wt/agents/skills"
```

Expected: all commands exit 0. If lock or skill files changed since Task 1, update the dotfiles feature branch snapshot, rerun Task 1 verification, and commit that update before proceeding.

- [ ] **Step 3: Merge the dotfiles branch first**

Run:

```bash
git -C ~/.local/share/chezmoi status --short --branch
git -C ~/.local/share/chezmoi merge --ff-only docs/agents-home-symlink-design
```

Expected: primary dotfiles `main` is clean before the merge and advances by fast-forward.

- [ ] **Step 4: Preserve runtime directories and replace the live directory through chezmoi**

Run:

```bash
source_agents=$(chezmoi source-path)/agents
backup=$(cat /tmp/agents-migration-backup-path)
mkdir -p "$source_agents/state" "$source_agents/backups"
cp -a "$backup/dot-agents/state/." "$source_agents/state/"
cp -a "$backup/dot-agents/backups/." "$source_agents/backups/"
mv ~/.agents "$backup/dot-agents-live-before-link"
chezmoi apply ~/.agents
```

Expected: `~/.agents` no longer exists before apply; apply creates it as a symlink. If either runtime directory was absent in the original snapshot, omit only that directory’s `cp` command after confirming its absence.

- [ ] **Step 5: Verify the live neutral link before harness integration**

Run:

```bash
test -L ~/.agents
test "$(readlink ~/.agents)" = "$(chezmoi source-path)/agents"
cmp ~/.agents/AGENTS.md ~/.local/share/chezmoi/agents/AGENTS.md
test -d ~/.agents/state
test -d ~/.agents/backups
git -C ~/.local/share/chezmoi check-ignore -q agents/state/active.json
git -C ~/.local/share/chezmoi status --short
```

Expected: the link targets the primary source checkout, runtime directories exist and are ignored, and dotfiles status has no unexpected portable changes.

- [ ] **Step 6: Merge the Pi branch and verify instruction resolution**

Run:

```bash
git -C ~/.pi status --short --branch
git -C ~/.pi merge --ff-only feat/shared-agents-instructions
test -L ~/.pi/agent/AGENTS.md
test "$(readlink ~/.pi/agent/AGENTS.md)" = '../../.agents/AGENTS.md'
cmp ~/.pi/agent/AGENTS.md ~/.agents/AGENTS.md
```

Expected: Pi main was clean, fast-forwards, and resolves to the canonical file.

- [ ] **Step 7: Merge the Claude branch without disturbing unrelated changes**

Run:

```bash
git -C ~/.claude status --short --untracked-files=all > /tmp/claude-status-before-merge
git -C ~/.claude diff --quiet -- CLAUDE.md
git -C ~/.claude merge --ff-only feat/shared-agents-instructions
test -L ~/.claude/CLAUDE.md
test "$(readlink ~/.claude/CLAUDE.md)" = '../.agents/AGENTS.md'
cmp ~/.claude/CLAUDE.md ~/.agents/AGENTS.md
```

Expected: `CLAUDE.md` has no uncommitted change before merging, the fast-forward succeeds despite unrelated dirty paths, and the link resolves to the canonical Pi-authored file. Do not restore, stash, or clean any unrelated Claude paths.

- [ ] **Step 8: Run end-to-end verification**

Run:

```bash
bash ~/.local/share/chezmoi/tests/chezmoi/test-agents-home.sh
chezmoi apply ~/.agents
test ! -e ~/agents
printf '\n# agents-home-smoke\n' >> ~/.agents/AGENTS.md
grep -Fq '# agents-home-smoke' ~/.pi/agent/AGENTS.md
grep -Fq '# agents-home-smoke' ~/.claude/CLAUDE.md
git -C ~/.local/share/chezmoi diff -- agents/AGENTS.md
git -C ~/.local/share/chezmoi checkout -- agents/AGENTS.md
! grep -Fq '# agents-home-smoke' ~/.agents/AGENTS.md
```

Expected: the focused test passes; apply leaves the link intact; one temporary edit is visible through all paths and in Git; restoring the tracked file removes only the smoke line.

Run final audits:

```bash
cd ~/.local/share/chezmoi && fallow audit --changed-since main
cd ~/.pi/agent && python3 scripts/validate-config-docs.py
cd ~/.pi && fallow audit --changed-since main
cd ~/.claude && fallow audit --changed-since main
```

Expected: all audits and Pi configuration-documentation validation pass.

- [ ] **Step 9: Publish only after reviewing all repository states**

Run:

```bash
git -C ~/.local/share/chezmoi status --short --branch
git -C ~/.pi status --short --branch
git -C ~/.claude status --short --branch
```

Expected: dotfiles and Pi are clean; Claude shows only its pre-existing unrelated changes. Push each repository’s `main` only after explicit user approval. Retain the migration backup path recorded in `/tmp/agents-migration-backup-path` until the user confirms normal agent and skills CLI operation.
