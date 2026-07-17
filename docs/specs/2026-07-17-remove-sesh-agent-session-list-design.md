# Remove Agent Session Listing from sesh

## Goal

Remove the agent-session list feature and every agent-specific path from sesh pickers on all platforms without changing tmux agent navigation, state hooks, or bell/status behavior.

## Scope

- Delete the Unix `list-agent-sessions.sh` wrapper.
- Delete the Unix agent-aware preview wrapper, which is only used by the removed picker integration.
- Remove the Unix picker’s agent header entry, Ctrl-E binding, agent selection dispatch, and agent-aware preview command.
- Keep the Windows picker free of agent-session integration.
- Update tests so they reject agent-list traces in sesh while continuing to verify tmux agent navigation and bell configuration.

## Preserved behavior

- `agent-state.sh` remains available to agent hooks.
- `agent-next.sh` remains available through tmux `prefix+A`.
- tmux bell monitoring, visual bell handling, and window bell styling remain unchanged.
- Normal sesh listing, filtering, preview, connection, and kill behavior remain unchanged on Unix and Windows.

## Verification

1. Search the repository for the deleted script names, Ctrl-E agent picker binding, and agent picker labels.
2. Run shell syntax and the agent/tmux state test.
3. Verify the Unix picker uses ordinary `sesh preview {}` and ordinary selection dispatch.
4. Verify the Windows picker remains free of agent-list integration.
5. Verify the tmux agent-next binding and bell/status settings are still present and unchanged.
6. Run the repository’s relevant template/static validation.
