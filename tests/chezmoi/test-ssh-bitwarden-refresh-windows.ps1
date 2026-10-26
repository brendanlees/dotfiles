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
$global:BWAttachmentMode = 'none'
$global:BWAttachmentCalls = @()

# A function shadows the real vault CLI. No credentials or live preferences are used.
function bw {
    $global:BWCalls++
    $global:LASTEXITCODE = 0
    if ($args[0] -eq 'status') {
        $status = if ($global:BWLocked) { 'locked' } else { 'unlocked' }
        return (@{ status = $status } | ConvertTo-Json -Compress)
    }
    if ($args[0] -eq 'get' -and $args[1] -eq 'attachment') {
        $request = $args -join ' '
        $global:BWAttachmentCalls += $request
        if ($request -ne 'get attachment manifest-attachment-id --itemid manifest-record-id --raw') {
            throw 'unexpected attachment request'
        }
        switch ($global:BWAttachmentMode) {
            'download-failure' { $global:LASTEXITCODE = 1; return }
            'invalid-json' { return 'ATTACHMENT_CONTENT_NOT_FOR_LOGS' }
            'invalid-shape' { return '{"keys": [], "hosts": {}}' }
            'invalid-scalar' { return '{"keys": "not-an-object", "hosts": {}}' }
            'invalid-hosts-array' { return '{"keys": {}, "hosts": [{}]}' }
            'invalid-root-array' { return '[{"keys": {}, "hosts": {}}]' }
        }
        return (@{
            description = 'ATTACHMENT_CONTENT_NOT_FOR_LOGS' + ('x' * 12000)
            keys = @{}
            hosts = @{ 'attachment-host' = @{ scope = 'personal'; host = 'attachment.invalid' } }
        } | ConvertTo-Json -Depth 5)
    }
    if ($args[0] -ne 'get' -or $args[1] -ne 'item' -or $args[2] -ne 'fixture-manifest') { throw 'unexpected Bitwarden command' }
    $manifest = @{ keys = @{}; hosts = @{ fixture = @{ scope = 'personal'; host = 'fixture.invalid'; user = 'fixture' } } }
    $attachments = @()
    if ($global:BWAttachmentMode -eq 'unrelated') {
        $attachments = @(@{ id = 'other'; fileName = 'unrelated.json' })
    } elseif ($global:BWAttachmentMode -ne 'none') {
        $attachments = @(@{ id = 'manifest-attachment-id'; fileName = 'bw-ssh-config.json' })
        if ($global:BWAttachmentMode -eq 'duplicate') {
            $attachments += @{ id = 'duplicate-id'; fileName = 'bw-ssh-config.json' }
        }
    }
    return (@{ id = 'manifest-record-id'; notes = ($manifest | ConvertTo-Json -Depth 5 -Compress); attachments = $attachments } | ConvertTo-Json -Depth 5 -Compress)
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
    # Prefer the large attachment over valid legacy Notes, using canonical IDs and stdout.
    $global:BWAttachmentMode = 'present'
    $attachmentOutput = (& $helper --fail 6>&1 | Out-String)
    Assert-True ($global:BWAttachmentCalls[-1] -eq 'get attachment manifest-attachment-id --itemid manifest-record-id --raw') 'attachment was not read using canonical IDs and raw output'
    Assert-True ((Get-Content -Raw $config) -match 'Host attachment-host') 'attachment did not override Notes'
    Assert-True ((Get-Content -Raw $config) -notmatch 'Host fixture') 'stale Notes were used'
    Assert-True ($attachmentOutput -notmatch 'ATTACHMENT_CONTENT_NOT_FOR_LOGS') 'manifest contents leaked into output'
    Assert-True (-not (Test-Path (Join-Path $Stage 'bw-ssh-config.json'))) 'attachment was saved to disk'

    $global:BWAttachmentMode = 'unrelated'
    $attachmentCalls = $global:BWAttachmentCalls.Count
    & $helper --fail
    Assert-True ((Get-Content -Raw $config) -match 'Host fixture') 'unrelated attachment prevented Notes fallback'
    Assert-True ($global:BWAttachmentCalls.Count -eq $attachmentCalls) 'unrelated attachment was downloaded'

    foreach ($mode in @('download-failure','invalid-json','invalid-shape','invalid-scalar','invalid-hosts-array','invalid-root-array','duplicate')) {
        $global:BWAttachmentMode = $mode
        Set-Content -LiteralPath $config -Value 'Host keep-existing'
        $failed = $false
        try {
            & $helper --fail
            $failed = ($LASTEXITCODE -ne 0)
        } catch { $failed = $true }
        Assert-True $failed "attachment mode $mode did not fail"
        Assert-True ((Get-Content -Raw $config).Trim() -eq 'Host keep-existing') "attachment mode $mode replaced existing config"
    }
    Write-Host 'Windows SSH attachment loading and change-driven provisioning ok'
} finally {
    Set-Variable -Name HOME -Value $OriginalHome -Force
    $env:CHEZMOI_ROLE = $OriginalRole
    $env:XDG_STATE_HOME = $OriginalState
    $env:SSH_BW_MANIFEST_ITEM = $OriginalManifest
    $env:SSH_BW_AGENT_SOCK_ENV = $OriginalSocketName
    $env:BW_SESSION = $OriginalSession
    Remove-Item -LiteralPath $Stage -Recurse -Force -ErrorAction SilentlyContinue
}
