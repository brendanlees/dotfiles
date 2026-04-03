#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Start Kanata
# @raycast.mode compact
# @raycast.packageName Kanata

# Optional parameters:
# @raycast.icon 🎹
# @raycast.needsConfirmation false

# Documentation:
# @raycast.description Start the Kanata homerow mods service
# @raycast.author xbxd
# @raycast.authorURL https://gitea.lab.brendans.cloud/xbxd

# Create temp script to run with single password prompt
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << 'SCRIPT_EOF'
#!/bin/bash
if launchctl list | grep -q xbxd.kanata; then
    echo "ALREADY_RUNNING"
else
    launchctl kickstart system/xbxd.kanata
    sleep 0.5
    if launchctl list | grep -q xbxd.kanata; then
        echo "STARTED"
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
    "ALREADY_RUNNING")
        echo "✅ Kanata is already running"
        exit 0
        ;;
    "STARTED")
        echo "✅ Kanata started successfully"
        exit 0
        ;;
    "FAILED")
        echo "❌ Failed to start Kanata"
        exit 1
        ;;
    *)
        echo "❌ Unexpected error"
        exit 1
        ;;
esac
