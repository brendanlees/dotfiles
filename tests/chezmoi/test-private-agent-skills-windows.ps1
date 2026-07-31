$ErrorActionPreference = 'Stop'
if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$RealGit = (Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$Chezmoi = (Get-Command chezmoi -ErrorAction Stop | Select-Object -First 1).Source
$Stage = Join-Path ([IO.Path]::GetTempPath()) "private-agent-skills-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $Stage | Out-Null

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Initialize-GitRepo([string]$Path) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
    & $RealGit -C $Path init -q
    & $RealGit -C $Path config user.name 'Synthetic Fixture'
    & $RealGit -C $Path config user.email 'fixture@invalid.example'
}

function ConvertTo-TomlString([string]$Value) {
    return $Value.Replace('\', '\\').Replace('"', '\"')
}

function Render-Helper([string]$Source, [string]$Config, [string]$Output, [string]$Override = '') {
    $template = Get-Content -Raw (Join-Path $RepoRoot 'dot_local/bin/executable_cz-private-agent-skills.ps1.tmpl')
    $arguments = @('execute-template', '--source', $Source, '--config', $Config)
    if ($Override) { $arguments += @('--override-data', $Override) }
    $rendered = $template | & $Chezmoi @arguments | Out-String
    [IO.File]::WriteAllText($Output, $rendered, [Text.UTF8Encoding]::new($false))
}

function Invoke-Helper([string]$Helper, [string[]]$Arguments, [bool]$ExpectSuccess = $true) {
    & pwsh -NoProfile -File $Helper @Arguments
    $status = $LASTEXITCODE
    if ($ExpectSuccess -and $status -ne 0) { throw "helper failed with exit $status" }
    if (-not $ExpectSuccess -and $status -eq 0) { throw 'helper unexpectedly succeeded' }
}

function Get-JunctionTarget([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $item -or $item.LinkType -ne 'Junction') { return '' }
    return [IO.Path]::GetFullPath([string]$item.Target).TrimEnd('\', '/')
}

try {
    $runtimeId = [guid]::NewGuid().ToString('N')
    $remote = "git@fixture-$runtimeId.invalid:owner-$runtimeId/repo-$runtimeId.git"
    $firstSkill = "skill-$runtimeId"
    $secondSkill = "second-$runtimeId"
    $thirdSkill = "third-$runtimeId"
    $privateContent = "content-$runtimeId"

    $privateSeed = Join-Path $Stage 'private-seed'
    Initialize-GitRepo $privateSeed
    $firstSource = Join-Path $privateSeed "skills/$firstSkill"
    $draftSource = Join-Path $privateSeed "skills/draft-$runtimeId"
    $nestedSource = Join-Path $privateSeed "skills/nested-$runtimeId/child-$runtimeId"
    New-Item -ItemType Directory -Force -Path $firstSource, $draftSource, $nestedSource | Out-Null
    Set-Content -Encoding utf8NoBOM -Path (Join-Path $firstSource 'SKILL.md') -Value "---`nname: $firstSkill`n---`n$privateContent"
    Set-Content -Encoding utf8NoBOM -Path (Join-Path $draftSource 'README.md') -Value $privateContent
    Set-Content -Encoding utf8NoBOM -Path (Join-Path $nestedSource 'SKILL.md') -Value "---`nname: nested`n---"
    & $RealGit -C $privateSeed add .
    & $RealGit -C $privateSeed commit -qm 'test: initialize synthetic private fixture'

    $fixtureSsh = Join-Path $Stage 'fixture-ssh.cmd'
    @'
@echo off
"%REAL_GIT%" upload-pack "%FIXTURE_PRIVATE_SEED%"
exit /b %ERRORLEVEL%
'@ | Set-Content -Encoding ascii -Path $fixtureSsh
    $env:REAL_GIT = $RealGit
    $env:FIXTURE_PRIVATE_SEED = $privateSeed
    $env:GIT_SSH = $fixtureSsh
    $env:GIT_SSH_VARIANT = 'ssh'

    $publicRoot = Join-Path $Stage 'public'
    Initialize-GitRepo $publicRoot
    $publicSkill = Join-Path $publicRoot 'agents/skills/public-fixture'
    New-Item -ItemType Directory -Force -Path $publicSkill | Out-Null
    Set-Content -Encoding utf8NoBOM -Path (Join-Path $publicSkill 'SKILL.md') -Value 'public'
    Set-Content -Encoding utf8NoBOM -Path (Join-Path $publicRoot '.gitignore') -Value '/agents/state/'
    & $RealGit -C $publicRoot add .
    & $RealGit -C $publicRoot commit -qm 'test: initialize synthetic public fixture'

    $checkout = Join-Path $Stage 'private-checkout'
    $config = Join-Path $Stage 'chezmoi.toml'
    $configContent = @"
[data]
personal = true

[data.private_agent_skills]
remote = "$(ConvertTo-TomlString $remote)"
checkout = "$(ConvertTo-TomlString $checkout)"
"@
    [IO.File]::WriteAllText($config, $configContent, [Text.UTF8Encoding]::new($false))
    $helper = Join-Path $Stage 'cz-private-agent-skills.ps1'
    Render-Helper $publicRoot $config $helper

    Assert-True ((Get-Content -Raw $helper).Contains("`$TemplatePersonal = `$true")) 'personal data did not render'
    Assert-True ((Get-Content -Raw $helper).Contains("`$TemplateOs = 'windows'")) 'Windows data did not render'

    # Negative eligibility with otherwise valid machine-local configuration is a no-op.
    $negativeRoot = Join-Path $Stage 'negative-public'
    Initialize-GitRepo $negativeRoot
    New-Item -ItemType Directory -Force -Path (Join-Path $negativeRoot 'agents/skills/public-fixture') | Out-Null
    Set-Content -Encoding utf8NoBOM -Path (Join-Path $negativeRoot 'agents/skills/public-fixture/SKILL.md') -Value 'public'
    & $RealGit -C $negativeRoot add .
    & $RealGit -C $negativeRoot commit -qm 'test: initialize negative fixture'
    $negativeCheckout = Join-Path $Stage 'negative-checkout'
    $negativeConfig = Join-Path $Stage 'negative.toml'
    [IO.File]::WriteAllText($negativeConfig, $configContent.Replace('personal = true', 'personal = false').Replace((ConvertTo-TomlString $checkout), (ConvertTo-TomlString $negativeCheckout)), [Text.UTF8Encoding]::new($false))
    $negativeHelper = Join-Path $Stage 'negative-helper.ps1'
    Render-Helper $negativeRoot $negativeConfig $negativeHelper
    Invoke-Helper $negativeHelper @('--fail', 'reconcile')
    Assert-True (-not (Test-Path -LiteralPath $negativeCheckout)) 'non-personal checkout was created'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $negativeRoot 'agents/state/private-agent-skills.json'))) 'non-personal state was created'

    # A failed SSH clone leaves no partial checkout or composition state.
    $cloneFailConfig = Join-Path $Stage 'clone-fail.toml'
    [IO.File]::WriteAllText($cloneFailConfig, $configContent.Replace((ConvertTo-TomlString $checkout), (ConvertTo-TomlString $negativeCheckout)), [Text.UTF8Encoding]::new($false))
    $cloneFailHelper = Join-Path $Stage 'clone-fail-helper.ps1'
    Render-Helper $negativeRoot $cloneFailConfig $cloneFailHelper
    $failSsh = Join-Path $Stage 'fail-ssh.cmd'
    "@echo off`r`nexit /b 1`r`n" | Set-Content -Encoding ascii -Path $failSsh
    $env:GIT_SSH = $failSsh
    try { Invoke-Helper $cloneFailHelper @('reconcile') }
    finally { $env:GIT_SSH = $fixtureSsh }
    Assert-True (-not (Test-Path -LiteralPath $negativeCheckout)) 'failed clone left checkout content'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $negativeRoot 'agents/state/private-agent-skills.json'))) 'failed clone left state'
    Assert-True (@(Get-ChildItem -LiteralPath $Stage -Filter '.negative-checkout.cz-private-agent-skills.*.tmp' -Force).Count -eq 0) 'failed clone left a temporary sibling'

    # Bootstrap and direct junction composition.
    Invoke-Helper $helper @('--fail', 'reconcile')
    $firstDestination = Join-Path $publicRoot "agents/skills/$firstSkill"
    Assert-True (Test-Path -LiteralPath (Join-Path $checkout '.git')) 'checkout was not cloned'
    Assert-True ((Get-JunctionTarget $firstDestination).Equals((Join-Path $checkout "skills/$firstSkill"), [StringComparison]::OrdinalIgnoreCase)) 'private junction target is wrong'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $publicRoot "agents/skills/draft-$runtimeId"))) 'draft was composed'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $publicRoot "agents/skills/nested-$runtimeId"))) 'nested skill was composed'
    $stateFile = Join-Path $publicRoot 'agents/state/private-agent-skills.json'
    $excludeFile = Join-Path $publicRoot '.git/info/exclude'
    $ledger = Get-Content -Raw $stateFile | ConvertFrom-Json
    Assert-True ($ledger.schema_version -eq 1 -and @($ledger.entries).Count -eq 1) 'initial ledger is invalid'
    Assert-True (@(Get-Content $excludeFile | Where-Object { $_ -ceq "agents/skills/$firstSkill" }).Count -eq 1) 'exact exclude is missing'
    Assert-True (-not (& $RealGit -C $publicRoot status --porcelain)) 'public Git became dirty'

    $stateHash = (Get-FileHash -Algorithm SHA256 $stateFile).Hash
    $excludeHash = (Get-FileHash -Algorithm SHA256 $excludeFile).Hash
    Invoke-Helper $helper @('--fail', 'reconcile')
    Assert-True ((Get-FileHash -Algorithm SHA256 $stateFile).Hash -eq $stateHash) 'second reconcile changed state'
    Assert-True ((Get-FileHash -Algorithm SHA256 $excludeFile).Hash -eq $excludeHash) 'second reconcile changed excludes'

    # Dirty inventory reconciles, interrupted operations pause, and collisions remain untouched.
    Add-Content -LiteralPath (Join-Path $firstDestination 'SKILL.md') -Value $privateContent
    Assert-True ([bool](& $RealGit -C $checkout status --porcelain)) 'private edit did not dirty private Git'
    Assert-True (-not (& $RealGit -C $publicRoot status --porcelain)) 'private edit dirtied public Git'
    $secondSource = Join-Path $checkout "skills/$secondSkill"
    New-Item -ItemType Directory -Force -Path $secondSource | Out-Null
    Set-Content -Encoding utf8NoBOM -Path (Join-Path $secondSource 'SKILL.md') -Value "---`nname: $secondSkill`n---"
    Invoke-Helper $helper @('--fail', 'reconcile')
    $secondDestination = Join-Path $publicRoot "agents/skills/$secondSkill"
    Assert-True ([bool](Get-JunctionTarget $secondDestination)) 'dirty inventory did not reconcile'

    $thirdSource = Join-Path $checkout "skills/$thirdSkill"
    New-Item -ItemType Directory -Force -Path $thirdSource | Out-Null
    Set-Content -Encoding utf8NoBOM -Path (Join-Path $thirdSource 'SKILL.md') -Value "---`nname: $thirdSkill`n---"
    Set-Content -Encoding ascii -Path (Join-Path $checkout '.git/MERGE_HEAD') -Value 'synthetic'
    Invoke-Helper $helper @('--fail', 'reconcile') $false
    $thirdDestination = Join-Path $publicRoot "agents/skills/$thirdSkill"
    Assert-True (-not (Test-Path -LiteralPath $thirdDestination)) 'interrupted Git operation changed composition'
    Remove-Item -LiteralPath (Join-Path $checkout '.git/MERGE_HEAD')
    Set-Content -Encoding ascii -Path $thirdDestination -Value 'collision'
    Invoke-Helper $helper @('--fail', 'reconcile') $false
    Assert-True ((Get-Content -Raw $thirdDestination).Trim() -eq 'collision') 'collision was changed'
    Remove-Item -LiteralPath $thirdDestination
    Invoke-Helper $helper @('--fail', 'reconcile')
    Assert-True ([bool](Get-JunctionTarget $thirdDestination)) 'reconcile did not recover after collision removal'

    # Missing and stale owned junctions are repaired or removed without target deletion.
    [IO.Directory]::Delete($secondDestination, $false)
    Invoke-Helper $helper @('--fail', 'reconcile')
    Assert-True ([bool](Get-JunctionTarget $secondDestination)) 'missing junction was not repaired'
    Set-Content -Encoding ascii -Path (Join-Path $secondSource 'preserve.txt') -Value 'preserve'
    Remove-Item -LiteralPath (Join-Path $secondSource 'SKILL.md')
    Invoke-Helper $helper @('--fail', 'reconcile')
    Assert-True (-not (Test-Path -LiteralPath $secondDestination)) 'stale junction was not removed'
    Assert-True (Test-Path -LiteralPath (Join-Path $secondSource 'preserve.txt')) 'stale cleanup deleted private content'

    # Malformed state and uncertain junction ownership fail closed.
    $validState = [IO.File]::ReadAllText($stateFile)
    [IO.File]::WriteAllText($stateFile, '{not-json', [Text.UTF8Encoding]::new($false))
    Invoke-Helper $helper @('--fail', 'reconcile') $false
    Assert-True ([bool](Get-JunctionTarget $firstDestination)) 'malformed state changed composition'
    [IO.File]::WriteAllText($stateFile, $validState, [Text.UTF8Encoding]::new($false))
    [IO.Directory]::Delete($firstDestination, $false)
    New-Item -ItemType Junction -Path $firstDestination -Target $thirdSource | Out-Null
    Invoke-Helper $helper @('--fail', 'reconcile') $false
    Assert-True ((Get-JunctionTarget $firstDestination).Equals($thirdSource, [StringComparison]::OrdinalIgnoreCase)) 'uncertain junction was replaced'
    [IO.Directory]::Delete($firstDestination, $false)
    New-Item -ItemType Junction -Path $firstDestination -Target (Join-Path $checkout "skills/$firstSkill") | Out-Null

    # Remote mismatch is non-fatal by default and blocks only integration.
    & $RealGit -C $checkout remote set-url origin "git@wrong-$runtimeId.invalid:wrong/repo.git"
    & pwsh -NoProfile -File $helper reconcile *> $null
    Assert-True ($LASTEXITCODE -eq 0) 'automatic failure was not isolated'
    & $RealGit -C $checkout remote set-url origin $remote

    # Deactivate, reactivate, reject unconfirmed finalization, then finalize exactly once.
    Invoke-Helper $helper @('--fail', 'deactivate')
    Assert-True (Test-Path -LiteralPath $checkout) 'deactivation deleted checkout'
    Assert-True (-not (Test-Path -LiteralPath $firstDestination)) 'deactivation left discovery junction'
    Assert-True ((Get-Content -Raw $stateFile | ConvertFrom-Json).decommission_pending) 'deactivation did not persist pending state'
    Invoke-Helper $helper @('--fail', 'reconcile')
    Assert-True ([bool](Get-JunctionTarget $firstDestination)) 'reactivation did not restore junction'
    Invoke-Helper $helper @('--fail', 'deactivate')
    Invoke-Helper $helper @('--fail', 'finalize') $false
    Assert-True (Test-Path -LiteralPath $checkout) 'unconfirmed finalization deleted checkout'
    Invoke-Helper $helper @('--fail', 'finalize', '--confirm-delete')
    Assert-True (-not (Test-Path -LiteralPath $checkout)) 'confirmed finalization left checkout'
    Assert-True (-not (Test-Path -LiteralPath $stateFile)) 'confirmed finalization left ledger'
    Assert-True (-not ([IO.File]::ReadAllText($config).Contains('[data.private_agent_skills]'))) 'confirmed finalization left configuration'
    Assert-True (-not (& $RealGit -C $publicRoot status --porcelain)) 'public Git is dirty after finalization'

    # Runtime confidentiality values remain absent from tracked public source and inventory.
    $trackedInventory = @(& $RealGit -C $publicRoot ls-files) -join "`n"
    foreach ($value in @($remote, $checkout, $firstSkill, $privateContent)) {
        & $RealGit -C $RepoRoot grep -Fq -- $value
        if ($LASTEXITCODE -eq 0 -or $trackedInventory.Contains($value, [StringComparison]::Ordinal)) {
            throw 'runtime confidentiality value crossed the public boundary'
        }
    }

    Write-Host 'private agent skills Windows lifecycle ok'
}
finally {
    Remove-Item Env:REAL_GIT -ErrorAction SilentlyContinue
    Remove-Item Env:FIXTURE_PRIVATE_SEED -ErrorAction SilentlyContinue
    Remove-Item Env:GIT_SSH -ErrorAction SilentlyContinue
    Remove-Item Env:GIT_SSH_VARIANT -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $Stage -Recurse -Force -ErrorAction SilentlyContinue
}
