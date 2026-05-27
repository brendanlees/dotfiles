# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Stop Kanata
# @raycast.mode compact
# @raycast.packageName Kanata

# Optional parameters:
# @raycast.icon 🛑
# @raycast.needsConfirmation false

# Documentation:
# @raycast.description Stop the Kanata homerow mods service (Windows; will NOT auto-restart)
# @raycast.author xbxd
# @raycast.authorURL https://gitea.lab.brendans.cloud/xbxd

# Stop the kanata homerow-mods service (mirrors raycast/kanata-stop.sh on macOS).
# NOTE: unlike macOS launchd KeepAlive=true, the Windows scheduled task triggers
# only at logon -- stopping here does NOT auto-restart. Use kanata-start.ps1 to
# bring it back without logging out.
$ErrorActionPreference = 'Stop'

$taskName = 'xbxd.kanata'

if (-not (Get-Process kanata_wintercept -ErrorAction SilentlyContinue)) {
    Write-Host "[!] Kanata is not running"
    exit 0
}

Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 800

if (Get-Process kanata_wintercept -ErrorAction SilentlyContinue) {
    Write-Host "[X] Failed to stop Kanata (process still alive). Try running this from an elevated shell."
    exit 1
} else {
    Write-Host "[OK] Kanata stopped successfully (will not auto-restart; use kanata-start to relaunch)"
    exit 0
}
