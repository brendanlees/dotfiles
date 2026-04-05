#!/bin/bash
set -euo pipefail

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Disable Kanata
# @raycast.mode compact
# @raycast.packageName Kanata

# Optional parameters:
# @raycast.icon 🚫
# @raycast.needsConfirmation true

# Documentation:
# @raycast.description Completely disable Kanata service (no auto-restart)
# @raycast.author xbxd
# @raycast.authorURL https://gitea.lab.brendans.cloud/xbxd

# Create temp script to run with single password prompt
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << 'SCRIPT_EOF'
#!/bin/bash
# Unload the service completely (stops it and prevents auto-restart)
if launchctl bootout system /Library/LaunchDaemons/xbxd.kanata.plist 2>/dev/null; then
    echo "DISABLED"
else
    # Check if it was already disabled
    if ! launchctl list | grep -q xbxd.kanata; then
        echo "ALREADY_DISABLED"
    else
        echo "FAILED"
    fi
fi
SCRIPT_EOF

chmod +x "$TEMP_SCRIPT"

# Run with single password prompt
RESULT=$(osascript -e "do shell script \"$TEMP_SCRIPT\" with administrator privileges" 2>/dev/null)

# Cleanup
rm -f "$TEMP_SCRIPT"

case "$RESULT" in
    "DISABLED")
        echo "✅ Kanata disabled successfully (no auto-restart)"
        exit 0
        ;;
    "ALREADY_DISABLED")
        echo "✅ Kanata is already disabled"
        exit 0
        ;;
    "FAILED")
        echo "❌ Failed to disable Kanata"
        exit 1
        ;;
    *)
        echo "❌ Unexpected error"
        exit 1
        ;;
esac
