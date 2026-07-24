# Claude Adapter

## Shared instruction source

Treat `AGENTS.md` as the canonical shared repository instruction file and require `CLAUDE.md` to be a symlink to `AGENTS.md`.

Classify the observed `CLAUDE.md` state as:

- correct symlink;
- missing;
- regular-file copy;
- broken symlink;
- symlink to the wrong target.

Before proposing a relink, compare a regular file or wrong target with `AGENTS.md`. Preserve and reconcile any unique content so a maintenance repair cannot discard instructions.

## Audit guidance

Keep shared repository conventions in `AGENTS.md`. Identify Claude-only material separately rather than duplicating the full shared file. Verify Claude-specific paths, features, and command claims against current official documentation or direct runtime evidence.

Begin read-only. Report the exact link target and proposed repair, then require explicit approval before replacing, unlinking, or creating `CLAUDE.md`.
