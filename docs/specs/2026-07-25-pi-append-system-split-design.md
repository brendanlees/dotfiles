# Pi Append-System Instruction Split Design

## Goal

Keep `~/.agents/AGENTS.md` harness-neutral while preserving Pi-specific operational policy in Pi's supported global `APPEND_SYSTEM.md` system-prompt extension.

## Evidence

Installed Pi 0.81.1 documents these distinct inputs:

- `~/.pi/agent/AGENTS.md` is a global context file.
- `~/.pi/agent/APPEND_SYSTEM.md` appends to Pi's default system prompt without replacing it.
- `/reload` reloads context and system-prompt resource files.

The split therefore changes both ownership and prompt level: shared defaults remain context guidance, while Pi-only rules become Pi system-prompt additions.

## Layout and Ownership

Dotfiles owns both canonical instruction files:

```text
<chezmoi-source>/agents/
├── AGENTS.md
└── pi/
    └── APPEND_SYSTEM.md
```

The existing neutral and new Pi links are:

```text
~/.pi/agent/AGENTS.md        -> ../../.agents/AGENTS.md
~/.pi/agent/APPEND_SYSTEM.md -> ../../.agents/pi/APPEND_SYSTEM.md
~/.claude/CLAUDE.md          -> ../.agents/AGENTS.md
```

The Pi repository tracks both Pi-side relative links. The Claude repository remains unchanged. Because `~/.agents` points to the dotfiles source checkout, edits through either Pi link modify dotfiles content directly.

## Shared Instructions

`agents/AGENTS.md` retains only harness-neutral workflow policy:

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

No Pi tool names, Pi paths, Pi config obligations, browser skill routing, model selection, handoff commands, RTK behavior, or Pi orchestration policy remain in the shared file.

## Pi Append Instructions

`agents/pi/APPEND_SYSTEM.md` begins with a concise statement that it supplements the shared context for Pi. It preserves the removed policy under explicitly scoped headings:

- `Pi Tool Routing`: Serena, FFF, bounded reads and shell use, web/browser capability routing, and explicit-only `pi-orchestration` delegation.
- `Pi Safety Additions`: browser-session ownership and `browser-session-discipline` routing.
- `Pi Config Changes`: durable configuration, documentation updates, harness-config workflow, Pi/Claude boundaries, validation, and runtime-state caution.
- `Pi Defaults`: direct model selection, handoff commands, and RTK behavior.

The shared Worktrunk, general verification, and Conventional Commit bullets are not duplicated in the Pi append file.

## Prompt Composition

A normal global Pi session receives:

1. Pi's built-in default system prompt.
2. The global Pi `APPEND_SYSTEM.md` content.
3. The shared global `AGENTS.md` context.
4. Applicable parent and project context files.

Claude continues to receive only the shared neutral file through its existing `CLAUDE.md` link. It does not load the Pi append file.

## Rollout

The repositories cannot expose the new file atomically. Rollout order is strict:

1. Add and merge `agents/pi/APPEND_SYSTEM.md` in dotfiles.
2. Confirm the live `~/.agents/pi/APPEND_SYSTEM.md` target resolves.
3. Add and merge the Pi-tracked `agent/APPEND_SYSTEM.md` symlink.
4. Reload or restart Pi and verify the resource is active.

This order prevents a dangling Pi system-prompt link. The unrelated dirty `~/.pi/agent/npm/package.json` must remain untouched throughout.

## Documentation

The Pi change is durable configuration. Update:

- `agent/docs/features/pi-agent-instructions.md` to describe the two-layer shared-context/Pi-system architecture;
- `agent/docs/index.json` metadata;
- `agent/docs/changelog.md`;
- verification and revert instructions for both tracked links.

Dotfiles documentation should identify `agents/pi/APPEND_SYSTEM.md` as Pi-specific source-owned content.

## Verification

Automated and static checks must establish:

- `agents/AGENTS.md` exactly contains the approved neutral sections and bullets;
- removed Pi policy markers remain in `agents/pi/APPEND_SYSTEM.md`;
- the neutral file contains no Pi-specific routing, config, browser, model, handoff, RTK, or orchestration rules;
- `~/.pi/agent/APPEND_SYSTEM.md` has Git mode `120000` and target `../../.agents/pi/APPEND_SYSTEM.md`;
- both Pi links resolve to regular canonical files;
- Claude's link still resolves only to shared `AGENTS.md`;
- Pi's config-doc validator passes;
- Fallow reports no findings in changed files;
- a fresh Pi process or `/reload` uses the appended system prompt.

Verification must not make a provider request merely to inspect resource loading. Prefer startup/resource evidence; if deterministic non-provider evidence is unavailable, perform a person-observed `/reload` check.

## Failure and Revert

- If the append link is dangling, do not start or reload Pi until dotfiles provides the target; restore the previous regular/shared instruction state if necessary.
- If Pi fails to load the append resource, keep the shared neutral file intact and remove only the new Pi append link while investigating.
- Full revert moves the Pi-specific rules back into `agents/AGENTS.md`, removes the Pi append canonical file and tracked symlink, and updates all Pi feature documentation.
- Existing unrelated Pi working-tree changes must never be stashed, restored, cleaned, or committed as part of this work.

## Deferred Work

This change does not introduce per-harness files for Claude or other agents, alter skills, add synchronization scripts, change models, or revise the substance of existing policy beyond the minimum wording needed to scope it accurately.
