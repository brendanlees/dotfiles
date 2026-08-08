# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Kanata Status
# @raycast.mode fullOutput
# @raycast.packageName Kanata

# Optional parameters:
# @raycast.icon 📊
# @raycast.needsConfirmation false

# Documentation:
# @raycast.description Check Kanata service status, configuration, and recent logs (Windows)
# @raycast.author xbxd
# @raycast.authorURL https://gitea.lab.brendans.cloud/xbxd

# Show kanata service status, configuration, and recent logs.
# Mirrors raycast/kanata-status.sh on macOS.
$ErrorActionPreference = 'Stop'

$taskName  = 'xbxd.kanata'
$configRel = '~\.config\kanata\config-windows.kbd'
$logPath   = Join-Path $env:LOCALAPPDATA 'Kanata\kanata.log'

$proc = Get-Process kanata_wintercept -ErrorAction SilentlyContinue
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Kanata Service Status"
Write-Host "===================="
Write-Host ""

if ($proc) {
    Write-Host ("[OK] Service:    Running (PID {0}, started {1:HH:mm:ss})" -f $proc.Id, $proc.StartTime)
} else {
    Write-Host "[X]  Service:    Not running"
}

if ($task) {
    $info = $task | Get-ScheduledTaskInfo
    if ($task.State -eq 'Disabled') {
        Write-Host "[!]  Auto-start: Disabled (will not start at logon)"
    } else {
        Write-Host "[OK] Auto-start: Enabled (state=$($task.State))"
    }
    if ($info.LastRunTime) {
        Write-Host ("     LastRunTime:    {0}" -f $info.LastRunTime)
    }
    if ($null -ne $info.LastTaskResult) {
        $resHex = '0x{0:X}' -f $info.LastTaskResult
        Write-Host ("     LastTaskResult: {0} ({1})" -f $info.LastTaskResult, $resHex)
    }
} else {
    Write-Host "[X]  Auto-start: Task not registered (run 'chezmoi apply')"
}

Write-Host ""
Write-Host "Configuration"
Write-Host "-------------"
Write-Host "Config: $configRel"
Write-Host "Log:    $logPath"
Write-Host ""

if (Test-Path $logPath) {
    Write-Host "Recent log (last 10 INFO/ERROR lines)"
    Write-Host "-------------------------------------"
    # Strip ANSI color escapes (kanata emits them; PS 5.1 console doesn't interpret)
    $ansi = [regex]'\x1B\[[0-9;]*[A-Za-z]'
    Get-Content $logPath -ErrorAction SilentlyContinue |
        Select-String '\[INFO\]|\[ERROR\]' |
        Select-Object -Last 10 |
        ForEach-Object { $ansi.Replace($_.Line, '') }
} else {
    Write-Host "No log file at $logPath"
}
