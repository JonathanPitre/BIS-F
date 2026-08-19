<#
.SYNOPSIS
  Installs Base Image Script Framework (BIS-F) to Program Files and registers Path/Version.

.DESCRIPTION
  Copies Framework, ADMX, PrepareBaseImage.cmd, and LICENSE into the install root,
  writes HKLM:\SOFTWARE\Login Consultants\BISF Path and Version (from BISF.psd1),
  and creates a shortcut under All Users Administrative Tools (not shown to standard users).

  By default downloads the refactor/modernize branch zip from GitHub. Pass -SourcePath
  to install from a local checkout instead.

  Run elevated (Administrator).

.PARAMETER InstallRoot
  Destination folder. Default: C:\Program Files (x86)\Base Image Script Framework (BIS-F)

.PARAMETER SourcePath
  Local repo root containing Framework\, ADMX\, PrepareBaseImage.cmd, LICENSE.
  When omitted, downloads from -ZipUrl.

.PARAMETER ZipUrl
  GitHub archive URL used when -SourcePath is not set.

.PARAMETER SkipShortcut
  Do not create the Administrative Tools shortcut.

.EXAMPLE
  # Download and install (Administrator)
  .\tools\Install-BISF.ps1

.EXAMPLE
  # Install from this checkout
  .\tools\Install-BISF.ps1 -SourcePath D:\BIS-F
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
	[string]$InstallRoot = 'C:\Program Files (x86)\Base Image Script Framework (BIS-F)',

	[string]$SourcePath,

	[string]$ZipUrl = 'https://github.com/JonathanPitre/BIS-F/archive/refs/heads/refactor/modernize.zip',

	[switch]$SkipShortcut
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
	$Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
	$Principal = New-Object Security.Principal.WindowsPrincipal($Identity)
	return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-BISFModuleVersionFromManifest {
	param([Parameter(Mandatory)][string]$ManifestPath)

	if (-not (Test-Path -LiteralPath $ManifestPath)) {
		throw "BIS-F module manifest not found: $ManifestPath"
	}
	$Manifest = Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop
	return [string]$Manifest.Version
}

function Set-BISFInstallRegistry {
	param(
		[Parameter(Mandatory)][string]$InstallPath,
		[Parameter(Mandatory)][string]$Version
	)

	$RegPath = 'HKLM:\SOFTWARE\Login Consultants\BISF'
	if (-not (Test-Path -LiteralPath $RegPath)) {
		New-Item -Path $RegPath -Force | Out-Null
	}

	$NormalizedPath = $InstallPath.TrimEnd('\') + '\'
	Set-ItemProperty -Path $RegPath -Name 'Path' -Value $NormalizedPath -Type String -Force
	Set-ItemProperty -Path $RegPath -Name 'Version' -Value $Version -Type String -Force
	Write-Host "Registry $RegPath Path=$NormalizedPath Version=$Version"
}

function New-BISFStartMenuShortcut {
	param(
		[Parameter(Mandatory)][string]$InstallPath
	)

	$NormalizedRoot = $InstallPath.TrimEnd('\')
	$Target = Join-Path $NormalizedRoot 'PrepareBaseImage.cmd'
	if (-not (Test-Path -LiteralPath $Target)) {
		Write-Warning "PrepareBaseImage.cmd not found at $Target; skipping shortcut."
		return
	}

	# Administrative Tools is hidden from standard users; do not place this under Programs.
	$ShortcutDir = [Environment]::GetFolderPath('CommonAdminTools')
	if ([string]::IsNullOrWhiteSpace($ShortcutDir)) {
		$ShortcutDir = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Administrative Tools'
	}
	if (-not (Test-Path -LiteralPath $ShortcutDir)) {
		New-Item -ItemType Directory -Path $ShortcutDir -Force | Out-Null
	}

	$ShortcutPath = Join-Path $ShortcutDir 'Prepare Base Image (BIS-F).lnk'
	$IconPath = Join-Path $NormalizedRoot 'Framework\SubCall\Global\BISF.ico'

	$WshShell = New-Object -ComObject WScript.Shell
	$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
	$Shortcut.TargetPath = $Target
	$Shortcut.WorkingDirectory = $NormalizedRoot
	$Shortcut.Description = 'Run Base Image Script Framework (Admin Only)'
	if (Test-Path -LiteralPath $IconPath) {
		$Shortcut.IconLocation = $IconPath
	}
	$Shortcut.Save()
	Write-Host "Administrative Tools shortcut: $ShortcutPath"

	# Remove a previous install's visible Programs folder if present
	$LegacyDir = Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'Base Image Script Framework (BIS-F)'
	if (Test-Path -LiteralPath $LegacyDir) {
		Remove-Item -LiteralPath $LegacyDir -Recurse -Force
		Write-Host "Removed legacy Start Menu folder: $LegacyDir"
	}
}

if (-not (Test-IsAdministrator)) {
	throw 'Install-BISF.ps1 must be run as Administrator.'
}

$Keep = @('Framework', 'ADMX', 'PrepareBaseImage.cmd', 'LICENSE')
$TempRoot = $null
$PayloadRoot = $null

try {
	if ($SourcePath) {
		$PayloadRoot = (Resolve-Path -LiteralPath $SourcePath).Path
		Write-Host "Installing from local source: $PayloadRoot"
	}
	else {
		$TempRoot = Join-Path $env:TEMP ('BIS-F-' + [guid]::NewGuid().ToString('N'))
		$ZipPath = Join-Path $TempRoot 'BIS-F.zip'
		New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null
		Write-Host "Downloading $ZipUrl ..."
		Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath
		Expand-Archive -Path $ZipPath -DestinationPath $TempRoot -Force
		$Extracted = Get-ChildItem -Path $TempRoot -Directory |
			Where-Object { $_.Name -like 'BIS-F-*' } |
			Select-Object -First 1
		if (-not $Extracted) {
			throw 'Could not find extracted BIS-F folder in the zip archive.'
		}
		$PayloadRoot = $Extracted.FullName
		Write-Host "Extracted to $PayloadRoot"
	}

	foreach ($Name in $Keep) {
		$Source = Join-Path $PayloadRoot $Name
		if (-not (Test-Path -LiteralPath $Source)) {
			throw "Required payload missing: $Source"
		}
	}

	$ManifestPath = Join-Path $PayloadRoot 'Framework\SubCall\Global\BISF.psd1'
	$ModuleVersion = Get-BISFModuleVersionFromManifest -ManifestPath $ManifestPath

	if ($PSCmdlet.ShouldProcess($InstallRoot, "Install BIS-F $ModuleVersion")) {
		if (Test-Path -LiteralPath $InstallRoot) {
			Remove-Item -LiteralPath $InstallRoot -Recurse -Force
		}
		New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null

		foreach ($Name in $Keep) {
			$Source = Join-Path $PayloadRoot $Name
			Copy-Item -LiteralPath $Source -Destination (Join-Path $InstallRoot $Name) -Recurse -Force
		}

		Set-BISFInstallRegistry -InstallPath $InstallRoot -Version $ModuleVersion

		if (-not $SkipShortcut) {
			New-BISFStartMenuShortcut -InstallPath $InstallRoot
		}

		Write-Host "BIS-F $ModuleVersion installed to $InstallRoot" -ForegroundColor Green
	}
}
finally {
	if ($TempRoot -and (Test-Path -LiteralPath $TempRoot)) {
		Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
	}
}
