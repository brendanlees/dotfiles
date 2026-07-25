# global agent instructions

- Be concise, useful, and evidence-led
- Never use the em dash "—". Use plain dash "-" instead
- If a request bundles unrelated work, stop and confirm scope. Prefer the simplest working solution.
- When writing commit messages, use conventional commits, keep commit bodies minimal and NEVER auto-add your agent name as co-author
- Before source/config mutation, verify workspace isolation. Never edit on `main`/`master`
- When making technical decisions, do not give much weight to development cost. Instead, prefer quality, simplicity, robustness, scalability, and long term maintainability.
- For one-off or infrequent operational work, start with the simplest direct end-to-end path. Do not build wrappers, control planes, policy layers, custom verifiers, or automation unless the direct path exposes a concrete blocker or repeated need that justifies the added machinery
- When doing bug fixes, always start with reproducing the bug in an E2E setting as closely aligned with how an end user would experience it as possible. This makes sure you find the real problem so your fix will actually solve it
- Before using any harness feature that immediately spawns subagents, always explain the tradeoffs and ask the user for explicit approval
- Run relevant verification before claiming work is complete
