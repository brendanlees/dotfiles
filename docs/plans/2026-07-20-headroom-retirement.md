# Headroom Retirement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove Headroom completely from chezmoi, Pi, Claude launch integration, and the local runtime while preserving native Pi Codex access and historical changelog records.

**Architecture:** Retire tracked chezmoi and Pi integration in separate Worktrunk worktrees, verify each repository independently, integrate the commits, then remove runtime processes, the uv tool, deployed files, and private data. Native `openai-codex/gpt-5.6-sol` remains the only Pi path affected by this change.

**Tech Stack:** chezmoi templates, zsh, shell tests, Pi JSON configuration, Python config tests, Worktrunk, uv tools, Herdr/tmux runtime inspection.

## Global Constraints

- Reliability wins over token savings.
- Preserve historical changelog entries; add a retirement entry instead of rewriting history.
- Delete `~/.headroom-private` only after tracked configuration is safely retired.
- Do not modify unrelated Claude configuration.
- Do not use subagents; if delegation becomes necessary, use Herdr panes with task-appropriate models.
- Keep `~/.pi/agent/models-store.json` untouched.

---

### Task 1: Capture baseline and create the Pi worktree

**Files:**
- Read: `/Users/brendan/.pi/agent/mcp.json`
- Read: `/Users/brendan/.pi/agent/models-store.json`
- Create runtime backup: `/tmp/pi-pre-headroom-retirement-<timestamp>/`

**Interfaces:**
- Consumes: clean Pi `main` plus existing user modifications in the original checkout.
- Produces: isolated Pi worktree `chore/retire-headroom` and bounded backups of dirty files.

- [ ] **Step 1: Record current repository state**

Run:

```bash
cd ~/.pi
git status --short
git diff -- agent/mcp.json > /tmp/pi-mcp-before-headroom.patch
git diff -- agent/models-store.json > /tmp/pi-models-store-before-headroom.patch
```

Expected: status reports the known `mcp.json` and `models-store.json` modifications; both patches are saved without changing the checkout.

- [ ] **Step 2: Create the isolated Pi worktree**

Run:

```bash
wt -C ~/.pi switch --create chore/retire-headroom --yes
```

Expected: Worktrunk reports a new worktree, normally `~/.pi.chore-retire-headroom`.

- [ ] **Step 3: Verify the Pi worktree baseline**

Run from the returned worktree:

```bash
cd ~/.pi.chore-retire-headroom/agent
python3 scripts/validate-config-docs.py
python3 scripts/test-headroom-models.py
```

Expected: docs validation reports zero errors; the Headroom model test prints `headroom models config ok` before retirement.

### Task 2: Remove Headroom from chezmoi

**Files:**
- Delete: `dot_config/headroom/env.zsh.tmpl`
- Delete: `dot_config/headroom/functions.zsh.tmpl`
- Delete: `dot_config/zsh/exact_aliases.d/headroom.zsh.tmpl`
- Delete: `dot_local/bin/executable_headroom-codex-shim`
- Delete: `dot_local/bin/executable_headroom-herdr`
- Delete: `dot_local/bin/executable_headroom-tmux`
- Delete: `tests/chezmoi/test-headroom-codex-shim-client-disconnect.sh`
- Delete: `tests/chezmoi/test-headroom-codex-shim-waits-for-proxy.sh`
- Delete: `tests/chezmoi/test-headroom-codex-shim.sh`
- Delete: `tests/chezmoi/test-headroom-herdr-launcher.sh`
- Delete: `tests/chezmoi/test-headroom-layout.sh`
- Delete: `tests/chezmoi/test-headroom-tmux-launcher.sh`
- Delete: `tests/chezmoi/test-hr-pix-model-cycle.sh`
- Delete: `docs/agentic-tooling.md`
- Modify: `docs/testing.md`
- Delete: `docs/plans/2026-07-19-headroom-herdr-launcher.md`
- Delete: `docs/specs/2026-07-19-headroom-herdr-launcher-design.md`
- Modify: `.chezmoiignore`
- Modify: `README.md`

**Interfaces:**
- Consumes: approved retirement design in `docs/specs/2026-07-20-agent-tooling-slimming-design.md`.
- Produces: chezmoi source with no active Headroom integration.

- [ ] **Step 1: Remove Headroom-managed files**

