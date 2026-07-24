---
name: system-prompt-maintainer
description: Audit and maintain Claude or Pi system prompts and repository instruction files. Use whenever a user asks to review AGENTS.md, CLAUDE.md, SYSTEM.md, APPEND_SYSTEM.md, stale agent instructions, prompt bloat, harness best practices, instruction deduplication, or moving always-loaded guidance into skills.
---

# System Prompt Maintainer

Audit configuration instructions against current evidence while preserving intent.

## Select scope

Determine whether the request targets project files, global harness files, or both. Detect Claude and Pi from the request and local configuration. Load only the matching adapter:

- Claude: `references/claude.md`
- Pi: `references/pi.md`
- Audit categories and confidence: `references/audit-rubric.md`

## Workflow

1. Start read-only. State the target and excluded sensitive/runtime paths.
2. Run `python3 scripts/inspect_prompt_config.py --root <project-root>` for deterministic facts. The inspector is bounded and non-recursive; its warnings are findings, not command failures, and do not establish semantic staleness.
3. Read only the discovered instruction files and the minimum excerpts needed.
4. Verify version-sensitive claims with current official documentation or direct runtime evidence. Model memory is not evidence.
5. Classify findings as Confirmed stale, Likely stale, or Optimization.
6. For each instruction, recommend keep, shorten, move to a skill, or remove. Move to a skill only when guidance is reusable, conditional, or a multi-step workflow with a clear trigger.
7. Report before changing anything. Require explicit approval for each project or global mutation scope.
8. After approval, use an isolated worktree for source-controlled edits, preserve unique content, show a focused diff, and run relevant validation.

## Report

### Executive summary
### Scope and evidence
### Findings
### Prompt disposition
### Maintenance
### Proposed changes
### Verification

Include severity, confidence, path and bounded location, evidence source, and recommended action. Mark inaccessible or unresolved checks unverified; never call them passing.
