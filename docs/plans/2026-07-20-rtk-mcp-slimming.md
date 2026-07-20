# RTK and MCP Slimming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep RTK command rewriting, remove Pi's second output-compaction pass, reduce ICM to two direct tools, and reduce Serena to five direct setup/navigation tools.

**Architecture:** First review and commit the approved existing `mcp.json` change directly on Pi `main`, while preserving the dirty `models-store.json` byte-for-byte. Create the dedicated Pi Worktrunk worktree from that commit without importing a patch, then use the adapter's exact `directTools` whitelists and `excludeTools` filters. Update durable docs, measure the resulting direct tool surface, and integrate with a preconditioned fast-forward merge that never invokes Worktrunk on dirty Pi `main`.

**Tech Stack:** Pi `pi-rtk-optimizer`, `pi-mcp-adapter`, JSON, Python validation, MCP metadata cache, Worktrunk.

## Constraints

- RTK is the sole shell-output optimizer; post-result compaction and hard truncation stay disabled.
- ICM direct tools: `icm_memory_recall`, `icm_memory_store` only. Other ICM tools remain proxy-accessible.
- Serena direct tools: `initial_instructions`, `check_onboarding_performed`, `get_symbols_overview`, `find_symbol`, `find_referencing_symbols` only.
- Serena edit/memory tools are hidden from both direct exposure and proxy discovery.
- Keep Serena lifecycle hooks; remove dead direct-edit hook matchers.
- Preserve the committed direct-tool tuning in `agent/mcp.json`; never modify, stage, stash, reset, or restore `agent/models-store.json`.
- After the safety preflight commit, the only dirty path allowed on Pi `main` is the byte-unchanged `agent/models-store.json`.
- Never invoke Worktrunk on dirty Pi `main` during integration; use the preconditioned fast-forward merge in Task 4.
- No subagents. If delegation becomes necessary, use Herdr panes with task-appropriate models.

---

### Task 1: Commit the approved MCP preflight and create the Pi worktree

**Files:**
- Commit on Pi `main`: `agent/mcp.json`
- Preserve without staging or mutation: `agent/models-store.json`
- Compare against: `/tmp/pi-pre-headroom-retirement-20260720-121432/`

- [x] **Step 1: Verify the original checkout and review the bounded semantic diff**

```bash
cd ~/.pi
test "$(git rev-parse HEAD)" = bd786caa80937569d9449d8596120a3fefaae6f3
test "$(git branch --show-current)" = main
test "$(git status --short --untracked-files=all)" = $' M agent/mcp.json\n M agent/models-store.json'
cmp -s agent/mcp.json /tmp/pi-pre-headroom-retirement-20260720-121432/mcp.json
cmp -s agent/models-store.json /tmp/pi-pre-headroom-retirement-20260720-121432/models-store.json
python3 -m json.tool agent/mcp.json >/dev/null
python3 -m json.tool agent/models-store.json >/dev/null
python3 - <<'PY'
import json, subprocess
from pathlib import Path
before=json.loads(subprocess.check_output(['git','show','HEAD:agent/mcp.json'], text=True))
after=json.loads(Path('agent/mcp.json').read_text())
changes=[]
def walk(a,b,path=()):
    if isinstance(a,dict) and isinstance(b,dict):
        for key in sorted(a.keys() | b.keys()):
            if key not in a: changes.append(('added','.'.join(path+(key,)),None,b[key]))
            elif key not in b: changes.append(('removed','.'.join(path+(key,)),a[key],None))
            else: walk(a[key],b[key],path+(key,))
    elif a != b: changes.append(('changed','.'.join(path),a,b))
walk(before,after)
assert changes == [
 ('changed','mcpServers.astro-docs.directTools',True,False),
 ('changed','mcpServers.starwind-ui.directTools',True,False),
 ('added','mcpServers.unifi-network.directTools',None,True),
]
print(changes)
PY
```

Expected: both files match the safety backup byte-for-byte, both parse as JSON, and the script prints only the three approved `directTools` changes without exposing unrelated server configuration.

