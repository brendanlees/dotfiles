$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$Stage = Join-Path ([IO.Path]::GetTempPath()) "ssh-refresh-$([guid]::NewGuid().ToString('N'))"
$OriginalHome = $HOME
$OriginalRole = $env:CHEZMOI_ROLE
$OriginalState = $env:XDG_STATE_HOME
$OriginalManifest = $env:SSH_BW_MANIFEST_ITEM
$OriginalSocketName = $env:SSH_BW_AGENT_SOCK_ENV
$OriginalSession = $env:BW_SESSION
$global:BWCalls = 0
$global:BWLocked = $true

# A function shadows the real vault CLI. No credentials or live preferences are used.
function bw {
    $global:BWCalls++
    $global:LASTEXITCODE = 0
    if ($args[0] -eq 'status') {
        $status = if ($global:BWLocked) { 'locked' } else { 'unlocked' }
        return (@{ status = $status } | ConvertTo-Json -Compress)
    }
    if ($args[0] -ne 'get' -or $args[2] -ne 'fixture-manifest') { throw 'unexpected Bitwarden command' }
    $manifest = @{ keys = @{}; hosts = @{ fixture = @{ scope = 'personal'; host = 'fixture.invalid'; user = 'fixture' } } }
    return (@{ notes = ($manifest | ConvertTo-Json -Depth 5 -Compress) } | ConvertTo-Json -Compress)
}
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

try {
    New-Item -ItemType Directory -Force -Path (Join-Path $Stage '.local/bin') | Out-Null
    Set-Variable -Name HOME -Value $Stage -Force
    $env:CHEZMOI_ROLE = 'personal'
    $env:XDG_STATE_HOME = Join-Path $Stage 'state'
    $env:SSH_BW_MANIFEST_ITEM = 'fixture-manifest'
    $env:SSH_BW_AGENT_SOCK_ENV = 'FIXTURE_UNUSED_AGENT'
    $data = '{"personal":true,"work":false,"homelab":false,"ephemeral":false,"chezmoi":{"os":"windows"}}'
    $chezmoiConfig = Join-Path $Stage 'chezmoi.toml'
    Set-Content -LiteralPath $chezmoiConfig -Value '[data]'
    $helper = Join-Path $Stage '.local/bin/cz-ssh-refresh.ps1'
    $runner = Join-Path $Stage 'refresh.ps1'
    foreach ($pair in @(
        @('dot_local/bin/executable_cz-ssh-refresh.ps1.tmpl', $helper),
        @('.chezmoiscripts/windows/run_after_01-refresh-ssh-keys.ps1.tmpl', $runner)
    )) {
        $rendered = & chezmoi execute-template --source $RepoRoot --config $chezmoiConfig --override-data $data --file (Join-Path $RepoRoot "home/$($pair[0])") | Out-String
        if ($LASTEXITCODE -ne 0) { throw 'template render failed' }
        [IO.File]::WriteAllText($pair[1], $rendered)
    }
    $config = Join-Path $Stage '.ssh/config.d/personal.conf'
    & $runner
    Assert-True (-not (Test-Path $config)) 'locked vault unexpectedly provisioned SSH'
    $global:BWLocked = $false
    & $runner
    Assert-True (Test-Path $config) 'unlocked retry did not provision SSH'
    $calls = $global:BWCalls
    $global:BWLocked = $true
    $env:BW_SESSION = 'fixture-new-session'
    & $runner
    Assert-True ($global:BWCalls -eq $calls) 'unchanged apply accessed Bitwarden'

    Add-Content -LiteralPath $helper -Value '# fixture: changed provisioning inputs'
    & $runner
    Assert-True ($global:BWCalls -gt $calls) 'changed helper did not retry'
    $calls = $global:BWCalls
    $global:BWLocked = $false
    & $runner
    Assert-True ($global:BWCalls -gt $calls) 'locked skip was incorrectly cached'
    $calls = $global:BWCalls
    & $runner
    Assert-True ($global:BWCalls -eq $calls) 'successful changed inputs were not cached'

    Remove-Item -LiteralPath $config
    & $runner
    Assert-True (Test-Path $config) 'missing config was not repaired'
    $calls = $global:BWCalls
    & $helper
    Assert-True ($global:BWCalls -gt $calls) 'manual refresh must remain unconditional'
    Write-Host 'Windows SSH provisioning skips unchanged success and retries failures'
} finally {
    Set-Variable -Name HOME -Value $OriginalHome -Force
    $env:CHEZMOI_ROLE = $OriginalRole
    $env:XDG_STATE_HOME = $OriginalState
    $env:SSH_BW_MANIFEST_ITEM = $OriginalManifest
    $env:SSH_BW_AGENT_SOCK_ENV = $OriginalSocketName
    $env:BW_SESSION = $OriginalSession
    Remove-Item -LiteralPath $Stage -Recurse -Force -ErrorAction SilentlyContinue
}
