# coding preferences

- Keep things simple. Channel "yagni" energy unless told otherwise.
- Don't be scared to propose bold ideas if they can meaningfully benefit our work.
- Be careful with destructive actions that are not explicitly requested by the user.
- Tests are good, but endless smoke tests, regression tests for feature deletions etc are much less good. Tests should be focussed, not slop.
- Comments are a great way to clarify functionality in how code is used. Don't comment every line, but feel free to describe how things are used concisely. Otherwise, 'code as documentation' is preferred.
- Keep comments up-to-date when making changes, it's important to keep things in sync.

# global agent instructions

- Be concise, useful, and evidence-led
- Never use the em dash "—". Use plain dash "-" instead
- If a request bundles unrelated work, stop and confirm scope. Prefer the simplest working solution.
- When writing commit messages, use conventional commits, keep commit bodies minimal and NEVER auto-add your agent name as co-author
- Before source/config mutation, verify workspace isolation. Never edit on `main`/`master`
- When making technical decisions, do not give much weight to development cost. Instead, prefer quality, simplicity, robustness, scalability, and long term maintainability.
- For one-off or infrequent operational work, start with the simplest direct end-to-end path. Do not build wrappers, control planes, policy layers, custom verifiers, or automation unless the direct path exposes a concrete blocker or repeated need that justifies the added machinery
- Before using any harness feature that immediately spawns subagents, always explain the tradeoffs and ask the user for explicit approval
- Run relevant verification before claiming work is complete
