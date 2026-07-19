# Headroom Herdr launcher design

## Goal

Make `hr-proxy-pi` create the existing four-service Headroom dashboard when invoked inside Herdr, while preserving the current tmux and foreground behavior outside Herdr.

## Scope

- Detect a Herdr-managed shell through `HERDR_ENV=1`.
- Prefer Herdr when both `HERDR_ENV` and `TMUX` are present.
- Create, reuse, focus, or rebuild a dedicated Herdr workspace labeled `headroom`.
- Reproduce the tmux dashboard topology and commands in four labeled panes.
- Keep Herdr orchestration limited to `hr-proxy-pi`; do not change `hr-proxy-claude` behavior.
- Preserve `hr-proxy-pi --help` as a non-mutating help path.
- Add focused stub-driven tests and user documentation.

## Non-goals

- Refactor the working tmux launcher into a generic multiplexer abstraction.
- Add Herdr behavior to `hr-proxy-claude`.
- Create multiple concurrent Headroom workspaces.
- Attach panes to proxy processes started outside the managed workspace.
- Add an explicit multiplexer-selection flag.

## Architecture

Add `dot_local/bin/executable_headroom-herdr` beside the existing `executable_headroom-tmux`. The new executable owns Herdr JSON parsing, workspace lifecycle, pane topology, command construction, and cleanup. The tmux launcher remains unchanged.

Update `hr-proxy-pi` in `dot_config/headroom/functions.zsh.tmpl` so its dispatch order is:

1. Delegate `-h`, `--help`, or `help` to the existing help path without creating a workspace.
2. If `HERDR_ENV=1`, require both the `herdr` CLI and the caller context variables supplied by Herdr, then invoke `headroom-herdr` through `hr-run-headroom-command`.
3. Otherwise call `hr-proxy-claude --openai-api-url https://openrouter.ai/api/v1` as today. That retains existing tmux detection and foreground fallback.

This keeps environment selection in the small alias layer and all Herdr control logic in a testable executable.

## Workspace lifecycle

The launcher reserves the exact workspace label `headroom`.

It checks the primary proxy, Codex proxy, and Codex shim health endpoints using the configured ports. It also lists Herdr workspaces and parses exact-label matches from the CLI's JSON output.

| Service state | Workspace state | Result |
| --- | --- | --- |
| all healthy | one exists | focus that workspace and exit successfully |
| any unhealthy | one or more exist | close matching stale workspaces, then create a clean workspace |
| all healthy | none exists | report that services are active externally and exit without starting duplicate listeners |
| any unhealthy | none exists | create a clean workspace |

The launcher treats `headroom` as a reserved label. Matching stale workspaces can therefore be closed during rebuild. It never closes non-matching workspaces.

A new workspace is created focused, with its cwd set to the directory from which `hr-proxy-pi` was invoked. The launcher reads the returned workspace ID, lists that workspace's initial pane, and uses returned JSON IDs for every later operation. It never constructs Herdr IDs or relies on sidebar ordering.

## Pane topology and commands

The initial pane becomes `proxy`. The launcher then creates this layout:

```text
+----------------------+----------------------+
|                      | stats                |
| proxy                +----------------------+
|                      | codex-proxy          |
|                      +----------------------+
|                      | codex-shim           |
+----------------------+----------------------+
```

Creation order mirrors the tmux launcher:

1. Rename the initial pane `proxy`.
2. Split `proxy` right to create `stats`.
3. Split `stats` down to create `codex-proxy`.
4. Split `codex-proxy` down to create `codex-shim`.
5. Rename every pane using the IDs returned by each split.
6. Submit one long-lived command to each pane with `herdr pane run`.

The pane commands source the installed Headroom alias file and run:

- `hr-proxy-claude --foreground --openai-api-url https://openrouter.ai/api/v1 ...caller arguments...`
- `hr-watch-stats`
- `hr-proxy-codex`
- `hr-codex-shim`

They retain the existing semantic terminal colors and finish with `exec zsh -l` when the service command exits. Caller arguments are shell-quoted before being embedded in the primary proxy command.

## Error handling

- Herdr dispatch requires `HERDR_ENV=1`, an available `herdr` executable, and the Herdr caller context variables. Missing requirements produce a concise non-zero error instead of silently selecting tmux or foreground mode.
- Malformed or incomplete JSON is a launcher error. Parsing validates that required workspace and pane IDs are non-empty.
- Workspace creation, pane splits, pane renames, and command submissions are checked individually.
- Once a new workspace is created, a failure trap closes only that newly created workspace. The trap is cleared after all panes and commands are configured successfully.
- Health checks treat missing `curl` or an unreachable endpoint as unhealthy and rebuild the reserved workspace.
- If services are already healthy without a managed workspace, the launcher does not attempt duplicate port binding and explains why no workspace was created.

## Testing

Add `tests/chezmoi/test-headroom-herdr-launcher.sh` with stub `herdr`, `curl`, and service commands. The test will assert:

- Herdr-first dispatch when `HERDR_ENV` and `TMUX` coexist.
- `--help` creates no workspace.
- Workspace creation uses the caller cwd and `headroom` label.
- Returned non-sequential workspace and pane IDs are propagated into later commands.
- The four labels, split directions, topology, service commands, semantic colors, and caller arguments are correct.
- Healthy services plus an existing workspace focus and reuse it.
- Unhealthy services plus an existing workspace close it before creating a replacement.
- Healthy externally managed services without a workspace do not create duplicate listeners.
- Setup failure closes only the workspace created by that invocation.

Extend `tests/chezmoi/test-headroom-layout.sh` to require the new managed executable and function dispatch. Keep `tests/chezmoi/test-headroom-tmux-launcher.sh` unchanged.

Update `docs/agentic-tooling.md` to describe Herdr detection, the dedicated workspace, reuse/rebuild behavior, and troubleshooting.

Verification will run the focused Headroom shell tests with pane-color override variables unset, relevant chezmoi validation, `git diff`, and `fallow audit --changed-since main`.

## Success criteria

- Running `hr-proxy-pi` inside Herdr creates and focuses one `headroom` workspace with the expected four-pane dashboard.
- Rerunning the command focuses a healthy workspace or replaces a stale one.
- Running the command outside Herdr preserves existing tmux and foreground behavior.
- `hr-proxy-claude` behavior is unchanged.
- Existing tmux tests and the new Herdr tests pass.
