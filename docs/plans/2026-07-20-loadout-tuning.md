# Collaborative Pi Loadout Tuning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the stale full/worker snapshots with a lean global default and reviewed `lean`, `coding`, `research`, `browser`, and `ops` presets.

**Architecture:** Tune one profile at a time in a dedicated Pi Worktrunk worktree. Each candidate is derived from the live post-slimming inventory, shown to Brendan with intentional overlaps called out, approved before mutation, written as an exact snapshot, and smoke-tested before moving to the next profile.

**Tech Stack:** `pi-loadout`, Pi active-tool/skill APIs, JSON, Python validation, Worktrunk.

## Constraints

- This plan begins only after Headroom retirement and RTK/MCP slimming are integrated.
- Do not edit a profile until Brendan approves its exact tools, skills, and intentional overlaps.
- Profile snapshots contain exact names; stale names are removed.
- Disabled skills remain manually callable with `/skill:name`.
- Loadouts control active tools/skills, not MCP server lifecycle.
- Browser automation and browser diagnostics may intentionally overlap only in the browser profile.
- Serena appears only in the coding profile.
- ICM direct recall/store may appear broadly; no other direct ICM tools may appear.
- Reliability and exact output take priority over the smallest possible list.
- No subagents. If delegation becomes necessary, use Herdr panes with task-appropriate models.

---

### Task 1: Create the worktree and inventory live names

**Files:**
- Modify later: `agent/loadout.json`
- Modify later: `agent/loadout-profiles.json`
- Preserve: `agent/models-store.json`
- Create temporary helper: `/tmp/pi-loadout-inventory.ts`

- [ ] **Step 1: Create the isolated worktree**

```bash
wt -C ~/.pi switch --create chore/tune-loadouts --yes
```

Expected: a new worktree, normally `~/.pi.chore-tune-loadouts`.

- [ ] **Step 2: Capture the live post-slimming inventory**

Create `/tmp/pi-loadout-inventory.ts`:

```ts
export default function (pi: any) {
  pi.on("input", () => {
    console.log(JSON.stringify({
      tools: pi.getAllTools().map((x: any) => x.name).sort(),
      activeTools: pi.getActiveTools().sort(),
    }));
    return { action: "handled" };
  });
}
```

Prepare an ignored, disposable runtime overlay and run against the worktree agent directory:

```bash
cd ~/.pi.chore-tune-loadouts/agent
cp ~/.pi/agent/settings.json settings.json
cp ~/.pi/agent/mcp-cache.json mcp-cache.json
test -e npm/node_modules || ln -s ~/.pi/agent/npm/node_modules npm/node_modules
PI_CODING_AGENT_DIR="$PWD" pi --no-session -e /tmp/pi-loadout-inventory.ts -p inventory
```

Use `PI_CODING_AGENT_DIR="$PWD" pi --no-session`, then `/loadout full` and `/loadout status`, to capture all available skill names. Do not save that temporary full selection. The copied runtime files and symlink remain ignored and disposable.

- [ ] **Step 3: Prove current snapshots are stale**

```bash
python3 - <<'PY'
import json
from pathlib import Path
for name in ('loadout.json','loadout-profiles.json'):
    data=json.loads(Path(name).read_text())
    text=json.dumps(data)
    for stale in ('code_search','fetch_content','get_search_content','web_search','tmux'):
        if stale in text: print(name, stale)
PY
```

Expected: stale tool names are reported, demonstrating the need for replacement rather than incremental edits.

### Task 2: Review and establish the lean default

**Files:**
- Modify after approval: `agent/loadout.json`
- Modify after approval: `agent/loadout-profiles.json`

**Candidate tool groups:**

- Core interaction: `ask_user_question`, `bash`, `read`, `edit`, `write`.
- Deterministic repository navigation: `fffind`, `ffgrep`, `find`, `grep`, `ls`.
- Official library docs: all three Context7 tools.
- Continuity and escape hatches: `icm_icm_memory_recall`, `icm_icm_memory_store`, `mcp`, `session_query`.

