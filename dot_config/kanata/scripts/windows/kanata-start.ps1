# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Start Kanata
# @raycast.mode compact
# @raycast.packageName Kanata

# Optional parameters:
# @raycast.icon 🎹
# @raycast.needsConfirmation false

# Documentation:
# @raycast.description Start the Kanata homerow mods service (Windows)
# @raycast.author xbxd
# @raycast.authorURL https://gitea.lab.brendans.cloud/xbxd

# Start the kanata homerow-mods service (mirrors raycast/kanata-start.sh on macOS).
# The xbxd.kanata scheduled task is elevated; Start-ScheduledTask works from a
# normal user shell because we own the task.
$ErrorActionPreference = 'Stop'

$taskName = 'xbxd.kanata'

if (Get-Process kanata_wintercept -ErrorAction SilentlyContinue) {
    Write-Host "[OK] Kanata is already running"
    exit 0
}

Start-ScheduledTask -TaskName $taskName
Start-Sleep -Milliseconds 800

if (Get-Process kanata_wintercept -ErrorAction SilentlyContinue) {
    Write-Host "[OK] Kanata started successfully"
    exit 0
} else {
    Write-Host "[X] Failed to start Kanata -- check $env:LOCALAPPDATA\Kanata\kanata.log"
    exit 1
}
