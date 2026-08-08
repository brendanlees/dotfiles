# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Enable Kanata
# @raycast.mode compact
# @raycast.packageName Kanata

# Optional parameters:
# @raycast.icon ✅
# @raycast.needsConfirmation false

# Documentation:
# @raycast.description Enable and start Kanata service (Windows)
# @raycast.author xbxd
# @raycast.authorURL https://gitea.lab.brendans.cloud/xbxd

# Re-enable and start the kanata service. Mirrors raycast/kanata-enable.sh on macOS.
$ErrorActionPreference = 'Stop'

$taskName = 'xbxd.kanata'

$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if (-not $task) {
    Write-Host "[X] Kanata task '$taskName' not registered. Run 'chezmoi apply' first."
    exit 1
}

if ($task.State -ne 'Disabled' -and (Get-Process kanata_wintercept -ErrorAction SilentlyContinue)) {
    Write-Host "[OK] Kanata is already enabled and running"
    exit 0
}

if ($task.State -eq 'Disabled') {
    Enable-ScheduledTask -TaskName $taskName | Out-Null
}

Start-ScheduledTask -TaskName $taskName
Start-Sleep -Milliseconds 800

$task = Get-ScheduledTask -TaskName $taskName
if ($task.State -ne 'Disabled' -and (Get-Process kanata_wintercept -ErrorAction SilentlyContinue)) {
    Write-Host "[OK] Kanata enabled and started successfully"
    exit 0
} else {
    Write-Host "[X] Failed to enable Kanata"
    exit 1
}
