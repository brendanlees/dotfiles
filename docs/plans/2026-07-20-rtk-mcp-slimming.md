# RTK and MCP Slimming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep RTK command rewriting, remove Pi's second output-compaction pass, reduce ICM to two direct tools, and reduce Serena to five direct setup/navigation tools.

**Architecture:** Apply changes in a dedicated Pi Worktrunk worktree after Headroom retirement. Import the original checkout's existing `mcp.json` changes first, then use the adapter's exact `directTools` whitelists and `excludeTools` filters. Update durable docs and measure the resulting direct tool surface.

**Tech Stack:** Pi `pi-rtk-optimizer`, `pi-mcp-adapter`, JSON, Python validation, MCP metadata cache, Worktrunk.

## Constraints

- RTK is the sole shell-output optimizer; post-result compaction and hard truncation stay disabled.
- ICM direct tools: `icm_memory_recall`, `icm_memory_store` only. Other ICM tools remain proxy-accessible.
- Serena direct tools: `initial_instructions`, `check_onboarding_performed`, `get_symbols_overview`, `find_symbol`, `find_referencing_symbols` only.
- Serena edit/memory tools are hidden from both direct exposure and proxy discovery.
- Keep Serena lifecycle hooks; remove dead direct-edit hook matchers.
- Preserve user changes in `agent/mcp.json`; never modify `agent/models-store.json`.
- No subagents. If delegation becomes necessary, use Herdr panes with task-appropriate models.

---

### Task 1: Create the Pi worktree and import existing MCP changes

**Files:**
- Modify later: `agent/mcp.json`
- Preserve: `agent/models-store.json`
- Create: `/tmp/pi-mcp-before-slimming.patch`
- Create: `/tmp/pi-models-store-before-slimming.patch`

- [ ] **Step 1: Capture bounded patches from the original checkout**

```bash
cd ~/.pi
git diff -- agent/mcp.json > /tmp/pi-mcp-before-slimming.patch
git diff -- agent/models-store.json > /tmp/pi-models-store-before-slimming.patch
test -s /tmp/pi-mcp-before-slimming.patch
test -s /tmp/pi-models-store-before-slimming.patch
```

Expected: both patches are non-empty; the checkout is unchanged.

- [ ] **Step 2: Create the isolated worktree**

```bash
wt -C ~/.pi switch --create chore/slim-rtk-mcp --yes
```

Expected: Worktrunk reports a new worktree, normally `~/.pi.chore-slim-rtk-mcp`.

- [ ] **Step 3: Apply only the MCP patch**

```bash
cd ~/.pi.chore-slim-rtk-mcp
git apply /tmp/pi-mcp-before-slimming.patch
git diff -- agent/mcp.json
```

Expected: the user's Astro Docs, Playwriter, and UniFi changes are present. Do not apply the models-store patch.

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

- [ ] **Step 5: Commit and integrate**

```bash
git diff --check
git add agent
git commit -m "chore: slim rtk and mcp tooling"
wt merge --yes
```

If Worktrunk refuses because `~/.pi` is dirty, stop and reconcile only `agent/mcp.json`; never reset `agent/models-store.json`.

- [ ] **Step 6: Final live verification**

Run from `~/.pi/agent`:

```bash
python3 scripts/validate-config-docs.py
fallow audit --changed-since main
pi --no-session -e /tmp/pi-tool-inventory.ts -p inventory
```

Expected: all validation passes and the live direct-tool surface matches policy.
