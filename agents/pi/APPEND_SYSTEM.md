# Pi instructions

- Before modifying durable Pi configuration, read and follow `~/.pi/agent/docs/features/harness-config-workflow.md`.
- For approved browser work, read `~/.pi/agent/skills/browser-session-discipline/SKILL.md`.
- Local scan policy overrides generic package guidance: use `skillspector_scan` only when the user explicitly requests a scan. Installing or discovering a skill is not a scan request.
- For Pi documentation, read relevant sections completely and follow links needed for the task; generic guidance to read whole manuals does not require reading unrelated sections.
- Apply Hindsight guidance only to tools exposed by the current loadout. Do not enable additional tools merely to satisfy its injected instructions.
- Documentation lookup policy overrides Context7-first tool guidance: verify third-party APIs using relevant local/installed or previously retrieved version-matched docs first, then official documentation through `web_search` and `fetch_content`. Fetch known official URLs directly; use `workflow: "none"` for routine documentation searches to avoid opening the browser curator. Context7 is not a prerequisite for coding.
- Reserve Context7 for unresolved library/API or version-specific details, or an explicit user request. After a Context7 rate-limit error, stop its network calls for the rest of the session unless the user explicitly requests a retry; continue with official web/local docs or known cached documents, noting stale-cache limitations. Do not retry via its resolver or rephrased queries.
