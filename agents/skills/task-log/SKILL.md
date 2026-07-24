---
name: task-log
description: Use when tracking granular, multi-session task state that must survive
  context compaction and read identically from any harness (Claude, Pi). Maintains an
  append-friendly tasks.jsonl ledger in the repo — distinct from roadmap milestones and
  from ICM semantic recall. Use to add, start, update, finish, or list tasks, and to
  derive roadmap/handoff summaries from them.
---

# Task Log

## Overview

A harness-neutral task ledger that lives **in the repo as a plain file**, so Claude and
Pi read and write the same state with no MCP, no plugin, and no node CLI dependency.

It occupies one specific layer. Keep these straight:

| Layer | System of record | Shape |
|---|---|---|
| **Granular task state** | `tasks.jsonl` (this skill) | enumerable, diffable, git-versioned, non-decaying |
| **Milestones / phases** | `roadmap.md` | human-curated; *derived* from tasks, never auto-rewritten |
| **Semantic recall ("why")** | ICM (`icm_memory_*`) | fuzzy, importance-decayed, embedding-retrieved |
| **In-flight ticks** | the harness todo facility | ephemeral; dies on compaction — do not rely on it for durable state |

If you can answer the question by *enumerating exactly*, it belongs in `tasks.jsonl`. If
it's a *fuzzy "why did we do X weeks ago"*, it belongs in ICM. Don't double-write.

## File location

Default: `docs/tasks.jsonl` (this project keeps tracking under `docs/`). If the repo has
no `docs/`, use `tasks.jsonl` at the repo root. Honor an explicit per-project override if
the project's agent-instructions file names a different path.

One JSON object per line. Newline-terminated. No comments, no blank lines, no trailing
commas — it must stay valid JSONL.

## Schema

```json
{
  "id":      "a1b2c3",          // opaque, unique, never reused (e.g. `openssl rand -hex 3`)
  "title":   "one-line summary",
  "status":  "open",            // open | in_progress | blocked | done | dropped
  "branch":  "feat/foo",        // git branch / worktree that owns this task
  "context": "background, requirements, approach — the why",
  "result":  "",               // TERSE: what changed, where, outcome. ≤ ~1 line. See ICM rule.
  "phase":   "Phase 5",        // optional — links to a roadmap phase
  "parent":  null,              // optional — parent task id for grouping subtasks
  "depends_on": [],             // optional — task ids that must finish first
  "blocked_by": [],             // optional — task ids or external refs currently blocking this task
  "tags":    [],                // optional
  "refs":    [],                // optional — PR/commit/file pointers, e.g. ["#128","src/x.astro"]
  "icm":     false,             // true once rationale promoted to ICM (prevents double-promote)
  "created": "2026-06-25T00:00:00Z",
  "updated": "2026-06-25T00:00:00Z"
}
```

## Optional patterns (dex-inspired, still plain JSONL)

Keep these fields absent, `null`, or `[]` until they help. Do not add a second task
system, install dex, or make any external tool the source of truth.

| Pattern | Field(s) | Rule |
|---|---|---|
| **Blockers / dependencies** | `depends_on`, `blocked_by` | Use task ids for internal links; external refs like `"PR #128"` are okay in `blocked_by`. Keep the human-readable blocker in `result` while status is `blocked`. |
| **Parent-child grouping** | `parent` | Children point at one parent id. Do **not** maintain a `children` list; derive it with `jq` to avoid drift. |
| **Archive views** | `status`, `updated` | Completed/dropped tasks stay in JSONL. Archive by filtering, not moving lines, unless the user explicitly asks for a separate archive file. |
| **Status summaries** | `status`, `phase`, `branch`, `parent` | Summaries are generated views. They may inform roadmap or handoff text, but do not replace the ledger. |

## The ICM scoping rule (load-bearing)

`tasks.jsonl` is the ledger; ICM is not. To keep them from drifting:

1. **`result` stays terse** — what changed, where, the outcome. One line. It is a pointer,
   not an essay.
2. **Promote to ICM only rationale you'll later want to recall *out of context*** — a
   non-obvious decision, a gotcha, a discovered preference. Use `icm_memory_store` with the
   project's topic convention (`decisions-<project>`, `errors-resolved`, `preferences`).
3. **Mark `icm: true`** on the task once promoted, so neither harness promotes it twice.
4. **Never mirror the task list into ICM.** Enumeration is the ledger's job; ICM recall is
   approximate and decays — wrong shape for "what's open".

## Operations

These are plain-file actions — express them with whatever read/write/shell tools the
current harness has. New tasks are **appends** (merge-clean across worktrees). Status/result
changes **edit that task's own line**; because each task carries its owning `branch`, parallel
worktrees touch different lines and stay merge-clean. Only edit a task whose `branch` you own.

- **add** — append one line, `status: "open"`, fresh `id`, `created`/`updated` = now.
- **start** — set `status: "in_progress"`, bump `updated`.
- **update** — revise `result` (keep terse) and/or `status`; bump `updated`. Apply the ICM rule.
- **finish** — `status: "done"`, final terse `result`, bump `updated`.
- **block / drop** — `status: "blocked"` (note blocker in `result`; add `blocked_by`
  when a stable id/ref exists) or `"dropped"`.
- **group** — set `parent` on child tasks; leave the parent line terse and derive children.
- **link dependency** — add prerequisite ids to `depends_on`; don't duplicate dependency prose
  unless it affects the immediate `result`.
