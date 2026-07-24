# Audit Rubric

## Evidence

Use current official harness documentation, installed-version documentation, or direct runtime output for version-sensitive claims. Record the source and observation date. Model memory and unsupported inference are not evidence. Mark inaccessible or unresolved checks as **unverified**, never passing.

Quote only the smallest excerpt needed to locate a finding. Do not inspect credentials, sessions, caches, OAuth state, authentication files, or unrelated logs.

## Dimensions

- **Correctness:** obsolete paths, commands, models, tools, APIs, or behavior claims.
- **Consistency:** contradictory rules, duplicated instructions, and unclear precedence.
- **Leanness:** repetition, oversized examples, commentary, and rules enforced elsewhere.
- **Skill offloading:** reusable, conditional, multi-step workflows that need not be always loaded.
- **Harness separation:** Claude- or Pi-specific direction placed in shared instructions.
- **Maintenance:** broken instruction links, risky replacement prompts, and ambiguous ownership.

## Confidence

- **Confirmed stale:** current official documentation or runtime evidence contradicts the instruction.
- **Likely stale:** credible indicators exist, but available evidence is inconclusive.
- **Optimization:** the content may be valid but is duplicated, expensive, or misplaced.

Keep confidence separate from severity. An unverified claim cannot be Confirmed stale.

## Disposition

- **Keep:** concise, current guidance needed in most sessions.
- **Shorten:** preserve intent while removing repetition or low-value examples.
- **Move to a skill:** reusable or conditional workflow with a clear trigger and meaningful procedure.
- **Remove:** obsolete, contradictory, or already enforced content with no remaining purpose.

Do not move ordinary repository facts, one-line commands, or universal safety boundaries into skills merely to reduce line count. Do not remove behavior or safety intent without identifying where it remains enforced.
