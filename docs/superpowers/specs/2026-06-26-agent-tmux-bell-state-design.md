# Agent tmux bell/state design

## Status
Approved for implementation.

## Date
2026-06-26

## Goal
When Claude or Pi agents finish a turn, tmux should receive a bell and show a short-lived semantic completion state in the window title. The state should follow the semantic palette conventions already defined in `.chezmoidata/themes.yml` and consumed by `dot_config/chezmoi-theme/active.lua.tmpl` and `dot_config/tmux/tmux.conf.tmpl`.

## Context
The reference repository `vossenwout/pookie-dotfiles` uses a Pi extension that writes `\x07` on `agent_end`, paired with tmux `monitor-bell on`, `bell-action other`, and `window-status-bell-style` settings. This repo already has a themed tmux status bar, a Pi tmux-window-name extension, and a Claude `Stop` hook, `~/.claude/hooks/tmux-window-name.sh`, that derives the normal tmux window name from session context.

## Decision
Use a layered design:

1. Update the chezmoi-managed tmux template to enable bell monitoring and style bell/activity states with existing semantic palette colors.
2. Add a small shared tmux state helper script for transient agent states. It will ring the terminal bell, rename the current tmux window to a semantic completion label, and restore the prior title after a short delay.
3. Add/adjust Claude Stop hook configuration so Claude keeps its existing session-derived tmux name behavior, then briefly overlays the completion state.
4. Add a Pi extension in `~/.pi/agent/extensions/` that uses Pi's documented `agent_end` lifecycle event and `ctx.hasPendingMessages()` guard to avoid signaling while follow-up work is queued.

## Behavior
- On agent completion: emit bell, show a transient title such as `✓ complete`, then restore the previous tmux window title.
- On active/next prompt: any stale transient state should be cleared by normal window naming or agent-start handling.
- If not inside tmux, hooks/extensions should exit successfully without noise.
- If tmux commands fail, hooks/extensions should not block the agent.

## Semantic conventions
- Success/completion uses the theme `success` color in tmux status styling.
- Activity/warning-like state uses `warn` where tmux already exposes activity styling.
- Error styling is reserved for future error-aware hooks and should use `error` if added later.
- Default/inactive styling continues to use existing `comment`/`muted` conventions.

## Alternatives considered

### Direct bell only
Simpler, but does not satisfy the requested window-title state change.

### Persistent title state
Clearer until acknowledged, but more disruptive because it can overwrite useful session-derived tmux names.

### Replace existing Claude/Pi title hooks
Rejected because the current hooks/extensions already contain useful session naming logic. A transient overlay preserves that behavior.

## Testing
- Render or syntax-check the chezmoi tmux template.
- Shellcheck/syntax-check the new shell helper.
- Type-check or at least parse the Pi TypeScript extension if local tooling allows.
- Run Pi config docs validation after durable Pi config/doc changes.
