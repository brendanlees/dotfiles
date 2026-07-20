# Agent Tooling Slimming Design

## Purpose

Simplify Brendan's Pi workflow around reliability, exact evidence, and deliberate tool exposure. Remove Headroom entirely, retain RTK only for command rewriting, reduce ICM and Serena's direct MCP surfaces, and replace the current full loadout with a lean default plus task-specific profiles.

This work spans two repositories:

- `~/.local/share/chezmoi`: Headroom installation, shell helpers, launchers, tests, and documentation.
- `~/.pi`: Pi providers, RTK configuration, MCP exposure, loadouts, and durable Pi feature documentation.

## Decisions

1. Reliability wins when token savings conflict with exact output or workflow simplicity.
2. Remove Headroom completely from chezmoi, Pi, Claude integration, and the local runtime.
3. Delete Headroom's private runtime data and historical savings data under `~/.headroom-private`.
4. Preserve native `openai-codex/gpt-5.6-sol` as Pi's default provider/model path.
5. Keep RTK command rewriting, but disable Pi extension post-result compaction and truncation.
6. Keep ICM direct access only for memory recall and storage.
7. Keep Serena only for coding loadouts and expose navigation/setup tools, not editing or Serena memory tools.
8. Make a lean general-purpose loadout the global default.
9. Review and approve each specialized profile individually. Tool and skill overlap between profiles is expected when it reflects real role needs.
10. Do not add another context optimizer or custom MCP-lifecycle layer.
11. Preserve historical changelog entries; add retirement entries rather than rewriting history.
12. Do not use subagents for this sequential shared-config work. If delegation becomes warranted, use Herdr panes with task-appropriate models.
13. Treat `agent/models-store.json` as a dynamic catalog cache: never stage or commit it; preserve the approved provider key set and byte/JSON-equal `models` arrays, while allowing Pi to refresh only each provider's `checkedAt` value.

## Architecture and Phases

### Phase 1: Retire Headroom from chezmoi

Remove all active Headroom-managed source:

- `dot_config/headroom/`
- Headroom zsh aliases
- Headroom executable launchers and Codex shim
- Headroom-specific tests
- current Headroom documentation
- Headroom-specific historical design/implementation documents
- package or installation declarations
- ignore exceptions and generated-target references that exist only for Headroom

Applying chezmoi must remove obsolete deployed files instead of merely ceasing to manage them.

### Phase 2: Retire Headroom from Pi

Remove:

- `headroom-openrouter` and `headroom-codex-oauth` providers from `models.json`
- Headroom model verification scripts
- Headroom feature documentation and feature-index records
- Headroom-specific defaults or enabled-model entries in live/runtime settings
- active documentation references that describe Headroom as available

Keep native `openai-codex` model definitions and the direct `openai-codex/gpt-5.6-sol` default.

`agent/models-store.json` is runtime-owned cache state, not an integration artifact. Future Pi work must compare it with `/tmp/pi-pre-headroom-retirement-20260720-121432/models-store.json` semantically: the provider keys must match, every provider object must contain only `models` and `checkedAt`, and each `models` array must be equal. Runtime-only `checkedAt` drift is allowed.

### Phase 3: Remove the Headroom runtime

After tracked configuration is safely retired:

1. Stop Headroom Herdr/tmux workspaces and proxy/shim processes.
2. Uninstall `headroom-ai` through the package manager that owns the executable.
3. Remove generated Headroom files and `~/.headroom-private`.
4. Confirm commands, processes, listeners on ports 8787–8789, and private runtime data are absent.

Do not modify unrelated Claude configuration.

### Phase 4: Make RTK rewrite-only

Keep `pi-rtk-optimizer` installed with:

```json
{
  "enabled": true,
  "mode": "rewrite",
  "guardWhenRtkMissing": true,
  "outputCompaction": {
    "enabled": false
  }
}
```

The installed `rtk` binary remains the source of truth for eligible rewrites. Pi's extension must not apply a second result-compaction or hard-truncation pass.

### Phase 5: Reduce MCP exposure

#### ICM

Register only these direct tools:

- `icm_memory_recall`
- `icm_memory_store`

Maintenance, memoir, transcript, feedback, and health operations remain available deliberately through the generic `mcp` gateway rather than as always-registered direct tools.

#### Serena

Register only:

- `initial_instructions`
- `check_onboarding_performed`
- `get_symbols_overview`
- `find_symbol`
- `find_referencing_symbols`

Exclude Serena editing and memory-management tools. Pi's built-in `edit` remains the mutation path.

`pi-loadout` controls model-visible tools, not MCP server lifecycle. Serena may still start for MCP discovery even when its tools are inactive. A custom lifecycle manager or separate Pi configuration is out of scope because it would reintroduce complexity.

### Phase 6: Tune loadouts collaboratively

Build exact snapshots from the cleaned post-removal tool inventory, not from stale names in the current `full` loadout.

Initial profile set:

