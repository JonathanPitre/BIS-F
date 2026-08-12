<#
.SYNOPSIS
  Runs PSScriptAnalyzer against BIS-F Framework scripts.

.DESCRIPTION
  Recurses Framework for .ps1 / .psm1 / .psd1, applies
  .vscode/PSScriptAnalyzerSettings.psd1, and exits non-zero on findings.
  Default severity is Error (CI gate). Pass -Severity to include Warnings.

.PARAMETER Severity
  Severities to fail on. Default: Error

.PARAMETER Path
  Root path to scan. Default: Framework under the repo root.
#>
[CmdletBinding()]
param(
    [ValidateSet('Error', 'Warning', 'Information')]
    [string[]]$Severity = @('Error'),

    [string]$Path
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
if (-not $Path) {
    $Path = Join-Path $repoRoot 'Framework'
}
$settingsPath = Join-Path $repoRoot '.vscode\PSScriptAnalyzerSettings.psd1'

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Error 'PSScriptAnalyzer is not installed. Run: Install-Module PSScriptAnalyzer -Scope CurrentUser'
}

if (-not (Test-Path -LiteralPath $settingsPath)) {
    Write-Error "Settings file not found: $settingsPath"
}

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Error "Scan path not found: $Path"
}

Write-Host "Scanning: $Path"
Write-Host "Settings: $settingsPath"
Write-Host "Severity: $($Severity -join ', ')"

$results = @(Invoke-ScriptAnalyzer -Path $Path -Recurse -Settings $settingsPath -Severity $Severity -ErrorAction SilentlyContinue)

if ($results.Count -gt 0) {
    $results | Format-Table -AutoSize Severity, RuleName, ScriptName, Line, Message
    Write-Error ("PSScriptAnalyzer: {0} finding(s)" -f $results.Count)
    exit 1
}

Write-Host 'PSScriptAnalyzer passed.' -ForegroundColor Green
exit 0
