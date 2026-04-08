#!/bin/bash
# shared sudo wrapper for the kanata raycast scripts.
# raycast ignores this file because it has no @raycast.schemaVersion header.
#
# usage:
#   source "$(dirname "$0")/_run-with-sudo.sh"
#   RESULT=$(run_with_sudo <<'SCRIPT_EOF'
#       ...privileged commands...
#   SCRIPT_EOF
#   )
#
# behaviour: reads a script body from stdin, writes it to a tempfile,
# runs it via osascript with administrator privileges (single password
# prompt), cleans up the tempfile, and prints whatever the script wrote
# to stdout.

run_with_sudo() {
    local tmp
    tmp=$(mktemp)
    cat > "$tmp"
    chmod +x "$tmp"
    local result
    result=$(osascript -e "do shell script \"$tmp\" with administrator privileges" 2>/dev/null)
    rm -f "$tmp"
    printf '%s' "$result"
}
