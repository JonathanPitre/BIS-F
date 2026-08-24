<#
	.SYNOPSIS
		Run Omnissa Horizon OS Optimization Tool (OSOT) during base-image preparation.
	.DESCRIPTION
		Detects the Windows OS Optimization Tool for Omnissa Horizon (formerly VMware OSOT)
		portable EXE and runs optimization with the default or GPO-specified template.

		Search order: optional custom GPO folder, then well-known paths under
		ProgramFiles, ProgramFiles(x86), and ProgramData (Omnissa and legacy VMware roots).

		When enabled in GPO, BIS-F can discover and download the latest tool EXE from
		Omnissa Customer Connect (version-agnostic API discovery) if no local copy exists.

		Running OSOT sets LIC_BISF_3RD_OPT so BIS-F defers its own optimizations.
	.EXAMPLE
	.NOTES
		Author: Jonathan Pitre

		History:
		23.11.2016 MS: Script created
		06.12.2016 MS: Created folder if not exist -> VMware Templates path
		24.01.2017 MS: Limit search folders for performance
		28.01.2017 MS: Changed notice from CLI to ADMX
		01.08.2017 MS: Custom search folder and template from ADMX
		07.11.2017 MS: Enable 3rd Party Optimizations when vmOSOT runs
		14.08.2019 MS: Remove message box; default when GPO not configured
		18.02.2020 JK: Fixed log output spelling
		23.08.2026 JP: Omnissa OSOT 2603 CLI, env-based paths, Customer Connect auto-download

	.LINK
		https://docs.omnissa.com/bundle/Optimizing-Images-for-Horizon/page/OptimizingImagesforHorizon.html
	.LINK
		https://docs.omnissa.com/bundle/Optimizing-Images-for-Horizon/page/RunWindowsOSOptimizationToolforHorizonfromCommandLine.html
	.LINK
		https://docs.omnissa.com/bundle/Optimizing-Images-for-Horizon/page/InstallWindowsOSOptimizationToolforHorizon.html
#>

Begin {
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)

	$Product = 'Omnissa Horizon OS Optimization Tool (OSOT)'
	$OsotExePatterns = @('OmnissaHorizonOSOptimizationTool*.exe', 'VMwareOSOptimizationTool*.exe')
	$OsotInstallRoot = Join-Path $env:ProgramFiles 'Omnissa\OSOT'
	$OsotApiBase = 'https://customerconnect.omnissa.com/channel/public/api/v1.0'
	$OsotBrowserUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0'
	$OsotLogCandidates = @(
		Join-Path $env:SystemRoot 'Logs\VMwOsOptTool.log'
		Join-Path $env:SystemRoot 'Logs\OmnissaOsOptTool.log'
	)
}

