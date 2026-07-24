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
