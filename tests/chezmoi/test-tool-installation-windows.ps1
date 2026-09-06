$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$temp = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
[IO.Directory]::CreateDirectory($temp) | Out-Null
$originalToken = $env:GITHUB_TOKEN
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
        (Join-Path $repoRoot 'home/.chezmoiscripts/windows/run_after_install_tools.ps1.tmpl') |
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
    Write-Output 'Windows tool install and process-only token contract ok'
} finally {
    $env:GITHUB_TOKEN = $originalToken
    Remove-Item -LiteralPath $temp -Recurse -Force
}
