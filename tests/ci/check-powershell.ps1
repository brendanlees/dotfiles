$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$Config = $env:CHEZMOI_CONFIG_FILE
if (-not $Config) {
    throw 'CHEZMOI_CONFIG_FILE must name an initialized config'
}

$Chezmoi = (Get-Command chezmoi -ErrorAction Stop).Source
$Stage = Join-Path ([System.IO.Path]::GetTempPath()) "chezmoi-pwsh-$PID"
New-Item -ItemType Directory -Force -Path $Stage | Out-Null
$Failures = [System.Collections.Generic.List[string]]::new()

function Test-PowerShellFile([string]$Path) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $Path, [ref]$tokens, [ref]$errors
    ) | Out-Null
    foreach ($parseError in $errors) {
        $Failures.Add(
            "${Path}:$($parseError.Extent.StartLineNumber): $($parseError.Message)"
        )
    }
}

$OriginalPath = $env:PATH
$pathSeparator = [System.IO.Path]::PathSeparator
$env:PATH = (($OriginalPath -split [regex]::Escape($pathSeparator)) |
    Where-Object {
        $_ -and
        -not (Test-Path (Join-Path $_ 'bw')) -and
        -not (Test-Path (Join-Path $_ 'bw.exe'))
    }) -join $pathSeparator

try {
    git -C $RepoRoot ls-files '*.ps1' |
        Where-Object { $_ } |
        ForEach-Object {
            Test-PowerShellFile (Join-Path $RepoRoot $_)
        }

    git -C $RepoRoot ls-files '*.ps1.tmpl' |
        Where-Object { $_ } |
        ForEach-Object {
            $relative = $_
            $source = Join-Path $RepoRoot $relative
            $safeName = (($relative -replace '[\/]', '__') -replace '\.tmpl$', '')
            $output = Join-Path $Stage $safeName
            try {
                $rendered = Get-Content -Raw $source |
                    & $Chezmoi execute-template --source $RepoRoot --config $Config |
                    Out-String
                if ($rendered.Trim().Length -gt 0) {
                    Set-Content -Encoding utf8NoBOM -Path $output -Value $rendered
                    Test-PowerShellFile $output
                }
            }
            catch {
                $Failures.Add("${relative}: template render failed: $_")
            }
        }

    if ($Failures.Count -gt 0) {
        $Failures | ForEach-Object { Write-Error $_ }
        exit 1
    }
    Write-Host 'PowerShell static and rendered syntax ok'
}
finally {
    $env:PATH = $OriginalPath
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $Stage
}
