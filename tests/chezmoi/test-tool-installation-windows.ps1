$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$temp = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
[IO.Directory]::CreateDirectory($temp) | Out-Null
$originalToken = $env:GITHUB_TOKEN
$originalLegacyToken = $env:GITHUB_PERSONAL_ACCESS_TOKEN
$originalAutoexport = $env:GH_TOKEN_AUTOEXPORT
$userToken = [Environment]::GetEnvironmentVariable('GITHUB_TOKEN', 'User')

# Stub only external tools. The rendered hook runs in the real PowerShell runtime.
function mise {
    if ($args.Count -ne 3 -or $args[0] -ne '--cd' -or $args[1] -ne $HOME -or $args[2] -ne 'install') {
        throw 'apply must only install missing global tools'
    }
    if ($env:GITHUB_TOKEN -ne $global:expectedToken) { throw 'bootstrap token priority changed' }
    $global:LASTEXITCODE = $global:installStatus
}
function bat { $global:LASTEXITCODE = 0 }

try {
    $config = Join-Path $temp 'config.toml'
    $rendered = Join-Path $temp 'install.ps1'
    Set-Content $config "[data]`ngithub_token = 'fixture-cached-token'"
    chezmoi execute-template --source $repoRoot --config $config --file `
        (Join-Path $repoRoot 'home/.chezmoiscripts/windows/run_after_00-install-tools.ps1.tmpl') |
        Set-Content $rendered
    if ($LASTEXITCODE -ne 0) { throw 'template rendering failed' }

    $global:installStatus = 0
    $global:expectedToken = 'fixture-cached-token'
    $env:GITHUB_TOKEN = $null
    & $rendered
    $global:expectedToken = 'fixture-injected-token'
    $env:GITHUB_TOKEN = $global:expectedToken
    & $rendered
    if ([Environment]::GetEnvironmentVariable('GITHUB_TOKEN', 'User') -ne $userToken) {
        throw 'bootstrap token must not change the persistent User environment'
    }

    $global:installStatus = 42
    $failed = $false
    try { & $rendered } catch { $failed = $true }
    if (-not $failed) { throw 'tool install failure must fail apply' }
    # Exercise only the token section so no interactive profile integrations run.
    $profileText = chezmoi execute-template --source $repoRoot --config $config --file `
        (Join-Path $repoRoot 'home/Documents/PowerShell/profile.ps1.tmpl') | Out-String
    if ($LASTEXITCODE -ne 0) { throw 'profile rendering failed' }
    if ($profileText.Contains('fixture-cached-token')) { throw 'profile must not contain a cached secret' }
    $start = $profileText.IndexOf('# github token')
    $end = $profileText.IndexOf('# aliases', $start)
    if ($start -lt $profileText.IndexOf('mise activate pwsh')) { throw 'resolve token after mise activation' }
    $auth = Join-Path $temp 'auth.ps1'
    Set-Content $auth $profileText.Substring($start, $end - $start)
    function chezmoi {
        if ($args[0] -ne 'execute-template') { throw 'unexpected chezmoi call' }
        $global:LASTEXITCODE = 0
        return $global:cachedToken
    }
    function gh { $global:LASTEXITCODE = 0; return 'fixture-gh-token' }
    $global:cachedToken = 'fixture-cached-token'
    foreach ($case in @(
        @('', '', '', 'fixture-cached-token'),
        @('fixture-injected-token', '', '', 'fixture-injected-token'),
        @('', 'fixture-legacy-token', '', 'fixture-legacy-token'),
        @('', '', '0', '')
    )) {
        $env:GITHUB_TOKEN, $env:GITHUB_PERSONAL_ACCESS_TOKEN, $env:GH_TOKEN_AUTOEXPORT = $case[0..2]
        . $auth
        if ([string]$env:GITHUB_TOKEN -ne $case[3]) { throw 'shell token precedence changed' }
        if ($case[2] -eq '0' -and (gh-token) -ne 'fixture-cached-token') { throw 'accessor must remain available' }
    }
    $global:cachedToken = $null
    $env:GITHUB_TOKEN = $null
    $env:GH_TOKEN_AUTOEXPORT = $null
    . $auth
    if ($env:GITHUB_TOKEN -ne 'fixture-gh-token') { throw 'gh auth fallback failed' }
    if ([Environment]::GetEnvironmentVariable('GITHUB_TOKEN', 'User') -ne $userToken) {
        throw 'shell must not change the persistent User environment'
    }
    Write-Output 'Windows tool install and process-only shell token contract ok'
} finally {
    $env:GITHUB_TOKEN = $originalToken
    $env:GITHUB_PERSONAL_ACCESS_TOKEN = $originalLegacyToken
    $env:GH_TOKEN_AUTOEXPORT = $originalAutoexport
    Remove-Item -LiteralPath $temp -Recurse -Force
}