Run in `~/.local/share/chezmoi.chore-agent-tooling-slimming`:

```bash
git rm \
  dot_config/headroom/env.zsh.tmpl \
  dot_config/headroom/functions.zsh.tmpl \
  dot_config/zsh/exact_aliases.d/headroom.zsh.tmpl \
  dot_local/bin/executable_headroom-codex-shim \
  dot_local/bin/executable_headroom-herdr \
  dot_local/bin/executable_headroom-tmux \
  tests/chezmoi/test-headroom-codex-shim-client-disconnect.sh \
  tests/chezmoi/test-headroom-codex-shim-waits-for-proxy.sh \
  tests/chezmoi/test-headroom-codex-shim.sh \
  tests/chezmoi/test-headroom-herdr-launcher.sh \
  tests/chezmoi/test-headroom-layout.sh \
  tests/chezmoi/test-headroom-tmux-launcher.sh \
  tests/chezmoi/test-hr-pix-model-cycle.sh \
  docs/agentic-tooling.md \
  docs/plans/2026-07-19-headroom-herdr-launcher.md \
  docs/specs/2026-07-19-headroom-herdr-launcher-design.md
```

Remove only the `## headroom` section from `docs/testing.md`; preserve its CI and branch-apply guidance. Remove the now-dangling `agentic tooling` link from `README.md` without changing unrelated documentation links.

Expected: Git stages the listed deletions and the two narrow documentation edits. The approved slimming spec remains.

- [ ] **Step 2: Remove obsolete executable allowlist entries**

Delete exactly these lines from `.chezmoiignore`:

```text
!.local/bin/headroom-codex-shim
!.local/bin/headroom-herdr
!.local/bin/headroom-tmux
```

- [ ] **Step 3: Verify no active chezmoi references remain**

Run:

```bash
git grep -Iin headroom -- .chezmoiignore dot_config dot_local tests || true
git grep -Iin headroom -- docs \
  ':!docs/specs/2026-07-20-agent-tooling-slimming-design.md' \
  ':!docs/plans/2026-07-20-headroom-retirement.md' \
  ':!docs/plans/2026-07-20-rtk-mcp-slimming.md' \
  ':!docs/plans/2026-07-20-loadout-tuning.md' || true
```

Expected: no output. The approved design and implementation plans are retained as historical decision records.

- [ ] **Step 4: Verify source-state retirement and identify deployed cleanup**

Run:

```bash
targets=(
  "$HOME/.config/headroom/env.zsh"
  "$HOME/.config/headroom/functions.zsh"
  "$HOME/.config/zsh/aliases.d/headroom.zsh"
  "$HOME/.local/bin/headroom-codex-shim"
  "$HOME/.local/bin/headroom-herdr"
  "$HOME/.local/bin/headroom-tmux"
)
for target in "${targets[@]}"; do
  if chezmoi --source "$PWD" source-path "$target" >/dev/null 2>&1; then
    printf 'still in source state: %s\n' "$target" >&2
    exit 1
  fi
  test ! -e "$target" || printf 'pending deployed cleanup: %s\n' "$target"
done
```

Expected: none of the six targets has a source path. Existing deployed targets are reported as pending cleanup for Task 4; their contents are not printed because the environment file may contain secrets. Do not run or apply a broad target diff.

- [ ] **Step 5: Commit the chezmoi retirement**

Run:

```bash
git diff --cached --check
git commit -m "chore: remove headroom tooling"
```

Expected: one atomic retirement commit after the existing design commit.

### Task 3: Remove Headroom providers and active Pi references

**Files:**
- Delete: `agent/models.json`
- Delete: `agent/scripts/test-headroom-models.py`
- Delete: `agent/docs/features/headroom-codex-oauth-provider.md`
- Delete: `agent/docs/features/headroom-openrouter-provider.md`
- Delete: `agent/docs/superpowers/plans/2026-07-13-provider-aware-model-routing.md`
- Delete: `agent/docs/superpowers/specs/2026-07-13-provider-aware-model-routing-design.md`
- Delete: `agent/docs/superpowers/specs/2026-07-19-headroom-gpt-5.6-model-store-design.md`
- Modify: `agent/AGENTS.md`
- Modify: `agent/docs/features/pi-agent-instructions.md`
- Modify: `agent/docs/features/pi-verifier-agent.md`
- Modify: `agent/packages/pi-verifier-agent-local/README.md`
- Modify: `agent/packages/pi-codex-usage-local/tests/statusline.test.ts`
- Modify: `agent/docs/index.json`
- Modify: `agent/docs/changelog.md`