- `lean`: global default; core file/shell tools, FFF, structured questions, generic MCP access, and ICM recall/store.
- `coding`: lean plus Serena navigation, Context7, session inspection, and coding/testing/review skills.
- `research`: lean plus SearXNG, Exa, deep research, and documentation/research skills.
- `browser`: lean plus Playwriter, Chrome DevTools, and browser-session skills.
- `ops`: lean plus relevant UniFi, Home Assistant, Hermes, and operational skills.

Checkpoint 6 is not an automatic bulk edit. Review one profile at a time, identify intentional overlap, discuss questionable tools/skills, approve its exact membership, then save and verify it before moving to the next profile.

Avoid routine mid-session profile switching because changing active tool definitions invalidates the provider prompt cache. Prefer selecting the appropriate profile at session start.

## Existing Work Preservation

The `~/.pi` main checkout currently has uncommitted changes in:

- `agent/mcp.json`
- `agent/models-store.json`

Implementation must:

1. Save bounded patches/backups before integration.
2. Carry the existing `mcp.json` changes into the Pi feature worktree before applying ICM/Serena changes.
3. Never stage, commit, restore, stash, or reset `models-store.json`; before and after integration, require the approved provider key set and equal `models` arrays while allowing only runtime `checkedAt` drift.
4. Verify the original `mcp.json` changes are represented in the committed result before cleaning or merging the original checkout.
5. Never overwrite unrelated live settings while synchronizing tracked templates.

## Error Handling and Rollback

- Use separate Worktrunk worktrees for chezmoi and Pi.
- Keep phases in separate Conventional Commits.
- Stop at each checkpoint if direct Pi model access, RTK rewriting, MCP registration, or loadout restoration fails.
- Keep bounded pre-change copies of mutable runtime JSON during integration; use the approved `models-store.json` backup for semantic assertions, not byte hashes.
- Require `agent/models-store.json` to remain the sole dirty Pi-main path and absent from every feature-branch diff; use explicit staging allowlists that cannot stage it.
- Run Pi smoke processes with a disposable `PI_CODING_AGENT_DIR` overlay so verification cannot refresh live runtime state.
- Treat missing/stale loadout names as cleanup findings; do not silently substitute unrelated tools.
- If applying chezmoi would remove a non-Headroom user file, stop and review the target diff.
- If a Headroom process remains after package removal, identify its owner before terminating it; do not kill unrelated Python or terminal processes.

## Verification

### Checkpoint 1: Headroom source retired

- No active Headroom source, package declaration, test, current documentation, provider, or feature-index entry remains.
- Historical changelog references remain and a new retirement entry exists.
- `openai-codex/gpt-5.6-sol` is available and selected by plain Pi.
- Chezmoi managed-file inspection confirms obsolete deployed Headroom files will be removed.

### Checkpoint 2: Runtime retired

- No Headroom command resolves.
- No Headroom processes or Herdr/tmux workspace remains.
- Ports 8787–8789 have no Headroom listeners.
- `~/.headroom-private` is absent.

### Checkpoint 3: RTK rewrite-only

- `/rtk verify` reports the RTK binary.
- `/rtk show` reports rewrite mode and disabled output compaction.
- A representative eligible command is rewritten.
- Tool output is not altered by Pi's post-result compaction pipeline.

### Checkpoint 4: MCP exposure reduced

- ICM exposes only recall/store directly.
- Serena exposes only five setup/navigation tools directly.
- The lean default disables Serena.
- Record direct tool count and estimated schema size before and after.

### Checkpoint 5: Profiles approved and verified

For each profile, separately:

1. Review its purpose and exact tool/skill list with Brendan.
2. Identify intentional overlap with other profiles.
3. Apply it in a fresh Pi session.
4. Confirm required tools are present and unrelated tool groups are absent.
5. Save only after approval.

### Repository validation

For Pi:

```bash
cd ~/.pi/agent
python3 scripts/validate-config-docs.py
fallow audit --changed-since main
```

Also run focused JSON, provider, RTK, MCP, and loadout checks. Any check that launches Pi must point `PI_CODING_AGENT_DIR` at a disposable copy of the agent directory, never the live runtime directory.

For chezmoi:

- run relevant surviving shell tests;
- run the targeted chezmoi test suite;
- inspect `chezmoi diff` and managed-file removals;
- scan for active Headroom references outside historical changelog records.

## Baseline Note

Before implementation, `tests/chezmoi/test-headroom-tmux-launcher.sh` failed identically in the isolated worktree and untouched `main`. Brendan approved proceeding because the failing test and feature are both retirement-scoped. Other focused Headroom tests passed.

## Out of Scope

- Replacing RTK with another optimizer.
- Adding custom context compaction.
- Adding a custom MCP server lifecycle manager.
- Rewriting historical changelog records.
- Consolidating ICM memory topics during this change.
- Removing Serena or ICM data stores.
- Optimizing unrelated Pi packages before post-cleanup profile review.
- Normalizing or rolling back runtime-only `models-store.json` `checkedAt` refreshes.
