<#
.SYNOPSIS
  Ensures PowerShell scripts are saved as UTF-8 with BOM (Windows PowerShell 5.1).

.DESCRIPTION
  Scans *.ps1 / *.psm1 / *.psd1 under the repo. Exit code 1 when any file is missing
  the UTF-8 BOM (EF BB BF). Pass -Fix to rewrite those files as UTF-8 with BOM while
  preserving existing line endings.

.PARAMETER Path
  Root path to scan. Default: repository root (parent of tools/).

.PARAMETER Fix
  Rewrite files that lack a UTF-8 BOM.

.PARAMETER ChangedOnly
  Scan only added/modified .ps1/.psm1/.psd1 vs the merge base
  (GITHUB_BASE_REF / origin/<base> when present, otherwise HEAD~1).

.PARAMETER BaseRef
  Optional git ref to diff against when -ChangedOnly is set.
#>
[CmdletBinding()]
param(
	[string]$Path,

	[switch]$Fix,

	[switch]$ChangedOnly,

	[string]$BaseRef
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Utf8Bom = [byte[]](0xEF, 0xBB, 0xBF)
$RepoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')
if (-not $Path) {
	$Path = $RepoRoot.Path
}
else {
	$Path = (Resolve-Path -LiteralPath $Path).Path
}

function Test-HasUtf8Bom {
	param([Parameter(Mandatory)][string]$FilePath)

	$Stream = [System.IO.File]::OpenRead($FilePath)
	try {
		if ($Stream.Length -lt 3) { return $false }
		$Header = New-Object byte[] 3
		$null = $Stream.Read($Header, 0, 3)
		return ($Header[0] -eq $Utf8Bom[0] -and $Header[1] -eq $Utf8Bom[1] -and $Header[2] -eq $Utf8Bom[2])
	}
	finally {
		$Stream.Dispose()
	}
}

function Repair-Utf8Bom {
	param([Parameter(Mandatory)][string]$FilePath)

	$Bytes = [System.IO.File]::ReadAllBytes($FilePath)
	$Offset = 0
	if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
		return $false
	}
	# Strip UTF-16 BOM if present (unexpected but recoverable)
	if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) {
		$Text = [System.Text.Encoding]::Unicode.GetString($Bytes, 2, $Bytes.Length - 2)
	}
	elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF) {
		$Text = [System.Text.Encoding]::BigEndianUnicode.GetString($Bytes, 2, $Bytes.Length - 2)
	}
	else {
		# Prefer UTF-8 decode; fall back to Default only if invalid UTF-8
		$Utf8Strict = New-Object System.Text.UTF8Encoding $false, $true
		try {
			$Text = $Utf8Strict.GetString($Bytes)
		}
		catch {
			Write-Warning "File is not valid UTF-8; decoding with system ANSI: $FilePath"
			$Text = [System.Text.Encoding]::Default.GetString($Bytes)
		}
	}

	$Utf8WithBom = New-Object System.Text.UTF8Encoding $true
	[System.IO.File]::WriteAllText($FilePath, $Text, $Utf8WithBom)
	return $true
}

function Get-ChangedPowerShellFiles {
	param(
		[Parameter(Mandatory)][string]$Root,
		[string]$CompareRef
	)

	$GitRoot = $RepoRoot.Path
	Push-Location $GitRoot
	try {
		if (-not $CompareRef) {
			if ($env:GITHUB_BASE_REF) {
				$CompareRef = "origin/$($env:GITHUB_BASE_REF)"
			}
			else {
				$CompareRef = 'HEAD~1'
			}
		}
		$DiffOut = & git diff --name-only --diff-filter=AM "$CompareRef" -- '*.ps1' '*.psm1' '*.psd1' 2>$null
		if ($LASTEXITCODE -ne 0) {
			throw "git diff against '$CompareRef' failed (exit $LASTEXITCODE)."
		}
		$Files = @()
		foreach ($Rel in @($DiffOut)) {
			if ([string]::IsNullOrWhiteSpace($Rel)) { continue }
			$Full = Join-Path $GitRoot $Rel.Trim().Replace('/', '\')
			if (Test-Path -LiteralPath $Full) {
				$Files += (Resolve-Path -LiteralPath $Full).Path
			}
		}
		return $Files
	}
	finally {
		Pop-Location
	}
}

$Extensions = @('*.ps1', '*.psm1', '*.psd1')
$Targets = @()

if ($ChangedOnly) {
	$Targets = @(Get-ChangedPowerShellFiles -Root $Path -CompareRef $BaseRef)
}
else {
	foreach ($Ext in $Extensions) {
		$Targets += Get-ChildItem -Path $Path -Filter $Ext -Recurse -File -ErrorAction SilentlyContinue |
			Where-Object {
				$_.FullName -notmatch '[\\/]\.git[\\/]' -and
				$_.Name -notlike '_*.ps1'
			} |
			ForEach-Object { $_.FullName }
	}
}

$Targets = @($Targets | Sort-Object -Unique)
if ($Targets.Count -eq 0) {
	Write-Host 'No PowerShell files to check.'
	exit 0
}

$Missing = @()
foreach ($File in $Targets) {
	if (-not (Test-HasUtf8Bom -FilePath $File)) {
		$Missing += $File
	}
}

if ($Missing.Count -eq 0) {
	Write-Host ("OK: {0} PowerShell file(s) have UTF-8 BOM." -f $Targets.Count)
	exit 0
}

Write-Host ("Missing UTF-8 BOM ({0}):" -f $Missing.Count) -ForegroundColor Yellow
foreach ($File in $Missing) {
	$Rel = $File
	if ($File.StartsWith($RepoRoot.Path, [StringComparison]::OrdinalIgnoreCase)) {
		$Rel = $File.Substring($RepoRoot.Path.Length).TrimStart('\', '/')
	}
	Write-Host "  $Rel"
}

if (-not $Fix) {
	Write-Host ''
	Write-Host 'Re-run with -Fix to rewrite these files as UTF-8 with BOM.'
	exit 1
}

$Fixed = 0
foreach ($File in $Missing) {
	if (Repair-Utf8Bom -FilePath $File) {
		$Fixed++
		Write-Host "Fixed: $File"
	}
}

Write-Host ("Fixed {0} file(s)." -f $Fixed) -ForegroundColor Green
exit 0
