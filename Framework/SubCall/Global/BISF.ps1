<#
	.SYNOPSIS
		Load the global BIS-F environment and configuration.
	.DESCRIPTION
		Sets the global configuration needed for Base Image Script Framework (BIS-F).
		Merges registry/policy values into $BISFconfiguration, resolves the log file
		location, detects image-management software (PVS, MCS, Horizon, Frame, RAS, WVD),
		and applies PVS or MCS redirection. Dot-sourced from Framework/SubCall/Global
		during Preparation and Personalization (Invoke-BISFFolderScripts).
	.EXAMPLE
		. "$LIB_Folder\BISF.ps1"

		Loads global BIS-F configuration, log path, and product detection.
	.INPUTS
		None
	.OUTPUTS
		None
	.NOTES
		Author: Matthias Schlimm
		Editor: Mike Bijl (Rewritten variable names and script format)

		History:
		10.09.2013 MS: Script created
		16.09.2013 MS: function to read values from registry
		17.09.2013 MS: Add global values for Folders
		17.09.2013 MS: edit script logic to get variables and their values from registry, if not defined use script defined values
		18.09.2013 MS: syntax error line 140 -ErrorAction SilentlyContinue
		18.09.2013 MS: add rearm values for OS (Operating System) and OF (Office)
		18.09.2013 MS: replace $date with $(Get-date) to get current timestamp at running script lines write to the log file
		18.09.2013 MS: Add variable LIC_PVS_CtxImaPath to redirect local host cache
		18.09.2013 MS: remove $LIB & $SubCall folder from global variable
		18.09.2013 MS: add function CheckPVSDriveLetter and CheckPVSSysVariable
		19.09.2013 MS: remove $LOG = "C:\Windows\Log\$PSScriptName.log"
		19.09.2013 MS: add $RegVarFound = @()
		19.09.2013 MS: add function CheckRegHive
		01.10.2013 MS: add global value LIC_PVS_RefSrv_HostName to detect ReferenceServer
		17.12.2013 MS: Error handling: add return $false for exit script
		18.12.2013 MS: Line 47: $VarFound = @()
		28.01.2014 MS: Add $return for error handling
		28.01.2014 MS: Add CheckHostIDDir
		03.03.2014 BR: Revisited Script
		10.03.2014 MS: Remove Write-BISFLog in Line 139 and replace with Write-Host
		10.03.2014 MS: [array]$reg_value_data += "15_XX_Custom"
		21.03.2014 MS: last code change before release to web
		01.04.2014 MS: move central functions to 10_XX_LIB_Functions.psm1
		02.04.2014 MS: add variable to redirect Cache Location ->  $LIC_PVS_CtxCache
		02.04.2014 MS: Fix: wrong Log-Location
		15.05.2014 MS: Add get-Version to show current running version
		11.08.2014 MS: remove $returnCheckPVSDriveLetter
		12.08.2014 MS: remove to much entries for logging
		15.08.2014 MS: add line 242: Get-OSInfo
		15.08.2014 MS: add line 245: CheckXDSoftware
		31.10.2014 MB: Renamed functions: CheckXDSoftware -> Test-XDSoftware / CheckPVSSoftware -> Test-PVSSoftware / CheckPVSDriveLetter -> Get-PVSDriveLetter / CheckRegHive -> Test-BISFRegHive
		31.10.2014 MB: Renamed variables: returnCheckPVSSysVariable -> returnTestPVSEnvVariable
		14.04.2015 MS: Get-TaskSequence to activate or suppress a system shutdown
		14.04.2015 MS: detect if running from SCCM/MDT Task Sequence, if so it sets the log file location to the the Task Sequence “LogPath”
		02.06.2015 MS: define new global variables for all not predefined custom objects in $BISFconfiguration, do i need to store the CLI commands in registry
		02.06.2015 MS: running from SCCM or MDT ->  changing to $LogPath only (prev. $LogFilePath = "$LogPath\$LogFolderName"), only files directly in the folder are preserved, not sub folders
		10.08.2015 MS: Bug 50 - added existing function $Global:returnTestPVSDriveLetter=Test-PVSDriveLetter -Verbose:$VerbosePreference
		21.08.2015 MS: remove all XX,XA,XD from al files and Scripts
		29.09.2015 MS: Bug 93: check if preparation phase is running to run $Global:returnTestPVSDriveLetter=Test-PVSDriveLetter -Verbose:$VerbosePreference
		16.12.2015 MS: redirect spool directory to PVS WriteCacheDisk, if PVS Target Device Driver is installed only
		16.12.2015 MS: redirect event logs (Application, Security, System) to PVS WriteCacheDisk, if PVS Target Device Driver is installed only
		07.01.2016 MS: Feature 20: add VMware Horizon View detection
		27.01.2016 MS: move $State -eq "Preparation" from BISF.ps1 to function Test-BISFPVSDriveLetter
		28.01.2016 MS: add Request-BISFsysprep
		02.03.2016 MS: check PVS DiskMode at Prerequisites, to get an error on startup if Disk is in ReadOnly Mode
		18.10.2016 MS: change LIC_BISF_MAIN_PersScript to new folderPath, remove wrong clip "}"
		27.07.2017 MS: replace redirection of spool and evt-logs with central function Use-BISFPVSConfig, if using Citrix AppLayering with PVS it's a complex matrix to redirect or not.
		03.08.2017 MS: add $Global:BootMode = Get-BISFBootMode to get UEFI or Legacy
		14.08.2017 MS: add cli switch ExportSharedConfiguration to export BIS-F ADMX Reg Settings into an XML File
		07.11.2017 MS: add $LIC_BISF_3RD_OPT = $false, if vmOSOT or CTXO is enabled and found, $LIC_BISF_3RD_OPT = $true and disable BIS-F own optimizations
		20.10.2018 MS: Feature 63 - Citrix AppLayering - Create C:\Windows\Logs folder automatically if it doesn't exist
		13.08.2019 MS: ENH 97 - Nutanix Xi Frame Support
		14.08.2019 MS: ENH 6 - Parallels RAS Support
		25.08.2019 MS: ENH 132 - Windows 10 Enterprise for Virtual Desktops (WVD) Support
		25.08.2019 MS: FRQ 85 - Make SCCM / MDT Task Sequence log file redirection optional
		21.09.2019 MS: EHN 36 - Shared Configuration - JSON Export
		03.10.2019 MS: ENH 126 - MCSIO persistent drive
		03.10.2019 MS: ENH 28 - Check if there's enough disk space on P2V Custom UNC-Path
		05.10.2019 MS: ENH 12 - ADMX Extension: Configure sDelete
		05.10.2019 MS: ENH 22 - Get DiskID's of the system - for monitoring only ->  for later use to fix 'Endless Reboot with VMware Paravirtual SCSI disk'
		05.10.2019 MS: ENH 144 - Enable Powershell Transcript
		05.10.2019 MS: ENH 52 - Citrix AppLayering - different shared configuration based on Layer
		08.10.2019 MS: ENH 146 - Move Get-PendingReboot to earlier phase of preparation
		08.10.2019 MS: ENH 93 - Detect Citrix Cloud Connector installation and prevent BIS-F to run
		27.12.2019 MS/MN: HF 160 - typo for Calculation of free space for the VHDX file
		18.02.2020 JK: Fixed Log output spelling
		25.03.2020 MS: ENH 241 - skip PVS UNC vDisk Size if PVS Master Image is skipped
		18.06.2020 MS: HF 251 - switch the lines 356-357 -> $UPL muste be detected before Test-AppLayeringSoftware is used
		09.08.2020 MS: HF 272 - Central PERS Logs are missing the beginning
		08.01.2021 MS: HF 302 - using $DiskIdentifier instead DiskID, DiskID is for another Global variable
		16.08.2026 JP: Align script/function comment-based help and formatting with PowerShell best practices
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