- **list** — read the file, fold to current state, filter (open/in_progress, by `branch`,
  `phase`, or `parent`). For long files, tail the last N lines.
- **derive** — summarize task state into a roadmap-status suggestion, status report, or a
  handoff digest.

### Cross-harness recipes (work in any shell — Claude or Pi)

```bash
# add (generate id, append):
ID=$(openssl rand -hex 3)
printf '%s\n' "$(jq -nc --arg id "$ID" --arg t "TITLE" --arg b "$(git branch --show-current)" \
  --arg now "$(date -u +%FT%TZ)" \
  '{id:$id,title:$t,status:"open",branch:$b,context:"",result:"",phase:null,tags:[],refs:[],icm:false,created:$now,updated:$now}')' \
  >> docs/tasks.jsonl

# list open + in_progress for current branch:
jq -c "select(.branch==\"$(git branch --show-current)\" and (.status==\"open\" or .status==\"in_progress\"))" docs/tasks.jsonl

# update status/result for an id (rewrites in place, merge-safe within owning branch):
jq -c --arg id "ID" --arg now "$(date -u +%FT%TZ)" \
  'if .id==$id then .status="done" | .result="RESULT" | .updated=$now else . end' \
  docs/tasks.jsonl > docs/tasks.jsonl.tmp && mv docs/tasks.jsonl.tmp docs/tasks.jsonl

# block on another task/ref:
jq -c --arg id "ID" --arg blocker "BLOCKER-ID-OR-REF" --arg now "$(date -u +%FT%TZ)" \
  'if .id==$id then .status="blocked" | .blocked_by=((.blocked_by // []) + [$blocker] | unique) | .result="Blocked by \($blocker)" | .updated=$now else . end' \
  docs/tasks.jsonl > docs/tasks.jsonl.tmp && mv docs/tasks.jsonl.tmp docs/tasks.jsonl

# add dependency or parent grouping:
jq -c --arg id "ID" --arg dep "DEP-ID" --arg parent "PARENT-ID" --arg now "$(date -u +%FT%TZ)" \
  'if .id==$id then .depends_on=((.depends_on // []) + [$dep] | unique) | .parent=$parent | .updated=$now else . end' \
  docs/tasks.jsonl > docs/tasks.jsonl.tmp && mv docs/tasks.jsonl.tmp docs/tasks.jsonl
```

A harness with structured file tools (e.g. Claude's Edit) may edit the target line directly
instead of the jq rewrite — same result. The shell recipes exist so a non-MCP agent (Pi,
plain CLI) gets identical behavior.

### Derivation recipes

These are read-only views. Paste the output into a roadmap proposal, handoff, or status note;
do not overwrite `roadmap.md` or invent another source of truth.

```bash
# archive / status summary by phase and status:
jq -rs 'group_by(.phase // "unphased")[] | {phase: (.[0].phase // "unphased"), counts: (group_by(.status) | map({(.[0].status): length}) | add)}' docs/tasks.jsonl

# blocked/dependency view:
jq -c 'select((.blocked_by // [] | length) > 0 or (.depends_on // [] | length) > 0) | {id,title,status,depends_on,blocked_by,result}' docs/tasks.jsonl

# parent-child view for one parent:
jq -c --arg parent "PARENT-ID" 'select(.id==$parent or .parent==$parent) | {id,parent,title,status,result}' docs/tasks.jsonl

# derive-from-plan: convert checked markdown bullets into draft task objects for review:
grep -E '^[-*] \[[ xX]\] ' docs/plan.md | sed -E 's/^[-*] \[[ xX]\] //' | \
  jq -R --arg b "$(git branch --show-current)" --arg now "$(date -u +%FT%TZ)" \
  '{id:"REPLACE",title:.,status:"open",branch:$b,context:"Derived from docs/plan.md",result:"",phase:null,parent:null,depends_on:[],blocked_by:[],tags:[],refs:["docs/plan.md"],icm:false,created:$now,updated:$now}'

# handoff-summary: compact active work for the current branch:
jq -rs --arg b "$(git branch --show-current)" '
  map(select(.branch==$b and (.status=="open" or .status=="in_progress" or .status=="blocked")))
  | {branch:$b, active: map({id,title,status,parent,depends_on,blocked_by,result,refs})}
' docs/tasks.jsonl
```

## Relationship to roadmap.md — derive, never overwrite

`roadmap.md` is human-curated (this project's rule). Do **not** rewrite it from tasks. When a
cluster of tasks under a `phase` reaches `done`, *suggest* the roadmap status change and let the
user confirm — this matches the project's existing "auto-suggest phase transition" convention.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "I'll just track this in the todo list" | Todos die on compaction. Durable state goes in `tasks.jsonl`. |
| "I'll paste the full rationale into `result`" | `result` is terse. Rich "why" goes to ICM, then `icm: true`. |
| "I'll store the task list in ICM so Pi can see it" | ICM is fuzzy and decays. Both harnesses already read `tasks.jsonl` directly. |
| "I'll edit another branch's task line" | You'll cause merge conflicts. Edit only tasks whose `branch` you own. |
| "I'll rewrite roadmap.md to match" | Roadmap is human-curated. Suggest, don't overwrite. |

## When NOT to use

- For one-off, within-session ticks that won't outlive the session — the harness todo facility
  is fine.
- As a memory system — that's ICM. This is a ledger.
