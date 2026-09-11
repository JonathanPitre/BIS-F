<#
.SYNOPSIS
  Fails when BISF.psm1 loads splash DLLs that are not present in the tree.

.DESCRIPTION
  The MahApps.Metro splash was replaced with a native WPF dialog. This check
  catches the issue #2 regression: BISF.psm1 still LoadFroms
  Framework\SubCall\Global\assembly\MahApps.Metro.dll or
  System.Windows.Interactivity.dll after those files were removed.

  Exit code 1 when a referenced splash DLL is missing on disk.

.PARAMETER Path
  Repository root containing Framework\SubCall\Global\BISF.psm1.
  Default: parent of tools/.
#>
[CmdletBinding()]
param(
	[string]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')
if (-not $Path) {
	$Path = $RepoRoot.Path
}
else {
	$Path = (Resolve-Path -LiteralPath $Path).Path
}

$Psm1Path = Join-Path $Path 'Framework\SubCall\Global\BISF.psm1'
$AssemblyDir = Join-Path $Path 'Framework\SubCall\Global\assembly'

if (-not (Test-Path -LiteralPath $Psm1Path)) {
	throw "BISF.psm1 not found: $Psm1Path"
}

$Content = [System.IO.File]::ReadAllText($Psm1Path)

$SplashDlls = @(
	'MahApps.Metro.dll',
	'System.Windows.Interactivity.dll'
)

$Failures = @()
foreach ($Dll in $SplashDlls) {
	$Escaped = [regex]::Escape($Dll)
	$AssemblyRef = 'assembly[\\/]' + $Escaped
	$LoadFromRef = 'LoadFrom\([^)]*' + $Escaped
	$Referenced = [regex]::IsMatch($Content, $AssemblyRef, 'IgnoreCase') -or
		[regex]::IsMatch($Content, $LoadFromRef, 'IgnoreCase')
	$OnDisk = Test-Path -LiteralPath (Join-Path $AssemblyDir $Dll)
	if ($Referenced -and -not $OnDisk) {
		$Failures += $Dll
	}
}

if ($Failures.Count -eq 0) {
	Write-Host 'OK: splash assemblies are not LoadFrom-referenced without files on disk.'
	exit 0
}

Write-Host 'BISF.psm1 references splash DLLs that are missing from Framework\SubCall\Global\assembly:' -ForegroundColor Yellow
foreach ($Dll in $Failures) {
	Write-Host "  $Dll"
}
Write-Host ''
Write-Host 'Either restore the files or remove the LoadFrom / assembly\ references (native Fluent splash).'
exit 1
