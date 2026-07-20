# Collaborative Pi Loadout Tuning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the stale full/worker snapshots with a lean global default and reviewed `lean`, `coding`, `research`, `browser`, and `ops` presets.

**Architecture:** Tune one profile at a time in a dedicated Pi Worktrunk worktree. Each candidate is derived from the live post-slimming inventory, shown to Brendan with intentional overlaps called out, approved before mutation, written as an exact snapshot, and smoke-tested through a disposable `PI_CODING_AGENT_DIR` overlay before moving to the next profile. Treat `agent/models-store.json` as a dynamic runtime cache throughout: never stage or commit it, preserve the approved provider keys and `models` arrays, and allow only `checkedAt` drift.

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
- Never stage, commit, restore, stash, or reset `agent/models-store.json`; it must be absent from the feature-branch diff and remain exactly the sole dirty path on Pi `main`.
- Compare live `agent/models-store.json` with `/tmp/pi-pre-headroom-retirement-20260720-121432/models-store.json`: require identical provider keys, only `models`/`checkedAt` in each provider object, and equal `models` arrays; allow only runtime `checkedAt` drift.
- Every inventory and smoke Pi process must use a disposable `PI_CODING_AGENT_DIR` overlay so it cannot write live or feature-worktree runtime state.
- No subagents. If delegation becomes necessary, use Herdr panes with task-appropriate models and give each worker this cache invariant explicitly.

---

### Task 1: Create the worktree and inventory live names

**Files:**
- Modify later: `agent/loadout.json`
- Modify later: `agent/loadout-profiles.json`
- Preserve semantically and never stage: `agent/models-store.json`
- Create temporary helper: `/tmp/pi-loadout-inventory.ts`

- [ ] **Step 1: Create the isolated worktree**

```bash
wt -C ~/.pi switch --create chore/tune-loadouts --no-hooks --no-cd --yes
```

Expected: a new worktree, normally `~/.pi.chore-tune-loadouts`. `--no-hooks` prevents Worktrunk from stashing or otherwise reconciling the dirty runtime cache.

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

Create a persistent executable wrapper whose single process owns the entire disposable-overlay lifecycle for every inventory or smoke launch:

```bash
cat > /tmp/pi-loadout-smoke <<'SH'
#!/usr/bin/env bash
set -euo pipefail

source_dir=${PI_LOADOUT_SOURCE:-$HOME/.pi.chore-tune-loadouts/agent}
live_agent=$HOME/.pi/agent
test -d "$source_dir"
test -d "$live_agent/npm/node_modules"

overlay=$(mktemp -d "${TMPDIR:-/tmp}/pi-loadout-smoke.XXXXXX")
trap 'rm -rf -- "$overlay"' EXIT
chmod 700 "$overlay"
rsync -a --exclude='npm/node_modules' -- "$source_dir/" "$overlay/"
for runtime_file in settings.json mcp-cache.json auth.json; do
  if [[ -f "$live_agent/$runtime_file" ]]; then
    cp -p -- "$live_agent/$runtime_file" "$overlay/$runtime_file"
  fi
done
mkdir -p "$overlay/npm"
ln -s "$live_agent/npm/node_modules" "$overlay/npm/node_modules"
chmod 700 "$overlay"

PI_CODING_AGENT_DIR="$overlay" pi "$@"
SH
chmod 700 /tmp/pi-loadout-smoke
/tmp/pi-loadout-smoke --no-session -e /tmp/pi-loadout-inventory.ts -p inventory
```

The wrapper does not print copied runtime files. Each invocation creates a fresh mode-700 overlay from `PI_LOADOUT_SOURCE` (defaulting to the feature-worktree agent directory), overlays needed live runtime files without displaying them, reuses live `node_modules` through a symlink, waits for its foreground Pi process, and removes the overlay only through its `EXIT` trap after Pi exits.