Begin {
	####################################################################
	# Setting default variables ($PSScriptRoot/$LogFile/$PSCommand,$PSScriptFullName/$ScriptLibrary/LogFileName) independent on running script from console or ISE and the powershell version.
	if ($Host.Name -like '* ISE *') {
		# Running script from Windows PowerShell ISE
		$PSScriptFullName = $psISE.CurrentFile.FullPath.ToLower()
		$PSCommand = (Get-PSCallStack).InvocationInfo.MyCommand.Definition
	}
	else {
		$PSScriptFullName = $MyInvocation.MyCommand.Definition.ToLower()
		$PSCommand = $MyInvocation.Line
	}
	[string]$PSScriptName = (Split-Path -Path $PSScriptFullName -Leaf).ToLower()
	if ([string]::IsNullOrEmpty($PSScriptRoot)) {
		[string]$PSScriptRoot = (Split-Path -Path $PSScriptFullName).ToLower()
	}

	####################################################################
	# Maximize Window
	if ($Host.Name -match 'console') {
		$MaxHeight = $Host.UI.RawUI.MaxPhysicalWindowSize.Height
		$MaxWidth = $Host.UI.RawUI.MaxPhysicalWindowSize.Width
	}

	# Initialize script array
	if (($null -eq $PVSDiskDrive) -or ($PVSDiskDrive -eq '') -or ($PVSDiskDrive -eq 'NONE')) {
		$PVSDiskDrive = 'C:\Windows\Logs'
	}

	# Predefined BISF configuration values
	[array]$BISFconfiguration = @(
		[PSCustomObject]@{ Description = 'LogFileFolder'; Value = 'LIC_BISF_LogPath'; Data = "$PVSDiskDrive\BISFLogs"; FoundInReg = "$false" }
		[PSCustomObject]@{ Description = 'CitrixFolder'; Value = 'LIC_BISF_CtxPath'; Data = "$PVSDiskDrive\Citrix"; FoundInReg = "$false" }
		[PSCustomObject]@{ Description = 'RedirectedLocalHostCache'; Value = 'LIC_BISF_CtxImaPath'; Data = "$PVSDiskDrive\Citrix\IMA"; FoundInReg = "$false" }
		[PSCustomObject]@{ Description = 'RedirectedCitrixLicense'; Value = 'LIC_BISF_CtxCache'; Data = "$PVSDiskDrive\Citrix\Cache"; FoundInReg = "$false" }
		[PSCustomObject]@{ Description = 'RedirectedEventLogs'; Value = 'LIC_BISF_EvtPath'; Data = "$PVSDiskDrive\EventLogs"; FoundInReg = "$false" }
		[PSCustomObject]@{ Description = 'RedirectedPrintSpoolPath'; Value = 'LIC_BISF_SpoolPath'; Data = "$PVSDiskDrive\Spool"; FoundInReg = "$false" }
		[PSCustomObject]@{ Description = 'CitrixUPMLogPath'; Value = 'LIC_BISF_UPMPath'; Data = "$PVSDiskDrive\UPM"; FoundInReg = "$false" }
		[PSCustomObject]@{ Description = 'BISFPrepScripts'; Value = 'LIC_BISF_PrepFolder'; Data = 'Preparation'; FoundInReg = "$false" }
		[PSCustomObject]@{ Description = 'BISFPersScripts'; Value = 'LIC_BISF_PersFolder'; Data = 'Personalization'; FoundInReg = "$false" }
		[PSCustomObject]@{ Description = 'BISFPersScriptMain'; Value = 'LIC_BISF_MAIN_PersScript'; Data = "$Main_Folder\PersBISF_Start.ps1"; FoundInReg = "$false" }
		[PSCustomObject]@{ Description = 'CustomScriptsFolder'; Value = 'LIC_BISF_CustomFolder'; Data = 'Custom'; FoundInReg = "$false" }
		[PSCustomObject]@{ Description = 'OSRearm_Enable'; Value = 'LIC_BISF_RearmOS_run'; Data = '0'; FoundInReg = "$false" }
		[PSCustomObject]@{ Description = 'RearmOS_UserAccount'; Value = 'LIC_BISF_RearmOS_user'; Data = $false; FoundInReg = "$false" }
		[PSCustomObject]@{ Description = 'RearmOS_Date'; Value = 'LIC_BISF_RearmOS_date'; Data = $false; FoundInReg = "$false" }
		[PSCustomObject]@{ Description = 'RearmOF_Enable'; Value = 'LIC_BISF_RearmOF_run'; Data = '0'; FoundInReg = "$false" }
		[PSCustomObject]@{ Description = 'RearmOF_UserAccount'; Value = 'LIC_BISF_RearmOF_user'; Data = $false; FoundInReg = "$false" }
		[PSCustomObject]@{ Description = 'RearmOF_Date'; Value = 'LIC_BISF_RearmOF_date'; Data = $false; FoundInReg = "$false" }
		[PSCustomObject]@{ Description = 'MTDHostname'; Value = 'LIC_BISF_RefSrv_HostName'; Data = "$Computer"; FoundInReg = "$false" }
		[PSCustomObject]@{ Description = 'OptDrive_DriveLetter'; Value = 'LIC_BISF_OptDrive'; Data = $false; FoundInReg = "$false" }
		[PSCustomObject]@{ Description = 'ZCMAgent_args'; Value = 'LIC_BISF_ZCM_CFG'; Data = ''; FoundInReg = "$false" }
		[PSCustomObject]@{ Description = '3rd Party Optimizer'; Value = 'LIC_BISF_3RD_OPT'; Data = "$false"; FoundInReg = "$false" }
	)

	####################################################################
	####### functions #####
	####################################################################

	function Set-LogFile {
		<#
			.SYNOPSIS
				Set the path for the BIS-F log file.
			.DESCRIPTION
				Resolves the log share or write-cache disk, creates the log folder if needed,
				moves existing PREP/PERS logs, and sets $Global:LogFile and $Global:LogFilePath.
			.EXAMPLE
				Set-LogFile
			.OUTPUTS
				System.String. Full path of the BIS-F log file.
			.NOTES
				Author: Matthias Schlimm

				History:
				10.09.2103 MS: function created
				12.08.2014 MS: move function Set-LogFile from 10_XX_LIB_Functions.psm1 to 10_XX_LIB_Config.ps1, this function would be run from this script only and no more from other scripts
				13.08.2014 MS: add IF ($PVSDiskDrive -eq $null) {$PVSDiskDrive ="C:\Windows\Logs"}
				14.08.2014 MS: change function Set-LogFile if the Drive is not reachable
				18.08.2014 MS: move Log file folder PVSLogs to new Folder BISLogs\PVSLogs_old and remove the registry entry LIC_PVS_LogPath, their no longer needed
				19.10.2016 MS: add $Global:LogFilePath = "$LogPath"  to function Set-LogFile
				11.11.2017 MS: Retry 30 times if Log share on network path is not found with fallback after max. is reached
				02.07.2018 MS: Fixed 50 - function Set-LogFile -> invoke-BISFLogShare   (After LogShare is changed in ADMX, the old path will also be checked and skips execution)
				22.12.2020 JS: HF 302 - WriteCache disk access validated in Set-LogFile function before log move
		#>
		[CmdletBinding()]
		[OutputType([string])]
		param()

		if (-not (Test-Path -Path "$env:windir\Logs")) {
			Write-BISFLog -Msg "Folder $env:windir\Logs does NOT Exist, will be created now!" -Type W -ShowConsole
			New-Item -ItemType Directory -Path "$env:windir\Logs" | Out-Null
		}
		$LogShareReachable = $false
		Invoke-BISFLogShare -Verbose:$VerbosePreference
		$ErrorActionPreference = 'Stop'

		try {
			if (($LIC_BISF_CLI_LSb -eq 1) -and (Test-Path -Path $LIC_BISF_LogShare)) {
				$LogShareReachable = $true
			}
		}
		catch [System.IO.DirectoryNotFoundException] {
			Write-BISFLog -Msg 'Cannot create BISFLog folder, the volume is not formatted' -Type W -SubMsg
			$LogPath = "C:\Windows\Logs\$LogFolderName"
			New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
		}
		catch [System.IO.IOException] {
			Write-BISFLog -Msg 'BISFLog folder already exists'
			$LogShareReachable = $true
		}
		catch [System.UnauthorizedAccessException] {
			Write-BISFLog -Msg 'Cannot create BISFLog folder, the drive is not writeable' -Type W -SubMsg
			$LogPath = "C:\Windows\Logs\$LogFolderName"
			New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
		}
		catch {
			Write-BISFLog -Msg 'Unhandled Exception occurred' -Type W -SubMsg
			$LogPath = "C:\Windows\Logs\$LogFolderName"
			New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
		}
		finally {
			if ($LogShareReachable -eq $true) {
				$LogPath = "$LIC_BISF_LogShare\$Computer"
			}
			else {
				if (Test-BISFAccessValidated -Folder "$PVSDiskDrive\") {
					$LogPath = "$PVSDiskDrive\$LogFolderName"
				}
				else {
					$LogPath = "C:\Windows\Logs\$LogFolderName"
				}
			}

			if (-not (Test-Path -Path $LogPath -PathType Leaf)) {
				New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
			}
			Write-BISFLog -Msg "Move BIS-F log to $LogPath" -ShowConsole -Color DarkCyan -SubMsg
			Get-ChildItem -Path "C:\Windows\Logs\*" -Include 'PREP_BISF*.log', 'PERS_BISF*.log' -Exclude '*BISF_WPT*.log', '*dism_bisf*' -Recurse |
				Move-Item -Destination $LogPath -Force
			if (($NewLogPath) -and ($NewLogPath -ne $LogPath)) {
				Write-BISFLog -Msg "Move BIS-F log from $NewLogPath to $LogPath" -ShowConsole -Color DarkCyan -SubMsg
				Get-ChildItem -Path "$($NewLogPath)\*" -Include 'PREP_BISF*.log', 'PERS_BISF*.log' -Exclude '*BISF_WPT*.log', '*dism_bisf*' -Recurse |
					Move-Item -Destination $LogPath -Force
			}

			$Global:LogFile = "$LogPath\$LogFileName"
			$Global:LogFilePath = $LogPath
			$Global:NewLogPath = $LogPath
		}
		$ErrorActionPreference = 'Continue'
		return $LogFile
	}

	function Get-ActualConfig {
		<#
			.SYNOPSIS
				Merge BIS-F registry values into $BISFconfiguration.
			.DESCRIPTION
				Reads all values from the BIS-F registry key and, for each known
				configuration item, overwrites the default data. Unknown values are
				promoted to global variables via New-BISFGlobalVariable.
			.EXAMPLE
				Get-ActualConfig
			.OUTPUTS
				None
			.NOTES
				Author: Matthias Schlimm
		#>
		[CmdletBinding()]
		param()

		# Write-BISFLog -Msg "read values from registry $hklm_software_LIC_CTX_BISF_SCRIPTS"
		# Get all values and data from the BISF registry key
		$RegValues = Get-BISFRegistryValues "$HklmBisfScripts"
		# Check for every key found if this is a valid configuration item and update the data of the value
		foreach ($RegValue in $RegValues) {
			# look if there is a value in the $BISFconfiguration with the same name as the registry value
			$PredefinedData = ($BISFconfiguration | Where-Object { $_.Value -eq ($RegValue.Value) }).Data
			if ($null -ne $PredefinedData) {
				$DefaultData = ($BISFconfiguration | Where-Object { $_.Value -eq ($RegValue.Value) }).Data
				($BISFconfiguration | Where-Object { $_.Value -eq ($RegValue.Value) }).Data = $RegValue.Data # Update the data property in the array with the reg value data
				($BISFconfiguration | Where-Object { $_.Value -eq ($RegValue.value) }).FoundInReg = $true # Update the FoundInReg property in the array with $true
				# Write-BISFLog -Msg "The Value `"$($RegValue.value)`" with data `"$($RegValue.Data)`" read from registry $hklm_software_LIC_CTX_BISF_SCRIPTS overwrites the default value `"$DefaultData`""
			}
			else {
				# Write-BISFLog -Msg "The value `"$($RegValue.Value)`" with data `"$($RegValue.Data)`" read from registry $hklm_software_LIC_CTX_BISF_SCRIPTS is not a valid configuration item."
				New-BISFGlobalVariable -Name $($RegValue.Value) -Value $($RegValue.Data)
			}
		}
	}

	####### end functions #####
}

