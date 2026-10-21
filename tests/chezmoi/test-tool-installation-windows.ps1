$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$temp = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
[IO.Directory]::CreateDirectory($temp) | Out-Null
$originalToken = $env:GITHUB_TOKEN
$originalLegacyToken = $env:GITHUB_PERSONAL_ACCESS_TOKEN
$originalGhToken = $env:GH_TOKEN
$originalXdgDataHome = $env:XDG_DATA_HOME
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
function git {
    if ($args.Count -ne 5 -or $args[0] -ne 'clone' -or $args[1] -ne '--depth' -or
        $args[2] -ne '1' -or $args[3] -ne 'https://github.com/zdharma-continuum/zinit.git') {
        throw 'Zinit bootstrap must clone the official repository shallowly'
    }
    New-Item -ItemType Directory -Force -Path $args[4] | Out-Null
    Set-Content (Join-Path $args[4] 'zinit.zsh') 'stub'
    Add-Content (Join-Path $temp 'zinit-clones.log') $args[4]
    $global:LASTEXITCODE = 0
}

try {
    $config = Join-Path $temp 'config.toml'
    $zinitRendered = Join-Path $temp 'install-zinit.ps1'
    chezmoi execute-template --source $repoRoot --file `
        (Join-Path $repoRoot 'home/.chezmoiscripts/windows/run_once_before_install-zinit.ps1.tmpl') |
        Set-Content $zinitRendered
    if ($LASTEXITCODE -ne 0) { throw 'Zinit template rendering failed' }
    $env:XDG_DATA_HOME = Join-Path $temp 'data'
    & $zinitRendered
    & $zinitRendered
    if (@(Get-Content (Join-Path $temp 'zinit-clones.log')).Count -ne 1) {
        throw 'Zinit bootstrap must clone once and skip an existing installation'
    }
    $env:XDG_DATA_HOME = $originalXdgDataHome
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
    function gh { throw 'download accessor must never read the gh login' }
    $global:cachedToken = 'fixture-cached-token'
    foreach ($case in @(
        @('', '', ''),
        @('', 'fixture-project-token', ''),
        @('fixture-agent-token', 'fixture-project-token', 'fixture-legacy-token')
    )) {
        $env:GH_TOKEN, $env:GITHUB_TOKEN, $env:GITHUB_PERSONAL_ACCESS_TOKEN = $case
        . $auth
        if ([string]$env:GH_TOKEN -ne $case[0] -or [string]$env:GITHUB_TOKEN -ne $case[1] -or
            [string]$env:GITHUB_PERSONAL_ACCESS_TOKEN -ne $case[2]) {
            throw 'shell startup must preserve explicit gh credentials without exporting a download token'
        }
        if ((gh-download-token) -ne 'fixture-cached-token') { throw 'accessor must return only the download cache' }
    }
    # No cache must not promote the project token or the stored gh login.
    $global:cachedToken = $null
    if (gh-download-token) { throw 'missing download cache must return no token' }
    $env:GH_TOKEN, $env:GITHUB_TOKEN, $env:GITHUB_PERSONAL_ACCESS_TOKEN = $null, $null, $null
    . $auth
    if ($env:GITHUB_TOKEN -or $env:GH_TOKEN -or (gh-download-token)) {
        throw 'shell must not fall back to the stored gh login'
    }
    if ([Environment]::GetEnvironmentVariable('GITHUB_TOKEN', 'User') -ne $userToken) {
        throw 'shell must not change the persistent User environment'
    }
    Write-Output 'Windows tool install and isolated download credential contract ok'
} finally {
    $env:GITHUB_TOKEN = $originalToken
    $env:GITHUB_PERSONAL_ACCESS_TOKEN = $originalLegacyToken
    $env:GH_TOKEN = $originalGhToken
    $env:XDG_DATA_HOME = $originalXdgDataHome
    Remove-Item -LiteralPath $temp -Recurse -Force
}
