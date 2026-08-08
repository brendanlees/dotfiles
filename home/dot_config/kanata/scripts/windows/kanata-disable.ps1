# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Disable Kanata
# @raycast.mode compact
# @raycast.packageName Kanata

# Optional parameters:
# @raycast.icon 🚫
# @raycast.needsConfirmation true

# Documentation:
# @raycast.description Completely disable Kanata service (no auto-restart, Windows)
# @raycast.author xbxd
# @raycast.authorURL https://gitea.lab.brendans.cloud/xbxd

# Disable the kanata service completely -- stops it AND prevents the scheduled
# task from running at next logon. Mirrors raycast/kanata-disable.sh on macOS.
$ErrorActionPreference = 'Stop'

$taskName = 'xbxd.kanata'

$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if (-not $task) {
    Write-Host "[X] Kanata task '$taskName' not registered. Run 'chezmoi apply' first."
    exit 1
}

# Stop running instance first (no-op if not running)
Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

if ($task.State -eq 'Disabled') {
    Write-Host "[OK] Kanata is already disabled"
    exit 0
}

Disable-ScheduledTask -TaskName $taskName | Out-Null

$task = Get-ScheduledTask -TaskName $taskName
if ($task.State -eq 'Disabled' -and -not (Get-Process kanata_wintercept -ErrorAction SilentlyContinue)) {
    Write-Host "[OK] Kanata disabled successfully (no auto-restart at logon)"
    exit 0
} else {
    Write-Host "[X] Failed to disable Kanata"
    exit 1
}