**Interfaces:**
- Consumes: direct `openai-codex` catalog and tracked default from `settings.template.json`.
- Produces: Pi with no Headroom provider or active documentation.

- [ ] **Step 1: Add a failing retirement assertion before deleting the old test**

Create a temporary verification command:

```bash
python3 - <<'PY'
import json
from pathlib import Path
root = Path.home() / '.pi.chore-retire-headroom' / 'agent'
models = json.loads((root / 'models.json').read_text())
assert not any(name.startswith('headroom') for name in models.get('providers', {}))
PY
```

Expected before removal: FAIL because both Headroom providers exist.

- [ ] **Step 2: Delete provider-owned files and Headroom-specific historical plans**

Run in `~/.pi.chore-retire-headroom`:

```bash
git rm \
  agent/models.json \
  agent/scripts/test-headroom-models.py \
  agent/docs/features/headroom-codex-oauth-provider.md \
  agent/docs/features/headroom-openrouter-provider.md \
  agent/docs/superpowers/plans/2026-07-13-provider-aware-model-routing.md \
  agent/docs/superpowers/specs/2026-07-13-provider-aware-model-routing-design.md \
  agent/docs/superpowers/specs/2026-07-19-headroom-gpt-5.6-model-store-design.md
```

Expected: the custom-provider file disappears because it contains only Headroom providers.

- [ ] **Step 3: Remove active prose references**

Make these exact semantic replacements:

- `agent/AGENTS.md`: change the model default to direct `openai-codex/gpt-5.6-sol` only.
- `agent/docs/features/pi-agent-instructions.md`: describe plain direct Pi only.
- `agent/docs/features/pi-verifier-agent.md`: remove `hr-pix` resolution language.
- `agent/packages/pi-verifier-agent-local/README.md`: state that provider-relative `gpt-5.6-sol` resolves through the active direct Codex provider.
- `agent/packages/pi-codex-usage-local/tests/statusline.test.ts`: replace the Headroom-branded compatibility fixture with a neutral custom Codex proxy fixture while preserving generic Codex-model detection coverage:

```ts
{
  provider: "custom-codex-proxy",
  id: "gpt-5.4-mini",
  name: "Custom Codex OAuth GPT-5.4 mini",
}
```

- [ ] **Step 4: Remove feature index records and add retirement history**

In `agent/docs/index.json`:

- remove `features.headroom-openrouter-provider`;
- remove `features.headroom-codex-oauth-provider`;
- set `last_updated` to `2026-07-20`.

Prepend to `agent/docs/changelog.md`:

```markdown
## 2026-07-20 — Headroom retired

- `headroom-openrouter-provider` and `headroom-codex-oauth-provider` removed: Retired the local Headroom proxy, Pi providers, shim, launchers, active documentation, and runtime data. Plain Pi remains on direct `openai-codex/gpt-5.6-sol`; historical changelog entries remain unchanged.
  Files: `models.json`, `scripts/test-headroom-models.py`, `AGENTS.md`, `docs/features/headroom-*.md`, `docs/features/pi-agent-instructions.md`, `docs/features/pi-verifier-agent.md`, `docs/index.json`, `docs/changelog.md`, `packages/pi-verifier-agent-local/README.md`, `packages/pi-codex-usage-local/tests/statusline.test.ts`, `~/.local/share/chezmoi/`
```

- [ ] **Step 5: Validate the Pi retirement**

Run:

```bash
cd ~/.pi.chore-retire-headroom/agent
python3 -m json.tool settings.template.json >/dev/null
python3 scripts/validate-config-docs.py
npm --prefix packages/pi-codex-usage-local test
pi --list-models | grep '^openai-codex  *gpt-5.6-sol'
```

Expected: JSON and docs pass; package tests pass; direct Sol is listed.

- [ ] **Step 6: Scan active Pi files**

Run:

```bash
cd ~/.pi.chore-retire-headroom
git grep -Iin headroom -- agent \
  ':!agent/docs/changelog.md' \
  ':!agent/packages/pi-verifier-agent-local/_shared/socket-path.ts' \
  ':!agent/packages/pi-verifier-agent-local/verifiable.ts' || true
```