- [x] **Step 2: Commit only the existing MCP change on Pi `main`**

```bash
cd ~/.pi
models_hash=6749f2a6c7db1e473e4e118306ce8c9cf2ae2a5abc56b33b300b4b04abba62d7
test "$(sha256sum agent/models-store.json | awk '{print $1}')" = "$models_hash"
git add -- agent/mcp.json
test "$(git diff --cached --name-only)" = agent/mcp.json
test "$(git diff --name-only)" = agent/models-store.json
git diff --cached --check -- agent/mcp.json
git commit -m "chore: tune mcp direct tools"
test "$(sha256sum agent/models-store.json | awk '{print $1}')" = "$models_hash"
test "$(git status --short --untracked-files=all)" = " M agent/models-store.json"
```

Expected: Pi `main` advances from `bd786caa80937569d9449d8596120a3fefaae6f3` to the MCP-only commit; the protected hash is unchanged and `agent/models-store.json` is the only dirty path.

- [x] **Step 3: Create the isolated worktree from the committed MCP state**

```bash
cd ~/.pi
base=$(git rev-parse HEAD)
wt -C ~/.pi switch --create chore/slim-rtk-mcp --base="$base" --no-hooks --no-cd --yes
cd ~/.pi.chore-slim-rtk-mcp
test "$(git rev-parse HEAD)" = "$base"
test -z "$(git status --short --untracked-files=all)"
python3 - <<'PY'
import json
m=json.load(open('agent/mcp.json'))['mcpServers']
assert m['astro-docs']['directTools'] is False
assert m['starwind-ui']['directTools'] is False
assert m['unifi-network']['directTools'] is True
PY
```

Expected: Worktrunk creates clean branch `chore/slim-rtk-mcp`, normally at `~/.pi.chore-slim-rtk-mcp`, directly from the MCP commit. `--no-hooks` prevents dirty-main stash behavior; no patch is created or applied.

- [ ] **Step 4: Record baseline MCP metadata**

```bash
python3 - <<'PY'
import json
from pathlib import Path
cache=json.loads((Path.home()/'.pi/agent/mcp-cache.json').read_text())['servers']
for name in ('icm','serena'):
    tools=cache[name]['tools']
    raw=sum(len(json.dumps(t,separators=(',',':'))) for t in tools)
    print(name, 'tools=',len(tools),'schema_bytes=',raw,'rough_tokens=',round(raw/4))
PY
```

Expected: current counts are recorded before filtering.

### Task 2: Make RTK rewrite-only

**Files:**
- Modify: `agent/extensions/pi-rtk-optimizer/config.json`
- Modify: `agent/docs/features/pi-rtk-optimizer.md`
- Modify: `agent/RTK.md`
- Modify: `agent/docs/claude-feature-migration.md`
- Modify: `agent/docs/index.json`
- Modify: `agent/docs/changelog.md`

- [ ] **Step 1: Prove the old policy fails the new requirement**

```bash
cd ~/.pi.chore-slim-rtk-mcp/agent
python3 - <<'PY'
import json
c=json.load(open('extensions/pi-rtk-optimizer/config.json'))
assert c['enabled'] is True
assert c['mode'] == 'rewrite'
assert c['outputCompaction']['enabled'] is False
PY
```

Expected: FAIL because output compaction is currently enabled.

- [ ] **Step 2: Disable only post-result output compaction**

Set:

```json
"outputCompaction": {
  "enabled": false,
  "timeoutMs": 20000,
  "hardTruncate": false,
  "minInputChars": 800
}
```

Keep extension `enabled: true` and `mode: "rewrite"`.

- [ ] **Step 3: Update the RTK feature record and policy docs**

Document that:

- Pi rewrites eligible Bash commands through RTK.
- Pi does not compact tool results after execution.
- Pi does not hard-truncate those results.
- Native tool guards still apply independently.
- Claude compatibility is historical/reference-only.

Update `features.pi-rtk-optimizer.updated` and root `last_updated` in `docs/index.json` to `2026-07-20`. Prepend a concise `2026-07-20 — RTK rewrite-only policy` changelog entry.

