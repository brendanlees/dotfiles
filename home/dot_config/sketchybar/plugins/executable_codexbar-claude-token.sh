#!/usr/bin/env bash
# CodexBar can't keep Keychain access to Claude Code's OAuth token: each Claude
# token refresh rewrites the item and drops CodexBar's grant, so Claude usage
# fails or prompts repeatedly (steipete/CodexBar#3798). /usr/bin/security stays
# on the item's access list, so read the current token here and hand it over.
token=$(/usr/bin/security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null |
    jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
[[ -z "$token" ]] || export CODEXBAR_CLAUDE_OAUTH_TOKEN="$token"
exec codexbar "$@"
