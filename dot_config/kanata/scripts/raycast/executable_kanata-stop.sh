#!/bin/bash
set -euo pipefail

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Stop Kanata
# @raycast.mode compact
# @raycast.packageName Kanata

# Optional parameters:
# @raycast.icon 🛑
# @raycast.needsConfirmation false

# Documentation:
# @raycast.description Stop the Kanata homerow mods service (will auto-restart due to KeepAlive)
# @raycast.author xbxd
# @raycast.authorURL https://gitea.lab.brendans.cloud/xbxd

source "$(dirname "$0")/_run-with-sudo.sh"

RESULT=$(run_with_sudo <<'SCRIPT_EOF'
#!/bin/bash
if ! launchctl list | grep -q xbxd.kanata; then
    echo "NOT_RUNNING"
else
    launchctl kill TERM system/xbxd.kanata
    sleep 0.5
    if launchctl list | grep -q xbxd.kanata; then
        echo "RESTARTED"
    else
        echo "STOPPED"
    fi
fi
SCRIPT_EOF
)

case "$RESULT" in
    "NOT_RUNNING")
        echo "⚠️  Kanata is not running"
        exit 0
        ;;
    "RESTARTED")
        echo "⚠️  Kanata restarted (KeepAlive enabled)"
        exit 0
        ;;
    "STOPPED")
        echo "✅ Kanata stopped successfully"
        exit 0
        ;;
    *)
        echo "❌ Unexpected error"
        exit 1
        ;;
esac
