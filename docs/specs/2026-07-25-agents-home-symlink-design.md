# Agents Home Symlink Design

## Goal

Make the portable `~/.agents` configuration part of the dotfiles repository without requiring `chezmoi re-add` after agents or the skills CLI modify it.

## Scope

This first iteration manages the complete `~/.agents` working directory through one symlink. It does not add synchronization commands, lifecycle scripts, Bitwarden-backed private skills, SOPS/age encryption, or automatic conflict handling.

The Pi and Claude configuration repositories continue to own their harness-specific configuration. They track only relative instruction-file symlinks; the dotfiles repository owns the shared instruction content. The current Pi `agent/AGENTS.md` is the authoritative seed for the shared file; the distinct current Claude `CLAUDE.md` content is backed up and replaced rather than merged.

## Layout

The canonical directory lives directly in the chezmoi source repository:

```text
<chezmoi-source>/agents/
├── AGENTS.md
├── .skill-lock.json
├── skills/
├── state/       # retained locally, ignored by Git
└── backups/     # retained locally, ignored by Git
```

The home-directory entry is a chezmoi-managed symlink whose target is rendered from the active source directory rather than hard-coded:

```text
~/.agents -> <chezmoi-source>/agents
```

The source `agents/` path is excluded from normal chezmoi target rendering. Chezmoi must not also create `~/agents`.

The harness repositories track relative links to the neutral instruction path:

```text
~/.pi/agent/AGENTS.md -> ../../.agents/AGENTS.md
~/.claude/CLAUDE.md   -> ../.agents/AGENTS.md
```

The existing chezmoi external filters for `.pi` and `.claude` must retain these two tracked links.

## Ownership

| Owner | Paths |
|---|---|
| Dotfiles Git | `agents/AGENTS.md`, `agents/.skill-lock.json`, `agents/skills/**`, and the `~/.agents` symlink declaration |
| Local runtime | `agents/state/**` and `agents/backups/**` |
| Pi config Git | `agent/AGENTS.md` symlink only |
| Claude config Git | `CLAUDE.md` symlink only |

The runtime directories remain physically inside the dotfiles checkout but are ignored by Git. They are not durable merely because they reside there; `git clean -fdx` can delete them.

## Edit and Update Behavior

Because `~/.agents` points to the source checkout, ordinary writes beneath it modify the dotfiles working tree directly. This includes edits through either harness instruction link and changes made by the skills CLI to `.skill-lock.json` or `skills/`.

Directory-level indirection is intentional. A CLI may atomically replace the lock file or individual skill files without replacing a file-level symlink. No `chezmoi re-add` step is required.

The expected workflow is:

1. An agent or CLI changes a portable file beneath `~/.agents`.
2. Git reports the corresponding change beneath `<chezmoi-source>/agents`.
3. The user reviews and commits that change normally.

A dirty dotfiles checkout can prevent or complicate `chezmoi update`; changes should be reviewed and committed or stashed before updating the source repository.

## Failure Modes

### Top-level link replacement

A tool that removes and recreates `~/.agents` can replace the top-level link with a real directory. Chezmoi will then report drift. Recovery is manual in this iteration: preserve the replacement directory, compare it with the canonical source directory, and restore the symlink only after reconciling changes.

### Ignored runtime deletion

`git clean -fdx`, checkout removal, or loss of the source worktree can delete ignored `state/` and `backups/` content. Neither directory is treated as a backup boundary. Important data requires an independent backup.

### External filtering

If the `.pi` or `.claude` external excludes its tracked Markdown symlink, a fresh chezmoi application will omit that link. External filtering must be verified on a disposable target before migration is considered complete.

### Partial multi-repository rollout

The dotfiles, Pi, and Claude repository changes cannot become visible atomically. Roll out the dotfiles canonical directory and `~/.agents` link first, then the harness symlinks. During migration, retain backups of all replaced instruction files.

## Migration

Implementation will occur in isolated worktrees for each affected repository.

1. Back up the current `~/.agents`, `~/.pi/agent/AGENTS.md`, and `~/.claude/CLAUDE.md` without deleting their originals.
2. Add the canonical `agents/` directory to the dotfiles source, seeding `AGENTS.md` from the current Pi file and preserving current lock data, skills, state, and backups. Do not merge the current Claude instruction content.
3. Ignore only `agents/state/` and `agents/backups/` in Git.
4. Exclude the source `agents/` path from ordinary chezmoi target rendering.
5. Add the templated chezmoi declaration for the top-level `~/.agents` link.
6. Adjust external filtering as narrowly as necessary to retain the harness links.
7. Apply the dotfiles change and verify the live `~/.agents` link before changing either harness repository.
8. Replace each harness instruction file with its repository-tracked relative symlink.
9. Commit and publish each repository independently.

No migration step may silently replace an unexpected regular file.

## Verification

Use a disposable HOME or equivalent isolated target to verify:

- chezmoi creates `~/.agents` as a link to the active source repository;
- chezmoi does not create `~/agents`;
- `state/` and `backups/` do not appear in the dotfiles Git index;
- the skills CLI can read and update `.skill-lock.json` and files beneath `skills/`;
- edits through the neutral, Pi, and Claude instruction paths reach the same canonical file;
- `.pi` and `.claude` external installation retains their tracked links;
- a subsequent `chezmoi apply` does not overwrite canonical content;
- repository status shows portable edits immediately and ignores runtime changes.

## Deferred Work

The following remain explicitly deferred:

- `cz-agents-sync` commands or hooks;
- private skill distribution through Bitwarden;
- SOPS/age-managed private skill content;
- automatic repair of replaced links;
- automatic commit, stash, or conflict handling.
