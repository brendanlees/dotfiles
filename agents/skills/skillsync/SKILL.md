---
name: skillsync
description: Use when configuring, fetching, listing, or pushing Agent Skills across multiple coding tools with the skillsync CLI.
---

# Managing Skills with skillsync

## Overview

`skillsync` keeps agent skills in one canonical, manifest-backed source of truth
and realizes them into the local harnesses you use. The project manifest is
`skillsync.yaml`; canonical skills live under `skills/<name>/SKILL.md`; generated
store/index outputs are written by the CLI.

**Core principle:** inspect first, validate, then apply only when the generated
store and harness-facing state should be updated.

```sh
skillsync store status        # read-only: drift, active sets, validation summary
skillsync store plan          # read-only: preview composed skills/index
skillsync store validate      # read-only: frontmatter, conflicts, wording, store drift
skillsync store apply         # mutating: validate, then sync the shared store/index
```

If an older checkout or stale package reports that `apply` requires explicit
paths, use the repo-standard troubleshooting form:

```sh
skillsync store apply \
  --store ~/.agents/skills \
  --index docs/skills-index.json \
  --store-manifest docs/store-manifest.json \
  --backups ~/.agents/backups
```

`apply` writes generated outputs. Do not hand-edit generated files such as
`docs/skills-index.json`, `docs/store-manifest.json`, or the shared store.

## The CLI

Check the installed command surface first:

```sh
skillsync --help
```

| Command | Mutates? | What it does |
|---|---:|---|
| `skillsync init` | local manifest only | Create a starter `skillsync.yaml` manifest. |
| `skillsync store status` | no | Show drift, active sets, validation summary, and next-step guidance. Supports `--json`. |
| `skillsync store plan` | no | Preview the skills/index that would be composed without writing anything. Supports `--json`. |
| `skillsync store validate` | no | Check skills for frontmatter, conflicts, non-neutral wording, and store drift. |
| `skillsync store apply` | yes | Validate, then compose canonical skills into the shared store and generated index. |
| `skillsync store conflicts` | no | Report source conflicts, orphaned overlays, drops, and store drift. Supports `--json`. |
| `skillsync store prune` | only with `--apply` | Remove orphaned store dirs and dangling symlinks owned by skillsync; dry-run by default. |
| `skillsync skill list` / `skillsync skill ls` | no | List local skills grouped by category. Supports `--json`. |
| `skillsync skill find [query]` | no | Search local skills; `--remote` searches installable candidates. Supports `--json`. |
| `skillsync skill add <source>` | yes | Vendor skills from a git source and register them. Use `--list` to preview and `--yes`/`-y` to skip confirmation; non-TTY writes require `--yes`. |
| `skillsync skill vendor <source>` | only with `--apply` | Pull skills from an upstream repo and adapt them to the manifest. |
| `skillsync skill allow <name>` | yes | Allowlist acknowledged non-neutral wording for a skill. |
| `skillsync set list` | no | List defined skill sets and active set state. Supports JSON output. |
| `skillsync set use <set>` | yes | Switch the active skill set for one or more harnesses. |
| `skillsync set ...` | yes | Mutate the manifest's `sets:` block. Prefer subcommands over manual YAML edits. |
| `skillsync harness refs` | no | List declared external skill references and install state. Supports JSON output. |
| `skillsync harness publish hermes --apply` | yes | Publish allowlisted skills to the sandboxed Hermes agent repo. |
| `skillsync completion bash\|zsh\|fish` | no | Print shell completion scripts for the canonical command tree. |

## Manifest model

`skillsync.yaml` is the adoption contract and single source of truth. It records:

- shared paths such as `paths.store` and `paths.state`,
- harnesses such as Claude, Pi, and optional publish targets,
- external sources and vendored skill selections,
- active skill sets,
- category keywords and explicit category overrides for discovery.

A minimal initialized manifest is `version: 2`, omits the old `skills:` inventory
map, and starts with an `all` set so a new user can inspect status before doing
set management. Existing v1 manifests still load; migrate with
`skillsync project migrate-manifest --to v2` and add `--apply` only after
reviewing the dry-run output.

## PATH and completions

In a source checkout, use `scripts/skillsync` directly or symlink it into a PATH
directory:

```sh
cd /path/to/skillsync
mkdir -p ~/.local/bin
ln -sf "$PWD/scripts/skillsync" ~/.local/bin/skillsync
skillsync --help
```

If needed, add `export PATH="$HOME/.local/bin:$PATH"` to the user's shell rc.
For packed local dogfooding, use `./node_modules/.bin/skillsync` or add that
project-local `.bin` directory to the current shell's PATH.

Shell completions are generated from the live command tree:

```sh
skillsync completion bash > ~/.local/share/bash-completion/completions/skillsync
skillsync completion zsh > ~/.zsh/completions/_skillsync
skillsync completion fish > ~/.config/fish/completions/skillsync.fish
```

## Typical workflow

```sh
skillsync store status
skillsync store plan
skillsync store validate
skillsync store apply
# If an older checkout requires explicit paths, use the troubleshooting form above.
```

For discovery and installation:

```sh
skillsync skill find auth
skillsync skill find logging --remote
skillsync skill add owner/repo --list
skillsync skill add owner/repo --skill skill-name --yes
skillsync store status
skillsync store apply
```

For active skill sets:

```sh
skillsync set list
skillsync set use focused
skillsync set list --json
```

For cleanup:

```sh
skillsync store conflicts
skillsync store prune          # dry-run
skillsync store prune --apply  # remove only after reviewing the dry-run
```

## Add or edit skills in this repo

1. Edit the canonical skill under `skills/<name>/SKILL.md`.
2. For local canonical skills, let v2 derive inventory from `SKILL.md` frontmatter; use `skillsync skill add` / `skillsync skill vendor` for upstream sources.
3. Run `skillsync store status` to inspect drift.
4. Run `skillsync store validate` and fix any reported issues.
5. Run `skillsync store apply` only after confirming generated outputs should change.
6. Do not hand-edit generated docs or store copies; regenerate them with
   `skillsync store apply`.

## Rules

- Prefer `store status` and `store validate` before any mutating command.
- Prefer `store apply`; `sync` and legacy top-level verbs are no longer part of
  the command surface.
- Prefer `skill add`, `set`, and other CLI commands over manual manifest edits when the
  command exists and preserves intent.
- Use `--format json` (or legacy `--json`) on structured commands when scripting or instructing an agent.
- Treat `store prune --apply`, `harness publish hermes --apply`, and any command touching
  harness state as intentional writes.
- Keep canonical skills harness-neutral; put harness-specific wording in
  overlays when needed.

## Where things live

| Path | Purpose |
|---|---|
| `skillsync.yaml` | Single source of truth for paths, harnesses, sources, sets, categories, and migration-era v1 compatibility. |
| `skills/<name>/SKILL.md` | Canonical skills you edit. |
| `overlays/<harness>/<name>/overlay.yaml` | Harness-specific frontmatter/body changes. |
| `upstreams/<source>/<skill>/transform.yaml` | Neutralization transforms for vendored skills. |
| `docs/skills-index.json` | Generated skill index; do not hand-edit. |
| `docs/store-manifest.json` | Generated ownership manifest; do not hand-edit. |
| `~/.agents/skills` | Default shared generated skill store. |
| `~/.agents/state/active.json` | Default active-set state. |
