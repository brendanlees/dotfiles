# Pi Adapter

## Official system prompt files

Pi replaces the default system prompt with:

- `.pi/SYSTEM.md` for a project;
- `~/.pi/agent/SYSTEM.md` globally.

Pi appends to the default prompt without replacing it with:

- `.pi/APPEND_SYSTEM.md` for a project;
- `~/.pi/agent/APPEND_SYSTEM.md` globally.

Prefer `APPEND_SYSTEM.md` for genuine Pi-only system-level overrides because it preserves Pi's default prompt. Recommend `SYSTEM.md` only when full replacement is deliberate and its maintenance cost is accepted.

## Trust and scope

Project `.pi/SYSTEM.md` and `.pi/APPEND_SYSTEM.md` are subject to Pi project trust. `AGENTS.md` and `CLAUDE.md` context files load independently of project trust unless context loading is disabled.

Keep shared project conventions in `AGENTS.md`. Use project `.pi/APPEND_SYSTEM.md` for repository-specific Pi system direction and global `~/.pi/agent/APPEND_SYSTEM.md` only for Pi direction intended across projects. Request separate approval for project and global changes.

Verify these claims against the installed Pi documentation when auditing another version. Never create or convert a replacement prompt solely because an append file is absent.
