#!/bin/bash
set -euo pipefail

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Enable Kanata
# @raycast.mode compact
# @raycast.packageName Kanata

# Optional parameters:
# @raycast.icon ✅
# @raycast.needsConfirmation false

# Documentation:
# @raycast.description Enable and start Kanata service with auto-restart
# @raycast.author xbxd
# @raycast.authorURL https://gitea.lab.brendans.cloud/xbxd

# Create temp script to run with single password prompt
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << 'SCRIPT_EOF'
#!/bin/bash
# Bootstrap (load) the service with auto-restart
if launchctl bootstrap system /Library/LaunchDaemons/xbxd.kanata.plist 2>/dev/null; then
    sleep 0.5
    if launchctl list | grep -q xbxd.kanata; then
        echo "ENABLED"
    else
        echo "FAILED"
    fi
else
    # Check if it was already enabled
    if launchctl list | grep -q xbxd.kanata; then
        echo "ALREADY_ENABLED"
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
    "ENABLED")
        echo "✅ Kanata enabled and started successfully"
        exit 0
        ;;
    "ALREADY_ENABLED")
        echo "✅ Kanata is already enabled and running"
        exit 0
        ;;
    "FAILED")
        echo "❌ Failed to enable Kanata"
        exit 1
        ;;
    *)
        echo "❌ Unexpected error"
        exit 1
        ;;
esac
