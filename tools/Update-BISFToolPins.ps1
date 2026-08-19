<#
.SYNOPSIS
  Refresh CI tool pins in .github/tool-versions.env when newer versions exist.

.DESCRIPTION
  Checks PowerShell Gallery (PSScriptAnalyzer), microsoft/codeql releases
  (powershell.zip extractor), and GHCR (microsoft/powershell-queries).
  Writes updates in place. Exit 0 always; sets GITHUB_OUTPUT has_changes when
  running in Actions.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$VersionsFile = '.github/tool-versions.env'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$versionsPath = Join-Path $RepoRoot $VersionsFile
if (-not (Test-Path -LiteralPath $versionsPath)) {
    throw "Versions file not found: $versionsPath"
}

function Get-EnvMap {
    param([string]$Path)
    $map = [ordered]@{}
    Get-Content -LiteralPath $Path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith('#')) { return }
        $parts = $line.Split('=', 2)
        if ($parts.Count -ne 2) { return }
        $map[$parts[0].Trim()] = $parts[1].Trim()
    }
    return $map
}

function ConvertTo-Version {
    param([string]$Text)
    $clean = ($Text -replace '^v', '').Trim()
    try { return [version]$clean } catch { return $null }
}

function Get-LatestPsScriptAnalyzerVersion {
    if (-not (Get-Command Find-Module -ErrorAction SilentlyContinue)) {
        throw 'Find-Module is unavailable. Run on PowerShell with PowerShellGet.'
    }
    $mod = Find-Module -Name PSScriptAnalyzer -Repository PSGallery -ErrorAction Stop
    return [string]$mod.Version
}

function Get-LatestCodeQlPowerShellRelease {
    $uri = 'https://api.github.com/repos/microsoft/codeql/releases?per_page=30'
    $headers = @{
        Accept                 = 'application/vnd.github+json'
        'User-Agent'           = 'BIS-F-Update-BISFToolPins'
        'X-GitHub-Api-Version' = '2022-11-28'
    }
    if ($env:GITHUB_TOKEN) {
        $headers['Authorization'] = "Bearer $($env:GITHUB_TOKEN)"
    }

    $releases = Invoke-RestMethod -Uri $uri -Headers $headers
    $candidates = foreach ($rel in $releases) {
        if ($rel.tag_name -notmatch '^codeql-cli/v') { continue }
        $asset = @($rel.assets | Where-Object { $_.name -eq 'powershell.zip' })
        if ($asset.Count -eq 0) { continue }
        $verText = ($rel.tag_name -replace '^codeql-cli/v', '')
        $ver = ConvertTo-Version $verText
        if (-not $ver) { continue }
        [PSCustomObject]@{ Tag = [string]$rel.tag_name; Version = $ver }
    }

    $best = $candidates | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $best) {
        throw 'No microsoft/codeql release with powershell.zip and codeql-cli/v* tag found.'
    }
    return $best.Tag
}

function Get-LatestPowerShellQueriesPackVersion {
    $tokenUri = 'https://ghcr.io/token?service=ghcr.io&scope=repository:microsoft/powershell-queries:pull'
    $token = (Invoke-RestMethod -Uri $tokenUri).token
    $tagsUri = 'https://ghcr.io/v2/microsoft/powershell-queries/tags/list'
    $tags = (Invoke-RestMethod -Uri $tagsUri -Headers @{ Authorization = "Bearer $token" }).tags
    if (-not $tags) {
        throw 'No tags returned for microsoft/powershell-queries on GHCR.'
    }

    $best = $tags |
        ForEach-Object {
            $v = ConvertTo-Version $_
            if ($v) { [PSCustomObject]@{ Tag = [string]$_; Version = $v } }
        } |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if (-not $best) {
        throw 'Could not parse any semver tags for microsoft/powershell-queries.'
    }
    return $best.Tag
}

$map = Get-EnvMap -Path $versionsPath
$currentPssa = [string]$map['PSSCRIPTANALYZER_VERSION']
$currentRelease = [string]$map['CODEQL_POWERSHELL_RELEASE']
$currentPack = [string]$map['CODEQL_POWERSHELL_PACK_VERSION']

Write-Host "Current PSSCRIPTANALYZER_VERSION=$currentPssa"
Write-Host "Current CODEQL_POWERSHELL_RELEASE=$currentRelease"
Write-Host "Current CODEQL_POWERSHELL_PACK_VERSION=$currentPack"

$latestPssa = Get-LatestPsScriptAnalyzerVersion
$latestRelease = Get-LatestCodeQlPowerShellRelease
$latestPack = Get-LatestPowerShellQueriesPackVersion

Write-Host "Latest  PSSCRIPTANALYZER_VERSION=$latestPssa"
Write-Host "Latest  CODEQL_POWERSHELL_RELEASE=$latestRelease"
Write-Host "Latest  CODEQL_POWERSHELL_PACK_VERSION=$latestPack"

$changed = @()
if ($latestPssa -ne $currentPssa) {
    $map['PSSCRIPTANALYZER_VERSION'] = $latestPssa
    $changed += "PSScriptAnalyzer $currentPssa -> $latestPssa"
}
if ($latestRelease -ne $currentRelease) {
    $map['CODEQL_POWERSHELL_RELEASE'] = $latestRelease
    $changed += "CodeQL PowerShell extractor $currentRelease -> $latestRelease"
}
if ($latestPack -ne $currentPack) {
    $map['CODEQL_POWERSHELL_PACK_VERSION'] = $latestPack
    $changed += "CodeQL powershell-queries $currentPack -> $latestPack"
}

$hasChanges = $changed.Count -gt 0
if ($hasChanges -and $PSCmdlet.ShouldProcess($versionsPath, 'Update tool pins')) {
    $lines = @(
        '# Shared CI tool pins (updated by tools/Update-BISFToolPins.ps1 / update-tool-pins.yml).'
        '# Dependabot covers GitHub Actions; this file covers everything else.'
        ''
        "PSSCRIPTANALYZER_VERSION=$($map['PSSCRIPTANALYZER_VERSION'])"
        "CODEQL_POWERSHELL_RELEASE=$($map['CODEQL_POWERSHELL_RELEASE'])"
        "CODEQL_POWERSHELL_PACK_VERSION=$($map['CODEQL_POWERSHELL_PACK_VERSION'])"
        ''
    )
    Set-Content -LiteralPath $versionsPath -Value $lines -Encoding utf8
    Write-Host "Updated $versionsPath"
    $changed | ForEach-Object { Write-Host " - $_" }
}
elseif (-not $hasChanges) {
    Write-Host 'No tool pin updates available.'
}

$summary = if ($hasChanges) { ($changed -join '; ') } else { 'none' }
if ($env:GITHUB_OUTPUT) {
    $hasChangesOut = if ($hasChanges) { 'true' } else { 'false' }
    "has_changes=$hasChangesOut" | Add-Content -LiteralPath $env:GITHUB_OUTPUT
    "summary=$summary" | Add-Content -LiteralPath $env:GITHUB_OUTPUT
}
