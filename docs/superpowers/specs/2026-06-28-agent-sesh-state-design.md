# Agent sesh state integration design

## Status
Draft for user review.

## Date
2026-06-28

## Goal
Make the existing `sesh` picker agent-aware without replacing `sesh`, adding a dashboard, or filling the tmux status bar. Claude and Pi should write a small shared tmux-pane state record when an agent turn becomes actionable, and the chezmoi-managed `sesh`/tmux glue should use that state to preview, filter, and jump to agent panes.

## Context
This repo already has the right outer shape:

- `dot_config/tmux/tmux.conf.tmpl` binds `prefix K` to `~/.config/sesh/scripts/picker.sh --tmux`.
- `dot_config/sesh/scripts/executable_picker.sh.tmpl` uses `sesh list --icons` with `fzf` and `sesh preview {}`.
- `status-right` is intentionally empty, and window bell coloring already uses `window_bell_flag`.
- `docs/superpowers/specs/2026-06-26-agent-tmux-bell-state-design.md` defines the completion bell behavior.
- The external harness roots in `.chezmoiexternal.toml.tmpl` include `~/.claude` and `~/.pi`.
- Claude already has a Stop hook that calls `~/.claude/hooks/tmux-agent-state.sh complete` after tmux window naming.
- Pi already has an `agent-tmux-state.ts` extension that calls the same helper on `agent_end` when `ctx.hasPendingMessages()` is false.

The missing layer is persistence. Today the shared helper rings BEL so tmux marks a window, but it does not write state that `sesh` scripts can query.

## Decision
Use a layered state-backed sesh integration:

1. Keep `sesh` as the session router and picker.
2. Keep tmux as the runtime context and navigation target.
3. Extend the existing Claude/Pi completion hook path to write local runtime state.
4. Add small chezmoi-managed scripts that consume the state for `sesh` preview, agents-only filtering, and one jump binding.

## State location
Use XDG local state:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/agent-tmux/
```

This path is machine-local runtime state. It must not be checked into chezmoi and must not be synchronized across machines. Pane IDs, tmux session names, timestamps, and working directories are volatile.

## State semantics
The MVP records only actionable completion state.

When Claude Stop or Pi `agent_end` fires and there are no pending messages, the hook writes a record for the current tmux pane with:

- `harness`: `claude` or `pi` where known.
- `state`: `done`.
- `pane_id`: tmux `#{pane_id}`.
- `session_id`: tmux `#{session_id}`.
- `session_name`: tmux `#{session_name}`.
- `window_id`: tmux `#{window_id}`.
- `window_index`: tmux `#{window_index}`.
- `window_name`: tmux `#{window_name}`.
- `pane_current_path`: tmux `#{pane_current_path}`.
- `updated_at`: epoch seconds.

Store one shell-escaped env file per pane, for example `pane-%12.env`. Reader scripts must source only files they validate as simple `KEY='value'` assignments and must tolerate malformed or stale files.

## User-facing behavior

### Sesh preview
Change the picker preview from plain:

```sh
sesh preview {}
```

to a wrapper:

```sh
~/.config/sesh/scripts/preview-with-agent-state.sh {}
```

The wrapper prepends a compact block when the selected tmux session/window/pane has known agent state, then falls through to `sesh preview {}`. If no state matches, preview output should remain effectively unchanged.

### Agents-only picker mode
Add an fzf binding to the existing picker, for example:

```sh
--bind 'ctrl-e:change-prompt(🤖  )+reload(~/.config/sesh/scripts/list-agent-sessions.sh)'
```

The list script should emit selectable rows compatible with the existing `sesh connect` flow where practical. If exact `sesh connect` compatibility is not possible for pane-level targets, the design should prefer a tmux-aware execute path over forcing fragile parsing into `sesh` rows.

### Jump binding
Add one tmux binding:

```tmux
bind-key A run-shell '~/.config/sesh/scripts/agent-next.sh'
```

`agent-next.sh` scans valid state records and jumps to the oldest actionable pane. It should ignore stale records whose pane no longer exists. If no actionable panes exist, it should fail quietly or display a short tmux message.

## Cleanup and staleness
Reader scripts are responsible for tolerating stale records. A record is stale when its tmux pane no longer exists or required fields are missing. The MVP can delete stale files opportunistically during list/jump operations, but cleanup must never block navigation.

There is no manual acknowledge state in the MVP. Visiting or focusing a pane may clear the record if that proves simple and reliable, but the minimum acceptable implementation is: completion writes `done`, jump/list show `done`, stale pane cleanup removes dead records.

## Non-goals
- Do not replace `sesh`.
- Do not add a status-right segment, dashboard, sidebar, or permanent visual noise.
- Do not rename tmux windows for state.
- Do not track full lifecycle states such as `running`, `error`, or `needs-input` in the MVP.
- Do not sync state through chezmoi.
- Do not try to support every harness before Claude and Pi work reliably.

## Alternatives considered

### Preview-only inference
A preview wrapper could infer likely agent panes from tmux process or window metadata. This is low risk but cannot reliably distinguish running, idle, and done states.

### Tmux options as state backend
Pane/window options avoid filesystem state, but shell/fzf readers become harder to debug and less portable. Files are simpler for scripts and future harnesses.

### Full lifecycle model
Tracking `running`, `done`, `error`, `needs-input`, and acknowledged states would provide richer UX, but it requires more hook points and harness-specific semantics. The MVP should first make completion state reliable.

## Testing
- Render or syntax-check the chezmoi tmux template.
- Shell syntax-check all new or changed shell scripts.
- Test state writer behavior outside tmux, inside tmux, and when `tmux` is unavailable.
- Test reader behavior with valid, missing, malformed, and stale state files.
- Verify the picker still works with normal `sesh` modes (`ctrl-a`, `ctrl-t`, `ctrl-g`, `ctrl-x`, `ctrl-f`).
- If durable Pi config docs are changed later, run the Pi config docs validator required by repo instructions.