**Candidate skills:**

- `using-superpowers`, `brainstorming`, `writing-plans`, `executing-plans`, `systematic-debugging`, `verification-before-completion`, `using-git-worktrees`.

**Intentional overlap:** FFF plus built-in find/grep is retained because FFF is the efficient default while built-ins provide deterministic fallback. No research, browser, Serena, UniFi, or Hermes direct tools are enabled.

- [ ] **Step 1: Ask for explicit lean approval**

Present the exact names, total tool/skill counts, and the overlap above. Offer only concrete adjustments. Do not edit until Brendan approves.

- [ ] **Step 2: Write the approved lean snapshot**

Set `loadout.json.profileName` to `lean`. Add the same exact snapshot as `profiles.lean` in `loadout-profiles.json` with a fresh `updatedAt` timestamp.

- [ ] **Step 3: Validate and smoke-test lean**

```bash
python3 -m json.tool loadout.json >/dev/null
python3 -m json.tool loadout-profiles.json >/dev/null
PI_CODING_AGENT_DIR="$PWD" pi --no-session -p '/loadout use lean'
```

Then run `/loadout status` in a fresh temporary session and compare every active name to the approved list.

### Task 3: Review and establish the coding profile

**Files:**
- Modify after approval: `agent/loadout-profiles.json`

**Candidate additions to lean:**

- Serena: `serena_initial_instructions`, `serena_check_onboarding_performed`, `serena_get_symbols_overview`, `serena_find_symbol`, `serena_find_referencing_symbols`.
- Skills: `test-driven-development`, `incremental-implementation`, `requesting-code-review`, `receiving-code-review`, `finishing-a-development-branch`, `source-driven-development`, `code-review-and-quality`.

**Intentional overlap:** Serena performs symbolic navigation; FFF/built-ins remain for paths, literals, config, unsupported languages, and deterministic fallbacks. Context7 remains because coding against third-party APIs requires current official docs.

- [ ] **Step 1: Ask for explicit coding approval**

Present exact inherited and added names, counts, and overlap. Decide whether domain skills such as frontend/security/API design belong in the snapshot or stay manually callable.

- [ ] **Step 2: Write only the approved coding profile**

Add/replace `profiles.coding` with the exact approved snapshot and fresh `updatedAt`.

- [ ] **Step 3: Smoke-test coding**

Apply `/loadout use coding`, inspect `/loadout status`, and verify all five allowed Serena tools are active while Serena edit/memory tools remain absent.

### Task 4: Review and establish the research profile

**Files:**
- Modify after approval: `agent/loadout-profiles.json`

**Candidate additions to lean core:**

- Search/extraction: `searxng_search`, all Exa tools.
- Reports: `deep_research`, `super_deep_research`.
- Reasoning: `sequential_thinking_sequentialthinking`.
- Skills: `source-driven-development`, `idea-refine`, `pi-extension-advisor`, `find-skills`.

**Candidate removals from lean:** `edit` may be omitted if the profile is intended for report-only work; `read` and `write` remain for source inputs and artifacts.

**Intentional overlap:** SearXNG is the quick/general metasearch path; Exa reads and semantically searches known web content; deep-research tools produce sourced multi-search reports. Each has a distinct job.

- [ ] **Step 1: Ask for explicit research approval**

Decide exact quick-search/deep-search overlap and whether code-editing tools remain.

- [ ] **Step 2: Write only the approved research profile**

Add/replace `profiles.research` with exact names and fresh `updatedAt`.

- [ ] **Step 3: Smoke-test research**

Apply the profile, inspect status, run one bounded SearXNG query and one Exa tool-list call, and verify browser automation tools are absent.

### Task 5: Review and establish the browser profile

**Files:**
- Modify after approval: `agent/loadout-profiles.json`

**Candidate additions to lean core:**

- Playwriter direct tools: `playwriter_execute`, `playwriter_get_debugger_api`, `playwriter_get_editor_api`, `playwriter_get_styles_api`, `playwriter_reset`.
- Chrome DevTools direct tools: the complete live `chrome_devtools_*` group.
- Skills: `browser-session-discipline`, `playwriter`, `browser-testing-with-devtools`, `agent-browser`.

