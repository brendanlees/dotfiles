$ErrorActionPreference = 'Stop'
if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$SourceRoot = Join-Path $RepoRoot 'home'
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

function Render-Helper([string]$Source, [string]$Config, [string]$Output) {
    $template = Get-Content -Raw (Join-Path $SourceRoot 'dot_local/bin/executable_cz-private-agent-skills.ps1.tmpl')
    $rendered = $template | & $Chezmoi execute-template --source $Source --config $Config | Out-String
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
    $remote = 'git@fixture.invalid:owner/private-skills.git'
    $firstSkill = 'alpha-skill'
    $secondSkill = 'beta-skill'
    $thirdSkill = 'gamma-skill'

    $privateSeed = Join-Path $Stage 'private-seed'
    Initialize-GitRepo $privateSeed
    $firstSource = Join-Path $privateSeed "skills/$firstSkill"
    $draftSource = Join-Path $privateSeed 'skills/draft-skill'
    $nestedSource = Join-Path $privateSeed 'skills/nested-skill/child'
    New-Item -ItemType Directory -Force -Path $firstSource, $draftSource, $nestedSource | Out-Null
    Set-Content -Encoding utf8NoBOM -Path (Join-Path $firstSource 'SKILL.md') -Value "---`nname: $firstSkill`n---`nprivate fixture"
    Set-Content -Encoding utf8NoBOM -Path (Join-Path $draftSource 'README.md') -Value 'draft'
    Set-Content -Encoding utf8NoBOM -Path (Join-Path $nestedSource 'SKILL.md') -Value "---`nname: nested`n---"
    & $RealGit -C $privateSeed add .
    & $RealGit -C $privateSeed commit -qm 'test: initialize private fixture'

    $publicRoot = Join-Path $Stage 'public'
    Initialize-GitRepo $publicRoot
    $publicSkill = Join-Path $publicRoot 'agents/skills/public-fixture'
    New-Item -ItemType Directory -Force -Path $publicSkill, (Join-Path $publicRoot 'home') | Out-Null
    Set-Content -Encoding utf8NoBOM -Path (Join-Path $publicRoot '.chezmoiroot') -Value 'home'
    Set-Content -Encoding utf8NoBOM -Path (Join-Path $publicSkill 'SKILL.md') -Value 'public'
    Set-Content -Encoding utf8NoBOM -Path (Join-Path $publicRoot '.gitignore') -Value '/agents/state/'
    & $RealGit -C $publicRoot add .
    & $RealGit -C $publicRoot commit -qm 'test: initialize public fixture'

    $checkout = Join-Path $Stage 'private-checkout'
    $config = Join-Path $Stage 'chezmoi.toml'
    $helper = Join-Path $Stage 'cz-private-agent-skills.ps1'
    $configContent = @"
[data]
personal = true

[data.private_agent_skills]
remote = "$(ConvertTo-TomlString $remote)"
checkout = "$(ConvertTo-TomlString $checkout)"
"@

    # Negative eligibility and clone failure reuse the same untouched public fixture.
    [IO.File]::WriteAllText($config, $configContent.Replace('personal = true', 'personal = false'), [Text.UTF8Encoding]::new($false))
    Render-Helper $publicRoot $config $helper
    Invoke-Helper $helper @('--fail', 'reconcile')
    $stateFile = Join-Path $publicRoot 'agents/state/private-agent-skills.json'
    Assert-True (-not (Test-Path -LiteralPath $checkout)) 'non-personal checkout was created'
    Assert-True (-not (Test-Path -LiteralPath $stateFile)) 'non-personal state was created'

    [IO.File]::WriteAllText($config, $configContent, [Text.UTF8Encoding]::new($false))
    Render-Helper $publicRoot $config $helper
    $failSsh = Join-Path $Stage 'fail-ssh.cmd'
    "@echo off`r`nexit /b 1`r`n" | Set-Content -Encoding ascii -Path $failSsh
    $env:GIT_SSH = $failSsh
    try { Invoke-Helper $helper @('reconcile') }
    finally { Remove-Item Env:GIT_SSH -ErrorAction SilentlyContinue }
    Assert-True (-not (Test-Path -LiteralPath $checkout)) 'failed clone left checkout content'
    Assert-True (-not (Test-Path -LiteralPath $stateFile)) 'failed clone left state'
    Assert-True (@(Get-ChildItem -LiteralPath $Stage -Filter '.private-checkout.cz-private-agent-skills.*.tmp' -Force).Count -eq 0) 'failed clone left a temporary sibling'

    # Existing checkout reconciliation composes direct skills and exact excludes.
    & $RealGit clone --quiet $privateSeed $checkout
    & $RealGit -C $checkout remote set-url origin $remote
    Invoke-Helper $helper @('--fail', 'reconcile')
    $firstDestination = Join-Path $publicRoot "agents/skills/$firstSkill"
    $secondDestination = Join-Path $publicRoot "agents/skills/$secondSkill"
    $thirdDestination = Join-Path $publicRoot "agents/skills/$thirdSkill"
    $excludeFile = Join-Path $publicRoot '.git/info/exclude'
    Assert-True ((Get-JunctionTarget $firstDestination).Equals((Join-Path $checkout "skills/$firstSkill"), [StringComparison]::OrdinalIgnoreCase)) 'private junction target is wrong'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $publicRoot 'agents/skills/draft-skill'))) 'draft was composed'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $publicRoot 'agents/skills/nested-skill'))) 'nested skill was composed'
    $ledger = Get-Content -Raw $stateFile | ConvertFrom-Json
    Assert-True ($ledger.schema_version -eq 1 -and @($ledger.entries).Count -eq 1) 'initial ledger is invalid'
    Assert-True (@(Get-Content $excludeFile | Where-Object { $_ -ceq "agents/skills/$firstSkill" }).Count -eq 1) 'exact exclude is missing'
    Assert-True (-not (& $RealGit -C $publicRoot status --porcelain)) 'public Git became dirty'

    # Dirty private state can reconcile additions, but interrupted operations cannot.
    Add-Content -LiteralPath (Join-Path $firstDestination 'SKILL.md') -Value 'edited'
    $secondSource = Join-Path $checkout "skills/$secondSkill"
    New-Item -ItemType Directory -Force -Path $secondSource | Out-Null
    Set-Content -Encoding utf8NoBOM -Path (Join-Path $secondSource 'SKILL.md') -Value "---`nname: $secondSkill`n---"
    Invoke-Helper $helper @('--fail', 'reconcile')
    Assert-True ([bool](Get-JunctionTarget $secondDestination)) 'dirty inventory did not reconcile'
    Assert-True ([bool](& $RealGit -C $checkout status --porcelain)) 'private edit did not dirty private Git'
    Assert-True (-not (& $RealGit -C $publicRoot status --porcelain)) 'private edit dirtied public Git'

    $thirdSource = Join-Path $checkout "skills/$thirdSkill"
    New-Item -ItemType Directory -Force -Path $thirdSource | Out-Null
    Set-Content -Encoding utf8NoBOM -Path (Join-Path $thirdSource 'SKILL.md') -Value "---`nname: $thirdSkill`n---"
    Set-Content -Encoding ascii -Path (Join-Path $checkout '.git/MERGE_HEAD') -Value 'synthetic'
    Invoke-Helper $helper @('--fail', 'reconcile') $false
    Assert-True (-not (Test-Path -LiteralPath $thirdDestination)) 'interrupted Git operation changed composition'
    Remove-Item -LiteralPath (Join-Path $checkout '.git/MERGE_HEAD')

    # Collisions and uncertain owned-junction targets fail closed.
    Set-Content -Encoding ascii -Path $thirdDestination -Value 'collision'
    Invoke-Helper $helper @('--fail', 'reconcile') $false
    Assert-True ((Get-Content -Raw $thirdDestination).Trim() -eq 'collision') 'collision was changed'
    Remove-Item -LiteralPath $thirdDestination
    Invoke-Helper $helper @('--fail', 'reconcile')
    Assert-True ([bool](Get-JunctionTarget $thirdDestination)) 'reconcile did not recover after collision removal'

    [IO.Directory]::Delete($firstDestination, $false)
    New-Item -ItemType Junction -Path $firstDestination -Target $thirdSource | Out-Null
    Invoke-Helper $helper @('--fail', 'reconcile') $false
    Assert-True ((Get-JunctionTarget $firstDestination).Equals($thirdSource, [StringComparison]::OrdinalIgnoreCase)) 'uncertain junction was replaced'
    [IO.Directory]::Delete($firstDestination, $false)
    New-Item -ItemType Junction -Path $firstDestination -Target (Join-Path $checkout "skills/$firstSkill") | Out-Null

    # Stale junctions and excludes are removed without deleting private content.
    Set-Content -Encoding ascii -Path (Join-Path $secondSource 'preserve.txt') -Value 'preserve'
    Remove-Item -LiteralPath (Join-Path $secondSource 'SKILL.md')
    Invoke-Helper $helper @('--fail', 'reconcile')
    Assert-True (-not (Test-Path -LiteralPath $secondDestination)) 'stale junction was not removed'
    Assert-True (Test-Path -LiteralPath (Join-Path $secondSource 'preserve.txt')) 'stale cleanup deleted private content'
    Assert-True (@(Get-Content $excludeFile | Where-Object { $_ -ceq "agents/skills/$secondSkill" }).Count -eq 0) 'stale exclude was not removed'

    # Legacy fields are accepted. Deactivate preserves checkout and machine config.
    $legacyLedger = Get-Content -Raw $stateFile | ConvertFrom-Json
    $legacyLedger | Add-Member -NotePropertyName decommission_pending -NotePropertyValue $false
    $legacyLedger | Add-Member -NotePropertyName recorded_checkout -NotePropertyValue $null
    $legacyLedger | Add-Member -NotePropertyName checkout_deleted -NotePropertyValue $false
    [IO.File]::WriteAllText($stateFile, ($legacyLedger | ConvertTo-Json -Depth 5) + "`n", [Text.UTF8Encoding]::new($false))
    $ownedExcludes = @($legacyLedger.entries | ForEach-Object { [string]$_.exclude })
    Add-Content -Encoding utf8NoBOM -LiteralPath $excludeFile -Value 'keep/exclude'
    $configBefore = [IO.File]::ReadAllText($config)
    $checkoutMarker = Join-Path $checkout 'preserve-private-checkout.txt'
    [IO.File]::WriteAllText($checkoutMarker, 'preserve', [Text.UTF8Encoding]::new($false))

    Invoke-Helper $helper @('--fail', 'deactivate')
    Assert-True (Test-Path -LiteralPath $checkoutMarker -PathType Leaf) 'deactivation changed the private checkout'
    Assert-True (-not (Test-Path -LiteralPath $firstDestination)) 'deactivation left an owned junction'
    Assert-True (-not (Test-Path -LiteralPath $thirdDestination)) 'deactivation left an owned junction'
    Assert-True (-not (Test-Path -LiteralPath $stateFile)) 'deactivation left its ledger'
    Assert-True ([IO.File]::ReadAllText($config) -ceq $configBefore) 'deactivation changed machine config'
    Assert-True (@(Get-Content $excludeFile | Where-Object { $_ -ceq 'keep/exclude' }).Count -eq 1) 'deactivation removed an unrelated exclude'
    foreach ($exclude in $ownedExcludes) {
        Assert-True (@(Get-Content $excludeFile | Where-Object { $_ -ceq $exclude }).Count -eq 0) "deactivation left owned exclude: $exclude"
    }

    Invoke-Helper $helper @('--fail', 'deactivate')
    Invoke-Helper $helper @('--fail', 'reconcile')
    Assert-True ([bool](Get-JunctionTarget $firstDestination)) 'reconcile did not restore integration'
    Assert-True (Test-Path -LiteralPath $checkoutMarker -PathType Leaf) 'reactivation changed private checkout'
    Assert-True ([IO.File]::ReadAllText($config) -ceq $configBefore) 'reactivation changed machine config'
    Assert-True (-not (& $RealGit -C $publicRoot status --porcelain)) 'public Git is dirty after reactivation'

    Write-Host 'private agent skills Windows integration ok'
}
finally {
    Remove-Item Env:GIT_SSH -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $Stage -Recurse -Force -ErrorAction SilentlyContinue
}
