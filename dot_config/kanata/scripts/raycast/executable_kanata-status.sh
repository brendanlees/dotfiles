#!/bin/bash
set -euo pipefail

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Kanata Status
# @raycast.mode fullOutput
# @raycast.packageName Kanata

# Optional parameters:
# @raycast.icon 📊
# @raycast.needsConfirmation false

# Documentation:
# @raycast.description Check Kanata service status, configuration, and recent logs
# @raycast.author xbxd
# @raycast.authorURL https://gitea.lab.brendans.cloud/xbxd

source "$(dirname "$0")/_run-with-sudo.sh"

FULL_STATUS=$(run_with_sudo <<'SCRIPT_EOF'
#!/bin/bash
LIST_OUTPUT=$(launchctl list | grep xbxd.kanata || echo "NOT_FOUND")
if [ "$LIST_OUTPUT" != "NOT_FOUND" ]; then
    PID=$(echo "$LIST_OUTPUT" | awk '{print $1}')
    if [ -f /Library/Logs/Kanata/kanata.err.log ]; then
        LOGS=$(tail -n 5 /Library/Logs/Kanata/kanata.err.log 2>/dev/null | base64)
    else
        LOGS="NO_LOG_FILE"
    fi
    echo "RUNNING|$PID|$LOGS"
else
    echo "NOT_RUNNING||"
fi
SCRIPT_EOF
)

# Parse output
IFS='|' read -r STATUS PID LOGS <<< "$FULL_STATUS"

echo "🎹 Kanata Service Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$STATUS" = "RUNNING" ]; then
    echo "✅ Service: Running"
    if [ "$PID" != "-" ] && [ -n "$PID" ]; then
        echo "🔢 PID: $PID"
    fi
    echo "🟢 Auto-start: Enabled"
else
    echo "❌ Service: Not running"
    echo "🟡 Auto-start: Enabled (but not running)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Config: ~/.config/kanata/config.kbd"
echo "Timing: 180ms tap/hold"
echo ""

# Show recent log entries if running
if [ "$STATUS" = "RUNNING" ] && [ -n "$LOGS" ] && [ "$LOGS" != "NO_LOG_FILE" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📄 Recent Logs (last 5 lines)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$LOGS" | base64 -d
elif [ "$STATUS" = "RUNNING" ] && [ "$LOGS" = "NO_LOG_FILE" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📄 Recent Logs"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "No log file found"
fi
