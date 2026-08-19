<#
.SYNOPSIS
  Installs recommended VS Code / Cursor extensions for BIS-F development.

.DESCRIPTION
  Reads .vscode/extensions.json recommendations and installs each extension
  via `cursor` if available, otherwise `code`. Idempotent.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$extensionsJson = Join-Path $repoRoot '.vscode\extensions.json'

if (-not (Test-Path -LiteralPath $extensionsJson)) {
    Write-Error "Missing $extensionsJson"
}

$raw = Get-Content -LiteralPath $extensionsJson -Raw
# Strip // comments if present (VS Code JSONC)
$raw = [regex]::Replace($raw, '(?m)^\s*//.*$', '')
$json = $raw | ConvertFrom-Json
$extensions = @($json.recommendations)

if ($extensions.Count -eq 0) {
    Write-Host 'No extensions listed in .vscode/extensions.json'
    exit 0
}

$cli = $null
foreach ($candidate in @('cursor', 'code')) {
    if (Get-Command $candidate -ErrorAction SilentlyContinue) {
        $cli = $candidate
        break
    }
}

if (-not $cli) {
    Write-Error 'Neither `cursor` nor `code` was found on PATH. Install Cursor or VS Code CLI, or accept the workspace extension recommendations when prompted.'
}

Write-Host "Using CLI: $cli"
$failed = @()

foreach ($ext in $extensions) {
    Write-Host "Installing $ext ..."
    & $cli --install-extension $ext --force
    if ($LASTEXITCODE -ne 0) {
        $failed += $ext
        Write-Warning "Failed to install $ext (exit $LASTEXITCODE)"
    }
}

if ($failed.Count -gt 0) {
    Write-Error ("Failed to install: {0}" -f ($failed -join ', '))
    exit 1
}

Write-Host 'All recommended extensions installed.' -ForegroundColor Green
exit 0