Process {
	Write-BISFLog -Msg "Setting log file to $(Set-LogFile -Verbose:$VerbosePreference)" -ShowConsole -Color DarkCyan -SubMsg
	Get-ActualConfig -Verbose:$VerbosePreference # Update the $BISFconfiguration with possible registry values
	Write-BISFLog -Msg "Updating log file to $(Set-LogFile -Verbose:$VerbosePreference)" -ShowConsole -Color DarkCyan -SubMsg
	Get-BISFVersion -Verbose:$VerbosePreference
	Get-BISFOSCSessionType -Verbose:$VerbosePreference
	if ($LIC_BISF_PrepLastRunTime) {
		Write-BISFLog -Msg "Last BIS-F Preparation was performed on $LIC_BISF_PrepLastRunTime started by user $LIC_BISF_PrepLastRunUser" -ShowConsole -Color DarkCyan -SubMsg
	}
	Set-BISFLastRun -Verbose:$VerbosePreference
	Write-BISFLog -Msg "Running $State Phase" -ShowConsole -Color DarkCyan -SubMsg
	Invoke-BISFLogRotate -Versions 5 -Directory "$LogFilePath" -Verbose:$VerbosePreference
	Invoke-BISFLogShare -Verbose:$VerbosePreference
	Get-BISFOSInfo -Verbose:$VerbosePreference
	if ($LIC_BISF_CLI_LOG_WPT -eq 1) {
		Write-BISFLog -Msg "Windows Powershell Transcript enabled: $WPTLog" -ShowConsole -Color Cyan
		Invoke-BISFLogRotate -Versions 5 -Directory 'C:\Windows\Logs' -Verbose:$VerbosePreference
	}
	if ($ExportSharedConfiguration) {
		# Check switch ExportSharedConfiguration
		# EHN 36 - Shared Configuration - JSON Export
		if ($LIC_BISF_CLI_EX_PT) {
			# Check Path in Registry if set
			if ($LIC_BISF_POL_AppLayCfg -eq 1) {
				# Check if Citrix AppLayering is configured
				Write-BISFLog -Msg 'Running Export Shared Configuration for Citrix AppLayering' -ShowConsole -Color Cyan

				Write-Host 'Select the Citrix AppLayering Layer to export the current configuration' -ForegroundColor Green
				Write-Host ' '

				# Create dynamic menu based on ADMX configuration
				[array]$MenuItem = @()
				[array]$MenuCfg = @()
				if ($LIC_BISF_CLI_AppLayOSCfg -eq 1) { [array]$MenuItem += 'OS Layer'; [array]$MenuCfg += $AppLayOSCfg }
				if ($LIC_BISF_CLI_AppLayAppPltCfg -eq 1) { [array]$MenuItem += 'App-/Platform Layer'; [array]$MenuCfg += $AppLayAppPltCfg }
				if ($LIC_BISF_CLI_AppLayPltCfg -eq 1) { [array]$MenuItem += 'Platform Layer'; [array]$MenuCfg += $AppLayPltCfg }
				if ($LIC_BISF_CLI_AppLayNoELMcfg -eq 1) { [array]$MenuItem += 'Outside ELM'; [array]$MenuCfg += $AppLayNoELMCfg }

				$i = 0
				foreach ($Item in $MenuItem) {
					Write-Host "     $($i): $($MenuItem[$i])"
					$i++
				}

				Write-Host '     99: exit menu'
				Write-Host ' '

				[int]$Ans = 0
				do {
					try {
						$NumOk = $true
						if ($Ans -eq 99) {
							Write-BISFLog -Msg 'Press any key to exit ...' -ShowConsole -Color Red
							$null = $Host.UI.RawUI.ReadKey('NoEcho, IncludeKeyDown')
							$Global:TerminateScript = $true
							exit
						}
						[int]$Ans = Read-Host "Enter the Number of the Layer: (0 - $($i - 1) ) / 99 exit"
					}
					catch {
						$NumOk = $false
					}
				}
				until (($Ans -ge 0 -and $Ans -lt $i) -and $NumOk)
				$CfgExportFile = Join-Path -Path $LIC_BISF_CLI_EX_PT -ChildPath $MenuCfg[$Ans]
				Write-BISFLog -Msg "Export Registry for $($MenuItem[$Ans]) to $CfgExportFile" -ShowConsole -Color Cyan
				Export-BISFRegistry "$RegLicPolicies" -ExportType json -ExportPath "$CfgExportFile"
			}
			else {
				$CfgOSname = $OSName.Replace(' ', '')
				$CfgOSBitness = $OSBitness
				$CfgExportFile = Join-Path -Path $LIC_BISF_CLI_EX_PT -ChildPath ("BISFconfig_{0}_{1}.json" -f $CfgOSname, $CfgOSBitness)
				Write-BISFLog -Msg "Export Registry to $CfgExportFile" -ShowConsole -Color Cyan
				Export-BISFRegistry "$RegLicPolicies" -ExportType json -ExportPath "$CfgExportFile"
			}
		}
		else {
			Write-BISFLog -Msg 'Error: The custom path for the shared configuration is not configured in the Policy!' -Type E
		}
		Write-BISFLog -Msg 'Press any key to exit ...' -ShowConsole -Color Red
		$null = $Host.UI.RawUI.ReadKey('NoEcho, IncludeKeyDown')
		$Global:TerminateScript = $true
		exit
	}

	# ENH 146: move Get-PendingReboot to earlier phase of preparation
	if ($State -eq 'Preparation') {
		# Check pending reboot before continue
		$CheckPndReboot = Get-BISFPendingReboot
		if (($CheckPndReboot -eq $true) -and (-not $LIC_BISF_CLI_EX)) {
			if (($LIC_BISF_CLI_SR -eq 'NO') -or (-not $LIC_BISF_CLI_SR)) {
				$Text = 'A pending system reboot was detected, please reboot the system and run the script again!'
				Write-BISFLog -Msg $Text -Type E
				return $false
			}
			else {
				Write-BISFLog -Msg 'A pending reboot was detected, but suppressed by GPO configuration!' -Type W
			}
		}
		else {
			Write-BISFLog -Msg "Pending system reboot is $CheckPndReboot"
		}
		$null = Test-BISFCitrixCloudConnector
	}

	Get-BISFPSVersion -Verbose:$VerbosePreference
	Test-BISFRegHive -Verbose:$VerbosePreference
	$Global:DiskIdentifier = Get-BISFCacheDiskID
	$Global:ReturnGetHypervisor = Get-BISFHypervisor -Verbose:$VerbosePreference
	$Global:ReturnTestXDSoftware = Test-BISFXDSoftware -Verbose:$VerbosePreference
	$Global:ReturnTestAppLayeringSoftware = Test-BISFAppLayeringSoftware -Verbose:$VerbosePreference
	$Global:ReturnTestPVSSoftware = Test-BISFPVSSoftware -Verbose:$VerbosePreference
	$Global:ReturnTestVMHVSoftware = Test-BISFVMwareHorizonViewSoftware -Verbose:$VerbosePreference
	$Global:ReturnTestXiFrameSoftware = Test-BISFNutanixFrameSoftware -Verbose:$VerbosePreference
	$Global:ReturnTestParallelsRASSoftware = Test-BISFParallelsRASSoftware -Verbose:$VerbosePreference
	$Global:ReturnTestWVDSoftware = Test-BISFWVDSoftware -Verbose:$VerbosePreference
	$Global:ReturnRequestSysprep = Request-BISFSysprep -Verbose:$VerbosePreference
	$Global:DiskMode = Get-BISFDiskMode -Verbose:$VerbosePreference
	$Global:BootMode = Get-BISFBootMode

	# ENH 12: Set sDelete global Value
	if ($State -eq 'Preparation') {
		Write-BISFLog -Msg "Check SDelete $State config" -ShowConsole -Color Cyan
		if (
			(
				($LIC_BISF_CLI_SD_runBI -ne 1) -and
				($LIC_BISF_CLI_SD_runPVSparentDisk -ne 1) -and
				($LIC_BISF_CLI_SD_runOutsideELM -ne 1)
			) -or
			($LIC_BISF_CLI_SD -ne 'YES')
		) {
			$Global:RunPrepSdelete = $false
			Write-BISFLog -Msg "SDelete is NOT configured to run during $State" -ShowConsole -Color DarkCyan -SubMsg
		}
		else {
			$Global:RunPrepSdelete = $true
			Write-BISFLog -Msg "SDelete is configured to run during $State" -ShowConsole -Color DarkCyan -SubMsg
		}
	}

	if ($State -eq 'Personalization') {
		Write-BISFLog -Msg "Check SDelete $State config" -ShowConsole -Color Cyan
		if (
			(
				($LIC_BISF_CLI_SD_runPVSCacheDisk -ne 1) -and
				($LIC_BISF_CLI_SD_runMCSIO -ne 1) -and
				($LIC_BISF_CLI_SD_runMCS -ne 1)
			) -or
			($LIC_BISF_CLI_SD -ne 'YES')
		) {
			$Global:RunPersSdelete = $false
			Write-BISFLog -Msg "SDelete is NOT configured to run during $State" -ShowConsole -Color DarkCyan -SubMsg
		}
		else {
			$Global:RunPersSdelete = $true
			Write-BISFLog -Msg "SDelete is configured to run during $State" -ShowConsole -Color DarkCyan -SubMsg
		}
	}

	Get-ActualConfig -Verbose:$VerbosePreference # Update the $BISFconfiguration with possible registry values

	# Create Powershell variables from the BISFConfiguration items.
	foreach ($BISFconfig in $BISFconfiguration) {
		New-BISFGlobalVariable -Name $BISFconfig.Value -Value $BISFconfig.Data
	}

	# 03.10.2019 MS: ENH 126 - depend on the new MCSIO redirection the calling of the functions must be different now
	if ($ReturnTestPVSSoftware) {
		if (($State -eq 'Preparation') -and ($LIC_BISF_CLI_P2V_PT -eq '1')) {
			if ($DiskMode -notmatch 'AndSkipImaging') {
				Write-BISFLog -Msg 'Check if there is enough free disk space on the Custom UNC-Path available before proceeding' -ShowConsole -Color Cyan
				$FreeSpace = Get-BISFSpace -Path "$LIC_BISF_CLI_P2V_PT_CUS" -FreeSpace
				$UsedSpace = Get-BISFSpace -Path $env:SystemDrive
				if ($FreeSpace -le $UsedSpace) {
					Write-BISFLog -Msg 'STOP: There is NOT enough Free Space on the Custom UNC path to store the vDisk ' -ShowConsole -Type E -SubMsg
				}
				else {
					Write-BISFLog -Msg "Custom UNC Path has $FreeSpace GB left to convert to SystemDrive with $UsedSpace GB" -ShowConsole -Color DarkCyan -SubMsg
				}
			}
			else {
				Write-BISFLog -Msg 'Skipping Custom UNC Path free disk space, if PVS Master Image creation is skipped !' -ShowConsole -Color DarkCyan -SubMsg
			}
		}
		Use-BISFPVSConfig -Verbose:$VerbosePreference  # 27.07.2017 MS: new created
	}
	else {
		Use-BISFMCSConfig -Verbose:$VerbosePreference  # 03.10.2019 MS: new created
	}

	$TSEnvExist = Get-BISFTaskSequence -Verbose:$VerbosePreference
	if ($TSEnvExist -eq $true) {
		if ($LIC_BISF_CLI_TSLogRedirection -eq 1) {
			$TSEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment
			$LogPath = $TSEnv.Value('LogPath')
			Write-BISFLog -Msg "Set Log folder path to Task Sequence Log folder $LogPath"
			$LogFilePath = "$LogPath"
			$OldLogFile = $LogFile
			$Global:LogFile = "$LogFilePath\$LogFileName"

			if (-not (Test-Path -Path $LogFilePath)) {
				New-Item -Path $LogFilePath -ItemType Directory -Force | Out-Null
			}

			if (Test-Path -Path $OldLogFile -PathType Leaf) {
				Move-Item -Path "$OldLogFile" -Destination "$LogFile"
				Write-BISFLog -Msg "LogFile $LogFile" -ShowConsole -Color DarkCyan -SubMsg
			}
		}
		else {
			Write-BISFLog -Msg "SCCM/MDT Log file Redirection is NOT enabled, using log path $LogPath"
		}
	}
}

End {
	Add-BISFFinishLine
}
