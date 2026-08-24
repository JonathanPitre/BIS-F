Function Initialize-Configuration {
	<#
.SYNOPSIS
	Define global environment
.DESCRIPTION
	Defines the global variables for using in the script framework
.EXAMPLE
	Initialize-BISFConfiguration
.NOTES
	Author: Matthias Schlimm

	History:
		07.09.2015 MS: Added .SYNOPSIS to this function
		03.11.2015 MS: Removed function NimbleFastReclaim would be replaced with Write-ZeroesToFreeSpace
		25.11.2015 MS: Changed WindowTitle from 2015 to 2016
		16.12.2015 MS: Fixed code error 1133 Write-Progress "Done" "Done" -completed
		17.12.2015 MS: Fixed :$ImageSW=$false would be set to false, wrong order
		07.01.2016 MS: Added Optimize-WinSxs
		07.01.2016 MS: Added Test-VMwareHorizonViewSoftware
		07.01.2016 MS: Function Invoke-Service: If No Image Management-Software would be detected, the Service Startup type would not changed to manual
		20.01.2016 MS: Fixed wrong syntax to check if Image Management Software like VDA, PVS Target Device Driver or VMware View Agent is installed
		21.01.2016 MS: Added function Get-OSCSessionType to run BIS-F from console session only
		04.03.2016 MS: Fixed important bug in function invoke-service, services would not started if needed
		04.10.2016 MS: Changed $Global:CTX_BISF_SCRIPTS = "Citrix BISF Scripts" to $Global:CTX_BISF_SCRIPTS = "Login BIS-F"
		09.01.2017 MS: Created function Get-MacAddress
		19.01.2017 JP: Line 1898; Added -Wait parameter for Start-Process
		12.03.2017 MS: add $Global:Wait1= "10"  #global time in seconds
		11.09.2017 MS: add $TaskStates to control the Preparation is running after Personalization first
		03.10.2019 MS: ENH 126 - MCSIO for persistent to set $Global:PVSDiskDrive = LIC_BISF_CLI_MCSIODriveLetter
		07.01.2020 MS: HF 176 - $Global:ImageSW request is set one Time only
		18.02.2020 JK: Fixed Log output spelling
		24.02.2020 MS: ENH 200 - new Advanced Installer - change to get $InstallLocation and $BISFversion
		04.08.2020 MS: HF 271 - 00_PersBISF_WriteCacheDisk.ps1 fails, due to timing issue with registry values
		04.08.2020 MS: HF 272 - Central PERS Logs are missing the beginning
		19.08.2026 JP: Self-heal Path/Version from Framework parent and BISF.psd1 when installer registry is missing
#>

	Write-BISFLog -Msg "- - - Start Script - - - "
	Write-BISFLog -Msg "Checking Prerequisites" -ShowConsole -Color Cyan
	$Global:Computer = $env:COMPUTERNAME
	$Global:CurrentUser = $Env:USERNAME
	$Global:Domain = (Get-CimInstance -ClassName Win32_ComputerSystem).Domain
	$Global:HklmSoftware = "HKLM:\SOFTWARE"
	$Global:HklmSystem = "HKLM:\SYSTEM"
	$Global:HkcuSoftware = "HKCU:\Software"
	$Global:HkuSoftware = "HKU:\.DEFAULT\Software"
	$Global:HklmSoftwarePolicies = "HKLM:\SOFTWARE\Policies"
	$Global:LIC = "Login Consultants"
	$Global:CTX_BISF_SCRIPTS = "BISF"
	$Global:LogFolderName = "BISFLogs"
	$Global:FirstRun = $true
	$Global:HklmBisfScripts = "$HklmSoftware\$LIC\$CTX_BISF_SCRIPTS"
	$Global:FrameworkName = "Base Image Script Framework (BIS-F)"
	$Global:BISFTitle = "$FrameworkName @ EUCweb.com"
	$Host.UI.RawUI.WindowTitle = "$BISFTitle"
	$Global:Wait1 = "10"  #global time in seconds
	$Global:RegLicPolicies = "$HklmSoftwarePolicies\$LIC\$CTX_BISF_SCRIPTS"
	$AppGuid = "{A59AF8D7-4374-46DC-A0CD-8B9B50AFC32E}_is1"
	$HklmUninstall = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
	$Global:HklmFullUninstall = "$HklmUninstall\$AppGuid"

	# Ensure install hive exists (zip install may never have created it)
	if (-not (Test-Path -LiteralPath $HklmBisfScripts)) {
		New-Item -Path $HklmBisfScripts -Force | Out-Null
		Write-BISFLog -Msg "Created registry hive $HklmBisfScripts" -ShowConsole -Color DarkCyan -SubMsg
	}

	# ModuleVersion from loaded manifest is the single source of truth
	$ModuleVersionString = $null
	if ($null -ne $MainModuleName) {
		$LoadedModule = Get-Module -Name $MainModuleName -ErrorAction SilentlyContinue
		if ($null -ne $LoadedModule) {
			$ModuleVersionString = $LoadedModule.Version.ToString()
		}
	}
	if ([string]::IsNullOrEmpty($ModuleVersionString) -and $null -ne $LIB_Folder) {
		$ManifestFile = Join-Path $LIB_Folder 'BISF.psd1'
		if (Test-Path -LiteralPath $ManifestFile) {
			try {
				$ModuleVersionString = (Test-ModuleManifest -Path $ManifestFile -ErrorAction Stop).Version.ToString()
			}
			catch {
				Write-BISFLog -Msg "Could not read ModuleVersion from $ManifestFile : $($_.Exception.Message)" -Type W -SubMsg
			}
		}
	}

	# Derive install root from Framework parent (Main_Folder = ...\Framework)
	$DerivedInstallRoot = $null
	if (-not [string]::IsNullOrEmpty($Main_Folder)) {
		$Parent = Split-Path -Parent $Main_Folder
		if (-not [string]::IsNullOrEmpty($Parent)) {
			$DerivedInstallRoot = $Parent.TrimEnd('\') + '\'
		}
	}

	$RegItem = Get-ItemProperty -Path $HklmBisfScripts -ErrorAction SilentlyContinue
	$RegPath = $null
	$RegVersion = $null
	if ($null -ne $RegItem) {
		if ($RegItem.PSObject.Properties.Name -contains 'Path') { $RegPath = $RegItem.Path }
		if ($RegItem.PSObject.Properties.Name -contains 'Version') { $RegVersion = $RegItem.Version }
	}

	if ([string]::IsNullOrWhiteSpace($RegPath)) {
		if ([string]::IsNullOrEmpty($DerivedInstallRoot)) {
			throw "BIS-F install Path is missing under $HklmBisfScripts and Framework parent could not be derived."
		}
		Set-ItemProperty -Path $HklmBisfScripts -Name 'Path' -Value $DerivedInstallRoot -Type String -Force
		$RegPath = $DerivedInstallRoot
		Write-BISFLog -Msg "Wrote missing Path registry value: $RegPath" -ShowConsole -Color DarkCyan -SubMsg
	}
	else {
		# Normalize trailing backslash expected by shared-config concatenations
		if (-not $RegPath.EndsWith('\')) {
			$RegPath = $RegPath.TrimEnd('\') + '\'
			Set-ItemProperty -Path $HklmBisfScripts -Name 'Path' -Value $RegPath -Type String -Force
		}
	}

	if (-not [string]::IsNullOrEmpty($ModuleVersionString)) {
		if ($RegVersion -ne $ModuleVersionString) {
			Set-ItemProperty -Path $HklmBisfScripts -Name 'Version' -Value $ModuleVersionString -Type String -Force
			if ([string]::IsNullOrWhiteSpace($RegVersion)) {
				Write-BISFLog -Msg "Wrote missing Version registry value: $ModuleVersionString" -ShowConsole -Color DarkCyan -SubMsg
			}
			else {
				Write-BISFLog -Msg "Updated Version registry from '$RegVersion' to '$ModuleVersionString'" -ShowConsole -Color DarkCyan -SubMsg
			}
		}
		$RegVersion = $ModuleVersionString
	}
	elseif ([string]::IsNullOrWhiteSpace($RegVersion)) {
		Write-BISFLog -Msg "WARNING: BIS-F Version could not be determined from module or registry" -Type W -SubMsg
		$RegVersion = 'Unknown'
	}

	$Global:InstallLocation = $RegPath
	$Global:BISFversion = $RegVersion
	Write-BISFLog -Msg "Install location ""$InstallLocation"" " -ShowConsole -Color DarkCyan -SubMsg
	$Global:AppLayOSCfg = "BISFconfig_AppLay_OS.json"
	$Global:AppLayAppPltCfg = "BISFconfig_AppLay_AppPlt.json"
	$Global:AppLayPltCfg = "BISFconfig_AppLay_Plt.json"
	$Global:AppLayNoELMCfg = "BISFconfig_AppLay_NoELM.json"
	$Global:ImageSW = $false
	Import-BISFSharedConfiguration -Verbose:$VerbosePreference
	Write-BISFLog -Msg "Apply Computer GPO" -showConsole -Color Cyan
	Start-BISFProcWithProgBar -ProcPath "$env:SystemRoot\system32\gpupdate.exe" -Args "/Target:Computer /Force /Wait:0" -ActText "Apply Computer GPO" | Out-Null
	Get-BISFCLICmd -Verbose:$VerbosePreference #must be running before the $Global:PVSDiskDrive = $LIC_BISF_CLI_WCD is set

	IF ($LIC_BISF_CLI_MCSCfg -eq "YES") {
		$Global:PVSDiskDrive = $LIC_BISF_CLI_MCSIODriveLetter
	}
 ELSE {
		$Global:PVSDiskDrive = $LIC_BISF_CLI_WCD
	}


	$Global:TaskStates = @("AfterInst", "AfterPrep", "Active", "Finished")
}

function Get-RegistryValues($Key) {
	<#
	.SYNOPSIS
		Read all value names and data from a registry key.
	.DESCRIPTION
		Returns an array of objects with value and data properties for each registry value under the given key.
	.PARAMETER Key
		Registry path to enumerate.
	.EXAMPLE
		Get-BISFRegistryValues -Key "HKLM:\SOFTWARE\Login Consultants\BISF"
	#>
	$Values = (Get-Item $Key).GetValueNames()
	[array]$Result = @()
	Foreach ($Value in $Values) {
		$Result += [PSCustomObject]@{value = "$Value"; data = "$((Get-ItemProperty $Key $Value).$Value)" }
	}
	return $Result
}

function Get-FileVersion ($PathToFile) {
	<#
	.SYNOPSIS
		Get the four-part file version of an executable or DLL.
	.DESCRIPTION
		Reads VersionInfo from the file and returns a System.Version object.
	.PARAMETER PathToFile
		Full path to the file.
	.EXAMPLE
		Get-BISFFileVersion -PathToFile "C:\Windows\System32\kernel32.dll"
	#>
	$File = (Get-Item $PathToFile).VersionInfo
	$Version = New-Object System.Version -ArgumentList @(
		$File.FileMajorPart
		$File.FileMinorPart
		$File.FileBuildPart
		$File.FilePrivatePart
	)
	Write-Output $Version
}

function New-GlobalVariable {
	<#
	.SYNOPSIS
		Create or overwrite a global variable used by BIS-F.
	.DESCRIPTION
		Defines a new AllScope global variable so prep and pers scripts can share state.
	.PARAMETER Name
		Variable name without a scope prefix.
	.PARAMETER Value
		Value to assign.
	.EXAMPLE
		New-BISFGlobalVariable -Name "MyFlag" -Value "YES"
	#>
	param (
		[string]$Name,
		[string]$Value
	)
	## Define new global variable
	New-Variable -Name $Name -Value $Value -option AllScope -Scope Global -Force
	Write-BISFLog -Msg "Define new global variable $Name=$Value"

}

function Get-AdapterName {
	<#
	.SYNOPSIS
		Read network name lice LAN-Connection, etc.
	.DESCRIPTION
	  	Read all DHCP network adapter and give their names back
	.EXAMPLE
		Get-BISFAdapterName

	.NOTES
		Author: Matthias Schlimm

		History:
		07.09.2015 MS: add .SYNOPSIS to this function
#>
	$AdapterIndex = Get-CimInstance -Query "select * from Win32_NetworkAdapterConfiguration  where DHCPEnabled = ""True"" and DNSHostName = ""$env:COMPUTERNAME"" "
	IF (!($null -eq $AdapterIndex)) {
		foreach ($Adapter in $AdapterIndex) {
			$AdapterNr = $Adapter.Index
			$AdapterName = Get-CimInstance -Query "select NetConnectionID from Win32_NetworkAdapter where Index = ""$AdapterNr"" "
			[array]$AdapterNames += $AdapterName.NetConnectionID
		}
	}
	Else {
		Write-BISFLog -Msg "No DHCP network adapter found. DHCP network adapter will be optimized only!" -Type W
		$AdapterNames = $null
	}
	return $AdapterNames

}

function Show-MessageBox {
	<#
	.SYNOPSIS
		Show message box
	.DESCRIPTION
	  	Show message box inside the POSH framework for different scenarios
	.PARAMETER Msg
		Message text displayed in the dialog.
	.PARAMETER Title
		Dialog title. Defaults to an empty string.
	.PARAMETER OkCancel
		Use OK/Cancel buttons.
	.PARAMETER AbortRetryIgnore
		Use Abort/Retry/Ignore buttons.
	.PARAMETER YesNoCancel
		Use Yes/No/Cancel buttons.
	.PARAMETER YesNo
		Use Yes/No buttons.
	.PARAMETER RetryCancel
		Use Retry/Cancel buttons.
	.PARAMETER Critical
		Use the critical (error) icon.
	.PARAMETER Question
		Use the question icon.
	.PARAMETER Warning
		Use the warning icon.
	.PARAMETER Informational
		Use the informational icon.
	.EXAMPLE
		$MsgBox = Show-BISFMessageBox -Msg "your Question " -Title "Title" -YesNo -Question
		if ($MsgBox -eq "YES")
		{
			#YEs answer
		} ELSE {
			# No answer
		}
	.NOTES
		Author: Matthias Schlimm

		History:
		07.09.2015 MS: add .SYNOPSIS to this function
		14.08.2019 MS: FRQ 3 - Remove message box and using default setting if GPO is not configured
	.LINK
		http://msdn.microsoft.com/en-us/library/system.windows.forms.messagebox.aspx
#>
	Param(
		[Parameter(Mandatory = $True)][Alias('M')][String]$Msg,
		[Parameter(Mandatory = $False)][Alias('T')][String]$Title = "",
		[Parameter(Mandatory = $False)][Alias('OC')][Switch]$OkCancel,
		[Parameter(Mandatory = $False)][Alias('OCI')][Switch]$AbortRetryIgnore,
		[Parameter(Mandatory = $False)][Alias('YNC')][Switch]$YesNoCancel,
		[Parameter(Mandatory = $False)][Alias('YN')][Switch]$YesNo,
		[Parameter(Mandatory = $False)][Alias('RC')][Switch]$RetryCancel,
		[Parameter(Mandatory = $False)][Alias('C')][Switch]$Critical,
		[Parameter(Mandatory = $False)][Alias('Q')][Switch]$Question,
		[Parameter(Mandatory = $False)][Alias('W')][Switch]$Warning,
		[Parameter(Mandatory = $False)][Alias('I')][Switch]$Informational
	)
	#Set Message Box Style
	IF ($OkCancel) { $Type = 1 }
	Elseif ($AbortRetryIgnore) { $Type = 2 }
	Elseif ($YesNoCancel) { $Type = 3 }
	Elseif ($YesNo) { $Type = 4 }
	Elseif ($RetryCancel) { $Type = 5 }
	Else { $Type = 0 }

	#Set Message box Icon
	If ($Critical) { $Icon = 16 }
	ElseIf ($Question) { $Icon = 32 }
	Elseif ($Warning) { $Icon = 48 }
	Elseif ($Informational) { $Icon = 64 }
	Else { $Icon = 0 }

	If (!($LIC_BISF_CLI_VS) -or ($LIC_BISF_CLI_VS -eq $false)) {
		#detect CLI switch 'verysilent' to suppress any message boxes
		#Loads the WinForm Assembly, Out-Null hides the message while loading.
		[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null

		#Display the message with input
		$Answer = [System.Windows.Forms.MessageBox]::Show($MSG , $TITLE, $Type, $Icon)
	}
	ELSE {
		$Answer = "VerySilent"
	}
	#Return Answer
	Return $Answer

}

function Write-Log {
	<#
	.SYNOPSIS
		Write the Log file
	.DESCRIPTION
	  	Helper Function to Write Log Messages to Console Output and corresponding log file
	.PARAMETER Msg
		Log message text.
	.PARAMETER ShowConsole
		Also write the message to the console.
	.PARAMETER Color
		Console color when -ShowConsole is used.
	.PARAMETER Type
		Message type: W (warning), E (error, exits), L (external log). Empty is information.
	.PARAMETER SubMsg
		Indent the console line as a sub-message.
	.EXAMPLE
		Write-BISFLog -Msg "Warning Text" -Type W
	.EXAMPLE
		Write-BISFLog -Msg "Text would be shown on Console" -ShowConsole
	.EXAMPLE
		Write-BISFLog -Msg "Text would be shown on Console in Cyan Color, information status" -ShowConsole -Color Cyan
	.EXAMPLE
		Write-BISFLog -Msg "Error text, script would be existing automatically after this message" -Type E
	.EXAMPLE
		Write-BISFLog -Msg "External log content" -Type L
	.NOTES
		Author: Matthias Schlimm

		History:
		07.09.2015 MS: add .SYNOPSIS to this function
		29.09.2015 MS: add switch -SubMsg to define PreMsg string on each console line
		21.11.2017 MS: if Error appears, exit script with Exit 1
        11.10.2029 MS: Show script name in log file
#>

	Param(
		[Parameter(Mandatory = $True)][Alias('M')][String]$Msg,
		[Parameter(Mandatory = $False)][Alias('S')][Switch]$ShowConsole,
		[Parameter(Mandatory = $False)][Alias('C')][String]$Color = "",
		[Parameter(Mandatory = $False)][Alias('T')][String]$Type = "",
		[Parameter(Mandatory = $False)][Alias('B')][Switch]$SubMsg
	)


	$LogType = "INFORMATION..."
	IF ($Type -eq "W" ) { $LogType = "WARNING........."; $Color = "Yellow" }
	IF ($Type -eq "L" ) { $LogType = "EXTERNAL LOG...."; $Color = "DarkYellow" }
	IF ($Type -eq "E" ) { $LogType = "ERROR..............."; $Color = "Red" }

	IF (!($SubMsg)) {
		$PreMsg = "+"
	}
	ELSE {
		$PreMsg = "`t>"
	}

	$Date = Get-Date -Format G
	Out-File -Append -FilePath $LogFile -InputObject "$Date | $env:username | $LogType | $Msg" -Encoding default

	IF ($LIC_BISF_CLI_DB -eq $true) {
		#Debug mode is enabled
		Write-Host "- - - DebugMode enabled: Press any key to continue - - -" -ForegroundColor White
		$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		$VerbosePreference = "Continue"
	}

	If (!($ShowConsole)) {
		IF (($Type -eq "W") -or ($Type -eq "E" )) {
			IF ($VerbosePreference -eq 'SilentlyContinue') {
				Write-Host "$PreMsg $Msg" -ForegroundColor $Color
				$Color = $null
			}
		}
		ELSE {
			Write-Verbose -Message "$PreMsg $Msg"
			$Color = $null
		}

	}
	ELSE {
		if ($Color -ne "") {
			IF ($VerbosePreference -eq 'SilentlyContinue') {
				Write-Host "$PreMsg $Msg" -ForegroundColor $Color
				$Color = $null
			}
		}
		else {
			Write-Host "$PreMsg $Msg"
		}
	}
	IF ($Type -eq "E" ) { $Global:TerminateScript = $true; Start-Sleep 30; Exit 1 }
}


function Invoke-FolderScripts {
<#
	.SYNOPSIS
		Get the PS1 Files from a specific folder and process all scripts
	.DESCRIPTION
	  	process all PS1 files in a ascending order from the specific path
	.PARAMETER Path
		Folder that contains the .ps1 scripts to run.
	.PARAMETER ErrorHandling
		When set, treat a non-zero script exit as a terminating error.
	.EXAMPLE
		Invoke-BISFFolderScripts -path "C:\Program Files (x86)\Base Image Script Framework\Framework\SubCall\Preparation"

	.NOTES
		Author: Matthias Schlimm

		History:
		  
		  14.05.2020 MS: HF 239 - Invoke-FolderScripts is relying on the default order from Get-ChildItem
#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	PARAM(
		[Parameter(Mandatory = $True)][String]$Path,
		[Parameter(Mandatory = $False)][Switch]$ErrorHandling
	)
	Write-BISFLog -Msg "Loading Scripts from $Path"
	$Scripts = @(Get-ChildItem -Path $Path -Filter "*.ps1") | Sort-Object -Property Name
	Write-Verbose -message "$Scripts"
	IF ($null -ne $Scripts) {
		Foreach ($Item in $Scripts) {
			IF ($TerminateScript -eq $true) {
				Write-BISFLog -Msg "Check log file $LogFile for further information!" -Type W
				Write-BISFLog -Msg "Script exiting!" -Color Red
				Start-Sleep 5
				break
			}
			ELSE {
				Write-BISFLog -Msg "=========================== $($Item.name) ==========================="
			}
			if (-not $PSCmdlet.ShouldProcess($Item.FullName, 'Invoke script')) {
				continue
			}
			$ResCode = . $Item.FullName
			if ($ErrorHandling) {
				If ($ResCode -ne "Success") {
					Write-BISFLog -Msg "Error: $ResCode in Script Execution, Check $Item.log"  -Type E
				}
				else {
					Write-BISFLog -Msg "Script execution successful"
				}
			}
		}
	}
}

function Test-WriteCacheDiskDriveLetter {
	<#
		.SYNOPSIS
			Test if the WriteCacheDisk DriveLetter is configured
		.DESCRIPTION
			Test if the WriteCacheDisk DriveLetter is configured via ADMX
		.EXAMPLE
			Test-BISFWriteCacheDiskDriveLetter

		.NOTES
			Author: Matthias Schlimm

			History:
			12.03.2017 MS: add .SYNOPSIS to this function
			12.03.2017 MS: configure WriteCacheDisk DriveLetter with ADMX or show error if PVS Target Device Driver is installed
			03.10.2019 MS: ENH 126 - added MCSIO
			03.10.2019 MS: FRQ 3 - Remove message box
			04.01.2020 MS: HF 170 - using wrong $variable -> $LIC_BISF_POL_MCSCfg instead of $LIC_BISF_CLI_MCSCfg
	#>

	IF ($ReturnTestPVSSoftware) {
		IF ($null -eq $LIC_BISF_CLI_WCD) {
			Write-BISFLog -Msg "PVSWriteCacheDisk not configured with ADMX, configure it and run this script again! " -Type E -SubMsg
			return $false
			break
		}
		ELSE {
			$Global:PVSDiskDrive = $LIC_BISF_CLI_WCD
			Write-BISFLog -Msg "PVSWriteCacheDisk configured: $PVSDiskDrive" -ShowConsole -Color DarkCyan -SubMsg
			return $true
		}
	}

	# IF $MCSIO can be used with VDA 1903 and later and the BIS-F MCSIO ADMX is configured as well
	IF (($MCSIO) -and ($LIC_BISF_CLI_MCSCfg -eq "YES")) {
		$Global:PVSDiskDrive = $LIC_BISF_CLI_MCSIODriveLetter
		Write-BISFLog -Msg "MCSIO persistent Disk is configured: $PVSDiskDrive" -ShowConsole -Color DarkCyan -SubMsg
		return $true

	}
}

function Get-PSVersion {
	<#
	.SYNOPSIS
		Retrieve the PoSh Host Major version
	.DESCRIPTION
	.EXAMPLE
		Get-BISFPSVersion
	.NOTES
		Author: Matthias Schlimm

		History:
		23.05.2020 MS: HF 217 - Powershell Version 5 as minimum requirement
	#>
	$PShostMajor = $PSVersionTable.PSVersion.Major
	IF ($PShostMajor -lt 5) {
		Write-BISFLog -Msg "Notification only: Powershell Version $PShostMajor NOT up to date, possible to update to minimum version 5 or higher to prevent further issues" -ShowConsole -Color Yellow -Type W -SubMsg
		Start-Sleep 20
	} else 	{
		Write-BISFLog -Msg "Powershell Version $PShostMajor" -ShowConsole -Color DarkCyan -SubMsg
	}
}

function Test-RegHive {
	<#
	.SYNOPSIS
		Ensure the BIS-F registry hive exists.
	.DESCRIPTION
		Creates HKLM\SOFTWARE\Login Consultants\BISF if it is missing. Returns true when the hive was created, false when it already existed.
	.EXAMPLE
		Test-BISFRegHive
	#>
	IF (!(Test-Path $HklmSoftware\$LIC\$CTX_BISF_SCRIPTS)) {
		New-Item -Path $HklmSoftware -Name $LIC -Force | Out-Null
		New-Item -Path $HklmSoftware"\"$LIC -Name $CTX_BISF_SCRIPTS -Force | Out-Null
		Write-BISFLog -Msg "Create RegHive $HklmSoftware\$LIC\$CTX_BISF_SCRIPTS"
		return $true
	}
	ELSE {
		Write-BISFLog -Msg "Check RegHive $HklmSoftware\$LIC\$CTX_BISF_SCRIPTS"
		return $false
	}
	Write-BISFLog -Msg "Initialize $CTX_BISF_SCRIPTS ...$FirstRun"

}

function Test-WriteCacheDisk {
	<#
	.SYNOPSIS
		check PVSDiskDrive, if not abort script
	.DESCRIPTION
	  	check PVSDiskDrive, if not abort script
	.EXAMPLE
		Test-BISFWriteCacheDisk

	.NOTES
		Author: Matthias Schlimm

		History:
		12.03.2017 MS: add .SYNOPSIS to this function
		03.10.2019 MS: ENH 126 - added MCSIO persistent drive
		03.10.2019 MS: FRQ 3 - Remove message box
		04.01.2020 MS: HF 170 - C:\Windows\Logs does not exist
#>
	IF ($ReturnTestPVSSoftware) {
		$Global:PVSDiskDrive = $LIC_BISF_CLI_WCD
	} ELSE {
		IF (($MCSIO) -and ($LIC_BISF_CLI_MCSCfg -eq "YES")) {
			$Global:PVSDiskDrive = $LIC_BISF_CLI_MCSIODriveLetter
		}
	}

	IF ($PVSDiskDrive.substring(0,2) -eq $env:SystemDrive) {
		Write-BISFLog -Msg "No separate Cache Disk configured"
		return $true
		}
	ELSE {
		$CacheDisk = Get-CimInstance -Query "SELECT * from Win32_LogicalDisk where DriveType = 3 and DeviceID = ""$PVSDiskDrive"""
		IF ($null -eq $CacheDisk) {
			Write-BISFLog -Msg "Disk $PVSDiskDrive does not exist. Please create a new local disk with enough space, assign DriveLetter $PVSDiskDrive and run this script again!" -Type E -SubMsg
			return $false
		}
		ELSE {
			Write-BISFLog -Msg "Check WriteCache Disk $PVSDiskDrive"
			return $true
		}
	}
}

function Get-Version {
	<#
	.SYNOPSIS
		Display the running BIS-F version and DTAP stage.
	.DESCRIPTION
		Uses ModuleVersion from BISF.psd1 (mirrored in registry Version). YYMM.minor
		versions (for example 2608.0) are treated as production. Legacy four-part
		7.1912.* builds still map the first digit of the last segment to DTAP
		(1=prod, 2=beta, 3=test, 4=developer).
	.EXAMPLE
		Get-BISFVersion

	.NOTES
		Author: Matthias Schlimm

		History:
		25.07.2017 MS: add .SYNOPSIS to this function
		25.07.2017 MS: replace $ReleaseType (that is manual change in the script to set Alpha, beta or prod release) with $LIC_BISF_BuildNumber.substring(0,2) to get the right DTAP Stage
		03.10.2019 MS: ENH 90 - new version numbers 7.1912.0
		24.02.2020 MS: ENH 200 - new Advanced Installer - change to get DTAP Stage
		19.08.2026 JP: Support YYMM.minor; stop false BuildNumber warning for 2608.0
	#>

	IF ($ExportSharedConfiguration) { $Host.UI.RawUI.WindowTitle = "$BISFTitle [$BISFversion] - ExportSharedConfiguration" } ELSE { $Host.UI.RawUI.WindowTitle = "$BISFTitle [$BISFversion]" }

	if ([string]::IsNullOrWhiteSpace($BISFversion) -or $BISFversion -eq 'unknown') {
		Write-BISFLog -Msg "WARNING: The BuildNumber could not be determined !!" -Type W -SubMsg
		Start-Sleep $Wait1
		return
	}

	$Parts = $BISFversion.Split('.')
	# Modern scheme: YYMM.minor (two segments, first is year-month)
	if ($Parts.Count -eq 2 -and $Parts[0] -match '^\d{4}$') {
		Write-BISFLog -Msg "Running Version $BISFversion" -ShowConsole -SubMsg -Color DarkCyan
		return
	}

	# Legacy 7.1912.* DTAP: first digit of last segment
	if ($Parts.Count -ge 4) {
		$LastSegment = $Parts[-1]
		if ($LastSegment.Length -ge 1) {
			$BuildNbr = $LastSegment.Substring(0, 1)
			switch ($BuildNbr) {
				4 { Write-BISFLog -Msg "WARNING: This running version $BISFversion is a DEVELOPER Release, not for production use!" -Type W -SubMsg ; Start-Sleep $Wait1; return }
				3 { Write-BISFLog -Msg "WARNING: This running version $BISFversion is a TEST Release, not for production use!" -Type W -SubMsg ; Start-Sleep $Wait1; return }
				2 { Write-BISFLog -Msg "WARNING: This running version $BISFversion is a BETA Release, User Acceptance Test only!" -Type W -SubMsg ; Start-Sleep $Wait1; return }
				1 { Write-BISFLog -Msg "Running Version $BISFversion" -ShowConsole -SubMsg -Color DarkCyan; return }
			}
		}
	}

	# Unknown shape but we have a version string - still report it as running
	Write-BISFLog -Msg "Running Version $BISFversion" -ShowConsole -SubMsg -Color DarkCyan
}

function Set-NetworkProviderOrder {
	<#
	.SYNOPSIS
		Move a network provider to the last position in ProviderOrder.
	.DESCRIPTION
		Reads HKLM:\SYSTEM\CurrentControlSet\Control\NetworkProvider\Order and appends the named provider so it is last.
	.PARAMETER SearchProviderOrder
		Provider name to move, for example LanmanWorkstation.
	.EXAMPLE
		Set-BISFNetworkProviderOrder -SearchProviderOrder "LanmanWorkstation"
	#>
	PARAM(
		[parameter(Mandatory = $True)][string]$SearchProviderOrder
	)
	#search for the entered ProviderOrder and set this to the last one
	$Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\NetworkProvider\Order'
	$Value = 'ProviderOrder'
	$RawProviderOrder = $null
	$RegItem = Get-ItemProperty -Path $Key -Name $Value -ErrorAction SilentlyContinue
	IF ($null -ne $RegItem) { $RawProviderOrder = $RegItem.$Value }
	IF ([string]::IsNullOrEmpty($RawProviderOrder)) {
		Write-BISFLog -Msg "Warning: Registry value $Key\$Value not found..." -Type W
		return $false
	}
	# Force an array: a single provider (no comma) must not unroll to a string of characters
	[array]$ProviderOrder = @($RawProviderOrder.Split(','))

	Write-BISFLog -Msg "Change the NetworkProviderOrder, look for entry $SearchProviderOrder"

	$FoundIndex = -1
	for ($i = 0; $i -lt $ProviderOrder.Count; $i++) {
		IF ($ProviderOrder[$i] -eq $SearchProviderOrder) {
			$FoundIndex = $i
			Write-BISFLog -Msg "SearchString $SearchProviderOrder is found in index $FoundIndex"
		}
	}

	IF ($FoundIndex -lt 0) {
		Write-BISFLog -Msg "Warning: SearchString $SearchProviderOrder not found..." -Type W
		return $false
	}

	# Drop all matches, then append once so Unique cannot keep an earlier duplicate
	$WriteReg = (@($ProviderOrder | Where-Object { $_ -ne $SearchProviderOrder }) + $SearchProviderOrder) -join ","

	Set-ItemProperty $Key $Value $WriteReg
	Write-BISFLog -Msg "Set $SearchProviderOrder to the last index; NetworkProviderOrder is $WriteReg"

}

function Test-PVSSoftware {
	<#
	.SYNOPSIS
		check if the PVS Target Device Driver installed
	.DESCRIPTION
	  	if the PVS Target Device Driver installed they will send a true or false value and will set the global variable ImageSW to true or false
	.EXAMPLE
		Test-BISFPVSSoftware
	.NOTES
		Author: Matthias Schlimm

		History:
		07.09.2015 MS: add .SYNOPSIS to this function
		07.01.2020 MS: HF 176 - $Global:ImageSW request is set one Time only

#>
	$Svc = Test-BISFService -ServiceName "BNDevice" -ProductName "Citrix Provisioning Services Target Device Driver (PVS)"
	IF ($Svc -eq $true) { $Global:ImageSW = $true }
	return $Svc

}

function Test-XDSoftware {
	<#
	.SYNOPSIS
		check if the XenDesktop VDA installed
	.DESCRIPTION
	  	if the XenDesktop VDA installed they will send a true or false value and will set the global variable ImageSW to true or false
	.EXAMPLE
		Test-BISFXDSoftware
	.NOTES
		Author: Matthias Schlimm

		History:
		07.09.2015 MS: add .SYNOPSIS to this function
		25.08.2019 MS: ENH 126: detect MCSIO based on VDA Minimum Version
		05.01.2020 MS: ENH 165: detect UPL - new feature with VDA 1912 LTSR
		07.01.2020 MS: HF 176 - $Global:ImageSW request is set one Time only

#>
	$Svc = Test-BISFService -ServiceName "BrokerAgent" -ProductName "Citrix XenDesktop Virtual Desktop Agent (VDA)"

	IF ($Svc -eq $true) {
		$Version = Get-BISFFileVersion $GlbSVCImagePath
		$Global:VDAVersion = "$($Version.Major).$($Version.Minor)"
		$CheckVersion = "7.21" #VDA 1903
		IF ($VDAVersion -ge $CheckVersion){
			$Global:MCSIO = $true
			Write-BISFLog "VDA Version $VDAVersion supports MCS IO with persistent disk" -ShowConsole -Color DarkCyan -SubMsg
		} ELSE {
			$Global:MCSIO = $false
			Write-BISFLog "VDA version $VDAVersion does NOT support MCS IO with persistent disk"
		}
		$Global:ImageSW = $true
		$Global:UPL = $false
		$CheckVersion = "7.24" # VDA 1912  with UPL support
		IF ($VDAVersion -ge $CheckVersion){
			Write-BISFLog "VDA Version $VDAVersion supports User Personalization Layer (UPL).. check if the UPL Services are installed" -ShowConsole -Color DarkCyan -SubMsg
			$UPLsvc1 = Test-BISFService -ServiceName "upl-Support" -ProductName "Citrix UPL Support Service"
			$UPLsvc2 = Test-BISFService -ServiceName "ulayer" -ProductName "Citrix Layering Service"
			IF (($UPLsvc1 -eq $true) -and ($UPLsvc2 -eq $true)) {
				$Global:UPL = $true
				Write-BISFLog "UPL Services are installed" -ShowConsole -Color DarkCyan -SubMsg
			} ELSE {
				Write-BISFLog "UPL Services are NOT installed"
			}
		} ELSE {
			Write-BISFLog "VDA version $VDAVersion does NOT support User Personalization Layer (UPL)"
		}
	}

	return $Svc

}

function Get-OSInfo {
	<#
	.SYNOPSIS
		Collect operating system information into BIS-F globals.
	.DESCRIPTION
		Sets OSName, OSBitness, OSVersion, ProductType, language, and Program Files / Wow6432Node paths used by later scripts.
	.EXAMPLE
		Get-BISFOSInfo
	#>
	$Win32OS = Get-CimInstance -ClassName Win32_OperatingSystem
	$Global:OSName = $Win32OS.caption
	$Global:OSBitness = $Win32OS.OSArchitecture
	$Global:OSVersion = $Win32OS.version
	$Global:MuiLang = $Win32OS.MUILanguages
	$Global:ProductType = $Win32OS.ProductType
	Write-BISFLog -Msg "Operating System: $OSName"
	Write-BISFLog -Msg "Architecture: $OSBitness"
	Write-BISFLog -Msg "Version: $OSversion"
	Write-BISFLog -Msg "ProductType: $ProductType [1=Client, 2=DomainController, 3=MemberServer]"
	Write-BISFLog -Msg "Language: $MUIlang"

	IF ($OSBitness -eq "32-bit") {
		$Global:ProgramFilesx86 = "${env:ProgramFiles}"
		$Global:CommonProgramFilesx86 = "${env:CommonProgramFiles}"
		$Global:HklmSoftwareX86 = "$HklmSoftware"
	}
	ELSE {
		$Global:ProgramFilesx86 = "${env:ProgramFiles(x86)}"
		$Global:CommonProgramFilesx86 = "${env:CommonProgramFiles(x86)}"
		$Global:HklmSoftwareX86 = "$HklmSoftware\Wow6432Node"
	}
	Write-BISFLog -Msg "ProgramFiles X86 Path is set to: $ProgramFilesx86"
	Write-BISFLog -Msg "CommonProgramFiles X86 is set to: $CommonProgramFilesx86"
	Write-BISFLog -Msg "HKLM_sw_x86 is set to: $HklmSoftwareX86"

}

function Show-ProgressBar {
	<#
	.SYNOPSIS
		Show a PowerShell progress bar
	.DESCRIPTION
	  	Show Powershell progress bar to see something is working in the background, it checks an active process
	.PARAMETER CheckProcess
		A process object to pass to the function. This can be retrieved with "Get-Process" and stored as a variable
	.PARAMETER CheckProcessId
		A process ID that the function will check against.
	.PARAMETER ActivityText
		Text that describes what the progress bar is waiting on.
	.PARAMETER MaximumExecutionMinutes
		The amount of time in minutes that the function will wait before continuing.
	.PARAMETER TerminateRunawayProcess
		If the maximum execution time is exceeded this switch will forcibly terminate the process.
	.EXAMPLE
		Show-BISFProgressBar
	.NOTES
		Author: Matthias Schlimm

		History:
		28.06.2017 MS: add .SYNOPSIS to this function
		22.06.2017 FF: add ProgressID to this function to use it instead of ProgressName only
		31.08.2017 MS: POSH progress bar, sleep time during preparation only
		05.09.2017 TT: Added Maximum Execution Minutes and Terminate Runaway Process parameters
		25.03.2018 MS: Feature 17: Read $MaximumExecutionMinutes from ADMX if not internal override during BIS-F Call
		11.01.2020 MS: HF 181 - function never ends if it triggers from MDT cscript

#>
	PARAM(
		[parameter()][string]$CheckProcess,
		[parameter()][int]$CheckProcessId,
		[parameter(Mandatory = $True)][string]$ActivityText,
		[parameter()][int]$MaximumExecutionMinutes,
		[parameter()][switch]$TerminateRunawayProcess
	)
	$a = 0

	IF ($MaximumExecutionMinutes) {
		$MaximumExecutionTime = (Get-Date).AddMinutes($MaximumExecutionMinutes)
		Write-BISFLog "Maximum execution time will default override with the value of $MaximumExecutionTime minutes"
	}
	ELSE {
		IF ($LIC_BISF_CLI_METCfg -eq "YES") { $MaximumExecutionMinutes = $LIC_BISF_CLI_MET }
		IF ($LIC_BISF_CLI_METCfg -eq "NO") { $MaximumExecutionMinutes = 1440 }
		IF (($LIC_BISF_CLI_METCfg -eq "") -or ($null -eq $LIC_BISF_CLI_METCfg)) { $MaximumExecutionMinutes = 60 }
		$MaximumExecutionTime = (Get-Date).AddMinutes($MaximumExecutionMinutes)
		Write-BISFLog "Maximum execution time used the GPO value with $MaximumExecutionMinutes minutes"
	}

	Start-Sleep 5
	for ($a = 0; $a -lt 100; $a++) {
		IF ($a -eq "99") { $a = 0 }
		If ($CheckProcessId) {
			$ProcessActive = Get-Process -Id $CheckProcessId -ErrorAction SilentlyContinue
		}
		else {
			If ($CheckProcess -ne "cscript") {
				$ProcessActive = Get-Process $CheckProcess -ErrorAction SilentlyContinue
			} Else {
				$ProcessActive = $null
			}
		}
		#$ProcessActive = Get-Process $CheckProcess -ErrorAction SilentlyContinue  #26.07.2017 MS: comment-out:

		if ((Get-Date) -ge $MaximumExecutionTime) {
			Write-BISFLog -Msg "The operation has exceeded the maximum execution time of $MaximumExecutionMinutes Minutes." -Type W
			if ($TerminateRunawayProcess) {
				Write-BISFLog -Msg "Forcibly terminating process. $($ProcessActive.Name)" -Type W
				Stop-Process $ProcessActive -Force -ErrorAction SilentlyContinue
				Clear-Variable -Name "ProcessActive"
			}
			else {
				Clear-Variable -Name "ProcessActive" #this nulls out the variable allowing the "finish" bar
			}
		}

		if ($null -eq $ProcessActive) {
			$a = 100
			Write-Progress -Activity "Finish...waiting for next operation in 3 seconds" -PercentComplete $a -Status "Finish."
			IF ($State -eq "Preparation") { Start-Sleep 3 }
			Write-Progress "Done" "Done" -completed
			break
		}
		else {
			Start-Sleep 1
			$Display = "{0:N2}" -f $a #reduce display to 2 digits on the right side of the numeric
			Write-Progress -Activity "$ActivityText" -PercentComplete $a -Status "Please wait..."
		}
	}
}

function Get-LogContent {
	<#
	.SYNOPSIS
		Append an external log file into the BIS-F log.
	.DESCRIPTION
		Reads the given file and writes each non-empty line with Write-BISFLog -Type L.
	.PARAMETER GetLogFile
		Path of the log file to import.
	.EXAMPLE
		Get-BISFLogContent -GetLogFile "C:\Windows\Logs\VIEtool.log"
	#>
	PARAM(
		[parameter(Mandatory = $True)][string]$GetLogFile
	)
	Write-BISFLog -Msg "Get content from file $GetLogFile...please wait"
	Write-BISFLog -Msg "-----snip-----"
	$Content = Get-Content "$GetLogFile" -ErrorAction SilentlyContinue
	foreach ($Line in $Content) { IF (!($Line -eq "")) { Write-BISFLog -Msg "$Line" -Type L } }
	Write-BISFLog -Msg "-----snap-----"

}

function Test-Log {
	<#
	.SYNOPSIS
		Search a log file for a string.
	.DESCRIPTION
		Returns true if the search string is found in the file. Errors if the file does not exist.
	.PARAMETER CheckLogFile
		Path of the log file to search.
	.PARAMETER SearchString
		Text to find.
	.EXAMPLE
		Test-BISFLog -CheckLogFile "C:\Windows\Logs\BISFtmpProcessLog.log" -SearchString "error"
	#>
	PARAM(
		[parameter(Mandatory = $True)][string]$CheckLogFile,
		[parameter(Mandatory = $True)][string]$SearchString
	)
	Write-BISFLog -Msg "Check $CheckLogFile"
	IF (Test-Path ($CheckLogFile) -PathType Leaf) {
		Write-BISFLog -Msg "Check $CheckLogFile for $SearchString"
		$SearchP2PVS = Select-String -path "$CheckLogFile" -pattern "$SearchString" | Out-String
		IF ($SearchP2PVS) { return $True } else { return $false }
	}
	ELSE {
		Write-BISFLog -Msg "File $CheckLogFile does not exist" -Type E
		$SearchP2PVS = ""
	}
	return $SearchP2PVS

}

function Add-FinishLine {
	<#
	.SYNOPSIS
		Write the standard finish banner to the BIS-F log.
	.DESCRIPTION
		Used at the End block of prep and pers scripts to mark script completion.
	.EXAMPLE
		Add-BISFFinishLine
	#>
	Write-BISFLog -Msg "=========================== FINISH SCRIPT ==========================="
}

function Get-SoftwareInfo {
	<#
	.SYNOPSIS
	  Gets all installed software info about package(s)
	.DESCRIPTION
	  The script will return an array of objects based on registry key values.
	  When the criteria are specific enough the return value should contain one object. This can
	  be achieved by combining multiple parameters with specific names.

	  The parameters are searched for on a wildcard base. So it is possible that one parameter will result in multiple objects. TIP: be more specific and/or use multiple properties of the software.
	.PARAMETER Name
	  This is the display name registry value within the sub keys of HKLM\SOFTWARE(\Wow6432Node)\Microsoft\Windows\CurrentVersion\Uninstall
	.PARAMETER Version
	  This is the DisplayVersion registry value within the sub keys of HKLM\SOFTWARE(\Wow6432Node)\Microsoft\Windows\CurrentVersion\Uninstall
	.PARAMETER Publisher
	  This is the Publisher registry value within the sub keys of HKLM\SOFTWARE(\Wow6432Node)\Microsoft\Windows\CurrentVersion\Uninstall
	.PARAMETER InstallLocation
	  This is the InstallLocation registry value within the sub keys of HKLM\SOFTWARE(\Wow6432Node)\Microsoft\Windows\CurrentVersion\Uninstall
	.EXAMPLE Resolve Installation Location
	  $Package = Get-BISFSoftwareInfo -Name "Citrix Provision Services Target Device" -Publisher "Citrix"
	  $InstallationPath = $Package.GetEnumerator().InstallLocation


	  [System.Array]
	.NOTES
	  Author: Mike Bijl

	  History
	  2014-11-07T12:24:59 : Initial writing of the function.
	#>
	param(
		[string]$Name = "",
		[string]$Version = "",
		[string]$Publisher = "",
		[string]$InstallLocation = ""
	)
	$Info = @()

	# Get Uninstall registry keys x64 on a x64 system or the x86 on a x86 system
	$Keys = @(Get-ChildItem -path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | Where-Object { ((Get-ItemProperty -Path $_.PsPath).DisplayName -like "*$Name*") -and ((Get-ItemProperty -Path $_.PsPath).displayVersion -like "*$Version*") -and ((Get-ItemProperty -Path $_.PsPath).Publisher -like "*$Publisher*") -and ((Get-ItemProperty -Path $_.PsPath).InstallLocation -like "*$InstallLocation*") })
	# Get Uninstall registry keys x86 on a x64 system or skip this step on a x86 system
	If ((Test-Path "Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") -eq $true) {
		$Keys += @(Get-ChildItem -path "Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" | Where-Object { ((Get-ItemProperty -Path $_.PsPath).DisplayName -like "*$Name*") -and ((Get-ItemProperty -Path $_.PsPath).DisplayNameVersion -like "*$Version*") -and ((Get-ItemProperty -Path $_.PsPath).Publisher -like "*$Publisher*") -and ((Get-ItemProperty -Path $_.PsPath).InstallLocation -like "*$InstallLocation*") })
	}

	# Get the values from the registry keys which hold the info.
	Foreach ($Key in $Keys) {
		$Info += (Get-ItemProperty -Path $Key.PSPath)
	}

	# The comma is in the return to force the object that is returned, is always an array.
	return , $Info

}

Function Get-PendingReboot {
	<#
.SYNOPSIS
	Gets the pending reboot status on a local computer

.DESCRIPTION
	Returns true if Component Based Servicing, Windows Update, pending file rename, or SCCM reports a reboot is required.

.EXAMPLE
   Get-BISFPendingReboot

.NOTES
   #Adapted from https://gist.github.com/altrive/5329377
	#Based on <http://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542>
	Author: Matthias Schlimm
	  Company: EUCweb

	  History
	  dd.mm.yyy MS: script created
	  27.05.2018 MS: Hotfix 40: new Script to get pending reboot state
	  14.05.2019 JP: Improved Get-PendingReboot function, removed wmi commands
	  21.11.2010 MS: HF 280 - Log Message for "pending reboot error"
#>


	If (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) {
		Write-BISFLog -Msg "Component Based Servicing: $true" -ShowConsole -Color DarkCyan -SubMsg
		return $true
	}
	If (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) {
		Write-BISFLog -Msg "Windows Update: $true" -ShowConsole -Color DarkCyan -SubMsg
		return $true
	}
	If (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) {
		Write-BISFLog -Msg "Session Manager - PendingFileRenameOperations: $true" -ShowConsole -Color DarkCyan -SubMsg
		return $true
	}
	try {
		$RebootPending = Invoke-CimMethod -Namespace root\ccm\ClientSDK -ClassName CCM_ClientUtilities -Name DetermineIfRebootPending -ErrorAction SilentlyContinue | Select-Object "RebootPending"
		If ($RebootPending -eq $true) {
			Write-BISFLog -Msg "RebootPending: $RebootPending" -ShowConsole -Color DarkCyan -SubMsg
		}

		$IsHardRebootPending = Invoke-CimMethod -Namespace root\ccm\ClientSDK -ClassName CCM_ClientUtilities -Name DetermineIfRebootPending -ErrorAction SilentlyContinue | Select-Object "IsHardRebootPending"
		If ($IsHardRebootPending -eq $true) {
			Write-BISFLog -Msg "IsHardRebootPending: $IsHardRebootPending" -ShowConsole -Color DarkCyan -SubMsg
		}

		If (($RebootPending -eq $true) -or ($IsHardRebootPending -eq $true)) { return $true }
	}
	catch {
		# Expected when CCM client SDK / reboot-pending query is unavailable
		$null = $_
	}
	return $false
}

function Convert-Settings {
	<#
	.SYNOPSIS
		Migrate legacy Citrix BISF Scripts registry and task settings.
	.DESCRIPTION
		Removes the old LIC_PVS_Device_Personalize scheduled task when present.
	.EXAMPLE
		Convert-BISFSettings
	#>
	# Migrate Registry settings from Citrix BISF Scripts to BISF

	$OldTask = "LIC_PVS_Device_Personalize"
	$QueryTask = schtasks.exe /query /v /fo csv | ConvertFrom-Csv | ForEach-Object { $_.TaskName }
	Foreach ($Task in $QueryTask) {
		IF ($Task -eq "\LIC_PVS_Device_Personalize") {
			Write-BISFLog -Msg "Migrating BISF Settings: delete old Task $OldTask" -ShowConsole -Color DarkCyan -SubMsg
			& schtasks.exe /delete /TN $OldTask /F | Out-Null
		}
	}
}

Function Get-TaskSequence() {
	<#
	.SYNOPSIS
		Detect whether BIS-F is running inside an MDT or SCCM Task Sequence.
	.DESCRIPTION
		Loads Microsoft.SMS.TSEnvironment when available. Returns true in a Task Sequence and suppresses shutdown via LIC_BISF_CLI_SB.
	.EXAMPLE
		Get-BISFTaskSequence
	#>
	Try {
		[__ComObject]$SMSTSEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction 'SilentlyContinue' -ErrorVariable SMSTSEnvironmentErr
	}
	Catch {
		# Expected when not running inside an MDT/SCCM Task Sequence
		$null = $_
	}
	If ($SMSTSEnvironmentErr) {
		Write-BISFLog -Msg "Unable to load ComObject [Microsoft.SMS.TSEnvironment]."
		Write-BISFLog -Msg "The script is not currently running from an MDT or SCCM Task Sequence."
		Return $false
	}
	ElseIf ($null -ne $SMSTSEnvironment) {
		Write-BISFLog -Msg "Successfully loaded ComObject [Microsoft.SMS.TSEnvironment]."
		Write-BISFLog -Msg "The script is currently running from an MDT or SCCM Task Sequence."
		$Global:LIC_BISF_CLI_SB = "NO"
		Write-BISFLog -Msg "A system shutdown after successful build will be suppressed, it must be performed from Task Sequence!" -Type W
		Return $true
	}

}


<#
	For Powershell 3.0 compatibility.  Custom ScheduledTask functions...
	goal -> Recreate "Get-ScheduledTask for Powershell 3.0.
	cmdlet should retrieve a task with enough properties so the other recreated functions:
	"Disable-ScheduledTask" and "Enable-ScheduledTask" can operate.  The goal of this is that these functions should be
	able to be completely removed when 2008R2 goes away so we can use the native calls with PS4+.  These are bare minimum implementations
	accepting only a single parameter "TaskName"
	#>

function Get-ScheduledTask {
	<#
	.SYNOPSIS
		Gets the task definition object of a scheduled task that is registered on the local computer.
	.DESCRIPTION
	  	The Get-BISFScheduledTask cmdlet gets the task definition object of a scheduled task that is registered on a computer. This is a PowerShell 3.0 compatibility shim; on Windows PowerShell 4+ the native Get-ScheduledTask cmdlet remains available under its original name.
	.PARAMETER TaskName
		Specifies a name of a scheduled task.
	.EXAMPLE
		Get-BISFScheduledTask -TaskName "SystemScan"
	.NOTES
		Author: Trentent Tye
	  	Company: TheoryPC

		History:
	  	dd.mm.yyyy TT: function created
		09.11.2017 TT: add .SYNOPSIS to this function

#>
	[CmdletBinding()]
	param(
		[parameter(Position = 0)] [String[]] $TaskName = "*"
	)

	process {
		# Try to create the TaskService object on the local computer; throw an error on failure
		try {
			$TaskService = New-Object -ComObject "Schedule.Service"
		}
		catch [System.Management.Automation.PSArgumentException] {
			throw $_
		}
		try {
			$TaskService.Connect()
		}
		catch [System.Management.Automation.MethodInvocationException] {
			Write-Warning "$_"
			return
		}
		function get-task($TaskFolder) {
			$Tasks = $TaskFolder.GetTasks($Hidden.IsPresent -as [Int])
			$Tasks | ForEach-Object { $_ }
			try {
				$TaskFolders = $TaskFolder.GetFolders(0)
				$TaskFolders | ForEach-Object { get-task $_ $TRUE }
			}
			catch [System.Management.Automation.MethodInvocationException] {
				# Expected when a task folder denies enumeration
				$null = $_
			}
		}
		$RootFolder = $TaskService.GetFolder("\")
		$TaskList = get-task $RootFolder
		foreach ($Task in $TaskList) {
			if ($Task.name -eq $TaskName) {
				return $Task
			}
		}
	}
}

function Disable-ScheduledTask {
	<#
	.SYNOPSIS
	   Disables a scheduled task.
	.DESCRIPTION
	  	The Disable-BISFScheduledTask cmdlet disables a scheduled task. This is a PowerShell 3.0 compatibility shim; on Windows PowerShell 4+ the native Disable-ScheduledTask cmdlet remains available under its original name.
	.PARAMETER TaskName
		Specifies a name of a scheduled task, or a COM task object from Get-BISFScheduledTask.
	.EXAMPLE
		Get-BISFScheduledTask -TaskName "SystemScan" | Disable-BISFScheduledTask
	.EXAMPLE
		Disable-BISFScheduledTask -TaskName "SystemScan"
	.NOTES
		Author: Trentent Tye

		History:
	  	dd.mm.yyyy TT: function created
		09.11.2017 TT: add .SYNOPSIS to this function

#>
	[CmdletBinding()]
	param(
		[parameter(ValueFromPipeline = $True)] $TaskName
	)

	process {
		#check to see if this is a COMObject (someone is passing a scheduled task into this function) and pull the name from it.
		if ($null -ne $TaskName) { if ($TaskName.GetType().Name -eq "__ComObject") { $TaskName = $TaskName.name } }
		# Try to create the TaskService object on the local computer; throw an error on failure
		try {
			$TaskService = New-Object -ComObject "Schedule.Service"
		}
		catch [System.Management.Automation.PSArgumentException] {
			throw $_
		}
		try {
			$TaskService.Connect()
		}
		catch [System.Management.Automation.MethodInvocationException] {
			Write-Warning "$_"
			return
		}
		function get-task($TaskFolder) {
			$Tasks = $TaskFolder.GetTasks($Hidden.IsPresent -as [Int])
			$Tasks | ForEach-Object { $_ }
			try {
				$TaskFolders = $TaskFolder.GetFolders(0)
				$TaskFolders | ForEach-Object { get-task $_ $TRUE }
			}
			catch [System.Management.Automation.MethodInvocationException] {
				# Expected when a task folder denies enumeration
				$null = $_
			}
		}
		$RootFolder = $TaskService.GetFolder("\")
		$TaskList = get-task $RootFolder
		foreach ($Task in $TaskList) {
			if ($Task.name -eq $TaskName) {
				if ($Task.Enabled -eq $true) { $Task.Enabled = $false }
			}
		}
	}
}

function Enable-ScheduledTask {
	<#
	.SYNOPSIS
	   Enables a scheduled task.
	.DESCRIPTION
	  	The Enable-BISFScheduledTask cmdlet enables a disabled scheduled task. This is a PowerShell 3.0 compatibility shim; on Windows PowerShell 4+ the native Enable-ScheduledTask cmdlet remains available under its original name.
	.PARAMETER TaskName
		Specifies a name of a scheduled task, or a COM task object from Get-BISFScheduledTask.
	.EXAMPLE
		Get-BISFScheduledTask -TaskName "SystemScan" | Enable-BISFScheduledTask
	.EXAMPLE
		Enable-BISFScheduledTask -TaskName "SystemScan"
	.NOTES
		Author: Trentent Tye
	  	Company: TheoryPC

		History:
	  	dd.mm.yyyy TT: function created
		09.11.2017 TT: add .SYNOPSIS to this function

#>
	[CmdletBinding()]
	param(
		[parameter(ValueFromPipeline = $True)] $TaskName
	)

	process {
		#check to see if this is a COMObject (someone is passing a scheduled task into this function) and pull the name from it.
		if ($null -ne $TaskName) { if ($TaskName.GetType().Name -eq "__ComObject") { $TaskName = $TaskName.name } }
		# Try to create the TaskService object on the local computer; throw an error on failure
		try {
			$TaskService = New-Object -ComObject "Schedule.Service"
		}
		catch [System.Management.Automation.PSArgumentException] {
			throw $_
		}
		try {
			$TaskService.Connect()
		}
		catch [System.Management.Automation.MethodInvocationException] {
			Write-Warning "$_"
			return
		}
		function get-task($TaskFolder) {
			$Tasks = $TaskFolder.GetTasks($Hidden.IsPresent -as [Int])
			$Tasks | ForEach-Object { $_ }
			try {
				$TaskFolders = $TaskFolder.GetFolders(0)
				$TaskFolders | ForEach-Object { get-task $_ $TRUE }
			}
			catch [System.Management.Automation.MethodInvocationException] {
				# Expected when a task folder denies enumeration
				$null = $_
			}
		}
		$RootFolder = $TaskService.GetFolder("\")
		$TaskList = get-task $RootFolder
		foreach ($Task in $TaskList) {
			if ($Task.name -eq $TaskName) {
				if ($Task.Enabled -eq $false) { $Task.Enabled = $true }
			}
		}
	}
}

function Set-PreparationState {
	<#
	.SYNOPSIS
		Sets the current state of preparation
	.DESCRIPTION
		Sets the current state of preparation to either InProgress, RebootRequired or Completed.
		When preparation is run, the initial state is set to InProgress.  If a task or process
		requires a reboot *which can be deferred*, the script must use this function to set the
		state to RebootRequired.
		RebootRequired is a value that is checked at the end of the preparation process.  If it's
		found then a reboot is executed.  It is up to your script to ensure that whatever
		caused the reboot has been satisfied so that it does not set "RebootRequired" in a infinite loop.
		Diagram:

				 ----------------------
		|----->  |BISF-Prep is started|
		|        ----------------------
		|                   |
		|                   V
		|         --------------------------------------
		|         |LIC_BISF_PrepState value set to     |
		|         |"InProgress" and BISF Prep Scheduled| (Occurs in PrepBISF_Start.ps1)
		|         |Task is "Enabled"                   |
		|         --------------------------------------
		|                   |
		|          _________V___________
		|         /Does a script within \
		|        / Prep phase require a  \_____ No------------------------------------------------------|
		|        \        reboot?        /                                                              |
		|         -----------------------                                                               |
		|                   |                                                                           |
		|                  Yes                                                                          |
		|                   |                                                                           |
		|          _________V_________                 --------------------------------                 |
		|         /Can it be deferred?\_____ Yes-----> |Script sets LIC_BISF_PrepState|                 |
		|          -------------------                 |value to "RebootRequired"     |                 |
		|                   |                          --------------------------------                 |
		|                   No                                           |                              |
		|                   |                                            |                              |
		|                   V                                            |                              |
		|         ----------------------                    ____________/\____________                  V
		|         |       Reboot       |<--RebootRequired--< LIC_BISF_PrepState Check >(Occurs in 99_PrepBISF_POST_BaseImage.ps1)
		|         ----------------------                     -----------\/-------------
		|                   |                                            |
		|                   V                                            V
		|         /-------------------------/                        InProgress
		|        /On reboot, BISF Prep     /                             |
		|       / Scheduled Task executes /                              V
		|      /-------------------------/                ----------------------------------------
		|                   |                             | "Disable" BISF Prep scheduled task   |(Occurs in 99_PrepBISF_POST_BaseImage.ps1)
		--------------------                              | set LIC_BISF_PrepState to Completed  |
														  ----------------------------------------
																		|
																		V
																	 Shutdown


	.EXAMPLE
		Set-BISFPreparationState -RebootRequired
	.PARAMETER InProgress
		Set LIC_BISF_PrepState to InProgress.
	.PARAMETER RebootRequired
		Set LIC_BISF_PrepState to RebootRequired and enable the prep startup task.
	.PARAMETER Completed
		Set LIC_BISF_PrepState to Completed and disable the prep startup task.
	.NOTES
		Author: Trentent Tye
	  	Company: TheoryPC

		History:
	  	08.09.2017 TT: Function created
		11.09.2017 TT: Redesigned with flag to check for deferred reboot

#>
	Param(
		[Parameter(Mandatory = $False)][Switch]$InProgress,
		[Parameter(Mandatory = $False)][Switch]$RebootRequired,
		[Parameter(Mandatory = $False)][Switch]$Completed
	)

	if ($InProgress) {
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Login Consultants\BISF" -Name "LIC_BISF_PrepState" -Value "InProgress" -Force
		Write-BISFLog "LIC_BISF_PrepState set to InProgress"
	}
	if ($RebootRequired) {
		Get-BISFScheduledTask -TaskName "BISF Preparation Startup" | Enable-BISFScheduledTask
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Login Consultants\BISF" -Name "LIC_BISF_PrepState" -Value "RebootRequired" -Force
		Write-BISFLog "LIC_BISF_PrepState set to RebootRequired"
	}
	if ($Completed) {
		Get-BISFScheduledTask -TaskName "BISF Preparation Startup" | Disable-BISFScheduledTask
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Login Consultants\BISF" -Name "LIC_BISF_PrepState" -Value "Completed" -Force
		Write-BISFLog "LIC_BISF_PrepState set to Completed"
	}
}

function Get-vDiskDrive {
	<#
	.SYNOPSIS
		get the DriveLetter of the attached vDisk
	.DESCRIPTION
	  	Checks the DriveLetter of the PVS Disk and give them back also return value
		if the Citrix AppLayering is installed, every time the System drive will give it back
	.EXAMPLE
		Get-BISFvDiskDrive
	.NOTES
		Author: Matthias Schlimm

		History:
	  	31.07.2017 MS: add Microsoft SYNOPSIS to this function
		31.07.2017 MS: IF Citrix AppLayering is installed, give SystemDrive back

#>
	$PVSDestDrive = "FALSE"
	$SystemDrive = $env:SystemDrive
	$Array = @()
	$SystemDriveLabel = Get-CimInstance -Class Win32_Volume -Filter "DriveLetter = '$SystemDrive' " | ForEach-Object { $_.Label }
	$SystemLabelDriveLetters = Get-CimInstance -ClassName Win32_Volume -Filter "Label = '$SystemDriveLabel'" | ForEach-Object { $_.DriveLetter }
	$Array += $SystemLabelDriveLetters
	IF (!($CTXAppLayeringSW)) {

		# search for the pvs destination disk
		Foreach ($DrvInArray in $Array) {
			if ("$DrvInArray" -eq "$SystemDrive") {
				$PVSDestDrive = $DrvInArray
				Write-BISFLog -Msg "identify vDisk destination drive $PVSDestDrive.. booting up from vDisk"
			}
			ELSE {
				$PVSDestDrive = $DrvInArray
				Write-BISFLog -Msg "identify vDisk destination drive $PVSDestDrive.. booting up from hard disk"
				break
			}
		}
	}
	ELSE {
		$PVSDestDrive = $SystemDrive
		Write-BISFLog -Msg "Citrix AppLayering installed - identified Disk $PVSDestDrive - running $CTXAppLayerName"
	}
	Return $PVSDestDrive


}

function Enable-Privilege {
	<#
	.SYNOPSIS
		Enable a Windows privilege on the current process token.
	.DESCRIPTION
		Adjusts the process token so operations such as SeRestorePrivilege can succeed. Privilege names match the Windows privilege constants.
	.PARAMETER Privilege
		Privilege to enable, for example SeBackupPrivilege or SeRestorePrivilege.
	.PARAMETER ProcessId
		Target process ID. Defaults to the current process.
	.PARAMETER Disable
		Disable the privilege instead of enabling it.
	.EXAMPLE
		Enable-BISFPrivilege -Privilege SeRestorePrivilege
	#>
	param(
		# 20.05.2015 MS: feature 45 - added function
		## The privilege to adjust. This set is taken from
		## http://msdn.microsoft.com/en-us/library/bb530716(VS.85).aspx
		[ValidateSet(
			"SeAssignPrimaryTokenPrivilege", "SeAuditPrivilege", "SeBackupPrivilege",
			"SeChangeNotifyPrivilege", "SeCreateGlobalPrivilege", "SeCreatePagefilePrivilege",
			"SeCreatePermanentPrivilege", "SeCreateSymbolicLinkPrivilege", "SeCreateTokenPrivilege",
			"SeDebugPrivilege", "SeEnableDelegationPrivilege", "SeImpersonatePrivilege", "SeIncreaseBasePriorityPrivilege",
			"SeIncreaseQuotaPrivilege", "SeIncreaseWorkingSetPrivilege", "SeLoadDriverPrivilege",
			"SeLockMemoryPrivilege", "SeMachineAccountPrivilege", "SeManageVolumePrivilege",
			"SeProfileSingleProcessPrivilege", "SeRelabelPrivilege", "SeRemoteShutdownPrivilege",
			"SeRestorePrivilege", "SeSecurityPrivilege", "SeShutdownPrivilege", "SeSyncAgentPrivilege",
			"SeSystemEnvironmentPrivilege", "SeSystemProfilePrivilege", "SeSystemtimePrivilege",
			"SeTakeOwnershipPrivilege", "SeTcbPrivilege", "SeTimeZonePrivilege", "SeTrustedCredManAccessPrivilege",
			"SeUndockPrivilege", "SeUnsolicitedInputPrivilege")]
		$Privilege,
		## The process on which to adjust the privilege. Defaults to the current process.
		$ProcessId = $pid,
		## Switch to disable the privilege, rather than enable it.
		[Switch] $Disable
	)
	## Taken from P/Invoke.NET with minor adjustments.
	$Definition = @'
 using System;
 using System.Runtime.InteropServices;

 public class AdjPriv
 {
  [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
  internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
   ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);

  [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
  internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
  [DllImport("advapi32.dll", SetLastError = true)]
  internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
  [StructLayout(LayoutKind.Sequential, Pack = 1)]
  internal struct TokPriv1Luid
  {
   public int Count;
   public long Luid;
   public int Attr;
  }

  internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
  internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
  internal const int TOKEN_QUERY = 0x00000008;
  internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
  public static bool EnablePrivilege(long processHandle, string privilege, bool disable)
  {
   bool retVal;
   TokPriv1Luid tp;
   IntPtr hproc = new IntPtr(processHandle);
   IntPtr htok = IntPtr.Zero;
   retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
   tp.Count = 1;
   tp.Luid = 0;
   if(disable)
   {
	tp.Attr = SE_PRIVILEGE_DISABLED;
   }
   else
   {
	tp.Attr = SE_PRIVILEGE_ENABLED;
   }
   retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
   retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
   return retVal;
  }
 }
'@

	$ProcessHandle = (Get-Process -id $ProcessId).Handle
	$Type = Add-Type $Definition -PassThru
	$Type[0]::EnablePrivilege($ProcessHandle, $Privilege, $Disable)

}

function Get-CLICmd {
	<#
	.SYNOPSIS
		Write the CLI names and their values to the BIS-F log file
	.DESCRIPTION
	  	Write all used CLI values to the log file
	.EXAMPLE
		Get-BISFCLICmd
	.NOTES
		Author: Matthias Schlimm

		History:
	  	10.03.2016 MS: function created
		01.08.2017 MS: define global variable for each CLI command
#>
	IF (Test-Path $RegLicPolicies -ErrorAction SilentlyContinue) {
		Write-BISFLog -Msg "The following CLI commands will be set:"
		$RegValues = Get-BISFRegistryValues $RegLicPolicies
		Foreach ($RegValue in $RegValues) {
			New-BISFGlobalVariable -Name $($RegValue.value) -Value $($RegValue.data)
		}
	}
	ELSE {
		Write-BISFLog -Msg "No configuration via ADMX or Shared Configuration detected" -SubMsg -Type W -ShowConsole

	}

}

function Get-DiskMode {
	<#
	.SYNOPSIS
		get DiskMode from PVS or MCS
	.DESCRIPTION
	  	get DiskMode from PVS or MCS back as follows:
			ReadWrite
			ReadOnly
			Unmanaged
			VDAPrivate
			VDAShared
			ReadWriteAppLayering
			ReadOnlyAppLayering
			VDAPrivateAppLayering
			VDASharedAppLayering
			UNC-Path
	.EXAMPLE
		$DiskMode = Get-BISFDiskMode

	.NOTES
		Author: Matthias Schlimm

		History:
	  	dd.mm.yyyy BR: function created
		07.09.2015 MS: add .SYNOPSIS to this function
		30.09.2015 MS: Change $returnValue =  "Writeable" to $returnValue =  "ReadWrite"
		28.07.2017 MS: If Citrix AppLayerLayering is installed get back DiskMode $returnValue = "AppLayering"
		04.08.2017 MS: If Custom UNC-Path in ADMX is enabled, get back 'UNC-Path' as $ReturnValue
		06.08.2017 MS: Fixed -if Custom UNC-Path in ADMX is enabled, during "Personalization" the wrong $ReturnValue like MCSPrivate is given back, instead of "UNC-Path"
		15.08.2017 MS: get additional DiskMode with AppLayering back, like ReadWriteAppLayering, ReadOnlyAppLayering
		29.10.2017 MS: get VDA back instead of MCS
		13.08.2019 AS: ENH 46 - Make any PVS conversion work Optional
		20.09.2019 MS: ENH 136 - detect PVS Private Image with Asynchronous IO ($WriteCacheMode -eq "10")
		23.12.2019 MS: HF 46: moving AndSkipImaging into finally block
#>
	$ErrorActionPreference = "Stop"
	try {
		$WriteCacheMode = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\bnistack\PVSAgent).WriteCacheType

		if (($WriteCacheMode -eq "0") -or ($WriteCacheMode -eq "10")) {
			$ReturnValue = "ReadWrite"
		}
		else {
			$ReturnValue = "ReadOnly"
		}
	}
	catch [System.Management.Automation.ItemNotFoundException] {
		if (Test-Path -Path "C:\Personality.ini" -PathType Leaf) {
			$Personality = Get-Content -Path "C:\Personality.ini"
			foreach ($Line in $Personality) {
				if ($Line -like '*DiskMode=*') {
					$Line = $Line.split("=")
					$ReturnValue = "VDA" + $Line[1]
				}
			}
			IF ($LIC_BISF_CLI_P2V_PT -eq "1") { $ReturnValue = $ReturnValue + "UNC-Path" }
		}
		else {
			$ReturnValue = "Unmanaged"
			IF ($LIC_BISF_CLI_P2V_PT -eq "1") { $ReturnValue = $ReturnValue + "UNC-Path" }

		}
	}
	Finally {
		$ErrorActionPreference = "Continue"
		IF ($LIC_BISF_CLI_P2V_SKIP_IMG -eq "1") { $ReturnValue = $ReturnValue + "AndSkipImaging" }
	}
	IF ($CTXAppLayeringSW -eq $true) { $ReturnValue = $ReturnValue + "AppLayering" }
	Write-BISFLog -Msg "DiskMode is $($ReturnValue)"
	return $ReturnValue

}

function Test-RegistryValue {
	<#
	.SYNOPSIS
		Test-BISFRegistryValue
	.DESCRIPTION
	  	Test registry value if exists and returns a true or false value
	.PARAMETER Path
		Registry key path.
	.PARAMETER Value
		Value name to test.
	.EXAMPLE
		Test-BISFRegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion" -Value "CommonFilesDir"
		returns true if the value exist
		returns false if the value not exist
	.NOTES
		Author: Matthias Schlimm

		History:
	  	01.09.2015 MS: added function
		06.08.2017 MS: remove Warning if registry path not exists
#>
	param (
		# defines the registry Path
		[parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]$Path,

		# defines the registry Value
		[parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]$Value
	)
	$ErrorActionPreference = "Stop"
	try {
		Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Value | Out-Null
		Write-BISFLog -Msg "Registry path $($Path), Value $($Value) exists"
		return $true
	}
	catch {
		Write-BISFLog -Msg "Registry path $($Path), Value $($Value) NOT exists !!"
		return $false
	}
	Finally { $ErrorActionPreference = "Continue" }

}

function Get-DiskNameExtension {
	<#
	.SYNOPSIS
		Get-BISFDiskNameExtension
	.DESCRIPTION
	  	using with Citrix PVS Environment only. as result give back the last 4 strings from the attached PVS vDisk
	.EXAMPLE
		Get-BISFDiskNameExtension
		IF you have attached a vDisk with Name vDISK-STD-V01.vhd
		returns BaseDisk

	.EXAMPLE
		Get-BISFDiskNameExtension
		IF you have attached a vDisk with Name vDISK-STD-V01.avhd
		returns ParentDisk

	.EXAMPLE
		Get-BISFDiskNameExtension
		IF you haven't any vDisk attached
		returns NoVirtualDisk

	.NOTES
		Author: Matthias Schlimm

		History:
	  	01.09.2015 MS: added function, defrag would be performed on BaseDisk and hard drive only
		15.03.2017 MS: Change to $vDiskName = $vDiskName.split(".")[-1] # get correct vDiskExtension
#>
	$ErrorActionPreference = "Stop"
	try {
		$VDiskName = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\bnistack\PVSAgent).DiskName
		$VDiskName = $VDiskName.split(".")[-1] # get vDiskExtension

		if (($VDiskName -eq "vhd") -or ($VDiskName -eq "vhdx")) {
			$ReturnValue = "BaseDisk"
		}
		else {
			$ReturnValue = "ParentDisk"
		}
	}
	catch [System.Management.Automation.ItemNotFoundException] {
		$ReturnValue = "NoVirtualDisk"
	}

	Finally { $ErrorActionPreference = "Continue" }
	Write-BISFLog -Msg "vDisk Extension is $($ReturnValue)"
	return $ReturnValue
}

function Test-Service {
	<#
	.SYNOPSIS
		test service if exist
	.DESCRIPTION
	  	check if a service exists and send back a true or false value, Optional you can use the parameter product name to set the name of the Product
	.PARAMETER ServiceName
		Windows service name to test.
	.PARAMETER ProductName
		Optional product display name written to the log when the service exists.
	.PARAMETER RetrieveVersion
		Also return the service executable file version.
	.EXAMPLE
		Test-BISFService -ServiceName CcmExec
	.EXAMPLE
		Test-BISFService -ServiceName CcmExec -ProductName "Microsoft SCCM Agent"
	.NOTES
		Author: Matthias Schlimm

		History:
	  	02.09.2015 MS: function created
		06.03.2017 MS: get FileVersion from ImagePath
		28.02.2018 MS: Fixed get file version from Image Path, without arguments of the service
		20.10.2018 MS: Fixed 74: The Version from the Service could not extracted
		23.12.2020 MS: HF 304 - add switch RetrieveVersion
#>

	param (
		# Specifies the service name
		[parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]$ServiceName,

		# specifies the product name / software
		[parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]$ProductName,

		# Retrieve ServiceVersion
		[parameter(Mandatory = $false)]
		[switch]$RetrieveVersion
	)
	IF (Get-Service $ServiceName -ErrorAction SilentlyContinue) {
		Write-BISFLog -Msg "Service $($ServiceName) exists"
		IF ($ProductName) {
			$SVCFileVersion = $null
			$Service = Get-CimInstance -ClassName Win32_Service | Where-Object { $_.Name -eq $($ServiceName) }
			$SVCImagePath = ($Service | Select-Object -Expand PathName) -split "-|/"
			$SVCImagePath = $SVCImagePath[0]
			$SVCImagePath = $SVCImagePath -replace ('"', '')
			$Global:GlbSVCImagePath = "$SVCImagePath"
			$SVCFileVersion = (Get-Item $($SVCImagePath) -ErrorAction SilentlyContinue).VersionInfo.FileVersion
			IF (!([String]::IsNullOrEmpty($SVCFileVersion))) {
				$ShowVersion = "(Version $SVCFileVersion)"
				Write-BISFLog -Msg "Product $ProductName $ShowVersion installed" -ShowConsole -Color Cyan
			}
			ELSE {
				Write-BISFLog -Msg "The version from $ProductName could not be extracted from image	path $SVCImagePath"
				Write-BISFLog -Msg "Product $ProductName installed" -ShowConsole -Color Cyan
			}

		}
		if ($RetrieveVersion) {
			return $true, $SVCFileVersion
		} else {
			return $true
		}

	}
	ELSE {
		Write-BISFLog -Msg "Service $($ServiceName) does not exist"
		IF ($ProductName) { Write-BISFLog -Msg "Product $ProductName is NOT installed" }
		if ($RetrieveVersion) {
			return $false, 0
		} else {
			return $false
		}
	}

}

function Invoke-Service {
	<#
	.SYNOPSIS
		Reconfigure the service
	.DESCRIPTION
	  	Reconfigure a specified service to Start or Stop the service and set the startup type to disabled, manual, automatic
	.PARAMETER ServiceName
		Windows service name.
	.PARAMETER Action
		Start or Stop.
	.PARAMETER StartType
		Disabled, Manual, or Automatic.
	.PARAMETER CheckDiskMode
		Only act when DiskMode is RW or RO.
	.EXAMPLE
		The service will be stopped and set to manual startup type
		 Invoke-BISFService -ServiceName wuauserv -Action Stop -StartType manual
	.EXAMPLE
		The service will be stopped
		 Invoke-BISFService -ServiceName wuauserv -Action Stop
	.EXAMPLE
		The service will be started
		 Invoke-BISFService -ServiceName wuauserv -Action Start
	.EXAMPLE
		The service will be started if the Image is in ReadWrite Mode
		 Invoke-BISFService -ServiceName wuauserv -Action Start -CheckDiskMode RW
	.EXAMPLE
		The service will be started if the Image is in ReadOnly Mode
		 Invoke-BISFService -ServiceName wuauserv -Action Start -CheckDiskMode RO
	.NOTES
		Author: Matthias Schlimm, Florian Frank

		History:
	  	02.09.2015 MS: function created
		30.09.2015 MS: added CheckDiskMode to start the service if the DiskMode is in ReadWrite (RW) or ReadOnly (RO) Mode
		04.03.2016 MS: heavy bug in function Invoke-BISFService, services would not started if needed
		15.03.2016 MS: give wrong variable back, switch RO and RW
		15.03.2016 BR: Syntax error Invoke-BISFService: Set-Service -Name $svc.Name -StartupType $StartType | Out-Null
		15.08.2017 MS: Change $DiskMode -match, needed for AppLayering, example ReadWriteAppLayering
		24.08.2017 MS: add IF ($CheckDiskMode -eq $null) {Write-BISFLog -Msg "DiskMode must not be checked"} ELSE {Write-BISFLog -Msg "DiskMode $CheckDiskMode would be checked successfully"}s
		11.09.2017 FF: add missing function name
		29.10.2017 MS: test DiskMode match VDA instead of MCS
		01.07.2018 MS: Hotfix 49: running Test-BISFServiceState after changing Service to get the right Status back
#>

	param (
		# Specifies the ServiceName
		[parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]$ServiceName,

		# Specifies the Action to Start or Stop the Service
		[parameter(Mandatory = $true)]
		[ValidateSet("Start", "Stop")]
		[ValidateNotNullOrEmpty()]$Action,

		# Specifies the start type: Disabled, Manual, Automatic
		[parameter(Mandatory = $false)]
		[ValidateSet("Disabled", "Manual", "Automatic")]
		[ValidateNotNullOrEmpty()]$StartType,

		# Specifies the DiskMode to check: RW, RO
		[parameter(Mandatory = $false)]
		[ValidateSet("RW", "RO")]
		[ValidateNotNullOrEmpty()]$CheckDiskMode

	)

	If (!($null -eq $CheckDiskMode)) {
		$DiskMode = Get-BISFDiskMode
		IF (($DiskMode -match "ReadOnly") -or ($DiskMode -match "VDAShared")) { $DiskMode = "RO" }
		IF (($DiskMode -match "ReadWrite") -or ($DiskMode -match "VDAPrivate")) { $DiskMode = "RW" }
		Write-BISFLog -Msg "Image will be run in $DiskMode Mode (RO:ReadOnly, RW=ReadWrite)"
	}
	$ErrorActionPreference = "Stop"
	Write-BISFLog -Msg "Reconfigure Service $ServiceName" -ShowConsole -Color DarkCyan -SubMsg
	try {
		$Svc = Get-Service $ServiceName
		If ($Action -eq "Stop") {

			IF ($Svc.Status -eq 'Running') {
				$Svc.Stop() | Out-Null
				$Svc.WaitForStatus('Stopped') | Out-Null
				Write-BISFLog -Msg "Service $ServiceName will be stopped"
			}
			ELSE {
				Write-BISFLog -Msg "Service $ServiceName is already stopped!"
			}
			Test-BISFServiceState -ServiceName $ServiceName -Status "Stopped"
		}

		IF ($StartType) {
			IF (($StartType -eq "Manual") -and ($ImageSW -eq $false)) {
				Write-BISFLog -Msg "No Image Management Software detected, Service $ServiceName will not be changed to Startup Type $StartType" -Type W
			}
			ELSE {
				Write-BISFLog -Msg "Service $($Svc.Name) will be configured to Startup Type $StartType"
				Set-Service -Name $Svc.Name -StartupType $StartType | Out-Null
			}
		}

		IF (($null -eq $CheckDiskMode) -or ($CheckDiskMode -eq $DiskMode)) {
			IF ($null -eq $CheckDiskMode) { Write-BISFLog -Msg "DiskMode will not be checked" } ELSE { Write-BISFLog -Msg "DiskMode $CheckDiskMode will be checked" }
			If ($Action -eq "Start") {

				IF ($Svc.Status -eq 'Stopped') {
					$Svc.Start() | Out-Null
					$Svc.WaitForStatus('Running') | Out-Null
					Write-BISFLog -Msg "Service $ServiceName is running now"
				}
				ELSE {
					Write-BISFLog -Msg "Service $ServiceName is already running!"
				}
				Test-BISFServiceState -ServiceName $ServiceName -Status "Running"
			}
		}

	}

	catch {
		IF ($StartType) {
			Write-BISFLog -Msg "Error reconfiguring Service $($ServiceName) -Action $Action -StartType $StartType" -Type W -SubMsg
		}
		ELSE {
			Write-BISFLog -Msg "Error reconfiguring Service $($ServiceName) -Action $Action" -Type W -SubMsg
		}
		Write-BISFLog -Msg "The error is: $_" -Type W -SubMsg
	}
	Finally { $ErrorActionPreference = "Continue" }

}

function Get-AdapterGUID {
	<#
	.SYNOPSIS
		read network GUID like {0252A1FD-4299-4E1C-80B5-ADD027292A6E}
	.DESCRIPTION
	  	get GUID of all DHCP Adapters back
	.EXAMPLE
		Get-BISFAdapterGUID

	.NOTES
		Author: Matthias Schlimm

		History:
	  	25.11.2015 MS: function created
		15.03.2016 MS: get duplicate AdapterGUID back, instead unique of each adapter

#>
	Write-BISFLog -Msg "Read GUIDs of each Network Adapter"
	$HklmRegTcpip = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
	$AllAdapterGUIDs = Get-ChildItem "$HklmRegTcpip\Adapters" | Get-ItemProperty | ForEach-Object { $_.PSChildName }
	ForEach ($AdapterGUID in $AllAdapterGUIDs) {
		$TestDHCP = Get-ItemProperty "$HklmRegTcpip\Interfaces\$AdapterGUID" | ForEach-Object { $_.EnableDHCP }
		IF ($TestDHCP -eq 1) {
			Write-BISFLog -Msg "DHCP on Adapter with GUID $AdapterGUID is enabled"
			[array]$AdapterGUIDarray += $AdapterGUID
		}
		ELSE {
			Write-BISFLog -Msg "DHCP on Adapter with GUID $AdapterGUID is disabled!"
		}
	}

	return $AdapterGUIDarray
}

function Optimize-WinSxs {
	<#
	.SYNOPSIS
		Cleanup the WinSxs Folder
	.DESCRIPTION
		get further information here
	  	https://msdn.microsoft.com/en-us/library/dn251565.aspx
	.EXAMPLE
		Optimize-BISFWinSxs

	.NOTES
		Author: Matthias Schlimm

		History:
	  	07.01.2016 MS: function created
		17.05.2019 MS: HF 106 - remove unnecessary out-null command
		21.06.2019 MS: FRQ 115: ADMX: Control of WinSxS Optimization
		03.07.2019 MS: ENH 117: WinSxS hide DISM process and get log file of the DISM Process into BIS-F log
#>
	IF (!($LIC_BISF_CLI_WinSxS -eq "NO"))
	{
		Write-BISFLog -Msg "Perform WinSxS Optimization" -ShowConsole -Color Cyan
		$RunWinSxs = 1
		IF ($LIC_BISF_CLI_WinSxSBaseImage -eq 1)
		{
			$DiskNameExtension = Get-BISFDiskNameExtension
			IF (($DiskNameExtension -eq "BaseDisk") -or ($DiskNameExtension -eq "noVirtualDisk"))
			{
				$RunWinSxs = 1
			} ELSE {
				$RunWinSxs = 0
				Write-BISFLog "WinSxS Optimization is configured in ADMX to run on the Base Disk or when no Virtual Disk assigned, $DiskNameExtension detected" -ShowConsole -SubMsg -Color DarkCyan
			}

		}
		IF ($RunWinSxs -eq 1) {
			IF (!($LIC_BISF_CLI_WinSxSTimeout)) {$LIC_BISF_CLI_WinSxSTimeout = 60}
			IF (Test-path "C:\Windows\logs\DISM\dism_bisf.log") {Remove-Item "C:\Windows\logs\DISM\dism_bisf.log" -Force}
                	Start-Process 'Dism.exe' -ArgumentList '/online /Cleanup-Image /StartComponentCleanup /ResetBase /LogPath:C:\Windows\logs\DISM\dism_bisf.log' -RedirectStandardOutput "C:\windows\temp\WinSxs.log" -NoNewWindow
			Show-BISFProgressBar -CheckProcess "Dism" -ActivityText "run DISM to cleanup WinSxs Folder ...(max. Execution Timeout $LIC_BISF_CLI_WinSxSTimeout min)" -MaximumExecutionMinutes $LIC_BISF_CLI_WinSxSTimeout
		        Get-BISFLogContent -GetLogFile "C:\Windows\logs\DISM\dism_bisf.log"
		} ELSE {
			Write-BISFLog -Msg "WinSxS Optimization will not run (runWinSxs = 0)" -ShowConsole -SubMsg -Color DarkCyan
		}
	} ELSE {
		Write-BISFLog -Msg "WinSxS Optimization is disabled in ADMX configuration."
	}

}

function Test-VMwareHorizonViewSoftware {
	<#
	.SYNOPSIS
		check if the VMware Horizon View Agent installed
	.DESCRIPTION
	  	if the VMware Horizon View Agent installed they will send a true or false value and will set the global variable ImageSW to true or false
	.EXAMPLE
		Test-BISFVMwareHorizonViewSoftware
	.NOTES
		Author: Matthias Schlimm

		History:
	  	07.01.2016 MS: function created
		07.01.2020 MS: HF 176 - $Global:ImageSW request is set one Time only


#>
	$Svc = Test-BISFService -ServiceName "WSNM" -ProductName "VMware Horizon View Script Host"
	IF ($Svc -eq $true) { $Global:ImageSW = $true }
	return $Svc

}

Function Get-OSCSessionType {
	<#
	.SYNOPSIS
		check the Session type if there console or not
	.DESCRIPTION
	  	if the powershell script is running from console session they gives a true value back, instead of false for RDP Session
	.EXAMPLE
		Get-BISFOSCSessionType
	.NOTES
		Author: Matthias Schlimm

		History:
	  	21.01.2016 MS: function created, get POSH from https://gallery.technet.microsoft.com/scriptcenter/Determines-the-Terminal-a0a454a4
		10.03.2016 MS: add CLI switch to disable the Session type

#>
	IF (!($LIC_BISF_CLI_ST)) {
		#Do not check SessionType
		IF ($State -eq "Preparation") {
			$Results = @()
			#Use command "query session" to list all sessions
			$Sessions = query.exe session $Env:USERNAME /server:$Env:COMPUTERNAME
			#Split the results and store them into the variable $Result
			For ($i = 1 ; $i -lt $Sessions.Count) {
				$Temp = "" | Select-Object SessionName, Username
				#Split the result to get the session name
				$Temp.SessionName = $Sessions[$i].Substring(1, 18).Trim()
				#Split the result to get the user name
				$Temp.Username = $Sessions[$i].Substring(19, 20).Trim()
				#Store the result into $Result
				$Results += $Temp
				$i ++
			}
			#Verify if the session is terminal or console
			Foreach ($Result in $Results) {
				$Username = $Result.Username
				$SessionName = $Result.SessionName
				#Check the Username and SessionName
				If ($Username.Length -gt 0 ) {
					#Check for session name. If it contains "rdp-tcp#", the session is terminated.
					If ($SessionName -match "rdp-tcp#") {
						Write-BISFLog -Msg "BIS-F can run from an RDP session, but this feature is disabled by default. Run BIS-F from a Console session or enable RDP support in the BIS-F ADMX template" -Type E
					}
					#Check for session name.If it contains "console" ,the session is console.
					If ($SessionName -match "console") {
						Write-BISFLog -Msg "BIS-F is running from a console session " -ShowConsole -Color DarkCyan -SubMsg
					}
				}
			}
		}
	}
	ELSE {
		Write-BISFLog -Msg "RDP session support is enabled" -ShowConsole -SubMsg -Color DarkCyan
	}

}

function Set-Sysprep {
	<#
	.SYNOPSIS
		Set Sysprep usage when no image management software is present.
	.DESCRIPTION
		During preparation, sets whether Sysprep runs at the end of BIS-F when no supported
		VDI platform is detected. Reads the Sysprep ADMX policy when configured; otherwise
		defaults to No.

		Sysprep is disabled when any of these are installed: Citrix Virtual Apps and
		Desktops VDA, Citrix Provisioning Services (PVS) Target Device Driver, Citrix App
		Layering, Omnissa Horizon Agent, Parallels RAS, Dizzion Frame, or Azure Virtual
		Desktop (AVD). A Yes ADMX setting is ignored in that case and logged as a warning.
	.EXAMPLE
		Set-BISFSysprep
	.NOTES
		Author: Matthias Schlimm

		History:
	  	28.01.2016 MS: function created
		06.03.2017 MS: Fixed read Variable $varCLI = ...
		11.02.2018 MS: Fixed 235, if sysprep is enabled and other Management SW like Citrix VDA, PVS Target Device Driver, VMWare View Agent is installed, the script breaks
		14.08.2019 MS: FRQ 3 - Remove message box and using default setting if GPO is not configured
#>
	IF ($State -eq "Preparation") {
		IF (($ImageSW -eq $false) -or ($null -eq $ImageSW)) {
			$VarCLISP = $LIC_BISF_CLI_SP
			IF (($VarCLISP -eq "YES") -or ($VarCLISP -eq "NO")) {
				Write-BISFLog -Msg "Silent switch for Sysprep will be set to $VarCLISP"
			}
			ELSE {
				Write-BISFLog -Msg "GPO is not configured.. using default setting"
				$DefaultSysprep = "NO"
			}

			if (($DefaultSysprep -eq "YES" ) -or ($VarCLISP -eq "YES")) {
				Write-BISFLog -Msg "Sysprep will be used at the end of BIS-F" -ShowConsole -Color DarkCyan -SubMsg
				$Global:RunSysprep = $true

			}
			ELSE {
				Write-BISFLog -Msg "Skipping Sysprep usage"
				$Global:RunSysprep = $false
			}

		}
		ELSE {
			$Global:RunSysprep = $false
			IF ($LIC_BISF_CLI_SP -eq "YES") {
				Write-BISFLog -Msg "Sysprep cannot be used because supported image management software was detected (Citrix VDA, PVS, App Layering, Omnissa Horizon Agent, Parallels RAS, Dizzion Frame, or Azure Virtual Desktop)" -ShowConsole -SubMsg -Type W

			}
		}
	}

}


function Start-ProcWithProgBar {
	<#
	.SYNOPSIS
		Starting a normal Windows process and shows the progress bar in the PowerShell script
	.DESCRIPTION
	  	Starting a Process and using the Show-BISFProgressBar BISF-Function to show the progress bar on the PowerShell Script
	.PARAMETER ProcPath
		Full path to the executable.
	.PARAMETER Args
		Argument list passed to the process.
	.PARAMETER ActText
		Progress bar activity text.
	.EXAMPLE
		 Start-BISFProcWithProgBar -ProcPath "C:\SCRIPTS\BISF_SCRIPTS\10_SubCall\10_LIB\Tools\deplprof2.exe" -Args "/u /r" -ActText "Delprof2 is running"
	.NOTES
		Author: Matthias Schlimm

		History:
	  	10.03.2016 MS: function created
		17.03.2017 MS: Fixed: Start-BISFProcWithProgBar: using $ArgList instead og $Args at the Write-BISFLog command here
		17.03.2017 MS: Fixed: Start-BISFProcWithProgBar: remove -Wait from Start-Process

#>

	PARAM(
		[parameter(Mandatory = $True)][string]$ProcPath,
		[parameter(Mandatory = $True)][string]$Args,
		[parameter(Mandatory = $True)][string]$ActText
	)
	$TmpLogFile = "C:\Windows\logs\BISFtmpProcessLog.log"
	$ChkProc = [io.fileinfo] "$ProcPath" | ForEach-Object basename  # get name from executable without path and extension
	Write-BISFLog -Msg "Starting Process $ProcPath with ArgumentList $Args"
	Start-Process -FilePath "$ProcPath" -ArgumentList "$Args" -NoNewWindow -RedirectStandardOutput "$TmpLogFile" | Out-Null
	Show-BISFProgressBar -CheckProcess $ChkProc -ActivityText $ActText
	Get-BISFLogContent -GetLogFile "$TmpLogFile"
	Remove-Item -Path "$TmpLogFile" -Force | Out-Null
}

function Invoke-LogRotate {
	<#
	.SYNOPSIS
		Rotate log files
	.DESCRIPTION
	  	Cleanup log files and keep only a configured value of files
	.PARAMETER Versions
		Number of log files to keep.
	.PARAMETER StrLogFileName
		Optional filter; preparation and personalization override this from ADMX/state.
	.PARAMETER Directory
		Log directory to clean.
	.EXAMPLE
		Invoke-BISFLogRotate -Versions 5 -LogFileName "Prep*" -Directory "D:\BISFLogs"
	.NOTES
		Author: Benjamin Ruoff


		History:
	  	15.03.2016 BR: function created
		17.03.2016 BR: Change Remove-Item to delete the oldest log
		02.08.2017 MS: using log rotate from ADMX, default = 5 if not set
		10.01.2020 MS: HF 182 - if LogRotate is set to 0 it doesn't keep all logs

#>
	Param(
		[Parameter(Mandatory = $True)][Alias('C')][int]$Versions,
		[Parameter(Mandatory = $False)][Alias('FN')][string]$StrLogFileName,
		[Parameter(Mandatory = $True)][Alias('D')][string]$Directory
	)
	IF ($State -eq "Preparation") { $StrLogFileName = "Prep*" }
	IF ($State -eq "Personalization") { $StrLogFileName = "Pers*" }

	[int]$Versions = $LIC_BISF_CLI_LF_RT

	$ValLFRT = Test-BISFRegistryValue -Path "$RegLicPolicies" -Value "LIC_BISF_CLI_LF_RT"
	IF ($ValLFRT -eq $false) { Write-BISFLog -Msg "Log rotate is NOT specified in the ADMX, it uses the default value of 5 "; [int]$Versions = "5" }
	IF ($Versions -eq 0) { Write-BISFLog -Msg "Log rotate is set to 0 in the ADMX, it uses now the max. count of 9999 "; [int]$Versions = "9999" }

	$LogFiles = Get-ChildItem -Path $Directory -Filter $StrLogFileName | Sort-Object -Property LastWriteTime -Descending
	for ($i = $Versions; $i -le ($LogFiles.Count - 1); $i++) { Remove-Item $LogFiles[$i].FullName }
	Write-BISFLog -Msg "Cleaning log file ($StrLogFileName) in $Directory and keeping the last $Versions Logs"

}

function Invoke-LogShare {
	<#
	.SYNOPSIS
		Based on Preparation Phase the central Log share would be set

	.DESCRIPTION
	  	Preparation Phase:
			defines a optional Central LogShare for all the BISF log files, if the CLI command -LogShare would not
			specified a message box appears to ask for the UNC-Path.
			It's recommended "Authenticated Users has Read/Write Access to to this folder"
	.EXAMPLE
		Invoke-BISFLogShare
	.NOTES
		Author: Matthias Schlimm

		History:
	  	16.03.2016 MS: function created
		23.03.2016 MS: extend CLI command, you can use -LogShare NO for not being used the Central LogShare
		06.03.2017 MS: Fixed read Variable $varCLI = ...
		18.08.2017 FF: Fix for Bug 200: Popup shouldn't show up if Central Log share is enabled OR disabled
		02.07.2018 MS: Fixed 50 - set Global Variable after Registry is set (After LogShare is changed in ADMX, the old path will also be checked and skips execution)
		14.08.2019 MS: FRQ 3 - Remove message box and using default setting if GPO is not configured
#>
	IF ($State -eq "Preparation") {
		Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
		$VarCLILS = $LIC_BISF_CLI_LS
		$VarCLILSb = $LIC_BISF_CLI_LSb
		$VarCLILSCfg = $LIC_BISF_CLI_LogCfg
		IF ($null -ne $VarCLILSCfg) {
			IF ($VarCLILSb -eq "NO") { $VarCLILS = $VarCLILSb }
			Write-BISFLog -Msg "GPO value:: $VarCLILS"
			$CentralLogShare = $VarCLILS
		}
		ELSE {
			Write-BISFLog -Msg "GPO not configured.. using default setting"
			$DefaultLogShare = "NO"
			$CentralLogShare = ""
		}


		If (($CentralLogShare -ne "") -and ($CentralLogShare -ne "NO")) {
			Write-BISFLog -Msg "The BIS-F Central LogShare for the Client personalization will be set to $CentralLogShare" -ShowConsole -Color DarkCyan -SubMsg
			Write-BISFLog -Msg "Set BIS-F Central LogShare in the registry $HklmBisfScripts, Name LIC_BISF_LogShare, value $CentralLogShare"
			Set-ItemProperty -Path $HklmBisfScripts -Name "LIC_BISF_LogShare" -Value "$CentralLogShare" -Force
			$Global:LIC_BISF_LogShare = "$CentralLogShare"
		}
		ELSE {
			Write-BISFLog -Msg "No BIS-F Central LogShare defined, skip action"
			IF (($LIC_BISF_LogShare -eq "" ) -or ($null -eq $LIC_BISF_LogShare)) {
				Write-BISFLog -Msg "No Central LogShare will be configured, the local path will be used" -ShowConsole -Color DarkCyan -SubMsg
			}
			ELSE {
				Write-BISFLog -Msg "The Central LogShare has been previously defined to $LIC_BISF_LogShare, this log will be stored on the Central Share, but for the future logging the local path will be used" -ShowConsole -Color DarkCyan -SubMsg
			}
			Remove-ItemProperty -path $HklmBisfScripts -name "LIC_BISF_LogShare" -ErrorAction SilentlyContinue
			$Global:LIC_BISF_LogShare = ""
		}
	}
}

function Set-LastRun {
	<#
	.SYNOPSIS
		Writes the current TimeStamp to the BISF registry to see see last BISF Run
	.DESCRIPTION
		Records the last preparation run time and user in the BIS-F registry hive.
	.EXAMPLE
		Set-BISFLastRun
	.NOTES
		Author: Matthias Schlimm

		History:
	  	07.12.2016 MS: function created


#>
	$CurrentUser = $env:username
	IF ($State -eq "Preparation") {
		Set-ItemProperty -Path $HklmBisfScripts -Name "LIC_BISF_PrepLastRunTime" -Value $(Get-Date)
		Set-ItemProperty -Path $HklmBisfScripts -Name "LIC_BISF_PrepLastRunUser" -Value $CurrentUser
	}
}

function Get-MacAddress {
	<#
	.SYNOPSIS
		Get the Mac Address if the first adapter to use them with the GUID
	.DESCRIPTION
		Returns the MAC address of the adapter bound to the computer's primary IP address.
	.PARAMETER ConvertToLower
		Return the MAC address in lowercase without colons.
	.EXAMPLE
		$mac = Get-BISFMacAddress
	.EXAMPLE
		Convert the received MAC-Address to lowercase
		$mac = Get-BISFMacAddress -ConvertToLower
	.NOTES
		Author: Matthias Schlimm

		History:
	  	09.01.2017 MS: function created
		20.02.2017 MS: fix empty space given back from $mac, thx to Valentino
		18.09.2019 MS: HF 137 - generated GUID based on MAC-Address return in lowercase
		19.02.2020 MS: HF 212 - SEP duplicate HardwareID -> FIX: $ConvertToLower mac as an parameter

#>
	Param(
		[Parameter(Mandatory = $false)][switch]$ConvertToLower
	)

	$Computer = $env:COMPUTERNAME
	$HostIP = [System.Net.Dns]::GetHostByName($Computer).AddressList[0].IPAddressToString
	$Wmi = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration 
	$Mac = (($Wmi | Where-Object { $_.IPAddress -eq $HostIP }).MACAddress)
	$Delimiter = ":"
	IF ($ConvertToLower) {
		Write-BISFLog -Msg "MAC-Address is converted to lowercase"
		$Mac = ($Mac -replace "$Delimiter", "").toLower()
	} ELSE {
		$Mac = ($Mac -replace "$Delimiter", "")
	}
	Write-BISFLog -Msg "The MAC-Address for further use will be resolved: $Mac"
	return $Mac
}

function Test-AppLayeringSoftware {
	<#
	.SYNOPSIS
		check if the Citrix AppLayering Service installed
	.DESCRIPTION
	  	if the Citrix AppLayering Service they will send a true or false value and will set the global variable ImageSW to true or false
	.EXAMPLE
		Test-BISFAppLayeringSoftware
	.NOTES
		Author: Matthias Schlimm

		History:
	  	25.07.2017 MS: function created
		27.07.2017 MS: add detection of OS, Platform and Application Layer
		31.07.2017 MS: add $Global:CTXAppLayerName
		01.08.2017 MS: Fixed Test-AppLayeringSoftware, to much more bracket
		24.08.2017 MS: if OS and Platform/Application Layer not detected, VM is not running inside ELM, give back $GLobal:CTXAppLayerName="No-ELM"
		29.10.2017 MS: Fixed if VM is running outside ELM, different MachineState is set in registry
		25.02.2018 MS: Fixed 241: AppLayering does not detect the right layer
		30.03.2018 MS: Fixed 38: MachineState 3 not detected, Pre-ELM State, Layer finalized must not run
		01.07.2018 MS: Fixed 48: Using RunMode to detect the right AppLayer, persistent between AppLayering updates
		09.07.2018 MS: Fixed 48 - Part II: get DiskMode, to handle App Layering different
		09.07.2018 MS: Fixed 48 - Part III: using DiskMode in RunMode 4 to diff between App- or Platform Layer
		21.10.2018 MS: Fixed 62: BIS-F AppLayering - Layer Finalized is blocked with MCS - Booting Layered Image
		02.01.2020 MS: Fixed 164: Layer finalize is blocked with VDA 1912 LTSR and activated UPL
		07.01.2020 MS: HF 176 - $Global:ImageSW request is set one Time only
		01.06.2020 MS: HF 187 - VDA 1912 inside AppLayering Packaging VM wrong Layer back
		15.06.2020 MS: HF 247 - DomainMember output - missing $
		18.06.2020 MS: HF 251 - Wrong Citrix AppLayering Layer detected with UPL and on Server OS

    #>
	#default values
	$Global:CTXAppLayeringSW = $false            # AppLayering is installed
	$Global:CTXAppLayeringOSLayer = $false       # OS Layer detected
	$Global:CTXAppLayeringPFLayer = $false       # Platform Layer detected
	$Global:CTXAppLayerName = $Null
	$SvcName = "UniService"
	$ProductName = "Citrix AppLayering"
	$Svc = Test-BISFService -ServiceName $SvcName -ProductName $ProductName
	IF ($Svc -eq $true) {
		$Global:CTXAppLayeringSW = $true
		$Global:ImageSW = $true
		$OverrideRunMode = $false
		Write-BISFLog -Msg "OverrideRunMode: $OverrideRunMode"
		$Global:CTXAppLayeringRunMode = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\unifltr).RunMode
		Write-BISFLog -Msg "$ProductName RunMode: $CTXAppLayeringRunMode"
		$DiskMode = Get-BISFDiskMode
		$SvcStatus = Test-BISFServiceState -ServiceName $SvcName -Status "Running"
		Write-BISFLog -Msg "ServiceStatus Citrix AppLayering: $SvcStatus"
		$DomainMember = (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain
		Write-BISFLog -Msg "DomainMember: $DomainMember"
		Write-BISFLog -Msg "UPL: $UPL"

		IF ($CTXAppLayeringRunMode -ne 1) {
			IF (($SvcStatus -ne "Running") -or ($UPL -eq $true)) {$OverrideRunMode = $true; $OverrideCode = "UniService/UPL";Write-BISFLog -Msg "OverrideRunMode: $OverrideRunMode"}
		}

		IF ($OverrideRunMode -eq $true) {
			$CTXAppLayeringRunModeNew = 1
			Write-BISFLog "[Code $OverrideCode] The original $ProductName RunMode ist set to $CTXAppLayeringRunMode, based on the detection of the current environment the RunMode is internally changed to $CTXAppLayeringRunModeNew to get the right layer"
			$CTXAppLayeringRunMode = $CTXAppLayeringRunModeNew
		}
		Switch ($CTXAppLayeringRunMode) {
			1 {
				$Global:CTXAppLayerName = "No-ELM"
			}
			3 {
				$Global:CTXAppLayeringOSLayer = $true
				$Global:CTXAppLayerName = "OS-Layer"
			}
			4 {
				$Global:CTXAppLayeringPFLayer = $true
				$Global:CTXAppLayerName = "Platform/Application Layer"
				IF ($DiskMode -eq "VDAPrivateAppLayering") { $Global:CTXAppLayeringPFLayer = $true; $Global:CTXAppLayerName = "Platform-Layer" }
				IF ($DiskMode -eq "UnmanagedAppLayering") { $Global:CTXAppLayeringAppLayer = $true; $Global:CTXAppLayerName = "Application-Layer" }
			}
			Default { Write-BISFLog -Msg "Not defined - $ProductName RunMode is set to $CTXAppLayeringRunMode" -ShowConsole -Type W }
		}
		Write-BISFLog -Msg "$ProductName - $CTXAppLayerName detected" -ShowConsole -SubMsg -Color DarkCyan
	}
	return $Svc

}

function Use-PVSConfig {
	<#
	.SYNOPSIS
		Redirect Files to the PVS WriteCacheDisk
	.DESCRIPTION
	  	IF Citrix PVS Target Device Driver is installed, the redirection of event logs, spool and other is necessary
	.EXAMPLE
		Use-BISFPVSConfig
	.NOTES
		Author: Matthias Schlimm

		History:
	  	27.07.2017 MS: function created
		01.08.2017 MS: if custom spool folder is enabled in ADMX; use this instead of BIS-F standard
		02.08.2017 MS: change to new ADMX structure to get custom Spool foldername
		31.08.2017 MS: Fixed - event logs would be moved during Preparation only, this saved time during personalization
		04.09.2017 MS: Fixed - event logs would be moved for both States (Prep and Pers) now
		03.11.2017 MS: if PVS Target Device Driver not installed, write info to BIS-F log and set the value $Global:Redirection=$true; $Global:RedirectionCode="NoPVS"
		13.08.2019 AS: ENH 46 - Make any PVS conversion work Optional
		14.08.2019 MS: ENH 108 - set NTFS Rights for spool directory
		25.08.2019 MS: ENH 128 - Disable redirection if WriteCacheDisk is set to NONE
		08.10.2019 MS: ENH 145 - ADMX: Disable Redirection for Citrix PVS Target
		18.06.2020 MS: HF 249 - WEMCache folder will be reconfigured if UPL is installed
		22.12.2020 JS: HF 302 - WriteCache disk access validated before redirecting
		18.01.2021 MS: HF 302 - moving Test-BISFWriteCacheDiskDriveLetter outside of redirection, Return value muste be used for Formatting the CacheDisk if the redirection is enabled/disabled
#>
	IF ($ReturnTestPVSSoftware) {
		$Global:Redirection = $false
		Write-BISFLog -Msg "Checking if redirection of Files to PVS Write Cache Disk is possible" -ShowConsole -Color Cyan
		#enable redirection
		IF ($UPL -eq $true) {
			IF ($State -eq "Preparation") { $Global:Redirection = $true; $Global:RedirectionCode = "PVS-UPL-Prep" ; Write-BISFLog -Msg "enable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
			IF (($State -eq "Personalization") -and ($Computer -ne $LIC_BISF_RefSrv_HostName)) { $Global:Redirection = $true; $Global:RedirectionCode = "PVS-UPL-Pers-NoBI" ; Write-BISFLog -Msg "enable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
			IF (($State -eq "Personalization") -and ($Computer -eq $LIC_BISF_RefSrv_HostName)) { $Global:Redirection = $true; $Global:RedirectionCode = "PVS-UPL-Pers-BI" ; Write-BISFLog -Msg "enable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
			IF (($State -eq "Personalization") -and ($Computer -ne $LIC_BISF_RefSrv_HostName)) { $Global:Redirection = $true; $Global:RedirectionCode = "PVS-UPL-Pers-NoBI" ; Write-BISFLog -Msg "enable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
		} ELSE {
			IF (($CTXAppLayeringSW -eq $false) -and ($State -eq "Preparation")) { $Global:Redirection = $true; $Global:RedirectionCode = "PVS-NoAppLay-Prep" ; Write-BISFLog -Msg "enable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
			IF (($CTXAppLayeringSW -eq $false) -and ($State -eq "Personalization") -and ($Computer -ne $LIC_BISF_RefSrv_HostName)) { $Global:Redirection = $true; $Global:RedirectionCode = "PVS-NoAppLay-Pers-NoBI" ; Write-BISFLog -Msg "enable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
			IF (($CTXAppLayeringSW -eq $false) -and ($State -eq "Personalization") -and ($Computer -eq $LIC_BISF_RefSrv_HostName)) { $Global:Redirection = $true; $Global:RedirectionCode = "PVS-NoAppLay-Pers-BI" ; Write-BISFLog -Msg "enable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
			IF (($CTXAppLayeringSW -eq $true) -and ($State -eq "Personalization") -and ($Computer -ne $LIC_BISF_RefSrv_HostName)) { $Global:Redirection = $true; $Global:RedirectionCode = "PVS-AppLay-Pers-NoBI" ; Write-BISFLog -Msg "enable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
		}


		#disable redirection
		IF ($UPL -eq $false) {
			IF (($CTXAppLayeringSW -eq $true) -and ($State -eq "Preparation")) { $Global:Redirection = $false; $Global:RedirectionCode = "PVS-AppLay-Prep" ; Write-BISFLog -Msg "disable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
			IF (($CTXAppLayeringSW -eq $true) -and ($State -eq "Preparation") -and ($Computer -eq $LIC_BISF_RefSrv_HostName)) { $Global:Redirection = $false; $Global:RedirectionCode = "PVS-AppLay-Prep-BI" ; Write-BISFLog -Msg "disable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
			IF (($CTXAppLayeringSW -eq $true) -and ($State -eq "Personalization") -and ($Computer -eq $LIC_BISF_RefSrv_HostName)) { $Global:Redirection = $false; $Global:RedirectionCode = "PVS-AppLay-Pers-BI" ; Write-BISFLog -Msg "disable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
		}

		IF ($LIC_BISF_CLI_WCD -eq "NONE") {$Global:Redirection = $false; $Global:RedirectionCode = "PVS-Global-No-WCD" ; Write-BISFLog -Msg "disable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }

		IF ($LIC_BISF_CLI_PVSDisableRedirection -eq 1) { $Global:Redirection = $false; $Global:RedirectionCode = "PVS-Global-Disabled-Redirection" ; Write-BISFLog -Msg "disable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }

		IF ((Test-BISFAccessValidated -Folder "$PVSDiskDrive\") -eq $False) { $Global:Redirection = $false; $Global:RedirectionCode = "WCD-To-Be-Formatted" ; Write-BISFLog -Msg "disable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
		$Global:ReturnTestPVSEnvVariable = Test-BISFWriteCacheDiskDriveLetter -Verbose:$VerbosePreference

		IF ($Redirection -eq $true) {
			Write-BISFLog -Msg "Redirection is enabled with Code $RedirectionCode, configuring it now" -ShowConsole -SubMsg -Color DarkCyan

			#Check redirection
			IF ($State -eq "Preparation") {
				IF ($DiskMode -eq "ReadOnly") { Write-BISFLog -Msg "Mode $DiskMode - vDisk in Standard Mode, read access only!" -Type E -SubMsg }
				IF ($DiskMode -eq "Unmanaged") {
					IF($LIC_BISF_CLI_P2V_SKIP_IMG -eq 1) {
						Write-BISFLog -Msg "Mode $DiskMode - Policy 'Skip PVS master image creation' is enabled, so continuing" -SubMsg
					}
					ELSE {
						Write-BISFLog -Msg "Mode $DiskMode - No vDisk assigned to this Device" -Type E -SubMsg
					}
				}
				$Global:ReturnTestPVSDriveLetter = Test-BISFWriteCacheDisk -Verbose:$VerbosePreference
			}

			# test if custom spool folder is enabled
			IF ($LIC_BISF_CLI_SPb -eq "1") { $Global:LIC_BISF_SpoolPath = "$PVSDiskDrive\$LIC_BISF_CLI_SpoolFolder" }
			#redirect Spool directory

			# create redirected Spool directory
			Write-BISFLog -Msg "Redirect Spool directory to $LIC_BISF_SpoolPath" -ShowConsole -Color DarkCyan -SubMsg
			if (!(Test-Path -Path $LIC_BISF_SpoolPath)) {
				Write-BISFLog -Msg "Create redirected Spool directory"
				New-Item -Path $LIC_BISF_SpoolPath -ItemType Directory -Force
			}
			$StrRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Printers"
			Write-BISFLog -Msg "Configure redirected Spool directory in registry $StrRegPath"
			Set-ItemProperty -Path $StrRegPath  -Name "DefaultSpoolDirectory" -Value $LIC_BISF_SpoolPath
			Set-BISFACLRights -path $LIC_BISF_SpoolPath

			# redirected event	logs
			Move-BISFEvtLogs
		}
		ELSE {
			Write-BISFLog -Msg "Redirection is disabled with code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan
		}
	}
	ELSE {
		$Global:Redirection = $true; $Global:RedirectionCode = "NoPVS" ; Write-BISFLog -Msg "disable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan
	}
}

function Use-MCSConfig {
	<#
	.SYNOPSIS
		Redirect Files to the MCS CacheDisk
	.DESCRIPTION
	  	IF Citrix VDA 1903 or higher is installed, BIS-F can  redirect the event logs, spool and other is necessary
	.EXAMPLE
		Use-BISFMCSConfig
	.NOTES
		Author: Matthias Schlimm

		History:
		  03.10.2019 MS: EHN 126 - function created (copy from Use-PVSConfig function and modified for MCS)
		  03.01.2020 MS: HF 169 - Disable redirection if MCS GPO is disabled
		  18.06.2020 MS: HF 249 - WEMCache folder will be reconfigured if UPL is installed
		  23.12.2020 MS: HF 302 - WriteCache disk access validated before redirecting
		  18.01.2021 MS: HF 302 - moving Test-BISFWriteCacheDiskDriveLetter outside of redirection, return value muste be used for Formatting the Cache Disk if the redirection is enabled/disabled

#>
	IF ($MCSIO) {
		$Global:Redirection = $false
		Write-BISFLog -Msg "Check if redirection of Files to MCSIO CacheDisk is possible" -ShowConsole -Color Cyan
		#enable redirection
		IF ($LIC_BISF_CLI_MCSCfg -eq "YES") {
			IF ($UPL -eq $true) {
				IF ($State -eq "Preparation") { $Global:Redirection = $true; $Global:RedirectionCode = "MCS-UPL-Prep" ; Write-BISFLog -Msg "enable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
				IF (($State -eq "Personalization") -and ($Computer -ne $LIC_BISF_RefSrv_HostName)) { $Global:Redirection = $true; $Global:RedirectionCode = "MCS-UPL-Pers-NoBI" ; Write-BISFLog -Msg "enable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
				IF (($State -eq "Personalization") -and ($Computer -eq $LIC_BISF_RefSrv_HostName)) { $Global:Redirection = $true; $Global:RedirectionCode = "MCS-UPL-Pers-BI" ; Write-BISFLog -Msg "enable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
				IF (($State -eq "Personalization") -and ($Computer -ne $LIC_BISF_RefSrv_HostName)) { $Global:Redirection = $true; $Global:RedirectionCode = "MCS-UPL-Pers-NoBI" ; Write-BISFLog -Msg "enable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
			} ELSE {
				IF (($CTXAppLayeringSW -eq $false) -and ($State -eq "Preparation")) { $Global:Redirection = $true; $Global:RedirectionCode = "MCS-NoAppLay-Prep" ; Write-BISFLog -Msg "enable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
				IF (($CTXAppLayeringSW -eq $false) -and ($State -eq "Personalization") -and ($Computer -ne $LIC_BISF_RefSrv_HostName)) { $Global:Redirection = $true; $Global:RedirectionCode = "MCS-NoAppLay-Pers-NoBI" ; Write-BISFLog -Msg "enable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
				IF (($CTXAppLayeringSW -eq $false) -and ($State -eq "Personalization") -and ($Computer -eq $LIC_BISF_RefSrv_HostName)) { $Global:Redirection = $true; $Global:RedirectionCode = "MCS-NoAppLay-Pers-BI" ; Write-BISFLog -Msg "enable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
				IF (($CTXAppLayeringSW -eq $true) -and ($State -eq "Personalization") -and ($Computer -ne $LIC_BISF_RefSrv_HostName)) { $Global:Redirection = $true; $Global:RedirectionCode = "MCS-AppLay-Pers-NoBI" ; Write-BISFLog -Msg "enable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }

			}
		}

		#disable redirection
		IF ($UPL -eq $false) {
			IF (($CTXAppLayeringSW -eq $true) -and ($State -eq "Preparation")) { $Global:Redirection = $false; $Global:RedirectionCode = "MCS-AppLay-Prep" ; Write-BISFLog -Msg "disable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
			IF (($CTXAppLayeringSW -eq $true) -and ($State -eq "Preparation") -and ($Computer -eq $LIC_BISF_RefSrv_HostName)) { $Global:Redirection = $false; $Global:RedirectionCode = "MCS-AppLay-Prep-BI" ; Write-BISFLog -Msg "disable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
			IF (($CTXAppLayeringSW -eq $true) -and ($State -eq "Personalization") -and ($Computer -eq $LIC_BISF_RefSrv_HostName)) { $Global:Redirection = $false; $Global:RedirectionCode = "MCS-AppLay-Pers-BI" ; Write-BISFLog -Msg "disable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
		}

		IF ($LIC_BISF_CLI_MCSCfg -ne "YES") {$Global:Redirection = $false; $Global:RedirectionCode = "MCS-Global-Disabled" ; Write-BISFLog -Msg "disable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }
		IF ($LIC_BISF_CLI_MCSIODriveLetter -eq "NONE") {$Global:Redirection = $false; $Global:RedirectionCode = "MCS-Global-No-WCD" ; Write-BISFLog -Msg "disable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }

		IF ($LIC_BISF_CLI_MCSIODisableRedirection -eq 1) {$Global:Redirection = $false; $Global:RedirectionCode = "MCS-Global-Disabled-Redirection" ; Write-BISFLog -Msg "disable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }

		IF ((Test-BISFAccessValidated -Folder "$PVSDiskDrive\") -eq $False) { $Global:Redirection = $false; $Global:RedirectionCode = "WCD-To-Be-Formatted" ; Write-BISFLog -Msg "disable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan }

		$Global:ReturnTestPVSEnvVariable = Test-BISFWriteCacheDiskDriveLetter -Verbose:$VerbosePreference
		IF ($Redirection -eq $true) {
			Write-BISFLog -Msg "Redirection is enabled with Code $RedirectionCode, configuring it now" -ShowConsole -SubMsg -Color DarkCyan

			#Check redirection
			IF ($State -eq "Preparation") {
				IF ($DiskMode -eq "VDAShared") { Write-BISFLog -Msg "Mode $DiskMode - Image is in shared Mode, read access only!" -Type E -SubMsg }

				$Global:ReturnTestPVSDriveLetter = Test-BISFWriteCacheDisk -Verbose:$VerbosePreference
			}

			# test if custom spool folder is enabled
			IF ($LIC_BISF_CLI_SPb -eq "1") { $Global:LIC_BISF_SpoolPath = "$PVSDiskDrive\$LIC_BISF_CLI_SpoolFolder" }
			#redirect Spool directory

			# create redirected Spool directory
			Write-BISFLog -Msg "Redirect Spool directory to $LIC_BISF_SpoolPath" -ShowConsole -Color DarkCyan -SubMsg
			if (!(Test-Path -Path $LIC_BISF_SpoolPath)) {
				Write-BISFLog -Msg "Create redirected Spool directory"
				New-Item -Path $LIC_BISF_SpoolPath -ItemType Directory -Force
			}
			$StrRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Printers"
			Write-BISFLog -Msg "Configure redirected Spool directory in registry $StrRegPath"
			Set-ItemProperty -Path $StrRegPath  -Name "DefaultSpoolDirectory" -Value $LIC_BISF_SpoolPath
			Set-BISFACLRights -path $LIC_BISF_SpoolPath

			# Redirected event logs
			Move-BISFEvtLogs
		}
		ELSE {
			Write-BISFLog -Msg "Redirection is disabled with code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan
		}
	}
	ELSE {
		$Global:Redirection = $false; $Global:RedirectionCode = "NoMCSIO" ; Write-BISFLog -Msg "disable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan
	}
}

function Move-EvtLogs {
	<#
	.Synopsis
	   Enable all Eventlog and move event logs to E:\EventLogs
	.DESCRIPTION
		Enable all Eventlog and move event logs to the write cache disk when redirection is enabled.
	.NOTES
		Author: Matthias Schlimm

		History:
	  	29.07.2017 MS: function created, thx to Bernd Braun
		01.08.2017 MS: if custom eventlog folder is enabled in ADMX; use this instead of BIS-F standard
		02.08.2017 MS: change to new ADMX structure to get custom EventLog foldername
		11.11.2017 MS: Fixed, show the right Eventlog during move to the WCD
		14.08.2019 MS: ENH 108 - set NTFS Rights for Eventlog directory
		03.10.2019 MS: EHN 126 - added MCSIO redirection
        27.12.2019 MS/MN: HF 161 - Quotation marks are different
		16.12.2020 MW: HF 42 - New Move Event Log Function
		24.12.2020 MS: HF 42 - fixing 1 KB evtx and etl files in the BISF installation folder
		04.01.2021 MS: HF 42 - rename variable $LogFile to $NewLogFile, $LogFile is used for the BIS-F Log
		08.01.2021 MS: HF 42 - coding issue at line '$NewLogFile = Split-Path $LogFilepath -Leaf | out-null' -> remove '| out-null' to clear the variable itself

	.EXAMPLE
		Move-BISFEvtLogs

	.FUNCTIONALITY
		Enable all Eventlog and move event logs to the PVS WriteCacheDisk if Redirection is enabled function Use-BISFPVSConfig
			or
		Enable all Eventlog and move event logs to the MCSIO CacheDisk if Redirection is enabled function Use-BISFMCSConfig

	.Link
		https://gallery.technet.microsoft.com/scriptcenter/Change-the-path-of-the-f86d2427

	#>
	# test if custom search folder is enabled
	IF ($LIC_BISF_CLI_EVTb -eq "1") { $Global:LIC_BISF_EvtPath = "$PVSDiskDrive\$LIC_BISF_CLI_EvtFolder" }

	Write-BISFLog -Msg "Move event logs to the CacheDisk" -ShowConsole -Color Cyan
	If (!(Test-Path -Path $LIC_BISF_EvtPath)) {
		Write-BISFLog -Msg "Create Eventlog directory $LIC_BISF_EvtPath"
		New-Item -Path $LIC_BISF_EvtPath -ItemType Directory -Force
	}
	[Reflection.Assembly]::LoadWithPartialName("System.Diagnostics.Eventing.Reader")
	$EventLogSessions = New-Object System.Diagnostics.Eventing.Reader.EventLogSession

	foreach ($LogName in $EventLogSessions.GetLogNames()) {
		Write-BISFLog -Msg "Processing EventLog: $LogName" -ShowConsole -SubMsg -Color DarkCyan
        $EventLogConfig = New-Object System.Diagnostics.Eventing.Reader.EventLogConfiguration -ArgumentList $LogName,$EventLogSessions
        $LogFilepath = $EventLogConfig.LogFilePath
		Write-BISFLog -Msg "Current Path: $LogFilepath" -ShowConsole -SubMsg -Color DarkCyan
		$NewLogFile = Split-Path $LogFilepath -Leaf
        $NewLogFilePath = "$LIC_BISF_EvtPath\$NewLogFile"

		if ($LogFilepath -eq $NewLogFilePath) {
			Write-BISFLog -Msg "New and Current Path are equal - skipping configuration change" -ShowConsole -SubMsg -Color Green
		} else {
			Write-BISFLog -Msg "New Path: $NewLogFilePath" -ShowConsole -SubMsg -Color DarkCyan
			if (($EventLogConfig.LogType -eq "Debug" -or $EventLogConfig.LogType -eq " Analytical") -and $EventLogConfig.IsEnabled) {
				$EventLogConfig.IsEnabled = $false
				$EventLogConfig.SaveChanges()

				$EventLogConfig.LogFilePath = $NewLogFilePath
				$EventLogConfig.SaveChanges()

				$EventLogConfig.IsEnabled = $true
				$EventLogConfig.SaveChanges()
			} else {
				$EventLogConfig.LogFilePath = $NewLogFilePath
				$EventLogConfig.SaveChanges()
			}
		}
    }

	Set-BISFACLRights -path $LIC_BISF_EvtPath
}

function Get-BootMode {
	<#
	.SYNOPSIS
		get System BootMode
		Determines underlying firmware (BIOS) type and returns True for UEFI or False for legacy BIOS.
	.DESCRIPTION
	  	This function uses a complied Win32 API call to determine the underlying system firmware type.
		get System BootMode back as follows
			UEFI
			Legacy
	.EXAMPLE
		$BootMode = Get-BISFBootMode

	.NOTES
		Author: Matthias Schlimm

		History:
	  	03.08.2017 MS: function created
		17.09.2017 MS: change to new API Call, get from https://gallery.technet.microsoft.com/scriptcenter/Determine-UEFI-or-Legacy-7dc79488
		03.11.2017 MS: writing BootMode (UEFI or Legacy) in Function to BISF log
#>

	[OutputType([Bool])]
	Param ()


	Add-Type -Language CSharp -TypeDefinition @'

	using System;
	using System.Runtime.InteropServices;

	public class CheckUEFI
	{
		[DllImport("kernel32.dll", SetLastError=true)]
		static extern UInt32
		GetFirmwareEnvironmentVariableA(string lpName, string lpGuid, IntPtr pBuffer, UInt32 nSize);

		const int ERROR_INVALID_FUNCTION = 1;

		public static bool IsUEFI()
		{
			// Try to call the GetFirmwareEnvironmentVariable API.  This is invalid on legacy BIOS.

			GetFirmwareEnvironmentVariableA("","{00000000-0000-0000-0000-000000000000}",IntPtr.Zero,0);

			if (Marshal.GetLastWin32Error() == ERROR_INVALID_FUNCTION)

				return false;     // API not supported; this is a legacy BIOS

			else

				return true;      // API error (expected) but call is supported.  This is UEFI.
		}
	}
'@


	$a = [CheckUEFI]::IsUEFI()
	IF ($a -eq $true) { Write-BISFLog -Msg "BootMode UEFI detected"; return "UEFI" } ELSE { Write-BISFLog -Msg "BootMode Legacy detected"; return "Legacy" }

}

Function Export-Registry {

	<#
   .Synopsis
	Export registry item properties.
	.DESCRIPTION
	Export item properties for a give registry key. The default is to write results to the pipeline
	but you can export to either a CSV or XML file. Use -NoBinary to omit any binary registry values.
	.Parameter Path
	The path to the registry key to export.
	.Parameter ExportType
	The type of export, either CSV or XML.
	.Parameter ExportPath
	The filename for the export file.
	.Parameter NoBinary
	Do not export any binary registry values
   .Example
	Export-BISFRegistry "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ExportType json -ExportPath c:\files\WinLogon.xml

   .Notes
	NAME: Export-BISFRegistry
	Author: Jeffery Hicks / Matthias Schlimm


	History:
	14.08.2017 MS: import function into BIS-F
	15.08.2017 MS: Writing the second XML File, these file must be copied to the BIS-F Root Installation folder
	21.09.2019 MS: EHN 36 - Shared Configuration - JSON Export
	05.10.2019 MS: ENH 52 - Citrix AppLayering - different shared configuration based on Layer

#>

	[cmdletBinding()]

	Param(
		[Parameter(Position = 0, Mandatory = $True,
			HelpMessage = "Enter a registry path using the PSDrive format.",
			ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
		[ValidateScript( { (Test-Path $_) -AND ((Get-Item $_).PSProvider.Name -match "Registry") })]
		[Alias("PSPath")]
		[string[]]$Path,

		[Parameter()]
		[ValidateSet("json", "xml")]
		[string]$ExportType,

		[Parameter()]
		[string]$ExportPath,

		[switch]$NoBinary

	)

	Begin {
		Write-BISFLog "Starting registry Export" -ShowConsole -Color Cyan
		#initialize an array to hold the results
		$Data = @()
	} #close Begin

	Process {
		#go through each pipelined path
		Foreach ($Item in $Path) {
			Write-BISFLog "Getting $Item" -ShowConsole -Color DarkCyan -SubMsg
			$RegItem = Get-Item -Path $Item
			#get property names
			$Properties = $RegItem.Property
			Write-BISFLog "Retrieved $(($Properties | Measure-Object).count) properties" -ShowConsole -Color DarkCyan -SubMsg
			if (-not ($Properties)) {
				#no item properties were found so create a default entry
				$Value = $Null
				$PropertyItem = "(Default)"
				$RegType = "String"

				#create a custom object for each entry and add it the temporary array
				$Data += New-Object -TypeName PSObject -Property @{
					"Path"  = $Item
					"Name"  = $PropertyItem
					"Value" = $Value
					"Type"  = $RegType
					#"Computername"=$env:computername
				}
			}

			else {
				#enumerate each property getting its name, value and type
				foreach ($Property in $Properties) {
					Write-BISFLog "Exporting $Property" -ShowConsole -Color DarkCyan -SubMsg
					$Value = $RegItem.GetValue($Property, $null, "DoNotExpandEnvironmentNames")
					#get the registry value type
					$RegType = $RegItem.GetValueKind($Property)
					$PropertyItem = $Property

					#create a custom object for each entry and add it the temporary array
					$Data += New-Object -TypeName PSObject -Property @{
						"Path"  = $Item
						"Name"  = $PropertyItem
						"Value" = $Value
						"Type"  = $RegType
						#"Computername"=$env:computername
					}
				} #foreach
			} #else
		}#close Foreach
	} #close process

	End {
		#make sure we got something back
		if ($Data) {
			#filter out binary if specified
			if ($NoBinary) {
				Write-BISFLog "Removing binary values" -ShowConsole -Color DarkCyan -SubMsg
				$Data = $Data | Where-Object { $_.Type -ne "Binary" }
			}

			#export to a file both a type and path were specified
			if ($ExportType -AND $ExportPath) {
				Write-BISFLog "Exporting $ExportType data to $ExportPath" -ShowConsole -Color DarkCyan -SubMsg
				Switch ($ExportType) {
					"json" { $Data | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportPath }
					"xml" { $Data | Export-Clixml -Path $ExportPath }
				} #switch


				#Writing the second json File, these file must be copied to the BIS-F Root Installation folder
				# Set the File Name
				$FilePath = "$LIC_BISF_CLI_EX_PT" + "\BISFSharedConfig.json "
				Write-BISFLog -Msg "Writing $FilePath - copy this file to the BIS-F installation folder, like $InstallLocation on your destination computer (example: Citrix AppLayering in Worker group)," -ShowConsole -Color DarkCyan -SubMsg
				Write-BISFLog -Msg "To import the BIS-F configuration from $($ExportPath). If you run the Computer in a Workgroup you must set the shared path NTFS Rights to ""Everyone read"" to get access without being prompted."

				IF ($LIC_BISF_POL_AppLayCfg -eq 1) {
					Write-BISFLog -Msg "Citrix AppLayering export running.." -ShowConsole -Color DarkCyan -SubMsg
					IF ($LIC_BISF_CLI_AppLayOSCfg -eq 1) {
						$AppLayOSFilePath = $LIC_BISF_CLI_EX_PT + "\" +  $AppLayOSCfg
						$ExportPath = $null
					} ELSE {
						$AppLayOSFilePath = $null
					}

					IF ($LIC_BISF_CLI_AppLayAppPltCfg -eq 1) {
						$AppLayAppPltFilePath = $LIC_BISF_CLI_EX_PT + "\" + $AppLayAppPltCfg
						$ExportPath = $null
					} ELSE {
						$AppLayAppPltFilePath = $null
					}

					IF ($LIC_BISF_CLI_AppLayPltCfg -eq 1) {
						$AppLayPltFilePath = $LIC_BISF_CLI_EX_PT + "\" +  $AppLayPltCfg
						$ExportPath = $null
					} ELSE {
						$AppLayPltFilePath = $null
					}

					IF ($LIC_BISF_CLI_AppLayNoELM -eq 1) {
						$AppLayNoELMFilePath = $LIC_BISF_CLI_EX_PT + "\" +  $AppLayNoELMCfg
						$ExportPath = $null
					} ELSE {
						$AppLayNoELMFilePath = $null
					}

					(New-Object PSObject -Property @{
						ConfigFile 		= "$ExportPath"
						AppLayerOS		= "$AppLayOSFilePath"
						AppLayerAppPlt	= "$AppLayAppPltFilePath"
						AppLayerPlt 	= "$AppLayPltFilePath"
						AppLayerNoELM	= "$AppLayNoELMFilePath"
					}) | ConvertTo-Json -Depth 10 | Out-File -FilePath $FilePath

				} ELSE {
					(New-Object PSObject -Property @{
						ConfigFile 		= "$ExportPath"
					}) | ConvertTo-Json -Depth 10 | Out-File -FilePath $FilePath
				}

			} #if $exportType
			elseif ( ($ExportType -AND (-not $ExportPath)) -OR ($ExportPath -AND (-not $ExportType)) ) {
				Write-BISFLog "You forgot to specify both an export type and file." -ShowConsole -Type W -SubMsg
			}
			else {
				#write data to the pipeline
				$Data
			}
		} #if $#data
		else {
			Write-BISFLog "No data found" -ShowConsole -Type W -SubMsg
		}
		#exit the function
	} #close End

} #end Function

function Import-SharedConfiguration {
	<#
	.SYNOPSIS
		Import Shared Configuration from json file with fallback to the xml file
	.DESCRIPTION
	  	if the BISFSharedConfiguration.json does exist in the root of the BIS-F installation folder, read the json and get the path to the SharedConfiguration, fallback to the xml file for legacy support

	.EXAMPLE
		Import-BISFSharedConfiguration

	.NOTES
		Author: Matthias Schlimm

		History:
		  15.08.2017 MS: function created
		  21.09.2019 MS: EHN 36 - Shared Configuration - JSON Import
		  06.10.2019 MS: ENH 52 - Citrix AppLayering - different shared configuration based on Layer
		  30.01.2019 MS: HF 195 - Shared Configuration not imported
		  24.05.2020 MS: HF 242 - Shared Configuration error handling if FilePath is Null Or Empty

#>
	# JSON Import
	$JSONConfigFile = "$InstallLocation" + "BISFSharedConfig.json"
	IF (Test-Path $JSONConfigFile -PathType Leaf) {
		Write-BISFLog "Import JSON Shared Configuration " -ShowConsole -Color Cyan
		Write-BISFLog "Reading Shared Configuration from file $JSONConfigFile" -ShowConsole -SubMsg -Color DarkCyan
		$JsonFile = Get-Content $JSONConfigFile | ConvertFrom-Json
		$JSONSharedConfigFile = $JsonFile.ConfigFile
		IF ($JSONSharedConfigFile -eq "") {

			Write-BISFLog "Using Citrix AppLayering Shared Configuration" -ShowConsole -SubMsg -Color DarkCyan
			$null = Test-BISFAppLayeringSoftware

			switch ($CTXAppLayerName) {
				"OS-Layer" {
					Write-BISFLog "Layer $CTXAppLayerName detected" -ShowConsole -SubMsg -Color DarkCyan
					$JSONSharedConfigFile = $JsonFile.AppLayerOS
				}
				"Platform-Layer" {
					Write-BISFLog "Layer $CTXAppLayerName detected" -ShowConsole -SubMsg -Color DarkCyan
					$JSONSharedConfigFile = $JsonFile.AppLayerPlt
				}
				"Application-Layer" {
					Write-BISFLog "Layer $CTXAppLayerName detected" -ShowConsole -SubMsg -Color DarkCyan
					$JSONSharedConfigFile = $JsonFile.AppLayerAppPlt
				}
				"No-ELM" {
					Write-BISFLog "Layer $CTXAppLayerName detected" -ShowConsole -SubMsg -Color DarkCyan
					$JSONSharedConfigFile = $JsonFile.AppLayerNoELM
				}
				default {
					Write-BISFLog "AppLayer can't be retrieved, fallback to OS-Layer configuration" -ShowConsole -Type W -SubMsg
					$JSONSharedConfigFile = $JsonFile.AppLayerOS
				}
			}
		}
		IF (!([string]::IsNullOrEmpty($JSONSharedConfigFile))) {
			Write-BISFLog "Shared Configuration is stored in $JSONSharedConfigFile" -ShowConsole -SubMsg -Color DarkCyan
			IF (Test-Path $JSONSharedConfigFile -PathType Leaf) {
				IF (!(Test-Path $RegLicPolicies)) {
					New-Item -Path $HklmSoftwarePolicies -Name $LIC -Force | Out-Null
					New-Item -Path $HklmSoftwarePolicies"\"$LIC -Name $CTX_BISF_SCRIPTS -Force | Out-Null
					Write-BISFLog -Msg "create RegHive $RegLicPolicies"
				}
				Write-BISFLog "Import Json Configuration into the local Registry to path $RegLicPolicies" -ShowConsole -SubMsg -Color DarkCyan
				$Object = Get-Content $JSONSharedConfigFile | ConvertFrom-Json
				$Object | ForEach-Object { New-ItemProperty -path $_.path -name $_.Name -Value $_.Value -PropertyType $_.Type -Force | Out-Null }

			} ELSE {
				Write-BISFLog "Error: Shared Configuration $JSONSharedConfigFile does not exist!" -Type E
			}
		} ELSE {
			Write-BISFLog "Warning: Shared Configuration File for Layer $CTXAppLayerName is empty !" -ShowConsole -Type W -SubMsg
		}
	} ELSE {
		# Fallback to XML Import
		Write-BISFLog "Shared Configuration does not exist in $JSONConfigFile"
		$XMLConfigFile = "$InstallLocation" + "BISFSharedConfig.xml"
		IF (Test-Path $XMLConfigFile -PathType Leaf) {
			Write-BISFLog "Fallback to Legacy XML Shared Configuration " -ShowConsole -Color Cyan
			Write-BISFLog "Reading Shared Configuration from file $XMLConfigFile" -ShowConsole -SubMsg -Color DarkCyan
			[xml]$XmlDocument = Get-Content -Path "$XMLConfigFile"
			$XmlFullName = $XmlDocument.GetType().FullName
			$XmlSharedConfigFile = $XmlDocument.BISFconfig.ConfigFile
			IF (!([string]::IsNullOrEmpty($XmlSharedConfigFile))) {
				Write-BISFLog "Shared Configuration is stored in $XmlSharedConfigFile" -ShowConsole -SubMsg -Color DarkCyan
				IF (Test-Path $XmlSharedConfigFile -PathType Leaf) {
					IF (!(Test-Path $RegLicPolicies)) {
						New-Item -Path $HklmSoftwarePolicies -Name $LIC -Force | Out-Null
						New-Item -Path $HklmSoftwarePolicies"\"$LIC -Name $CTX_BISF_SCRIPTS -Force | Out-Null
						Write-BISFLog -Msg "create RegHive $RegLicPolicies"
					}
					Write-BISFLog "Import XML Configuration into the local Registry to path $RegLicPolicies" -ShowConsole -SubMsg -Color DarkCyan
					$Object = Import-Clixml "$XmlSharedConfigFile"
					$Object | ForEach-Object { New-ItemProperty -path $_.path -name $_.Name -Value $_.Value -PropertyType $_.Type -Force | Out-Null }

				}
			} ELSE {
				Write-BISFLog "Warning: Legacy Shared Configuration File is empty !" -ShowConsole -Type W -SubMsg
			}
			ELSE {
				Write-BISFLog "Error: Legacy Shared Configuration $XmlSharedConfigFile does not exist!" -Type E
			}
		} ELSE {
			Write-BISFLog "Legacy Shared Configuration does not exist in $XMLConfigFile"
		}
	}

}

function Remove-FolderAndContents {
	<#
	.SYNOPSIS
		Remove folder and contents
	.DESCRIPTION
	  	Remove the complete content including sub folders of an specified folder
	.PARAMETER FolderPath
		Folder to delete, including contents.
	.EXAMPLE
		Remove-BISFFolderAndContents ("C:\windows\temp")

	.NOTES
		Author: Matthias Schlimm

		History:
	  	22.08.2017 MS: function created
		27.12.2019 NM: HF 159 - added begin section

	  # http://stackoverflow.com/a/9012108
#>
	param(
		[Parameter(Mandatory = $true, Position = 1)] [string] $FolderPath
	)

	Begin {
            Write-BISFLog -Msg "Delete files and sub folders from folder $($FolderPath)"
      } #close Begin


	process {
		$ChildItems = ([array] (Get-ChildItem -Path $FolderPath -Recurse -Force))
		if ($ChildItems) {
			$null = $ChildItems | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue -Confirm:$False
		}
		$null = Remove-Item $FolderPath -Force -Recurse -Confirm:$False -ErrorAction SilentlyContinue
	} #close process
}

function Start-CDS {
	<#
	.SYNOPSIS
		Starts the Citrix Desktop Service
	.DESCRIPTION
	  	if the Delay Citrix Desktop Service is configured
		through ADMX, this service would be started

	.EXAMPLE
		Start-BISFCDS

	.NOTES
		Author: Matthias Schlimm

		History:
	  	10.09.2017 MS: function created
		12.09.2017 MS: Changing to $servicename = "BrokerAgent"
		25.03.2018 MS: Feature 14: ADMX Extension - enable additional time to delay the Citrix Desktop Service
		08.01.2020 MS: HF 178 - no default value is set if GPO for Additional Citrix Desktop Service delay is not configured
	  #
#>

	IF ($ReturnTestXDSoftware -eq "true") {
		# Citrix VDA only
		$ServiceName = "BrokerAgent"
		IF ($LIC_BISF_CLI_CDS -eq "1") {
			Write-BISFLog -Msg "The $ServiceName is configured through ADMX.. delay operation configured" -ShowConsole -Color Cyan

			IF ([string]::IsNullOrEmpty($LIC_BISF_CLI_CDSdelay)) { $LIC_BISF_CLI_CDSdelay = 0 }
			Write-BISFLog -Msg "Additional Citrix Desktop Service delay is set to $LIC_BISF_CLI_CDSdelay seconds"
			Start-Sleep -Seconds $LIC_BISF_CLI_CDSdelay
			Invoke-BISFService -ServiceName "$ServiceName" -Action Start -StartType Automatic
		}
		ELSE {
			Write-BISFLog -Msg "The $ServiceName has not been configured through ADMX.. normal operation state"
		}

	}

}

function Start-VHDOfflineDefrag {
	<#
	.SYNOPSIS
		Mount the VHD(X) File on the UNC-Path and defrag it
	.DESCRIPTION
	  	If using Custom UNC-Path to convert the BaseDisk,
		the vDisk on the UNC-Path will be mounted and defragmented

	.EXAMPLE
		Start-BISFVHDOfflineDefrag

	.NOTES
		Author: Dennis Span (http://dennisspan.com)


		History:
	  	11.10.2017 DD: Script created
		18.10.2017 MS: Implement function in BIS-F
		15.11.2017 MS: on the Mounted Disk, the same UniqueID must be set to fix boot recorded issues (https://blogs.technet.microsoft.com/markrussinovich/2011/11/06/fixing-disk-signature-collisions/)
	  #
#>

	# define Error handling
	# note: do not change these values
	$Global:ErrorActionPreference = "Stop"

	# Disable File Security
	$env:SEE_MASK_NOZONECHECKS = 1

	Write-BISFLog -Msg "Starting Offline $VhdExt defrag" -ShowConsole -Color Cyan

	# Check if the VHD(X) file exists
	Write-BISFLog -Msg "Check if the $VhdExt file '$VHDFileToDefrag' exists"
	if ( (Test-Path $VHDFileToDefrag ) -eq $True ) {
		Write-BISFLog -Msg "The $VhdExt file '$VHDFileToDefrag' exists" -ShowConsole -Color DarkCyan -SubMsg
	}
	else {
		Write-BISFLog -Msg "The $VhdExt file '$VHDFileToDefrag' does NOT exist or cannot be reached" -ShowConsole -SubMsg -Type E
	}

	# Retrieve drives before mounting the VHD(X)
	$DrivesAvailableBeforeVHDMount = (Get-PSDrive -PsProvider FileSystem).Name
	Write-BISFLog -Msg "Retrieving available drives (before mount): $([string]$DrivesAvailableBeforeVHDMount)" -ShowConsole -Color DarkCyan -SubMsg


	# Mount VHD(X) (using Cvhdmount.exe)
	$TmpLogFile = "C:\Windows\logs\BISFtmpProcessLog.log"
	Write-BISFLog -Msg "Mount (attach) the $VhdExt (using cvhdmount.exe)" -ShowConsole -Color DarkCyan -SubMsg
	$Process = Start-Process -FilePath "C:\Program Files\Citrix\Provisioning Services\CVhdMount.exe" -ArgumentList "-p 1 ""$VHDFileToDefrag""" -wait -PassThru -NoNewWindow -RedirectStandardOutput "$TmpLogFile"
	Get-BISFLogContent -GetLogFile "$TmpLogFile"
	Remove-Item -Path "$TmpLogFile" -Force | Out-Null
	$ProcessExitCode = $Process.ExitCode
	Start-Sleep -Seconds 5

	Write-BISFLog -Msg "bringing the attached $VhdExt online" -ShowConsole -Color DarkCyan -SubMsg
	$Process = Start-Process -FilePath "C:\Program Files\Citrix\Provisioning Services\CVhdMount.exe" -ArgumentList "-o 1 ""$VHDFileToDefrag""" -wait -PassThru -NoNewWindow -RedirectStandardOutput "$TmpLogFile"
	$ProcessExitCode = $Process.ExitCode
	Get-BISFLogContent -GetLogFile "$TmpLogFile"
	Remove-Item -Path "$TmpLogFile" -Force | Out-Null
	Start-Sleep -Seconds 5
	Write-BISFLog -Msg "The $VhdExt file was mounted successfully" -ShowConsole -Color DarkCyan -SubMsg


	# Retrieve drives after mounting the VHD(X)
	$DrivesAvailableAfterVHDMount = (Get-PSDrive -PsProvider FileSystem).Name
	Write-BISFLog -Msg "Retrieving available drives (after mount): $([string]$DrivesAvailableAfterVHDMount)" -ShowConsole -Color DarkCyan -SubMsg

	# Check which drive letter or driver letters were added after mounting the VHD(X) file (drive letters are written without a colon; e.g. "D" instead of "D:")
	try {
		[array]$Drives = ((Compare-Object $DrivesAvailableBeforeVHDMount $DrivesAvailableAfterVHDMount).InputObject).ToUpper()
	}
	catch {
		Write-BISFLog -Msg "No additional drives were detected. It is possible that the $VhdExt file was mounted, but that no drive letter could be assigned" -ShowConsole -SubMsg -Type W
		Write-BISFLog -Msg "Please make sure you are using a valid $VhdExt file containing a Windows operating system (Windows 7/Windows Server 2008 R2 or higher)" -ShowConsole -SubMsg -Type E
	}

	# Continue check which drive letter or driver letters were added after mounting the VHD(X) file (drive letters are written without a colon; e.g. "D" instead of "D:")
	$DriveCount = $Drives.Count
	switch ($DriveCount) {
		0 {
			Write-BISFLog -Msg "No new drives were added. Apparently the $VhdExt mount did not succeed" -ShowConsole -SubMsg -Type E
		}
		1 {
			# One additional drive will be found when capturing an operating system WITHOUT a 'System Reserved' boot partition (e.g. Windows 7, Windows Server 2008 R2)
			[string]$DriveLetterToDefrag = "$($Drives):"
			Write-BISFLog -Msg "One new drive was added: $DriveLetterToDefrag" -ShowConsole -SubMsg -Color DarkCyan
		}
		2 {
			# Two additional drives will be found when capturing an operating system WITH a 'System Reserved' boot partition (e.g. Windows 10, Windows Server 2016)
			Write-BISFLog -Msg "Two new drives were added. Checking which drive requires offline defragmentation" -ShowConsole -SubMsg -Color DarkCyan
			foreach ( $Drive in $Drives ) {
				Write-BISFLog -Msg "Checking drive $($Drive):" -ShowConsole -SubMsg -Color DarkCyan
				if ( (Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = '$($Drive):'").Label -like "*Reserved*") {
					Write-BISFLog -Msg "Drive $($Drive): is the 'System Reserved' drive. This one does not require offline defragmentation" -ShowConsole -SubMsg -Color DarkCyan
				}
				else {
					Write-BISFLog -Msg "Drive $($Drive): is the primary partition and requires offline defragmentation" -ShowConsole -SubMsg -Color DarkCyan
					[string]$DriveLetterToDefrag = "$($Drive):"
				}
			}
		}
		default {
			Write-BISFLog -Msg "More than two new drives were added. This script is not able to verify which drive needs offline defragmentation" -ShowConsole -SubMsg -Type E
		}
	}


	# Defrag VHD(X)
	Write-BISFLog -Msg "Running defrag on the $VhdExt mounted to drive $DriveLetterToDefrag..." -ShowConsole -SubMsg -Color DarkCyan
	$Process = Start-BISFProcWithProgBar -ProcPath "$($env:windir)\system32\defrag.exe" -Args "$DriveLetterToDefrag" -ActText "Defrag is running with mounted $VhdExt $VHDFileToDefrag on Drive $DriveLetterToDefrag"
	$ProcessExitCode = $Process.ExitCode
	Write-BISFLog -Msg  "ExitCode: $ProcessExitCode"
	if (($ProcessExitCode -eq 0 ) -or ($null -eq $ProcessExitCode )) {
		Write-BISFLog -Msg "Defrag drive $DriveLetterToDefrag completed successfully" -ShowConsole -SubMsg -Color DarkCyan
	}
	else {
		Write-BISFLog -Msg "An error occurred while attempting to defrag drive $DriveLetterToDefrag (error: $ProcessExitCode)" -ShowConsole -SubMsg -Type E
	}

	# Fixing DiskID before unmount
	# Get uniqueid SystemDrive
	Get-BISFDiskID -DriveLetter C: -ThrowWhenNotFound $true
	$DiskIdOSDisk = $DiskID

	#Set same UniqueID from SystemDrive on mounted VHD(X)
	$DiskIdVHDX = Get-BISFDiskID -DriveLetter $DriveLetterToDefrag
	$DiskIdVHDX = $DiskID
	$VolNbrVHDX = $VolNbr
	Write-BISFLog -Msg "UniqueID on SystemDrive is $DiskIdOSDisk  - UniqueID on mounted $VhdExt is $DiskIdVHDX" -ShowConsole -Color DarkCyan -SubMsg
	IF (!($DiskIdOSDisk -eq $DiskIdVHDX)) {
		Write-BISFLog -Msg "Setting the same UniqueID from SystemDrive on mounted $VhdExt - Drive $DriveLetterToDefrag" -ShowConsole -Type W -SubMsg
		$DiskpartFile = "$env:TEMP\$Computer-DiskpartFile.txt"
		If (Test-Path $DiskpartFile) { Remove-Item $DiskpartFile -Force }
		"Select volume $VolNbrVHDX" | Out-File -FilePath $DiskpartFile -Encoding Default
		"UniqueID disk ID=$DiskIdOSDisk" | Out-File -FilePath $DiskpartFile -Encoding Default -Append
		Get-BISFLogContent -GetLogFile "$DiskpartFile"
		diskpart.exe /s $DiskpartFile
		Write-BISFLog -Msg "Disk ID $DiskIdOSDisk is set on $DriveLetterToDefrag"
	}
	ELSE {
		Write-BISFLog "DiskID on both Disks are equal, no changes necessary!" -ShowConsole -Color DarkCyan -SubMsg
	}

	# Un-mount VHD(X) (using diskpart)
	Write-BISFLog -Msg "Dismount (detach) the $VhdExt (using CVhdMount.exe)" -ShowConsole -SubMsg -Color DarkCyan
	$Process = Start-Process -FilePath "C:\Program Files\Citrix\Provisioning Services\CVhdMount.exe" -ArgumentList "-u 1 ""$VHDFileToDefrag""" -Wait -NoNewWindow -RedirectStandardOutput "$TmpLogFile"
	$ProcessExitCode = $Process.ExitCode
	Write-BISFLog -Msg  "ExitCode: $ProcessExitCode"
	Get-BISFLogContent -GetLogFile "$TmpLogFile"
	Remove-Item -Path "$TmpLogFile" -Force | Out-Null
	Start-Sleep -Seconds 5
	# Enable File Security
	Remove-Item -Path env:\SEE_MASK_NOZONECHECKS -Force
	$Global:VerbosePreference = "Continue"

}

Function Get-DiskID {
	<#
	.SYNOPSIS
		Get the unique ID of the DriveLetter
	.DESCRIPTION
		Returns the unique disk ID for the given drive letter.
	.PARAMETER DriveLetter
		Drive letter including colon, for example C:.
	.PARAMETER ThrowWhenNotFound
		Throw when the drive cannot be found instead of returning a default.
	.EXAMPLE
		Get-BISFDiskID -DriveLetter C:

	.NOTES
		Author: Matthias Schlimm

		History:
	  	15.11.2017 MS: Script created

	  #
#>

	PARAM(
		[parameter(Mandatory = $True)][string]$DriveLetter,
		[parameter(Mandatory = $False)][bool]$ThrowWhenNotFound
	)
	if($false -eq $PSBoundParameters.ContainsKey('ThrowWhenNotFound')) {
		$ThrowWhenNotFound = $false;
	}
	$DiskpartFile = "$env:TEMP\$Computer-DiskpartFile.txt"
	Write-BISFLog -Msg "Get UniqueID from Drive $DriveLetter" -ShowConsole -Color DarkCyan -SubMsg
	$DriveLetter = $DriveLetter.substring(0, 1)
	Write-BISFLog -Msg "Using Diskpart and searching for Drive letter $DriveLetter"

	$SearchVol = "list volume" | C:\windows\system32\diskpart.exe | Select-String -pattern "Volume" | Select-String -pattern "$DriveLetter " -CaseSensitive | Select-String -pattern NTFS | Out-String
	$DiskID = "";
    $GetVolNbr = "";
    if($SearchVol.length -gt 0) {
        Write-BISFLog -Msg "$SearchVol"

	    $GetVolNbr = $SearchVol.substring(11, 1)   # Get Volume number from disk label
	    Write-BISFLog -Msg "Get volume number $GetVolNbr from disk label $DriveLetter"

	    Remove-Item $DiskpartFile -Recurse -ErrorAction SilentlyContinue
	    # Write Diskpart File
	    "select volume $GetVolNbr" | Out-File -filepath $DiskpartFile -Encoding Default
	    "uniqueid disk" | Out-File -FilePath $DiskpartFile -Encoding Default -Append
	    $Result = diskpart.exe /s $DiskpartFile
	    get-BISFLogContent -GetLogFile "$DiskpartFile"
	    $DiskID = $Result | Select-String -Pattern "ID" -CaseSensitive | Out-String
	    $DiskID = $DiskID.Split(":")  #split string on ":"
	    $DiskID = $DiskID[1] #get the first string after ":" to get the Disk ID only without the Text
	    $DiskID = $DiskID.trim() #remove empty spaces on the right and left
	    $Start = $DiskID.length
	    IF ($Start -eq "8") {
		    Write-BISFLog -Msg "MBR Disk with $Start characters identified"

	    }
	    ELSE {
		    Write-BISFLog -Msg "GPT Disk with $Start characters identified"
	    }
	    Write-BISFLog -Msg "UniqueID Disk of Drive $DriveLetter is $DiskID"
    } else {
		if($ThrowWhenNotFound){ 
			throw "Could not find volume $Drive"
		}
	}
	$Global:DiskID = $DiskID
	$Global:VolNbr = $GetVolNbr
}

Function Get-Hypervisor {
	<#
	.SYNOPSIS
		Get the installed Hypervisor like XenServer, VMware, Hyper-V, Nutanix AHV
	.EXAMPLE
		Get-BISFHypervisor
	.NOTES
		Author: Matthias Schlimm


		History
      	Last Change: 26.03.2018 MS: Script created
		Last Change: 13.05.2019 MS: FRQ 76 - rewritten script to detect the platform of the running computer
		Last Change: 05.01.2020 MS: remove typo
		Last Change: 16.08.2026 JP: Set $Global:IsVirtualMachine from Manufacturer/Model; use Get-CimInstance
#>

	$Hv = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object Manufacturer, Model
	$Platform = "$($Hv.Manufacturer) $($Hv.Model)"
	$VmPattern = 'Virtual Machine|VMware|Xen|XenServer|Nutanix|AHV|KVM|QEMU|VirtualBox|innotek|Amazon EC2|Google Compute|Hyper-V|Parallels'
	$Global:IsVirtualMachine = [bool]($Platform -match $VmPattern)
	Write-BISFLog -Msg "Computer is running on $Platform" -Color Cyan -ShowConsole
	if ($IsVirtualMachine) {
		Write-BISFLog -Msg "Platform is a virtual machine guest" -Color DarkCyan -ShowConsole -SubMsg
	}
	else {
		Write-BISFLog -Msg "Platform is physical or unknown (not treated as a VM guest)" -Color DarkCyan -ShowConsole -SubMsg
	}
	return $Platform

}

function Test-ServiceState {
	<#
	.SYNOPSIS
		check the State of the Service
	.DESCRIPTION
	  	After changing a Service from automatic to manual for example, it's necessary to test of the service has the right state before continue
	.PARAMETER ServiceName
		Windows service name.
	.PARAMETER Status
		Expected status: Running or Stopped.
	.EXAMPLE
		The Windows Update Service will be checked if the stopped
		 Test-BISFServiceState -ServiceName wuauserv -Status stopped
	.NOTES
		Author: Matthias Schlimm

		History:
	  	01.07.2018 MS: Hotfix 49 - function created
		21.10.2018 MS: add return $($svc.Status)
#>

	param (
		# Specifies the ServiceName
		[parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]$ServiceName,

		# Specifies the startup type: Disabled, Manual, Automatic
		[parameter(Mandatory = $false)]
		[ValidateSet("Running", "Stopped")]
		[ValidateNotNullOrEmpty()]$Status

	)
	$Svc = Get-Service $ServiceName

	IF ($Status -eq $Svc.Status ) {
		Write-BISFLog -Msg "The Service $($Svc.DisplayName) is successfully in $($Svc.Status) state"
	}
	else {
		Write-BISFLog -Msg "The Service $($Svc.DisplayName) is NOT successfully in $Status state" -Type W -SubMsg
	}
	return $Svc.Status
}

function Test-NutanixFrameSoftware {
	<#
	.SYNOPSIS
		check if the Nutanix Frame Agent installed
	.DESCRIPTION
	  	if the Nutanix Frame Agent installed they will send a true or false value and will set the global variable ImageSW to true or false
	.EXAMPLE
		Test-BISFNutanixFrameSoftware
	.NOTES
		Author: Matthias Schlimm

		History:
	  	13.08.2019 MS: function created
		07.01.2020 MS: HF 176 - $Global:ImageSW request is set one Time only
#>
	$Svc = Test-BISFService -ServiceName "MF2Service" -ProductName "Nutanix Xi Frame"
	IF ($Svc -eq $true) { $Global:ImageSW = $true }
	return $Svc

}

function Test-ParallelsRASSoftware {
	<#
	.SYNOPSIS
		check if the RAS RD Session Host Agent installed
	.DESCRIPTION
	  	if the RAS RD Session Host Agent installed they will send a true or false value and will set the global variable ImageSW to true or false
	.EXAMPLE
		Test-BISFParallelsRASSoftware
	.NOTES
		Author: Matthias Schlimm

		History:
	  	14.08.2019 MS: function created
		07.01.2020 MS: HF 176 - $Global:ImageSW request is set one Time only

#>
	$Svc = Test-BISFService -ServiceName "RAS RD Session Host Agent" -ProductName "Parallels RAS Software"
	IF ($Svc -eq $true) { $Global:ImageSW = $true }
	return $Svc

}

function Set-ACLRights {
	<#
	.SYNOPSIS
		Set the NTFS rights on the given path
	.DESCRIPTION
		Long description
	.PARAMETER path
		Defines the path to set the NTFS rights
	.EXAMPLE
		Set-BISFACLRights -Path "D:\EventLogs"
	.NOTES
			Author: Floris de Widt

			History:
			14.08.2019 MS: Function created
			04.01.2020 MS: HF 172 - set ACLrights error and using Quotation marks for $perm
			05.01.2020 MS: HF 172 - using S-1-5-19 instead of local Service
#>

	param(
		[parameter(Mandatory = $true)]
		[string]$Path
	)

	Write-BISFLog -Msg "Setting NTFS rights on $Path" -ShowConsole -Color Cyan

	$Acl = Get-Acl -Path $Path
	#$perm = "local service", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow"
	$LocalServiceSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-19")
	$LocalServiceName = ($LocalServiceSID.Translate( [System.Security.Principal.NTAccount])).Value
	$Perm = $LocalServiceName, "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow"
	$Rule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $Perm
	try {
		$Acl.SetAccessRule($Rule)
	}
	catch {
		Write-BISFLog -Msg "Error setting NTFS rights. The error is: $_" -Type W -SubMsg
	}

	$Acl | Set-Acl -Path $Path
	$Acl = Get-Acl -Path $Path

}

function Test-WVDSoftware {
	<#
	.SYNOPSIS
		Check if the Windows 10 Enterprise for Virtual Desktops is installed
	.DESCRIPTION
	  	If the Win32_OperatingSystem.Name is 'Microsoft Windows 10 Enterprise for Virtual Desktops' they  will send a true or false value and will set the global variable ImageSW to true or false
	.EXAMPLE
		Test-BISFWVDSoftware
	.NOTES
		Author: Matthias Schlimm

		History:
		  25.08.2019 MS: function created
		  07.01.2020 MS: HF 176 - $Global:ImageSW request is set one Time only
		  28.06.2020 MS: HF 257 - Azure WVD not detected
#>
	$Product = "Microsoft Windows 10 Enterprise for Virtual Desktops"
	IF ($OSName -eq $Product) { $WVD = $true } ELSE { $WVD = $false }
	IF ($WVD -eq $true) {
		Write-BISFLog -Msg "Product $Product installed" -ShowConsole -Color Cyan
		$Global:ImageSW = $true
	} ELSE {
			Write-BISFLog -Msg "Product $Product NOT installed"
	}
	return $WVD
}

function Set-LAPSExpirationTime{
	<#
	.SYNOPSIS
		During Computer startup the LAPS password expiration time is reset
	.DESCRIPTION
		Deploying Microsoft LAPS to a non-persistent VDI environment requires
		a slightly difference approach to traditional machines, especially for those environments that force a reboot after user log off

	.EXAMPLE
		Set-BISFLAPSExpirationTime
	.NOTES
		Author: Matthias Schlimm / Martin Zugec

		History:
	  	21.09.2019 MS: function created
		19.08.2026 JP: Search by sAMAccountName, load DN only, dispose ADSI objects, catch AD failures
#>

	Write-BISFLog -Msg "Reset Computer LAPS password" -ShowConsole -Color Cyan
	Write-BISFLog -Msg "Retrieve current machine account"

	$ComputerName = $env:COMPUTERNAME
	$LdapComputerName = $ComputerName.Replace('\', '\5c').Replace('*', '\2a').Replace('(', '\28').Replace(')', '\29')
	$Searcher = $null
	$DirectoryEntry = $null
	try {
		$Searcher = [ADSISearcher]"(&(objectCategory=computer)(sAMAccountName=${LdapComputerName}$))"
		$Searcher.PropertiesToLoad.Add('distinguishedName') | Out-Null
		$SearchResult = $Searcher.FindOne()
		if ($null -eq $SearchResult) {
			Write-BISFLog -Msg "Computer account $ComputerName was not found in Active Directory; LAPS expiration time was not reset" -Type W
			return
		}

		$DirectoryEntry = $SearchResult.GetDirectoryEntry()
		Write-BISFLog -Msg "Reset the password expiration timer to 0"
		$DirectoryEntry.PSBase.InvokeSet("ms-Mcs-AdmPwdExpirationTime", 0)
		Write-BISFLog -Msg "Save changes to the Active Directory object"
		$DirectoryEntry.SetInfo()
	}
	catch {
		Write-BISFLog -Msg "Unable to reset LAPS expiration time for $ComputerName : $($_.Exception.Message)" -Type W
	}
	finally {
		if ($null -ne $DirectoryEntry) {
			$DirectoryEntry.Dispose()
		}
		if ($null -ne $Searcher) {
			$Searcher.Dispose()
		}
	}

}

function Test-AzureVM {

		<#
	.SYNOPSIS
		detects if a computer is a virtual machine that is running in Microsoft Azure
	.DESCRIPTION
		The script checks if the computer is a Hyper-V guest by verifying that the Vmbus driver is running.

		If the Vmbus driver is running, the script does a platform invoke to call Win32 function DhcpRequestParams to query the DHCP server for option 245. Since Azure VMs must be configured for dynamic IP addresses, and option 245 is specific to Microsoft Azure, this confirms the VM is running in Microsoft Azure.

		Note  This method works even if you have configured Static for the IP in the portal. In that case, the IP is still provided by DHCP, but DHCP is providing the same IP address every time to that specific VM. However if you configured a static IP inside the guest OS itself (e.g. in TCP/IP properties in a Windows guest) - which is something you should never do with an Azure VM - then this method would not work.

		The script returns True if Vmbus is running and option 245 is returned by the DHCP server.

		The script returns False if Vmbus is not running or option 245 is not returned by the DHCP server.

	.EXAMPLE
		Test-BISFAzureVM
	.NOTES
		Author: Matthias Schlimm

		History:
	  	03.10.2019 MS: function created

		https://gallery.technet.microsoft.com/scriptcenter/Detect-Windows-Azure-aed06d51
#>

$Source = @"
using System;
using System.Collections.Generic;
using System.Text;
using System.Runtime.InteropServices;
using System.ComponentModel;
using System.Net.NetworkInformation;

namespace Microsoft.WindowsAzure.Internal
{
    /// <summary>
    /// A simple DHCP client.
    /// </summary>
    public class DhcpClient : IDisposable
    {
        public DhcpClient()
        {
            uint version;
            int err = NativeMethods.DhcpCApiInitialize(out version);
            if (err != 0)
                throw new Win32Exception(err);
        }

        public void Dispose()
        {
            NativeMethods.DhcpCApiCleanup();
        }

        /// <summary>
        /// Gets the available interfaces that are enabled for DHCP.
        /// </summary>
        /// <remarks>
        /// The operational status of the interface is not assessed.
        /// </remarks>
        /// <returns></returns>
        public static IEnumerable<NetworkInterface> GetDhcpInterfaces()
        {
            foreach (NetworkInterface nic in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (nic.NetworkInterfaceType != NetworkInterfaceType.Ethernet) continue;
                if (!nic.Supports(NetworkInterfaceComponent.IPv4)) continue;
                IPInterfaceProperties props = nic.GetIPProperties();
                if (props == null) continue;
                IPv4InterfaceProperties v4props = props.GetIPv4Properties();
                if (v4props == null) continue;
                if (!v4props.IsDhcpEnabled) continue;

                yield return nic;
            }
        }

        /// <summary>
        /// Requests DHCP parameter data.
        /// </summary>
        /// <remarks>
        /// Windows serves the data from a cache when possible.
        /// With persistent requests, the option is obtained during boot-time DHCP negotiation.
        /// </remarks>
        /// <param name="optionId">the option to obtain.</param>
        /// <param name="isVendorSpecific">indicates whether the option is vendor-specific.</param>
        /// <param name="persistent">indicates whether the request should be persistent.</param>
        /// <returns></returns>
        public byte[] DhcpRequestParams(string adapterName, uint optionId)
        {
            uint bufferSize = 1024;
        Retry:
            IntPtr buffer = Marshal.AllocHGlobal((int)bufferSize);
            try
            {
                NativeMethods.DHCPCAPI_PARAMS_ARRAY sendParams = new NativeMethods.DHCPCAPI_PARAMS_ARRAY();
                sendParams.nParams = 0;
                sendParams.Params = IntPtr.Zero;

                NativeMethods.DHCPCAPI_PARAMS recv = new NativeMethods.DHCPCAPI_PARAMS();
                recv.Flags = 0x0;
                recv.OptionId = optionId;
                recv.IsVendor = false;
                recv.Data = IntPtr.Zero;
                recv.nBytesData = 0;

                IntPtr recdParamsPtr = Marshal.AllocHGlobal(Marshal.SizeOf(recv));
                try
                {
                    Marshal.StructureToPtr(recv, recdParamsPtr, false);

                    NativeMethods.DHCPCAPI_PARAMS_ARRAY recdParams = new NativeMethods.DHCPCAPI_PARAMS_ARRAY();
                    recdParams.nParams = 1;
                    recdParams.Params = recdParamsPtr;

                    NativeMethods.DhcpRequestFlags flags = NativeMethods.DhcpRequestFlags.DHCPCAPI_REQUEST_SYNCHRONOUS;

                    int err = NativeMethods.DhcpRequestParams(
                        flags,
                        IntPtr.Zero,
                        adapterName,
                        IntPtr.Zero,
                        sendParams,
                        recdParams,
                        buffer,
                        ref bufferSize,
                        null);

                    if (err == NativeMethods.ERROR_MORE_DATA)
                    {
                        bufferSize *= 2;
                        goto Retry;
                    }

                    if (err != 0)
                        throw new Win32Exception(err);

                    recv = (NativeMethods.DHCPCAPI_PARAMS)
                        Marshal.PtrToStructure(recdParamsPtr, typeof(NativeMethods.DHCPCAPI_PARAMS));

                    if (recv.Data == IntPtr.Zero)
                        return null;

                    byte[] data = new byte[recv.nBytesData];
                    Marshal.Copy(recv.Data, data, 0, (int)recv.nBytesData);
                    return data;
                }
                finally
                {
                    Marshal.FreeHGlobal(recdParamsPtr);
                }
            }
            finally
            {
                Marshal.FreeHGlobal(buffer);
            }
        }

        ///// <summary>
        ///// Unregisters a persistent request.
        ///// </summary>
        //public void DhcpUndoRequestParams()
        //{
        //    int err = NativeMethods.DhcpUndoRequestParams(0, IntPtr.Zero, null, this.ApplicationID);
        //    if (err != 0)
        //        throw new Win32Exception(err);
        //}

        #region Native Methods
    }

    internal static partial class NativeMethods
    {
        public const uint ERROR_MORE_DATA = 124;

        [DllImport("dhcpcsvc.dll", EntryPoint = "DhcpRequestParams", CharSet = CharSet.Unicode, SetLastError = false)]
        public static extern int DhcpRequestParams(
            DhcpRequestFlags Flags,
            IntPtr Reserved,
            string AdapterName,
            IntPtr ClassId,
            DHCPCAPI_PARAMS_ARRAY SendParams,
            DHCPCAPI_PARAMS_ARRAY RecdParams,
            IntPtr Buffer,
            ref UInt32 pSize,
            string RequestIdStr
            );

        [DllImport("dhcpcsvc.dll", EntryPoint = "DhcpUndoRequestParams", CharSet = CharSet.Unicode, SetLastError = false)]
        public static extern int DhcpUndoRequestParams(
            uint Flags,
            IntPtr Reserved,
            string AdapterName,
            string RequestIdStr);

        [DllImport("dhcpcsvc.dll", EntryPoint = "DhcpCApiInitialize", CharSet = CharSet.Unicode, SetLastError = false)]
        public static extern int DhcpCApiInitialize(out uint Version);

        [DllImport("dhcpcsvc.dll", EntryPoint = "DhcpCApiCleanup", CharSet = CharSet.Unicode, SetLastError = false)]
        public static extern int DhcpCApiCleanup();

        [Flags]
        public enum DhcpRequestFlags : uint
        {
            DHCPCAPI_REQUEST_PERSISTENT = 0x01,
            DHCPCAPI_REQUEST_SYNCHRONOUS = 0x02,
            DHCPCAPI_REQUEST_ASYNCHRONOUS = 0x04,
            DHCPCAPI_REQUEST_CANCEL = 0x08,
            DHCPCAPI_REQUEST_MASK = 0x0F
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct DHCPCAPI_PARAMS_ARRAY
        {
            public UInt32 nParams;
            public IntPtr Params;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct DHCPCAPI_PARAMS
        {
            public UInt32 Flags;
            public UInt32 OptionId;
            [MarshalAs(UnmanagedType.Bool)]
            public bool IsVendor;
            public IntPtr Data;
            public UInt32 nBytesData;
        }
        #endregion
    }
}
"@

Add-Type -TypeDefinition $Source


	$Detected = $False

	[void][System.Reflection.Assembly]::LoadWithPartialName('System.ServiceProcess')

	$Vmbus = [System.ServiceProcess.ServiceController]::GetDevices() | Where-Object {$_.Name -eq 'vmbus'}

	If($Vmbus.Status -eq 'Running')
	{
		$Client = New-Object Microsoft.WindowsAzure.Internal.DhcpClient
		try {
			[Microsoft.WindowsAzure.Internal.DhcpClient]::GetDhcpInterfaces() | ForEach-Object {
				$Val = $Client.DhcpRequestParams($_.Id, 245)
				if($Val -And $Val.Length -eq 4) {
					$Detected = $True
				}
			}
		} finally {
			$Client.Dispose()
		}
	}
	return $Detected
}

Function Get-Space {
	<#
	.SYNOPSIS
		Get the space back in GB of the entered path

	.DESCRIPTION
		Returns used space in GB, or free space when -FreeSpace is set.
	.PARAMETER Path
		Local drive or UNC path to measure.
	.PARAMETER FreeSpace
		Return free space instead of used space.

	.EXAMPLE
		Get the used space in GB back
		Get-BISFSpace -path C:

	.EXAMPLE
		Get the free space in gb back
		Get-BISFSpace -Path \\PVS01\vDiskStore -FreeSpace

	.NOTES
		Author: Matthias Schlimm

		History:
		  03.10.2019 MS: function created
		  03.10.2019 MS: required for ENH 28 - Check if there's enough disk space on P2V Custom UNC-Path
		  27.12.2019 MS/MN: HF 160 - Calculation of free space for the VHDX file using [math]::round and PS-Drive

#>
	param (
		[parameter(Mandatory=$true)][string]$Path,
		[parameter(Mandatory=$false)][switch]$FreeSpace
	)


	IF ($Path -eq $env:SystemDrive) {
		$LocalSpace = Get-WmiObject Win32_Volume -Filter 'DriveLetter="C:"'| Select-Object Capacity,FreeSpace

		IF ($FreeSpace) {
			[int]$Space = [math]::Round((($LocalSpace.FreeSpace) / 1GB))
			Write-BISFLog -Msg "Free space for $Path is $Space GB"
		} ELSE {
			$UsedSpace = $LocalSpace.Capacity - $LocalSpace.FreeSpace
			[int]$Space = [math]::Round(($UsedSpace / 1GB))
			Write-BISFLog -Msg "Used space for $Path is $Space GB"
		}
	} ELSE {
		IF ($FreeSpace) {
			$FreeDrive =  Get-ChildItem function:[d-z]: -n | Where-Object{ !(test-path $_) } | Get-Random
			$DriveLetter = [string]$FreeDrive.Substring(0,1)
			$Drive = New-PSDrive -Name $DriveLetter -Root $Path -Persist -PSProvider FileSystem
			[int]$Space = [math]::Round((($Drive.free) / 1GB))
			$null = Remove-PSDrive -Name $DriveLetter
			Write-BISFLog -Msg "Free space for $Path is $Space GB"
		} ELSE {
			$ObjFSO = New-Object -com Scripting.FileSystemObject
			[int]$Space = [math]::Round((($ObjFSO.GetFolder($Path).Size) / 1GB))
			Write-BISFLog -Msg "Used space for $Path is $Space GB"
		}
	}
	return $Space
}

Function Get-CacheDiskID {
	<#
	.SYNOPSIS
		Get DiskID of the CacheDisk

	.DESCRIPTION
		It returns the BootDiskID, CacheDiskID
	.EXAMPLE
		$DiskIdentifier = Get-BISFCacheDiskID
		$BootDiskID = DiskIdentifier[0]
		$CacheDiskID = DiskIdentifier[1]
	.NOTES
		Author: Matthias Schlimm

		History:
		  05.10.2019 MS: function created
		  05.10.2019 MS: HF 22 - Endless Reboot with VMware Paravirtual SCSI disk need to get the DiskID
		  10.10.2019 MS: fixing error handling
		  08.01.2021 MS: HF 302 - using $DiskIdentifier instead DiskID, DiskID is for another Global variable
		  19.01.2021 MS: HF 302 - fixing BootDisk to get the correct DiskID (Line 4223 and 4230)

#>
	Write-BISFLog -Msg "Retrieving Disk ID's" -ShowConsole -Color Cyan
    try {
        [string]$BootDisk = (Get-WmiObject Win32_DiskPartition | Where-Object {$_.BootPartition -eq "true"}).DeviceID
    }
    catch {
        Write-BISFLog "BootDisk can't be retrieved from the System!" -ShowConsole -Type W
    }

    IF (-not [String]::IsNullOrEmpty($BootDisk)) {
        $BootDisk = ([regex]::matches($BootDisk, "Disk #\d")).value;$BootDisk = $BootDisk.Substring($BootDisk.length -1)
	    Write-BISFLog -Msg "BootDisk has Disk ID $BootDisk assigned" -ShowConsole -Color DarkCyan -SubMsg

	    $Disks = "list disk" | diskpart | where-Object {$_ -match "online"}
	    $i=0
	    ForEach ($Disk in $Disks) {
		    $i++
		    $OnlineDisk = $OnlineDisk + $i
		    $OnlineDisk = $Disk.split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
		    $GetID = $($OnlineDisk+$i)[1]
		    IF (!($GetID -eq $BootDisk)) {
			    Write-BISFLog -Msg "CacheDisk has DiskID $GetID"  -ShowConsole -Color DarkCyan -SubMsg
		    }
	    }
	    return $BootDisk,$GetID
    } ELSE {
        return $false,$false
    }

}

function Test-CitrixCloudConnector {
	<#
	.SYNOPSIS
		Detect the Services of the Citrix Cloud Connector like a Delivery Controller
	.DESCRIPTION
		BIS-F must prevent to run on a Citrix Cloud Connector
	.EXAMPLE
		Test-BISFCitrixCloudConnector
	.NOTES
		Author: Matthias Schlimm

		History:
		  08.10.2019 MS: function created
		  08.10.2019 MS: ENH 93 - Detect Citrix Cloud Connector installation and prevent BIS-F to run
#>
	$Services = @("CitrixHighAvailabilityService","CitrixConfigSyncService","CitrixWorkspaceCloudADProvider")

	ForEach ($Service in $Services) {
		$Svc = Test-BISFService -ServiceName $Service
		IF ($Svc) {
			Write-BISFLog -Msg "BIS-F can't run on machines holding roles such as Citrix Cloud Connector or Citrix Delivery Controller as part of the Vendor Best Practices, check out https://docs.citrix.com/en-us/citrix-cloud/citrix-cloud-resource-locations/citrix-cloud-connector/installation.html for more information" -Type E
		}

	}

}

function Show-SplashScreen {
	<#
	.SYNOPSIS
		Show a Fluent loading dialog when BIS-F starts
	.DESCRIPTION
		Displays a native WPF Fluent-style progress dialog (no third-party assemblies).
		The dialog is non-blocking; call Close-BISFSplashScreen when startup work is done.
	.EXAMPLE
		Show-BISFSplashScreen
		Initialize-BISFConfiguration
		Close-BISFSplashScreen
	.NOTES
		Author: Matthias Schlimm & Jonathan Pitre

		History:
		  10.10.2019 MS: function created
		  13.08.2026 JP: Replace MahApps.Metro splash with a native Fluent dialog
		  16.08.2026 JP: Fix typos and improve code readability
#>
	$ImageBase64 = "iVBORw0KGgoAAAANSUhEUgAAADcAAAA3CAYAAACo29JGAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsQAAA7EAZUrDhsAAAtdSURBVGhD3Vp5cJxlHX72SHaTbLY5mzRpm9aUphe1UFqggxwNioq1qFMUUEccRhQYZcaiDoNDHQYRYWQcZJxxZERRoDOggNBKQagzFZEWWir0btOSpiXk3s0m2dvneff7tps0x26uP/q03+x+x/t+v+f93e/G8fAHbcnjvRHs6ujHuQCHA/hsjQ9FbhcMuR+/e9q6de7gwQtnwVG5+YNkZyRuXTp30DjLB2fSOjnXkCQxJ030nIR8z2l9PycxbeTitJN4gsc0+sG0kIuTkT/PhfrifBS4HIbkdGDKyYnY6gov3m6cjT2fmYPtV9ZgflEepoPflJITgTyGrAeXl6PBn8eXkWhlATYt9iMZjfJsasPZpJKTMjIVkuQ/X74TdYVuRKhBkZUmF/rccAwEkUwov6YI6l7m2MnApJGT0AlK6DHJZbBGeGsQzHksCvR2kREJMm576YsJ3phMf5wwOaONaAKryr146fIaXFIQRTwSSSWa0aD7MRILdiMejuJLs33YfNks1PvyzHyTQXFC5MwqM8TfsagUr15Rg2tnF8EZj1EjPbzJz2wIWs97kcD184vxxlW1+Oq8YiRiKTOeCMZNTsTcFO63F83EoysrjFlFtOIZAvOhLDUYQaI/BESTqPa48MyaatyzrIw+OTGC4yKnF2rg71bNxK0L/AhFEohlSpEmSJ+Kp3xqdJy5H+Y8/bEE7ju/DJuWltIlx2+iOZPTi5KJBO5fXoGbP1FsiJlrPBT23Xa1ahMMUYNJanAMaKy9CAo4fSR47/nluLXehwQtYjzImZxetGFuMX6yuAR9luPrKGIFcjIUQVNgAA6boDSSIMGxbIvP7+/qRygah8elbJgaEibLX66oxHIfoyjJ5oqcyCnUVzBn/WxpmTFDW+ZCtxMHu/uxfusBHKaQzjQ5IfP78HBx/I5TPfjyKwfQGY5Z6YQuyBcU5+fhkQur4ImEGHJyQ07k5ODfXzgDi0vyMWAlL5lhiBr8xuuHsbs1YAQdDzRuW1MH7thxjIp0pHsxaXPtnFLcMNeHZE932nSzQdaSiEuJ142v0yQjDNM2ZEZ3/fcEdp0msXy3dXV8cHncePZQGx7aewqFNHMbCfr4txZVwRkLIxkKZE0w+2Vm1FpbVYA6Fr0yF6GAq/1WaxCP72+FI0OYCYFz/orkPgyGU0GGGKC/rar0YWWVH4kQU0aWBLMil6LiwHU1TNKc09abiydPHPqYFUV80lp6zdlOYk8faYfHMnH5WmGeE+vqSlIvD/enCI7hz1mRk6KKvS6sKvOYAljQqrb0RvDCceaycfrZiODcTx9tR2/kzKIpmF1W7YeTJE2hIIJ9oxPMTipOPLfAjRr6XEw7L0Q+37q7PYTWUHhIdBwMPe0aYkJDz4fCQT8+wKh7uGeA70mJKFeYX+xFqZe9oFY7k+AI82VHjnNVU3OFLLEsbiaX7e/uM5FmJFFFOjgQwz4+l89gI2276Ju72ntZeSRHNGVdD9PUjzJn2kWB+PjzXSjhkfYLm+AIPpilPSVN7cgFTc8rfNzPtmUU6HXylzvfbMK2E51oJdGnDnyMe3c2w8n5RgVXsTvCAiADEjYVZDKkGETQumYhS3LWdJnMCMcI5pAJae9I9wCu2bIPFzy7Bzf985BJ1NmMHfaRITIYpAkGBw3KmpySttJb5vuqCvIGXxgBLmpJ/zqpOZFVRBwTFLJkSN7UDlrE+MUw49MEz5hoduQozOmBOPrkX9a8qoUXlxZKNcMu5lCIj0gNI9ZZSJCAl761wO9N51SND9APu8PqMsyls2ETtKJoduQ4qLkvipb+GPIsdmFWDReUF6LGl5+KXpMIBZulXLgFMwpILlVRyteOBsLoGoiOGp0NwQESZH+YFTn5fi9XbGcnqwYrEKhwnlWUj/XzynRirk0aOPfXFlSw03CaKCmI0I6PAkjyXaNQS0EE2QBn7XPCX1t60y8TRPDmhplwM7zLlCYDcZZ5VTTHG+srELYWTYpSAf3iCRYMY0VZGySYPTnmge1tAzjWG023JHr5Raz5bltWjeQ4G8pMmOXhgv3okzWooVUMrmF78V5bLzWYvchZP6kFC9DnnjwRRJ47RU6vDnOlf766DpfWzkB8SF7KFQmmiBsaqnDn8hp24trTVFiQEhz4A2vYBN9luXxWyMksHVzBXx/qxt6uiNnzF2SaKsWevnohLqkhQQqYq4WaH0k4bv15lXjssvmIkoRt/urwt37Yhc2H2+B059Z55ERO1tjDlPDT9zvS58IAhZlDM3rumkW4nj6o/kvbAmNxFAF1FMpmt6+oxZ/XngcfyUQsZlo0Jfwf/uc4YhlpKFvkRE5wMYK92NyL+/Z3me0FvU9HiGQq2Gxu/nQDnrq6ASvoi2YHmZW9CChQpA+d8zorVVxeW4Itn1+C33yq3hTUMnPNp+9u+tdGEtvfFhpXhz+u38Rldsptj62sxG0LtVEUT5uRBJMp9XDOdxgA3jjVg138bOmLmHbJSyHrijy4tKoYV9T4saK8yNStWhwb2g9VEr/rzeN4+B3Wofyeo9LQOKds/D/4U064yfKB5WXYuKjMmJJtToL2QSS08pN+R5DwapdkatK4uc7npamMYRzjNM/d/faHeGRPCwtsWkeuzAiRy13XFhRPYnzrXbs7cMtbLQgwUvq4wrYfKu9p71ENp3xSVlVAQXVfm666rk+bmMzQx1qyORTBhlcP4pF31TmMj5iNcZMTRFCd8eNNIazZcgS/3/eR0ZhIeqQ1SzDJLxKKivq0FaX70pRISYMP7j6JNX/bi5eOdZjNpokQEybn71AoRVx5qTeAi8vycMuSarMlMJd1Z6HCt4S0GQnWeZDvbQoO4LWWHjx+oBX7GDik4qy6hjEwIZ87CySYlGYC3aZw9RXkY1FpAYtrHwtgD4oZZAQ+YprQgz0D2MOOXJ9hhnup0UUtThYml1wm2FPF1XooANpOlakMXdK5NCRSE7W/YTChgDIyKGiRHy5vgWlSXfQ/c1Bz6cM+tzSlqGkftvWac6lZ3/lp8qO9UBnQpczx9hhhCshpchIs9LPE8KbscBTMYOCYTd+sK/ZgZqG1s8X/5V43/HluQ0od+erqYtTyOZ1nQulGrddcjp+nObQ7YMFVtOH2Tf1KWlOBfA8FpcnH6FPDmJ4qlV9eWoeHLq7DWib07zIQzfF58Bpryb+wVq0gwW66zPPXNOCqWX5sZLcgWXd+FEzlSY6/ek4Jtn1ukbl/A3vAWhJ9hePrSwqnQnNDMIYGZ3rz8HJzF656bi/u2dWMmyigtgGLlOh5f928UvPchq0HsPGtE5hN4R3UlhQsDasgUOVz7baDWP38/8wctrlPPTmBPjgSwSBXf/3cUmxZtxSPrpmH55o6Ee6PmHv5FPKZw+1mv/L9Gy/EV+aX4YlDbWb/xrYDVUUzPC786Yp6vEQNr65kTWuVctNDThBBz9kE1fjuag/h4fdO4e6dzWis9WPxzGKT1EVOgn5h60F8+/UjjKpObG48Dw1MMf9atwTbr1uGhezau5lKXmCX/szRDpwMhdM/fk4fOUEmOoSgfgJTx32aZVdrX5Stkwd+dhfaaRbBH1xQi4cuqcO+jl78uzWAct4L0A/v392CB949iS7mTDWzf6SGn9zfiqZABrmpiiUjomgGGRUYghLqvc4Q6hhEHrtyATatnI37WSy/fSpgdrpa+6P4BUlI1pe/uAzfZDP7vR1NON0bxj+oqVeOd+JYMGx+s1DzrJ/R7OpGKcHRuO1ocnsry57pRl/Q7DHqFxuJo8P8yMLVdqrKtq7ZuU3a1NZDjGY6tJLREylKZ/CdZbWpP+D++8kA9Bfq047+IJKRsJW4LZKWlMZy+V2n+qouQ09YiklD9/Rs5vUlZUVoXDAb/wc+qzTiGCzF6QAAAABJRU5ErkJggg=="

	if ($null -ne $Script:BisfSplash) {
		Close-BISFSplashScreen
	}

	$Version = $null
	if ($null -ne $MainModuleName) {
		$LoadedModule = Get-Module -Name $MainModuleName -ErrorAction SilentlyContinue
		if ($null -ne $LoadedModule) {
			$Version = $LoadedModule.Version.ToString()
		}
	}

	$DarkMode = $false
	try {
		$Personalize = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme -ErrorAction Stop
		$DarkMode = ([int]$Personalize.AppsUseLightTheme -eq 0)
	} catch {
		$DarkMode = $false
	}

	$AccentHex = '#FF0078D4'
	try {
		$AccentRaw = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\DWM' -Name AccentColor -ErrorAction Stop).AccentColor
		$AccentBytes = [BitConverter]::GetBytes([int]$AccentRaw)
		$AccentAlpha = $AccentBytes[3]
		if ($AccentAlpha -eq 0) { $AccentAlpha = 255 }
		$AccentHex = '#{0:X2}{1:X2}{2:X2}{3:X2}' -f $AccentAlpha, $AccentBytes[0], $AccentBytes[1], $AccentBytes[2]
	} catch {
		$AccentHex = '#FF0078D4'
	}

	if ($DarkMode) {
		$Theme = @{
			Card          = '#E82C2C2C'
			TextPrimary   = '#FFFFFFFF'
			TextSecondary = '#FFC5C5C5'
			Track         = '#33FFFFFF'
			Accent        = $AccentHex
			Shadow        = '#AA000000'
		}
	} else {
		$Theme = @{
			Card          = '#F3FFFFFF'
			TextPrimary   = '#FF1A1A1A'
			TextSecondary = '#FF5C5C5C'
			Track         = '#1A000000'
			Accent        = $AccentHex
			Shadow        = '#66000000'
		}
	}

	try {
		Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
	} catch {
		return
	}

	try {
		$Image = New-Object System.Windows.Media.Imaging.BitmapImage
		$Image.BeginInit()
		$Image.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($ImageBase64)
		$Image.EndInit()
		$Image.Freeze()
	} catch {
		$Image = $null
	}

	$Hash = [hashtable]::Synchronized(@{})
	$Runspace = $null
	$PwshShell = $null
	try {
	$Runspace = [RunspaceFactory]::CreateRunspace()
	$Runspace.ApartmentState = 'STA'
	$Runspace.ThreadOptions = 'ReuseThread'
	$Runspace.Open()
	$Runspace.SessionStateProxy.SetVariable('Hash', $Hash)
	$Runspace.SessionStateProxy.SetVariable('Version', $Version)
	$Runspace.SessionStateProxy.SetVariable('Logo', $Image)
	$Runspace.SessionStateProxy.SetVariable('Theme', $Theme)

	$PwshShell = [PowerShell]::Create()
	$PwshShell.Runspace = $Runspace
	$null = $PwshShell.AddScript({
		try {
		Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

		$Xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="WindowSplash"
        Title="Base Image Script Framework"
        WindowStyle="None"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize"
        ShowInTaskbar="False"
        AllowsTransparency="True"
        Background="Transparent"
        SizeToContent="WidthAndHeight"
        Topmost="True"
        SnapsToDevicePixels="True"
        UseLayoutRounding="True">
  <Border x:Name="DialogCard" CornerRadius="8" Padding="24,20" Width="448" Margin="24">
    <Border.Effect>
      <DropShadowEffect x:Name="DialogShadow" BlurRadius="28" ShadowDepth="6" Direction="270" Opacity="0.35"/>
    </Border.Effect>
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="16"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="14"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <Grid Grid.Row="0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <Border x:Name="LogoPlate" Width="40" Height="40" CornerRadius="8" Margin="0,0,14,0">
          <Image x:Name="Logo" Width="28" Height="28" RenderOptions.BitmapScalingMode="HighQuality"/>
        </Border>
        <StackPanel Grid.Column="1" VerticalAlignment="Center">
          <TextBlock x:Name="Title" FontSize="16" FontWeight="SemiBold"
                     FontFamily="Segoe UI Variable Display, Segoe UI" TextWrapping="Wrap"/>
          <TextBlock x:Name="Subtitle" FontSize="12" Margin="0,2,0,0"
                     FontFamily="Segoe UI Variable Text, Segoe UI"/>
        </StackPanel>
      </Grid>
      <TextBlock x:Name="LoadingLabel" Grid.Row="2" FontSize="14"
                 FontFamily="Segoe UI Variable Text, Segoe UI"/>
      <ProgressBar x:Name="Progress" Grid.Row="4" Height="4" Minimum="0" Maximum="100"
                   IsIndeterminate="True" BorderThickness="0">
        <ProgressBar.Template>
          <ControlTemplate TargetType="ProgressBar">
            <Border x:Name="Track" Height="4" CornerRadius="2" ClipToBounds="True"
                    Background="{TemplateBinding Background}">
              <Border x:Name="Indicator" Width="96" Height="4" CornerRadius="2" HorizontalAlignment="Left"
                      Background="{TemplateBinding Foreground}">
                <Border.RenderTransform>
                  <TranslateTransform x:Name="IndicatorTransform" X="-96"/>
                </Border.RenderTransform>
              </Border>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsIndeterminate" Value="True">
                <Trigger.EnterActions>
                  <BeginStoryboard>
                    <Storyboard RepeatBehavior="Forever">
                      <DoubleAnimation Storyboard.TargetName="IndicatorTransform"
                                       Storyboard.TargetProperty="X"
                                       From="-96" To="448" Duration="0:0:1.6"/>
                    </Storyboard>
                  </BeginStoryboard>
                </Trigger.EnterActions>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </ProgressBar.Template>
      </ProgressBar>
    </Grid>
  </Border>
</Window>
'@

		$Xml = [xml]$Xaml
		$Reader = New-Object System.Xml.XmlNodeReader $Xml
		$Hash.window = [Windows.Markup.XamlReader]::Load($Reader)
		$Hash.LoadingLabel = $Hash.window.FindName('LoadingLabel')
		$Hash.Logo = $Hash.window.FindName('Logo')
		$Hash.Title = $Hash.window.FindName('Title')
		$Hash.Subtitle = $Hash.window.FindName('Subtitle')
		$Hash.Progress = $Hash.window.FindName('Progress')
		$Hash.DialogCard = $Hash.window.FindName('DialogCard')
		$Hash.DialogShadow = $Hash.window.FindName('DialogShadow')
		$Hash.LogoPlate = $Hash.window.FindName('LogoPlate')

		$BrushConverter = New-Object System.Windows.Media.BrushConverter
		$ColorConverter = New-Object System.Windows.Media.ColorConverter
		$Hash.DialogCard.Background = $BrushConverter.ConvertFromString($Theme.Card)
		$Hash.Title.Foreground = $BrushConverter.ConvertFromString($Theme.TextPrimary)
		$Hash.Subtitle.Foreground = $BrushConverter.ConvertFromString($Theme.TextSecondary)
		$Hash.LoadingLabel.Foreground = $BrushConverter.ConvertFromString($Theme.TextPrimary)
		$Hash.Progress.Foreground = $BrushConverter.ConvertFromString($Theme.Accent)
		$Hash.Progress.Background = $BrushConverter.ConvertFromString($Theme.Track)
		$Hash.DialogShadow.Color = $ColorConverter.ConvertFromString($Theme.Shadow)
		$AccentColor = $ColorConverter.ConvertFromString($Theme.Accent)
		$Hash.LogoPlate.Background = New-Object System.Windows.Media.SolidColorBrush (
			[System.Windows.Media.Color]::FromArgb(26, $AccentColor.R, $AccentColor.G, $AccentColor.B)
		)

		if ($null -ne $Logo) {
			$Hash.Logo.Source = $Logo
		}
		$Hash.Title.Text = 'Base Image Script Framework'
		if ([string]::IsNullOrEmpty($Version)) {
			$Hash.Subtitle.Text = 'BIS-F'
		} else {
			$Hash.Subtitle.Text = "Version $Version"
		}
		$Hash.LoadingLabel.Text = 'Loading - please wait'

		$CloseTimer = New-Object System.Windows.Threading.DispatcherTimer
		$CloseTimer.Interval = [TimeSpan]::FromSeconds(60)
		$CloseTimer.Add_Tick({ $Hash.window.Close() })
		$CloseTimer.Start()

		$Hash.window.ShowDialog()
		} catch {
			$Hash.Error = $_.Exception.Message
		}
	})

	$Script:BisfSplash = @{
		Hash       = $Hash
		PowerShell = $PwshShell
		Runspace   = $Runspace
		Handle     = $PwshShell.BeginInvoke()
	}
} catch {
	Write-Verbose "Fluent splash skipped: $($_.Exception.Message)"
	if ($null -ne $PwshShell) {
		try { $PwshShell.Dispose() } catch { Write-Verbose $_.Exception.Message }
	}
	if ($null -ne $Runspace) {
		try { $Runspace.Close(); $Runspace.Dispose() } catch { Write-Verbose $_.Exception.Message }
	}
	$Script:BisfSplash = $null
}
}

function Close-SplashScreen {
	<#
	.SYNOPSIS
		Close the Fluent BIS-F loading dialog
	.DESCRIPTION
		Closes the dialog started by Show-BISFSplashScreen and releases its runspace.
		Safe to call when no dialog is open.
	.EXAMPLE
		Close-BISFSplashScreen
	.NOTES
		Author: Jonathan Pitre

		History:
		  13.08.2026 JP: function created
#>

	if ($null -eq $Script:BisfSplash) {
		return
	}

	$Splash = $Script:BisfSplash
	$Script:BisfSplash = $null

	$WaitedMs = 0
	while ($null -eq $Splash.Hash.window -and $WaitedMs -lt 5000) {
		Start-Sleep -Milliseconds 50
		$WaitedMs += 50
	}

	try {
		$Window = $Splash.Hash.window
		if ($null -ne $Window) {
			$Window.Dispatcher.Invoke([action]{ $Window.Close() })
		}
	} catch {
		Write-Verbose "Splash close skipped: $($_.Exception.Message)"
	}

	if ($null -ne $Splash.Handle) {
		$Completed = $false
		try {
			$Completed = $Splash.Handle.AsyncWaitHandle.WaitOne(3000)
		} catch {
			Write-Verbose "Splash wait skipped: $($_.Exception.Message)"
		}
		if ($Completed) {
			try {
				$null = $Splash.PowerShell.EndInvoke($Splash.Handle)
			} catch {
				Write-Verbose "Splash runspace end skipped: $($_.Exception.Message)"
			}
		} else {
			try {
				$Splash.PowerShell.Stop()
			} catch {
				Write-Verbose "Splash runspace stop skipped: $($_.Exception.Message)"
			}
		}
	}

	try {
		$Splash.PowerShell.Dispose()
	} catch {
		Write-Verbose "Splash PowerShell dispose skipped: $($_.Exception.Message)"
	}
	try {
		$Splash.Runspace.Close()
		$Splash.Runspace.Dispose()
	} catch {
		Write-Verbose "Splash runspace dispose skipped: $($_.Exception.Message)"
	}
}

function Get-PVSWriteCacheType {
	<#
	.SYNOPSIS
		Read the PVS WriteCacheType from the Registry
	.DESCRIPTION
		Send the PVS WriteCacheValue back to the caller
	.EXAMPLE
		$WriteCacheType = Get-BISFPVSWriteCacheType

	.NOTES
		Author: Matthias Schlimm

		History:
		  23.05.2020 MS: function created

#>

	# Check for Cache on Device hard drive Mode
	$WriteCacheType = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\bnistack\PVSAgent).WriteCacheType
	Switch ($WriteCacheType) {
		0 {$WriteCacheTypeTxt = "Private"}
		1 {$WriteCacheTypeTxt = "Cache on Server"}
		3 {$WriteCacheTypeTxt = "Cache in Device RAM"}
		4 {$WriteCacheTypeTxt = "Cache on Device Hard Disk"}
		7 {$WriteCacheTypeTxt = "Cache on Server, Persistent"}
		9 {$WriteCacheTypeTxt = "Cache in Device RAM with Overflow on Hard Disk"}
		10 {$WriteCacheTypeTxt = "Private async"}
		11 {$WriteCacheTypeTxt = "Server persistent async"}
		12 {$WriteCacheTypeTxt = "Cache in Device RAM with Overflow on Hard Disk async"}
		default {$WriteCacheTypeTxt = "WriteCacheType $WriteCacheType not defined !!"; $WriteCacheType  = -1}
	}
	Write-BISFLog -Msg "PVS WriteCacheType is set to $WriteCacheType - $WriteCacheTypeTxt"
	return $WriteCacheType
}

function Get-DSRegState {
	<#
	.SYNOPSIS
		Return one value from dsregcmd /status
	.DESCRIPTION
		Runs dsregcmd /status and returns the trimmed value for a single key, such as AzureAdJoined,
		DomainJoined, or AzureAdPrt. Full dsregcmd output lists many keys; this helper is for automation
		when only one field is needed.
	.PARAMETER Key
		Name of the dsregcmd /status field to return, for example AzureAdJoined.
	.EXAMPLE
		$DSRegValue = Get-BISFDSRegState -Key "AzureAdJoined"
	.NOTES
		Author: Matthias Schlimm

		History:
		  21.11.2020 MS: HF 285 - function created
	#>
	param(
		[Parameter(Mandatory = $true)]
		[String]$Key
	)


	Write-BISFLog -Msg "Checking DSRegcmd State" -ShowConsole -Color Cyan
	$ValueData = ((dsregcmd /status | select-string -pattern $Key) -split(":") | select-object -last 1).trim()
	Write-BISFLog -Msg "$Key : $ValueData" -ShowConsole -Color DarkCyan -SubMsg
	return $ValueData
}

Function Test-AccessValidated {
	<#
	.SYNOPSIS
		Validate access to the WriteCache disk
	.DESCRIPTION
	  	Does a basic test to validate access to the WriteCache disk
	.PARAMETER Folder
		Path to test, typically the write cache drive root.
	.EXAMPLE
		IsAccessAllowed = Test-BISFAccessValidated -Folder "$PVSDiskDrive\"
	.EXAMPLE
		IF ((Test-BISFAccessValidated -Folder "$PVSDiskDrive\") -eq $False) { #code for $false value } else { #code for $true value }
	.NOTES
		Author: Jeremy Saunders

		History:
	  	22.12.2020 JS: HD 302 - function created
	.LINK
		https://www.jhouseconsulting.com
	#>
	param(
		[string]$Folder
	)
	If (TEST-PATH $Folder) {
		Write-BISFLog -Msg "Testing access to the WriteCache disk ($Folder)" -ShowConsole -SubMsg -Color DarkCyan
		Get-ChildItem -path $Folder -EA SilentlyContinue -ErrorVariable ErrVar
		# The -ErrorVariable common parameter creates an ArrayList. This variable always initialized,
		# which means it will never be $null. The proper way to test if an ArrayList is empty or not
		# is to use the Count property. It should be empty or equal to 0 if there are no errors.
		If ($ErrVar.count -eq 0) {
			Write-BISFLog -Msg "Access to the WriteCache disk is good" -ShowConsole -SubMsg -Color DarkCyan
			$Return = $True
		}
		Else {
			Write-BISFLog -Msg "Access to WriteCache disk is denied" -ShowConsole -SubMsg -Color DarkCyan
			$Return = $False
		}
	}
 Else {
		Write-BISFLog -Msg "The WriteCache disk ($Folder) does not exist" -ShowConsole -SubMsg -Color DarkCyan
		$Return = $False
	}
	return $Return
}