- [ ] **Step 4: Verify config and representative rewrites**

```bash
python3 -m json.tool extensions/pi-rtk-optimizer/config.json >/dev/null
python3 - <<'PY'
import json
c=json.load(open('extensions/pi-rtk-optimizer/config.json'))
assert c['enabled'] is True and c['mode']=='rewrite'
assert c['outputCompaction']['enabled'] is False
assert c['outputCompaction']['hardTruncate'] is False
PY
rtk rewrite 'git status'
rtk rewrite 'rg -n headroom agent'
```

Expected: assertions pass and both supported commands produce RTK rewrites.

### Task 3: Slim ICM and Serena exposure

**Files:**
- Modify: `agent/mcp.json`
- Modify: `agent/settings.template.json`
- Modify after merge: `~/.pi/agent/settings.json`
- Modify: `agent/docs/features/mcp-agent-tools.md`
- Modify: `agent/docs/features/pi-runtime-settings.md`
- Modify: `agent/docs/index.json`
- Modify: `agent/docs/changelog.md`

- [ ] **Step 1: Add failing policy assertions**

```bash
python3 - <<'PY'
import json
m=json.load(open('mcp.json'))
assert m['mcpServers']['icm']['directTools']==['icm_memory_recall','icm_memory_store']
assert m['mcpServers']['serena']['directTools']==[
 'initial_instructions','check_onboarding_performed','get_symbols_overview',
 'find_symbol','find_referencing_symbols']
PY
```

Expected: FAIL because both servers currently expose all tools.

- [ ] **Step 2: Configure the exact ICM whitelist**

Set:

```json
"directTools": ["icm_memory_recall", "icm_memory_store"]
```

Do not add `excludeTools` for ICM: non-direct ICM operations must remain discoverable through `mcp`.

- [ ] **Step 3: Configure the exact Serena whitelist and exclusions**

Set `directTools` to:

```json
[
  "initial_instructions",
  "check_onboarding_performed",
  "get_symbols_overview",
  "find_symbol",
  "find_referencing_symbols"
]
```

Set `excludeTools` to:

```json
[
  "delete_memory",
  "edit_memory",
  "insert_after_symbol",
  "insert_before_symbol",
  "open_dashboard",
  "read_memory",
  "rename_memory",
  "rename_symbol",
  "replace_symbol_body",
  "safe_delete_symbol",
  "write_memory"
]
```

Leave `onboarding` proxy-accessible for new projects.

- [ ] **Step 4: Remove obsolete direct-edit hook matchers**

From `settings.template.json` and the live ignored `settings.json`, remove these five entries only:

```text
serena_insert_after_symbol
serena_insert_before_symbol
serena_rename_symbol
serena_replace_symbol_body
serena_safe_delete_symbol
```

Keep the `pi-hooks/lifecycle-serena.ts` and `pi-hooks/serena-bind.ts` hooks.

- [ ] **Step 5: Update durable MCP/runtime documentation**

Document exact direct whitelists, Serena exclusions, retained proxy access, and retained lifecycle hooks. Update affected index records and prepend a `2026-07-20 — MCP direct-tool surface slimmed` changelog entry.

- [ ] **Step 6: Validate exact config state**

```bash
python3 -m json.tool mcp.json >/dev/null
python3 -m json.tool settings.template.json >/dev/null
python3 - <<'PY'
import json
m=json.load(open('mcp.json'))['mcpServers']
assert m['icm']['directTools']==['icm_memory_recall','icm_memory_store']
assert m['serena']['directTools']==['initial_instructions','check_onboarding_performed','get_symbols_overview','find_symbol','find_referencing_symbols']
blocked={'delete_memory','edit_memory','insert_after_symbol','insert_before_symbol','open_dashboard','read_memory','rename_memory','rename_symbol','replace_symbol_body','safe_delete_symbol','write_memory'}
assert set(m['serena']['excludeTools'])==blocked
PY
```

Expected: all assertions pass.

### Task 4: Verify, review, integrate, and measure