Expected: no product references. Generic English uses of “headroom” in socket/startup comments are explicitly excluded.

- [ ] **Step 7: Commit the Pi retirement**

Run:

```bash
git diff --check
git add agent
git commit -m "chore: retire headroom providers"
```

Expected: one atomic Pi retirement commit; `agent/models-store.json` remains unchanged in this worktree.

### Task 4: Review, integrate, and remove the runtime

**Files/runtime:**
- Apply merged chezmoi source.
- Update live `~/.pi/agent/settings.json` default provider/model.
- Remove `headroom-ai` uv tool.
- Delete `~/.headroom-private`.

**Interfaces:**
- Consumes: reviewed commits from Tasks 2 and 3.
- Produces: deployed system with no Headroom runtime or routes.

- [ ] **Step 1: Stop for human review**

Present both repository diffs and verification output. Do not merge or delete runtime data until Brendan approves.

- [ ] **Step 2: Integrate the chezmoi commit**

Use Worktrunk merge from the chezmoi feature worktree after confirming the original checkout is clean:

```bash
cd ~/.local/share/chezmoi.chore-agent-tooling-slimming
wt merge --yes
```

Expected: the feature branch merges into chezmoi `main` without unrelated files.

- [ ] **Step 3: Integrate the Pi commit without touching dirty `models-store.json`**

Before merge:

```bash
cd ~/.pi
git diff -- agent/models-store.json > /tmp/pi-models-store-pre-merge.patch
git diff -- agent/mcp.json > /tmp/pi-mcp-pre-merge.patch
```

Merge the Pi branch with Worktrunk. If Worktrunk refuses because the original checkout is dirty, stop and reconcile only the conflicting tracked paths; never restore or reset `models-store.json`.

Expected: Headroom retirement lands while the two saved patches remain available.

- [ ] **Step 4: Remove only deployed Headroom files**

First reconfirm that each exact target has no chezmoi source path, using the Task 2 source-state loop against the merged source. Then remove only the retired targets:

```bash
rm -rf ~/.config/headroom
rm -f \
  ~/.config/zsh/aliases.d/headroom.zsh \
  ~/.local/bin/headroom-codex-shim \
  ~/.local/bin/headroom-herdr \
  ~/.local/bin/headroom-tmux
```

Expected: the exact deployed Headroom directory, alias, and launchers are absent. Do not run a blanket `chezmoi apply`; unrelated target drift remains untouched.

- [ ] **Step 5: Update ignored live Pi defaults conservatively**

Patch only these keys in `~/.pi/agent/settings.json`:

```json
"defaultProvider": "openai-codex",
"defaultModel": "gpt-5.6-sol"
```

Remove any `headroom-*` entries from `enabledModels`, preserving every unrelated model and setting.

- [ ] **Step 6: Stop runtime processes and multiplexer containers**

Inspect before acting:

```bash
ps -axo pid,ppid,command | grep -Ei '[h]eadroom'
lsof -nP -iTCP:8787 -iTCP:8788 -iTCP:8789 -sTCP:LISTEN
herdr workspace list --json | grep -i headroom || true
tmux list-windows -a -F '#{session_name}:#{window_index}:#{window_name}' | grep -i headroom || true
```

Close only identified Headroom-owned Herdr workspaces/tmux windows or send normal termination to identified Headroom PIDs. Do not kill unrelated Python, zsh, or Pi processes.

- [ ] **Step 7: Uninstall and delete runtime data**

Run:

```bash
uv tool uninstall headroom-ai
rm -rf ~/.headroom-private
```

Expected: uv reports `headroom-ai` uninstalled; the private data directory is absent.

- [ ] **Step 8: Final runtime verification**

Run:

```bash
if command -v headroom >/dev/null; then exit 1; fi
if pgrep -afil '[h]eadroom'; then exit 1; fi
if lsof -nP -iTCP:8787 -iTCP:8788 -iTCP:8789 -sTCP:LISTEN; then exit 1; fi
test ! -e ~/.headroom-private
pi --list-models | grep '^openai-codex  *gpt-5.6-sol'
```

Expected: no Headroom command/process/listener/data; direct Sol remains available.