**Intentional overlap:** Playwriter is the default for authenticated/profile-aware and multi-step UI interaction. Chrome DevTools is retained for console, network, DOM/style/accessibility diagnostics, Lighthouse, and performance tracing—not duplicate form automation.

- [ ] **Step 1: Ask for explicit browser approval**

Present exact DevTools names and distinguish interaction from diagnostics. Decide whether all diagnostics or a smaller subset are warranted.

- [ ] **Step 2: Write only the approved browser profile**

Add/replace `profiles.browser` with exact names and fresh `updatedAt`.

- [ ] **Step 3: Smoke-test browser**

Follow the browser-session-discipline skill. Apply the profile, verify status, list pages with one browser owner only, and clean up the scoped browser session.

### Task 6: Review and establish the ops profile

**Files:**
- Modify after approval: `agent/loadout-profiles.json`

**Candidate additions to lean core:**

- UniFi: all five direct `unifi_network_*` wrapper tools.
- Messaging: seven direct `hermes_*` tools only if cross-platform operations are a routine ops need.
- Generic `mcp` for Home Assistant, UniFi Protect, and infrequent server-specific operations.
- Skills: `servarr-health-check`, `shield-health-check`, `moshi-best-practices`, `observability-and-instrumentation`.

**Intentional overlap:** UniFi wrappers remain direct for routine network work; generic `mcp` covers low-frequency home/Protect operations without loading every server schema. Hermes is optional and must be explicitly approved.

- [ ] **Step 1: Ask for explicit ops approval**

Decide whether Hermes belongs, whether browser diagnostics are needed, and whether destructive-capable network wrappers should all be active.

- [ ] **Step 2: Write only the approved ops profile**

Add/replace `profiles.ops` with exact names and fresh `updatedAt`.

- [ ] **Step 3: Smoke-test ops without mutation**

Apply the profile, inspect status, run read-only UniFi discovery/index and generic MCP server listing. Do not change devices, networks, messages, or Home Assistant state.

### Task 7: Remove obsolete presets, document, validate, and integrate

**Files:**
- Modify: `agent/loadout.json`
- Modify: `agent/loadout-profiles.json`
- Modify: `agent/docs/features/pi-packages.md`
- Modify: `agent/docs/index.json`
- Modify: `agent/docs/changelog.md`

- [ ] **Step 1: Remove obsolete worker and stale names**

Delete `profiles.worker`. Assert every saved tool and skill name exists in the live post-slimming inventory.

- [ ] **Step 2: Update durable docs**

Document the lean default, five profile purposes, intentional overlap boundaries, manual skill invocation, and the fact that loadouts do not control MCP lifecycle. Update `pi-packages.updated` and root `last_updated` to `2026-07-20`; prepend a `2026-07-20 — Lean task loadouts established` changelog entry.

- [ ] **Step 3: Run exact validation**

```bash
python3 -m json.tool loadout.json >/dev/null
python3 -m json.tool loadout-profiles.json >/dev/null
python3 scripts/validate-config-docs.py
fallow audit --changed-since main
```

Run each profile through `/loadout use <name>` and `/loadout status`; compare sorted active names against its JSON snapshot.

- [ ] **Step 4: Present final matrix for approval**

Report per-profile tool count, skill count, direct MCP groups, major omitted capabilities, and overlap rationale. Do not commit until Brendan approves the full matrix.

- [ ] **Step 5: Commit and integrate**

```bash
git diff --check
git add agent
git commit -m "chore: establish lean pi loadouts"
wt merge --yes
```

If the original Pi checkout is dirty, preserve `agent/mcp.json` and `agent/models-store.json`; never reset them.

- [ ] **Step 6: Final live verification**

In a new Pi session, verify the default reports `lean`, then apply each specialized profile once. Confirm the default can still use `mcp`, Context7, ICM recall/store, and deterministic repo navigation.