Process {

	function Expand-BISFEnvironmentPath {
		[CmdletBinding()]
		[OutputType([string])]
		param(
			[Parameter(Mandatory = $true)]
			[string]$Path
		)

		if ([string]::IsNullOrWhiteSpace($Path)) {
			return ''
		}
		return [Environment]::ExpandEnvironmentVariables($Path.Trim())
	}

	function Get-OsotSearchRoots {
		[CmdletBinding()]
		[OutputType([string[]])]
		param()

		$Roots = [System.Collections.Generic.List[string]]::new()

		if ($LIC_BISF_CLI_OT_SF -eq '1' -and -not [string]::IsNullOrWhiteSpace($LIC_BISF_CLI_OT_SF_CUS)) {
			$CustomRoot = Expand-BISFEnvironmentPath -Path $LIC_BISF_CLI_OT_SF_CUS
			if (-not [string]::IsNullOrWhiteSpace($CustomRoot)) {
				$Roots.Add($CustomRoot)
			}
		}

		$StandardSuffixes = @(
			@('Omnissa', 'OSOT')
			@('VMware', 'OSOT')
		)

		foreach ($Root in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData)) {
			if ([string]::IsNullOrWhiteSpace($Root)) { continue }
			foreach ($Suffix in $StandardSuffixes) {
				$Roots.Add((Join-Path $Root (Join-Path $Suffix[0] $Suffix[1])))
			}
		}

		$LegacyRoot = Join-Path ${env:ProgramFiles(x86)} 'vmOSOT'
		if (-not [string]::IsNullOrWhiteSpace(${env:ProgramFiles(x86)})) {
			$Roots.Add($LegacyRoot)
		}

		$Distinct = $Roots | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
		return ,$Distinct
	}

	function Get-OsotExecutableFromFolder {
		[CmdletBinding()]
		[OutputType([System.IO.FileInfo])]
		param(
			[Parameter(Mandatory = $true)]
			[string]$Folder,

			[Parameter(Mandatory = $false)]
			[bool]$Recurse = $false
		)

		if (-not (Test-Path -LiteralPath $Folder)) {
			return $null
		}

		$Matches = @()
		foreach ($Pattern in $OsotExePatterns) {
			$Params = @{
				Path        = $Folder
				Filter      = $Pattern
				File        = $true
				ErrorAction = 'SilentlyContinue'
			}
			if ($Recurse) {
				$Params['Recurse'] = $true
			}
			$Matches += Get-ChildItem @Params
		}

		if ($Matches.Count -eq 0) {
			return $null
		}

		$Best = $Matches | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
		return $Best
	}

	function Find-OsotExecutable {
		[CmdletBinding()]
		[OutputType([string])]
		param()

		$CustomOnly = $LIC_BISF_CLI_OT_SF -eq '1' -and -not [string]::IsNullOrWhiteSpace($LIC_BISF_CLI_OT_SF_CUS)

		foreach ($Root in (Get-OsotSearchRoots)) {
			$Recurse = $false
			if ($CustomOnly -and $Root -eq (Expand-BISFEnvironmentPath -Path $LIC_BISF_CLI_OT_SF_CUS)) {
				$Recurse = $true
			}

			Write-BISFLog -Msg "Looking for OSOT in $Root"
			$Candidate = Get-OsotExecutableFromFolder -Folder $Root -Recurse $Recurse
			if ($null -ne $Candidate) {
				Write-BISFLog -Msg "Found $($Candidate.FullName)" -ShowConsole -Color Cyan
				return $Candidate.FullName
			}
		}

		return $null
	}

	function Get-OsotTlsProtocolFlags {
		[CmdletBinding()]
		[OutputType([System.Net.SecurityProtocolType])]
		param()

		$Tls12 = [System.Net.SecurityProtocolType]::Tls12
		$Tls13Value = 12288

		try {
			$Tls13 = [System.Net.SecurityProtocolType]::Tls13
			return ($Tls13 -bor $Tls12)
		}
		catch {
			try {
				$Tls13 = [Enum]::ToObject([System.Net.SecurityProtocolType], $Tls13Value)
				return ($Tls13 -bor $Tls12)
			}
			catch {
				return $Tls12
			}
		}
	}

	function Invoke-OsotOmnissaRequest {
		[CmdletBinding()]
		[OutputType([object])]
		param(
			[Parameter(Mandatory = $true)]
			[string]$Uri,

			[Parameter(Mandatory = $false)]
			[string]$OutFile
		)

		$MaxAttempts = 3
		$BackoffSeconds = @(2, 4, 8)
		$PreviousTls = [System.Net.ServicePointManager]::SecurityProtocol
		$TlsFlags = Get-OsotTlsProtocolFlags

		try {
			[System.Net.ServicePointManager]::SecurityProtocol = $TlsFlags

			for ($Attempt = 1; $Attempt -le $MaxAttempts; $Attempt++) {
				try {
					if ($OutFile) {
						$Params = @{
							Uri             = $Uri
							OutFile         = $OutFile
							UseBasicParsing = $true
							UserAgent       = $OsotBrowserUserAgent
							TimeoutSec      = 120
							ErrorAction     = 'Stop'
						}
						Invoke-WebRequest @Params | Out-Null
						return $true
					}

					return Invoke-RestMethod -Uri $Uri -Method Get -UseBasicParsing -UserAgent $OsotBrowserUserAgent -TimeoutSec 60 -ErrorAction Stop
				}
				catch {
					$StatusCode = $null
					if ($null -ne $_.Exception.Response) {
						$StatusCode = [int]$_.Exception.Response.StatusCode
					}

					$NoRetry = $StatusCode -in @(401, 403, 404)
					if ($NoRetry -or $Attempt -eq $MaxAttempts) {
						throw
					}

					$Delay = $BackoffSeconds[$Attempt - 1]
					Write-BISFLog -Msg "Omnissa request failed (attempt $Attempt/$MaxAttempts): $($_.Exception.Message). Retrying in ${Delay}s..." -Type W
					Start-Sleep -Seconds $Delay
				}
			}
		}
		finally {
			[System.Net.ServicePointManager]::SecurityProtocol = $PreviousTls
		}

		return $null
	}

	function Get-OsotDownloadInfo {
		[CmdletBinding()]
		[OutputType([PSCustomObject])]
		param()

		Write-BISFLog -Msg 'Discovering latest OSOT EXE from Omnissa Customer Connect' -ShowConsole -Color Cyan

		$CatalogUri = "$OsotApiBase/products/getProductsAtoZ"
		$Catalog = Invoke-OsotOmnissaRequest -Uri $CatalogUri
		if ($null -eq $Catalog) {
			Write-BISFLog -Msg 'Customer Connect product catalog returned no data' -Type W
			return $null
		}

		$ProductEntry = $Catalog.productCategoryList |
			ForEach-Object { $_.ProductList } |
			Where-Object { $null -ne $_ } |
			ForEach-Object { $_ } |
			Where-Object { $_.name -match 'OS Optimization Tool' } |
			Select-Object -First 1

		if ($null -eq $ProductEntry) {
			Write-BISFLog -Msg 'OS Optimization Tool not found in Customer Connect catalog' -Type W
			return $null
		}

		$Action = $ProductEntry.actions | Where-Object { $_.linkname -eq 'View Download Components' } | Select-Object -First 1
		if ($null -eq $Action -or [string]::IsNullOrWhiteSpace($Action.target)) {
			Write-BISFLog -Msg 'No download components link for OS Optimization Tool' -Type W
			return $null
		}

		$Segments = $Action.target.Trim('/').Split('/')
		if ($Segments.Count -lt 3) {
			Write-BISFLog -Msg "Unexpected Customer Connect target path: $($Action.target)" -Type W
			return $null
		}

		$CategoryMap = $Segments[$Segments.Count - 3]
		$ProductMap = $Segments[$Segments.Count - 2]
		$VersionMap = $Segments[$Segments.Count - 1]

		Write-BISFLog -Msg "Customer Connect maps: category=$CategoryMap product=$ProductMap version=$VersionMap" -SubMsg

		$ListUri = "$OsotApiBase/products/getRelatedDLGList?locale=en_US&category=$CategoryMap&product=$ProductMap&version=$VersionMap&dlgType=PRODUCT_BINARY"
		$ListResponse = Invoke-OsotOmnissaRequest -Uri $ListUri
		if ($null -eq $ListResponse) {
			return $null
		}

		$DlgItem = $null
		foreach ($Edition in $ListResponse.dlgEditionsLists) {
			foreach ($Item in $Edition.dlgList) {
				if ($Item.name -match 'Windows OS Optimization Tool|OS Optimization Tool') {
					$DlgItem = $Item
					break
				}
			}
			if ($null -ne $DlgItem) { break }
		}

		if ($null -eq $DlgItem) {
			$DlgItem = $ListResponse.dlgEditionsLists | ForEach-Object { $_.dlgList } | Select-Object -First 1
		}

		if ($null -eq $DlgItem) {
			Write-BISFLog -Msg 'No download group returned for OS Optimization Tool' -Type W
			return $null
		}

		$DetailsUri = "$OsotApiBase/dlg/details?locale=en_US&downloadGroup=$($DlgItem.code)&productId=$($DlgItem.productId)&rPId=$($DlgItem.releasePackageId)"
		$Details = Invoke-OsotOmnissaRequest -Uri $DetailsUri
		if ($null -eq $Details -or $null -eq $Details.downloadFiles) {
			Write-BISFLog -Msg 'No download files in Customer Connect details response' -Type W
			return $null
		}

		$ExeFiles = $Details.downloadFiles |
			Where-Object {
				$_.fileName -match 'OSOptimizationTool' -and
				$_.fileName -match '\.exe$' -and
				$_.fileName -notmatch 'MDT|Plugin|\.zip'
			} |
			Sort-Object -Property releaseDate

		$Selected = $ExeFiles | Select-Object -Last 1
		if ($null -eq $Selected) {
			Write-BISFLog -Msg 'No matching OSOT EXE in Customer Connect download list' -Type W
			return $null
		}

		$DownloadUri = $Selected.thirdPartyDownloadUrl
		if ([string]::IsNullOrWhiteSpace($DownloadUri)) {
			Write-BISFLog -Msg 'Customer Connect returned no download URL (login or EULA may be required)' -Type W
			return $null
		}

		return [PSCustomObject]@{
			Uri      = $DownloadUri
			FileName = $Selected.fileName
			Version  = $Selected.version
		}
	}

	function Install-OsotFromDownload {
		[CmdletBinding(SupportsShouldProcess = $true)]
		[OutputType([string])]
		param(
			[Parameter(Mandatory = $true)]
			[PSCustomObject]$DownloadInfo
		)

		if (-not $PSCmdlet.ShouldProcess($Product, 'Download and install OSOT EXE')) {
			return $null
		}

		$TempFile = Join-Path $env:TEMP $DownloadInfo.FileName
		Write-BISFLog -Msg "Downloading $($DownloadInfo.FileName) from Customer Connect" -ShowConsole -Color Cyan

		try {
			Invoke-OsotOmnissaRequest -Uri $DownloadInfo.Uri -OutFile $TempFile
		}
		catch {
			Write-BISFLog -Msg "OSOT download failed: $($_.Exception.Message)" -Type E
			return $null
		}

		if (-not (Test-Path -LiteralPath $TempFile)) {
			Write-BISFLog -Msg 'Download completed but temp file is missing' -Type E
			return $null
		}

		try {
			Unblock-File -LiteralPath $TempFile -ErrorAction SilentlyContinue
		}
		catch {
			Write-BISFLog -Msg "Unblock-File warning: $($_.Exception.Message)" -Type W
		}

		if (-not (Test-Path -LiteralPath $OsotInstallRoot)) {
			New-Item -Path $OsotInstallRoot -ItemType Directory -Force | Out-Null
			Write-BISFLog -Msg "Created $OsotInstallRoot" -SubMsg
		}

		$TargetExe = Join-Path $OsotInstallRoot $DownloadInfo.FileName
		try {
			Copy-Item -LiteralPath $TempFile -Destination $TargetExe -Force -ErrorAction Stop
		}
		catch {
			Write-BISFLog -Msg "Failed to copy OSOT to $TargetExe : $($_.Exception.Message)" -Type E
			return $null
		}

		try {
			Unblock-File -LiteralPath $TargetExe -ErrorAction SilentlyContinue
		}
		catch {
			Write-BISFLog -Msg "Unblock-File on install path warning: $($_.Exception.Message)" -Type W
		}

		try {
			Remove-Item -LiteralPath $TempFile -Force -ErrorAction SilentlyContinue
		}
		catch {
			# lean-ctx: temp cleanup optional
		}

		Write-BISFLog -Msg "Installed OSOT to $TargetExe" -ShowConsole -Color Green
		return $TargetExe
	}

	function Get-OsotTemplateArgument {
		[CmdletBinding()]
		[OutputType([string])]
		param()

		if ([string]::IsNullOrWhiteSpace($LIC_BISF_CLI_OT_Templ)) {
			return $null
		}

		$Template = Expand-BISFEnvironmentPath -Path $LIC_BISF_CLI_OT_Templ
		if ([string]::IsNullOrWhiteSpace($Template)) {
			return $null
		}

		return $Template
	}

	function Invoke-OsotOptimize {
		[CmdletBinding(SupportsShouldProcess = $true)]
		[OutputType([bool])]
		param(
			[Parameter(Mandatory = $true)]
			[string]$ExecutablePath
		)

		if (-not $PSCmdlet.ShouldProcess($Product, 'Run OSOT optimization')) {
			return $true
		}

		try {
			Unblock-File -LiteralPath $ExecutablePath -ErrorAction SilentlyContinue
		}
		catch {
			Write-BISFLog -Msg "Unblock-File before run warning: $($_.Exception.Message)" -Type W
		}

		$ReportDir = $LogFilePath
		if ([string]::IsNullOrWhiteSpace($ReportDir)) {
			$ReportDir = Join-Path $env:TEMP 'BISF_OSOT_Report'
		}

		$ArgumentList = @('-o', '-v', '-r', $ReportDir)
		$Template = Get-OsotTemplateArgument
		if (-not [string]::IsNullOrWhiteSpace($Template)) {
			Write-BISFLog -Msg "Using template: $Template" -ShowConsole -SubMsg -Color DarkCyan
			$ArgumentList += @('-t', $Template)
		}
		else {
			Write-BISFLog -Msg 'Using OSOT default template for this OS' -SubMsg -Color DarkCyan
		}

		Write-BISFLog -Msg "Running $Product" -ShowConsole -Color Cyan
		Write-BISFLog -Msg "Executable: $ExecutablePath" -SubMsg
		Write-BISFLog -Msg "Arguments: $($ArgumentList -join ' ')" -SubMsg

		try {
			$Proc = Start-Process -FilePath $ExecutablePath -ArgumentList $ArgumentList -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
			Write-BISFLog -Msg "OSOT exit code: $($Proc.ExitCode)" -ShowConsole -Color DarkCyan -SubMsg
			if ($Proc.ExitCode -ne 0) {
				Write-BISFLog -Msg "OSOT returned non-zero exit code $($Proc.ExitCode)" -Type W
			}
		}
		catch {
			Write-BISFLog -Msg "Failed to run OSOT: $($_.Exception.Message)" -Type E
			return $false
		}

		foreach ($LogCandidate in $OsotLogCandidates) {
			if (Test-Path -LiteralPath $LogCandidate) {
				Get-BISFLogContent -GetLogFile $LogCandidate
			}
		}

		if (-not [string]::IsNullOrWhiteSpace($LogFilePath)) {
			Write-BISFLog -Msg "The HTML report can be found at $LogFilePath" -ShowConsole -Color DarkCyan -SubMsg
		}

		$Global:LIC_BISF_3RD_OPT = $true
		return $true
	}

	#### Main Program
	$VarCLI = $LIC_BISF_CLI_OT
	if ($VarCLI -eq 'NO') {
		Write-BISFLog -Msg "Skip searching and running $Product (ADMX disabled)"
		return
	}

	if ($VarCLI -ne 'YES') {
		Write-BISFLog -Msg "OSOT policy not enabled (LIC_BISF_CLI_OT=$VarCLI); skipping optimization"
		return
	}

	Write-BISFLog -Msg "Searching for $Product" -ShowConsole -Color Cyan

	$OsotExe = Find-OsotExecutable

	if ([string]::IsNullOrWhiteSpace($OsotExe) -and $LIC_BISF_CLI_OT_DL -eq '1') {
		Write-BISFLog -Msg 'OSOT not found locally; auto-download from Customer Connect is enabled' -ShowConsole -Color Cyan
		$DownloadInfo = Get-OsotDownloadInfo
		if ($null -ne $DownloadInfo) {
			$OsotExe = Install-OsotFromDownload -DownloadInfo $DownloadInfo
		}
	}

	if ([string]::IsNullOrWhiteSpace($OsotExe)) {
		Write-BISFLog -Msg "$Product is NOT installed and auto-download did not succeed"
		return
	}

	Write-BISFLog -Msg "$Product ready at $OsotExe" -ShowConsole -Color Cyan
	$null = Invoke-OsotOptimize -ExecutablePath $OsotExe
}

End {
	Add-BISFFinishLine
}
