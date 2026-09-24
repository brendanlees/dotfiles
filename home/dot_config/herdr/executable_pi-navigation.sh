#!/usr/bin/env bash
# Pi decides whether autocomplete owns Ctrl+J/K; other apps keep Vim/Herdr routing.
set -euo pipefail

direction="${1:?usage: pi-navigation.sh <up|down>}"
case "$direction" in
  down) key='ctrl+j' ;;
  up) key='ctrl+k' ;;
  *) exit 2 ;;
esac
herdr="${HERDR_BIN_PATH:-herdr}"
pane="${HERDR_ACTIVE_PANE_ID:-${HERDR_PANE_ID:-}}"

if [ -n "$pane" ] && "$herdr" pane process-info --pane "$pane" 2>/dev/null |
  jq -e '.result.process_info.foreground_processes[]? | select(.name == "pi")' >/dev/null 2>&1; then
  exec "$herdr" pane send-keys "$pane" "$key"
fi

exec "$herdr" plugin action invoke "vim-herdr-navigation.$direction"