Run `/tmp/pi-loadout-smoke --no-session`, then `/loadout full` and `/loadout status`, to capture all available skill names. Do not save that temporary full selection. Invoke the wrapper again after tracked configuration changes; every launch receives a new overlay, and all runtime writes, including `models-store.json` refreshes, remain disposable.

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
/tmp/pi-loadout-smoke --no-session
```

In that wrapper-owned interactive Pi process, run `/loadout use lean` and then `/loadout status`. Capture and compare every active name with the approved list before exiting the same process; do not inspect the applied profile through a second wrapper invocation.

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

Launch the isolated coding smoke explicitly:

```bash
/tmp/pi-loadout-smoke --no-session
```

Apply `/loadout use coding`, inspect `/loadout status`, and verify all five allowed Serena tools are active while Serena edit/memory tools remain absent. Exit Pi to let the wrapper remove its overlay.

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

Launch the isolated research smoke explicitly:

```bash
/tmp/pi-loadout-smoke --no-session
```

Apply `/loadout use research`, inspect `/loadout status`, run one bounded SearXNG query and one Exa tool-list call, and verify browser automation tools are absent. Exit Pi to let the wrapper remove its overlay.

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

Follow the browser-session-discipline skill, including its one-browser-owner and scoped-cleanup requirements. Launch the isolated browser smoke explicitly:

```bash
/tmp/pi-loadout-smoke --no-session
```

Apply `/loadout use browser`, verify `/loadout status`, list pages with one browser owner only, clean up the scoped browser session, and then exit Pi so the wrapper removes its overlay.

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

Launch the isolated ops smoke explicitly:

```bash
/tmp/pi-loadout-smoke --no-session
```

Apply `/loadout use ops`, inspect `/loadout status`, and run read-only UniFi discovery/index and generic MCP server listing. Do not change devices, networks, messages, or Home Assistant state. Exit Pi to let the wrapper remove its overlay.

### Task 7: Remove obsolete presets, document, validate, and integrate

**Files:**
- Modify: `agent/loadout.json`
- Modify: `agent/loadout-profiles.json`
- Modify: `agent/docs/features/pi-packages.md`
- Modify: `agent/docs/index.json`
- Modify: `agent/docs/changelog.md`

- [ ] **Step 1: Remove obsolete worker and stale names**

Delete `profiles.worker`. Refresh the isolated live post-slimming inventory explicitly, then assert every saved tool and skill name exists in it:

```bash
/tmp/pi-loadout-smoke --no-session -e /tmp/pi-loadout-inventory.ts -p inventory
```

- [ ] **Step 2: Update durable docs**

Document the lean default, five profile purposes, intentional overlap boundaries, manual skill invocation, and the fact that loadouts do not control MCP lifecycle. Update `pi-packages.updated` and root `last_updated` to `2026-07-20`; prepend a `2026-07-20 — Lean task loadouts established` changelog entry.

- [ ] **Step 3: Run exact validation**

```bash
python3 -m json.tool loadout.json >/dev/null
python3 -m json.tool loadout-profiles.json >/dev/null
python3 scripts/validate-config-docs.py
fallow audit --changed-since main
```

Validate each profile in its own wrapper-owned interactive Pi process. Apply the profile and inspect its status before exiting that same process; never use a second wrapper launch to inspect a selection made by an earlier launch.

1. Launch the lean validation process:

   ```bash
   /tmp/pi-loadout-smoke --no-session
   ```

   At its Pi prompt, run:

   ```text
   /loadout use lean
   /loadout status
   ```

   Capture the `/loadout status` output, compare its sorted active names with the `lean` JSON snapshot, and only then exit this same interactive process.

2. Launch the coding validation process:

   ```bash
   /tmp/pi-loadout-smoke --no-session
   ```

   At its Pi prompt, run:

   ```text
   /loadout use coding
   /loadout status
   ```

   Capture the `/loadout status` output, compare its sorted active names with the `coding` JSON snapshot, and only then exit this same interactive process.

3. Launch the research validation process:

   ```bash
   /tmp/pi-loadout-smoke --no-session
   ```

   At its Pi prompt, run:

   ```text
   /loadout use research
   /loadout status
   ```

   Capture the `/loadout status` output, compare its sorted active names with the `research` JSON snapshot, and only then exit this same interactive process.

4. Launch the browser validation process under `browser-session-discipline`, keeping one browser owner and running browser-capable checks serially:

   ```bash
   /tmp/pi-loadout-smoke --no-session
   ```

   At its Pi prompt, run:

   ```text
   /loadout use browser
   /loadout status
   ```

   Capture the `/loadout status` output, compare its sorted active names with the `browser` JSON snapshot, perform scoped browser cleanup, and only then exit this same interactive process.

5. Launch the ops validation process:

   ```bash
   /tmp/pi-loadout-smoke --no-session
   ```

   At its Pi prompt, run:

   ```text
   /loadout use ops
   /loadout status
   ```

   Capture the `/loadout status` output, compare its sorted active names with the `ops` JSON snapshot, and only then exit this same interactive process.

- [ ] **Step 4: Present final matrix for approval**

Report per-profile tool count, skill count, direct MCP groups, major omitted capabilities, and overlap rationale. Do not commit until Brendan approves the full matrix.

- [ ] **Step 5: Commit and integrate**

Do not invoke Worktrunk from dirty Pi `main`. Use explicit staging paths, prove the branch excludes `models-store.json`, and fast-forward manually after the bounded semantic assertion:

```bash
cd ~/.pi.chore-tune-loadouts
models_backup=/tmp/pi-pre-headroom-retirement-20260720-121432/models-store.json
assert_models_store() {
  python3 - "$1" "$models_backup" <<'PY'
import json
import sys
from pathlib import Path

live_path, approved_path = map(Path, sys.argv[1:])
live = json.loads(live_path.read_text())
approved = json.loads(approved_path.read_text())
assert live.keys() == approved.keys()
for provider in approved:
    for label, catalog in (("live", live), ("approved", approved)):
        entry = catalog[provider]
        assert isinstance(entry, dict), (label, provider, type(entry).__name__)
        assert set(entry) == {"models", "checkedAt"}, (label, provider, sorted(entry))
        assert isinstance(entry["models"], list), (label, provider, "models")
        assert type(entry["checkedAt"]) is int, (label, provider, "checkedAt")
    assert live[provider]["models"] == approved[provider]["models"], provider
print(f"validated {len(approved)} providers; checkedAt drift allowed")
PY
}

