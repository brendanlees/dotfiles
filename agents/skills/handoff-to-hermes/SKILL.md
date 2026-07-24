---
name: handoff-to-hermes
description: Use when the user asks to hand off, push, sync, brief, or catch up Hermes
  on the current session or project via the hermes MCP. Manual and on-demand only —
  never automatic, never on a hook. Requires the hermes MCP server with messages_send.
---

# Handing Off to Hermes

## Overview

Hermes is a separate assistant agent reachable through chat platforms (Telegram,
Discord, Slack). The `hermes` MCP's `messages_send` posts into a **real chat channel
that Hermes — and possibly humans — read**. This is an outward-facing, irreversible
publish, not a local note. This skill packages a session/project summary and delivers
it safely.

Run this **only when the user explicitly asks**. Never on a hook, never automatically,
never "while I'm at it."

## The Iron Rule

**Never call `messages_send` until the user has approved BOTH the exact target AND the
exact message text.** No guessed targets, no "typical" channel names like
`discord:#<project>`, no sending first and asking later. A send cannot be unsent.

## Discord profile mentions

Every Discord handoff must mention one user-selected Hermes profile. Ask which
profile should receive the handoff for every Discord send; never infer it from the
channel or thread name.

| Profile | Discord mention |
|---|---|
| `main` | `<@1514182475612557312>` |
| `homelab` | `<@1523633568301973594>` |
| `work` | `<@1523633738171416647>` |
| `study` | `<@1526543237567742015>` |

Prefix the outgoing Discord message with the selected mention on its own line. If
the requested profile is unknown or unmapped, stop and ask the user to select a
mapped profile. Never guess, omit, or synthesize a mention. Telegram and Slack
handoffs do not use this mapping.

## Procedure

1. **Compose the handoff** from this session using the template below.
2. **Ask for additions** — "Anything to add or change before I send?" The payload is
   your summary *plus* the user's notes (the user-specified info).
3. **Redact before it leaves the machine.** Strip secrets, tokens, credentials,
   absolute local paths, and private business context — this posts to an external chat
   platform. When unsure, leave it out.
4. **Discover the target** — call `channels_list` (and/or `conversations_list`) and
   read back the *real* candidates returned. Never invent a target string.
5. **Select the Discord profile** — when the resolved target is Discord, ask the user
   to select one profile from the mapping above. Prefix the payload with that
   profile's exact mention. Stop if the profile is unknown or unmapped. Skip this
   step for non-Discord targets.
6. **Confirm** — show the user the resolved target, the selected profile when Discord,
   AND the final message verbatim, including the mention prefix, then get an explicit
   go-ahead.
7. **Send** — `messages_send(target=<confirmed>, message=<confirmed>)`. The payload
   must exactly match the confirmed, mention-prefixed text.
8. **Report** — state what was posted where and, for Discord, which profile was
   mentioned.

## Handoff template

```
**<project> — handoff <date>**
Goal:      <what the work is aiming at>
Status:    <where it stands now>
Done:      <key completed items>
Decisions: <choices made, commands run, findings>
Validation:<tests/checks and their results>
Next:      <open follow-ups>
Notes:     <user additions>
```

Keep it a **digest, not a transcript dump**. If it doesn't fit comfortably in a chat
message, summarize harder.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "I'll assume the channel is `discord:#<project>`" | You're guessing. Run `channels_list` and read back real targets. |
| "The channel is `#homelab`, so I'll choose `homelab`" | Profile selection is explicit. Ask the user; never infer it from the target name. |
| "User's in a hurry — I'll just send" | Confirming takes 5 seconds; a wrong send is public and permanent. |
| "I'll paste the whole session" | Digest, not dump. |
| About to confirm a Discord handoff without a mapped `<@USER_ID>` prefix | STOP. Select a mapped profile and show the mention-prefixed payload. |
| About to call `messages_send` without having shown the user the target + text | STOP. Confirm both first. |

## When NOT to use

- Automatically, on session end, or via a hook — manual invocation only.
- For handing off between your *own* local sessions — use the generic `handoff` skill.

## Prerequisite

Requires the `hermes` MCP server configured with `messages_send` enabled. If it isn't
connected, say so instead of attempting a send.
