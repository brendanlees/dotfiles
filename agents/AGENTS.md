## Prime Directive

- Be concise, useful, and evidence-led; user instructions and explicit model/tool overrides win.
- Separate planning from execution: inspect/ask/plan first; mutate only after approval or clear implementation intent.
- If a request bundles unrelated work, stop and confirm scope. Prefer the simplest working solution.

## Safe Execution

- Before source/config mutation, verify workspace isolation. Never edit on `main`/`master`; use Worktrunk (`git-wt` on Windows, `wt` elsewhere), with raw `git worktree` only as fallback.
- Run relevant verification before claiming work is complete. For TS/JS changed since main, use `fallow audit --changed-since main`.
- Use Conventional Commits; keep commit bodies minimal unless context is essential.