git diff --quiet HEAD -- agent/models-store.json
git diff --check
git add -- \
  agent/loadout.json \
  agent/loadout-profiles.json \
  agent/docs/features/pi-packages.md \
  agent/docs/index.json \
  agent/docs/changelog.md
git diff --cached --quiet -- agent/models-store.json
git commit -m "chore: establish lean pi loadouts"
git diff --quiet main...HEAD -- agent/models-store.json
test "$(git -C ~/.pi status --short --untracked-files=all)" = " M agent/models-store.json"
assert_models_store ~/.pi/agent/models-store.json
git merge-base --is-ancestor main HEAD
git -C ~/.pi merge --ff-only chore/tune-loadouts
test "$(git -C ~/.pi status --short --untracked-files=all)" = " M agent/models-store.json"
assert_models_store ~/.pi/agent/models-store.json
```

Any failed precondition is a hard stop. Never stage, commit, restore, stash, or reset `agent/models-store.json`; only `checkedAt` may differ from the approved backup.

- [ ] **Step 6: Final live verification**

After the fast-forward merge, point every self-contained wrapper launch at the merged live agent source explicitly. First launch the default check:

```bash
PI_LOADOUT_SOURCE=~/.pi/agent /tmp/pi-loadout-smoke --no-session
```

Run `/loadout status` at its Pi prompt, verify that it reports `lean`, capture the result, and then exit that interactive process.

Next, validate every merged profile with the same one-session apply-and-status rule:

1. Launch the lean check:

   ```bash
   PI_LOADOUT_SOURCE=~/.pi/agent /tmp/pi-loadout-smoke --no-session
   ```

   Before exiting that Pi process, run:

   ```text
   /loadout use lean
   /loadout status
   ```

   Capture the status, compare its sorted active names with the merged `lean` JSON snapshot, and only then exit this same interactive process.

2. Launch the coding check:

   ```bash
   PI_LOADOUT_SOURCE=~/.pi/agent /tmp/pi-loadout-smoke --no-session
   ```

   Before exiting that Pi process, run:

   ```text
   /loadout use coding
   /loadout status
   ```

   Capture the status, compare its sorted active names with the merged `coding` JSON snapshot, and only then exit this same interactive process.

3. Launch the research check:

   ```bash
   PI_LOADOUT_SOURCE=~/.pi/agent /tmp/pi-loadout-smoke --no-session
   ```

   Before exiting that Pi process, run:

   ```text
   /loadout use research
   /loadout status
   ```

   Capture the status, compare its sorted active names with the merged `research` JSON snapshot, and only then exit this same interactive process.

4. Launch the browser check under `browser-session-discipline`, with one browser owner and serial browser-capable checks:

   ```bash
   PI_LOADOUT_SOURCE=~/.pi/agent /tmp/pi-loadout-smoke --no-session
   ```

   Before exiting that Pi process, run:

   ```text
   /loadout use browser
   /loadout status
   ```

   Capture the status, compare its sorted active names with the merged `browser` JSON snapshot, complete scoped browser cleanup, and only then exit this same interactive process.

5. Launch the ops check:

   ```bash
   PI_LOADOUT_SOURCE=~/.pi/agent /tmp/pi-loadout-smoke --no-session
   ```

   Before exiting that Pi process, run:

   ```text
   /loadout use ops
   /loadout status
   ```

   Capture the status, compare its sorted active names with the merged `ops` JSON snapshot, and only then exit this same interactive process.

Finally, launch one more isolated default process:

```bash
PI_LOADOUT_SOURCE=~/.pi/agent /tmp/pi-loadout-smoke --no-session
```

Use that process only to confirm the default can still use `mcp`, Context7, ICM recall/store, and deterministic repo navigation, then exit. Every command above copies from `~/.pi/agent` but runs Pi only against a fresh wrapper-owned overlay; none sets `PI_CODING_AGENT_DIR` to the live agent directory. Continue to honor `browser-session-discipline` for every browser-capable check, including one browser owner, serial execution, and scoped cleanup.