**Files:**
- All changed files from Tasks 2–3.
- Temporary tool-inventory helper under `/tmp`, not committed.

- [ ] **Step 1: Run repository validation**

```bash
cd ~/.pi.chore-slim-rtk-mcp/agent
python3 scripts/validate-config-docs.py
fallow audit --changed-since main
```

Expected: docs validation and static analysis pass.

- [ ] **Step 2: Verify direct tools in a fresh Pi process**

Create `/tmp/pi-tool-inventory.ts`:

```ts
export default function (pi: any) {
  pi.on("input", () => {
    console.log(JSON.stringify(pi.getActiveTools().sort()));
    return { action: "handled" };
  });
}
```

Prepare an ignored, disposable runtime overlay so Pi reads the worktree configuration without reinstalling packages or mutating the live agent directory:

```bash
cd ~/.pi.chore-slim-rtk-mcp/agent
cp ~/.pi/agent/settings.json settings.json
cp ~/.pi/agent/mcp-cache.json mcp-cache.json
test -e npm/node_modules || ln -s ~/.pi/agent/npm/node_modules npm/node_modules
```

Apply the same five hook-matcher removals to the copied `settings.json`, then run:

```bash
PI_CODING_AGENT_DIR="$PWD" pi --no-session -e /tmp/pi-tool-inventory.ts -p inventory
```

Expected: output contains only the two direct ICM tools and five direct Serena tools. Excluded Serena editing/memory tools are absent. The copied settings/cache and symlink remain ignored and disposable.

- [ ] **Step 3: Verify proxy behavior**

Start a fresh session with:

```bash
PI_CODING_AGENT_DIR=~/.pi.chore-slim-rtk-mcp/agent pi --no-session
```

Then verify:

- `mcp({ server: "icm" })` lists non-direct ICM operations.
- `mcp({ server: "serena" })` includes `onboarding` but excludes every configured Serena editing/memory operation.

- [ ] **Step 4: Present the diff and measurements for review**

Report before/after direct-tool counts and rough schema bytes. Do not integrate until Brendan approves.

- [ ] **Step 5: Commit and integrate with explicit safety preconditions**

Do not call Worktrunk from dirty Pi `main`. Before staging, prove the feature worktree has not modified the protected file. After committing, prove the branch-level diff still excludes it, Pi `main` contains only the original byte-unchanged protected dirt, and the branch is a fast-forward descendant. Then integrate with `git merge --ff-only`:

```bash
cd ~/.pi.chore-slim-rtk-mcp
git diff --quiet HEAD -- agent/models-store.json
git diff --check
git add agent
test -z "$(git diff --cached --name-only -- agent/models-store.json)"
git commit -m "chore: slim rtk and mcp tooling"
git diff --quiet main...HEAD -- agent/models-store.json
models_hash=6749f2a6c7db1e473e4e118306ce8c9cf2ae2a5abc56b33b300b4b04abba62d7
test "$(git -C ~/.pi status --short --untracked-files=all)" = " M agent/models-store.json"
test "$(sha256sum ~/.pi/agent/models-store.json | awk '{print $1}')" = "$models_hash"
git merge-base --is-ancestor main HEAD
git -C ~/.pi merge --ff-only chore/slim-rtk-mcp
test "$(git -C ~/.pi status --short --untracked-files=all)" = " M agent/models-store.json"
test "$(sha256sum ~/.pi/agent/models-store.json | awk '{print $1}')" = "$models_hash"
```

Expected: the feature commit excludes `agent/models-store.json`, Pi `main` advances by fast-forward only, and the sole dirty path and protected hash are unchanged. Any failed precondition is a hard stop; do not stash, reset, restore, reconcile, or invoke Worktrunk on dirty Pi `main`.

- [ ] **Step 6: Final live verification**

Run from `~/.pi/agent`:

```bash
python3 scripts/validate-config-docs.py
fallow audit --changed-since main
pi --no-session -e /tmp/pi-tool-inventory.ts -p inventory
```

Expected: all validation passes and the live direct-tool surface matches policy.
