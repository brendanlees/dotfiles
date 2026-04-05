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

# Create temp script to run with single password prompt
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << 'SCRIPT_EOF'
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

chmod +x "$TEMP_SCRIPT"

# Run with single password prompt
RESULT=$(osascript -e "do shell script \"$TEMP_SCRIPT\" with administrator privileges" 2>/dev/null)

# Cleanup
rm -f "$TEMP_SCRIPT"

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
