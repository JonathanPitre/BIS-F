[CmdletBinding(SupportsShouldProcess = $true)]
param(
)
<#
	.SYNOPSIS
		Build vDisk for Citrix Provisioning
	.DESCRIPTION
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
		Editor: Mike Bijl (Rewritten variable names and script format)

		History:
		27.09.2012 MS: Script created
		17.10.2012 MS: Write-BISFLog TGTOPT disabled: TargetDeviceOptimizer, Values Write via GPO
		27.02.2013 MS: Write-BISFLog CheckvDisk: check if personality file exists.
		28.02.2013 MS: Remove-Item $P2PVS_LOGFile -recurse -ErrorAction SilentlyContinue
		27.08.2013 MS: Read WriteCacheType from PVSAgent, to identify the vDisk access
		12.09.2013 MS: Add progress bar during P2PVS
		16.09.2013 MS: check personality.ini if Device boot up from hardDisk or vDisk
		17.09.2013 MS: increase Wait to 20 seconds to identify the destination disk
		18.09.2013 MS: replace $date with $(Get-date) to get current timestamp at running script lines write to the log file
		18.09.2013 MS: ADD $Global:CheckP2PVSlog
		29.01.2014 MS: remove error handling for access rights to vDisk
		10.03.2014 MS: Change progress bar for PVS7.1 / only activity no real disk space
		18.03.2014 BR: revisited Script
		02.04.2014 MS: add TargetOSOptimizer.exe if boot from hard drive only
		13.05.2014 MS: TargetOSOptimizer.exe running silent, Line 83
		11.08.2014 MS: remove Write-Host change to Write-BISFLog
		13.08.2014 MS: remove $LogFile = Set-LogFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
		13.08.2014 MS: add IF ($returnTestPVSSoftware -eq "true") to build vDisk
		18.08.2014 MS: change check personality.ini for XenApp/XenDesktop 7.5
		19.08.2014 MS: move progress bar Write-BISFLog to central Write-BISFLogs
		20.08.2014 MS: add and use XenConvert to reduce vDisk storage, older technology but do not capture free space of the Base-Image. If XenConvert not exist, P2PVS that comes with PVS71 would be used
		15.09.2014 MS: remove XenConvert from Tools folder... to longer use you must install XenConvert on your base image in "C:\Program Files\Citrix\XenConvert"
		15.09.2014 MS: use CLI Switch LIC_PVS_CLI_PT use P2PVS instead of XenConvert if installed
		16.09.2014 MS: add CheckPvdLog to run directly after PVD Inventory Update
		31.10.2014 MB: Renamed Write-BISFLog progress bar to Show-ProgressBar
		18.05.2015 MS: Bug 43: wrong CLI variable for P2PVS -> Line 150 must be changed from $LIC_PVS_CLI_PT to $LIC_BISF_CLI_PT
		18.05.2015 MS: add CLI Switch VERYSILENT handling
		02.06.2015 MS: Line 152: check ($LIC_BISF_CLI_PT -eq $false) if set with CLI Command to get from registry
		07.08.2015 MS: script is looking in the wrong path for XenConvert, use new variable $PVSToolPath to define the correct path
		10.08.2015 MS: Bug 52: changing code for P2PVS or XenConvert Log file detection, looking in all paths and deleted older files
		11.08.2015 MS: log file Check and P2PVS Tool would only be checked if boot up from local hard drive
		12.08.2015 MS: separate Write-BISFLog Get-p2pvsLog to get P2PVS or XenConvert log file
		01.10.2015 MS: rewritten script to use central BIS-F
		06.03.2017 MS: Fixed read Variable $varCLI = ...
		12.03.2016 MS: move $Pvd_LOGFile_search="Update Inventory completed" from 99_PrepBISF_PostBaseImage.ps1 to this script, thx to Mathias Kowalkowski
		22.03.2017 MS: Fixed to read the right State from personality.ini if used VDA with PVS
		22.03.2017 MS: for P2PVS reconfigure Microsoft Software Shadow Copy Provider Service and VSS Service, needed them for P2PVS
		14.06.2017 MS: Running ImagingWizard instead of P2PVS to support UEFI Boot
		14.06.2017 MS: Stopping Shell Hardware Detection Service before ImagingWizard/XenConvert is starting, message box to format the disk suppressed now
		14.06.2017 MS: If Citrix AppLayering and PVS Target Device Driver installed, skip vDisk Operations
		02.08.2017 MS: Removing XenConvert completely and using settings from new ADMX to choose ImagingWizard or P2PVS
		02.08.2017 MS: IF ADMX for custom UNC-Path is enabled, the arguments for the P2V Tool must be changed, this vDisk Mode must not being checked
		03.08.2017 MS: Get-BISFBootMode get back UEFI or Legacy to using different command line switches for ImagingWizard or P2PVS
		03.08.2017 MS: Automatic fallback to ImagingWizard with UEFI BootMode, if P2PVS in ADMX is selected
		25.08.2017 MS: Fixed - P2V with UNC Path failed with space is in UNC Path
		25.08.2017 MS: Fixed - VHDX on UNC-Path would be created with double .vdhx extension
		06.09.2017 MS: Feature: Using custom arguments from PVS Target Configuration if enabled
		17.09.2017 MS: Fixed 212 - If Custom UNC-Path in ADMX is selected, and booting up a PVS avhd/avhdx, imaging wizard/P2PVS would be executed
		17.10.2017 MS: Feature: ADM extension PVS Target Device: select vDisk Type VHDX/VHD that can be using for P2PVS only, thx to Christian Schuessler
		29.10.2017 MS: Fixed: Custom UNC-Path get the wrong value back and does not perform a defrag on the vhd(x) and set the right value now $Global:TestDiskMode
		14.08.2019 MS: FRQ 3 - Remove message box and using default setting if GPO is not configured
		23.12.2019 MS: ENH 98 - Skip execution of PVS Target OS Optimization
		18.02.2020 JK: Fixed Log output spelling
		01.08.2020 MS: HF 262 - UPL + PVS Target Device Driver doesn't convert VHDX

#>

Begin {

	####################################################################
	# define environment
	# Setting default variables ($PSScriptRoot/$LogFile/$PSCommand,$PSScriptFullname/$ScriptLibrary/LogFileName) independent on running script from console or ISE and the powershell version.
	If ($($host.name) -like "* ISE *") {
		# Running script from Windows Powershell ISE
		$PSScriptFullName = $psISE.CurrentFile.FullPath.ToLower()
		$PSCommand = (Get-PSCallStack).InvocationInfo.MyCommand.Definition
	}
	ELSE {
		$PSScriptFullName = $MyInvocation.MyCommand.Definition.ToLower()
		$PSCommand = $MyInvocation.Line
	}
	[string]$PSScriptName = (Split-Path $PSScriptFullName -leaf).ToLower()
	If (($PSScriptRoot -eq "") -or ($PSScriptRoot -eq $null)) { [string]$PSScriptRoot = (Split-Path $PSScriptFullName).ToLower() }

	$SystemDrive = $env:SystemDrive
	$PVSPath = "$env:ProgramFiles\Citrix\Provisioning Services"
	$Global:PvdLogFile = "$env:ALLUSERSPROFILE\Citrix\personal vDisk\LOGS\PvDSvc.log.txt"
	$PvdLogFileSearch = "Update Inventory completed"
	$PersonalityFile = "$env:SystemDrive\Personality.ini"
	$PersonalitySearch1 = "_DiskMode=P"
	$PersonalitySearch2 = "=Private"
	$PersonalitySearch3 = "DiskMode=S"
	$VDiskMode = ""
	####################################################################

	####################################################################
	####### Write-BISFLogs #####

	####################################################################
	# write vDisk
	function Test-BootMode {
		if ((Test-Path -Path $PersonalityFile) -eq $true) {
			IF ($ReturnTestXDSoftware -eq "true") {
				Write-BISFLog -Msg "Start $PersonalityFile for Citrix Desktop Agent"
				Write-BISFLog -Msg "Search for $PersonalitySearch2"
				$Sel2 = Select-String -Pattern "$PersonalitySearch2" -Path $PersonalityFile
				If (!($null -eq $Sel2)) {
					Write-BISFLog -Msg "Boot from HardDisk"
					$VDiskMode = "HD"
					return $VDiskMode
				}
				$Sel3 = Select-String -Pattern $PersonalitySearch3 -Path $PersonalityFile
				If (!($null -eq $Sel3)) {
					$VDiskMode = $null
					Write-BISFLog -Msg "vDisk in Shared Mode - READ Access only!"
					$VDiskMode = "S"
					return $VDiskMode
				}
				ELSE {
					Write-BISFLog -Msg "vDisk in Private Mode"
					$VDiskMode = "P"
					return $VDiskMode
				}
			}
			ELSE {
				Write-BISFLog -Msg "Start $PersonalityFile for Citrix Provisioning Services"
				Write-BISFLog -Msg "Search for $PersonalitySearch1"
				$Sel1 = Select-String -Pattern "$PersonalitySearch1" -Path $PersonalityFile
				$Sel2 = Select-String -Pattern "$PersonalitySearch2" -Path $PersonalityFile
				If (!($null -eq $Sel1) -or (!($null -eq $Sel2))) {
					Write-BISFLog -Msg "vDisk in Private Mode"
					$VDiskMode = "P"
					return $VDiskMode
				}
				ELSE {
					Write-BISFLog -Msg "vDisk in Shared Mode - READ Access only!"
					$VDiskMode = "S"
					return $VDiskMode
				}
			}

		}
		ELSE {
			Write-BISFLog -Msg "$PersonalityFile not found, Device booting from HardDisk"
			$VDiskMode = "HD"
			return $VDiskMode
		}
	}
	####################################################################

	####################################################################
	### P2PVS
	function Start-P2PVS {
		<#
		.SYNOPSIS
		Starting the conversion for Citrix Provisioning Services

		.DESCRIPTION
		If the PVS Target Device software is installed, this will convert the hard drive C
		to the attached vDisk

		.EXAMPLE
		Start-P2PVS

		.NOTES
		Author: Matthias Schlimm

		History:
			14.08.2019 MS: ENH 98 - Skip execution of PVS Target OS Optimization

		#>


		$P2PVSTool = "$PVSToolPath\$PVSTool.exe"
		Write-BISFLog -Msg "Check Microsoft Software Shadow Copy Provider Service is running, needed for $PVSTool"
		Invoke-BISFService -ServiceName swprv -StartType manual -Action Start
		Restart-Service swprv | Out-Null
		Write-BISFLog -Msg "Check Volume Shadow Copy Service is running, needed for $PVSTool"
		Invoke-BISFService -ServiceName vss -StartType manual -Action Start
		Restart-Service vss | Out-Null
		Write-BISFLog -Msg "Stopping Shell Hardware Detection Service before $PVSTool is starting"
		Invoke-BISFService -ServiceName ShellHWDetection -Action Stop
		Start-Sleep $Wait1
		Write-BISFLog -Msg "Run start-process $P2PVSTool -ArgumentList '$PVSToolArgs' "
		Write-BISFLog -Msg "Running $P2PVSTool to convert HardDisk to vDisk now" -ShowConsole -Color DarkCyan -SubMsg
		Start-Process $P2PVSTool -ArgumentList "$($PVSToolArgs)"
	}
	####################################################################

	####################################################################
	### Set the P2PTool (IMagingWizard, P2PVS or custom UNC-Path)
	function Set-P2VTool {
		#02.08.2017 MS: using ImagingWizard or P2PVS based on ADMX
		IF (($LIC_BISF_CLI_PT -eq "P2PVS") -and ($BootMode -eq "UEFI")) {
			# automatic Fallback if P2PVS in ADMX is selected and UEFI BootMode was detected
			$LIC_BISF_CLI_PT = "ImagingWizard"
			Write-BISFLog -Msg "You have P2PVS in ADMX selected, but for $BootMode you must have $($LIC_BISF_CLI_PT). BIS-F will automatic fallback to $LIC_BISF_CLI_PT" -ShowConsole -SubMsg -Color DarkCyan -Type W
		}

		IF ($LIC_BISF_CLI_P2V_CUS_ARGS -eq "1") { Write-BISFLog -Msg "Custom Arguments in ADMX enabled, using $LIC_BISF_CLI_P2V_ARGS" }

		If ($LIC_BISF_CLI_PT -eq "ImagingWizard") {
			$Global:PVSTool = "ImagingWizard"
			$Global:PVSToolPath = $PVSPath
			IF ($BootMode -eq "UEFI") {
				IF ($LIC_BISF_CLI_P2V_CUS_ARGS -eq "1") { $Global:PVSToolArgs = "P2PVS $($LIC_BISF_CLI_P2V_ARGS)" } ELSE { $Global:PVSToolArgs = "P2PVS /QuitWhenDone" }
			}
			ELSE {
				IF ($LIC_BISF_CLI_P2V_CUS_ARGS -eq "1") { $Global:PVSToolArgs = "P2PVS $($LIC_BISF_CLI_P2V_ARGS)" } ELSE { $Global:PVSToolArgs = "P2PVS C: /QuitWhenDone" }
			}
			$Global:P2PVSLogFile = @()
			$Global:TestDiskMode = $true

		}
		ELSE {
			$Global:PVSTool = "P2PVS"
			$Global:PVSToolPath = $PVSPath
			IF ($LIC_BISF_CLI_P2V_CUS_ARGS -eq "1") { $Global:PVSToolArgs = "P2PVS $($LIC_BISF_CLI_P2V_ARGS)" } ELSE { $Global:PVSToolArgs = "P2PVS C: /Autofit /L" }
			$Global:P2PVSLogFile = @()
			$Global:TestDiskMode = $true
		}
		# Custom UNC-Path is enabled
		IF ($LIC_BISF_CLI_P2V_PT -eq "1") {
			Write-BISFLog -Msg "Custom UNC-Path is enabled and set to $LIC_BISF_CLI_P2V_PT_CUS"
			$Timestamp = Get-Date -Format yyyyMMdd-HHmm
			$Global:VDiskName = "$($Computer)-$($Timestamp)"
			#set default value for vDisk type if not set in ADMX
			IF (($LIC_BISF_CLI_PT_FT -eq "") -or ($null -eq $LIC_BISF_CLI_PT_FT)) {
				$Global:LIC_BISF_CLI_PT_FT = "vhdx"
				Write-BISFLog -Msg "vDisk type not selected in ADMX, using default value $LIC_BISF_CLI_PT_FT"
			}

			IF ($BootMode -eq "UEFI") {
				# UEFI boot with UNC-Path for VHDX
				IF ($PVSTool -eq "ImagingWizard") {
					$Global:LIC_BISF_CLI_PT_FT = "vhdx" # imagingWizard accept vhdx only
					IF ($LIC_BISF_CLI_P2V_CUS_ARGS -eq "1") { $Global:PVSToolArgs = "p2$($LIC_BISF_CLI_PT_FT) $VDiskName ""$LIC_BISF_CLI_P2V_PT_CUS"" $($LIC_BISF_CLI_P2V_ARGS)" } ELSE { $Global:PVSToolArgs = "p2$($LIC_BISF_CLI_PT_FT) $VDiskName ""$LIC_BISF_CLI_P2V_PT_CUS"" /QuitWhenDone" }
				}
			}
			ELSE {
				# Legacy boot with UNC-Path for VHDX
				IF ($PVSTool -eq "ImagingWizard") {
					$Global:LIC_BISF_CLI_PT_FT = "vhdx" # imagingWizard accept vhdx only
					IF ($LIC_BISF_CLI_P2V_CUS_ARGS -eq "1") { $Global:PVSToolArgs = "p2$($LIC_BISF_CLI_PT_FT) $VDiskName ""$LIC_BISF_CLI_P2V_PT_CUS"" $($LIC_BISF_CLI_P2V_ARGS)" } ELSE { $Global:PVSToolArgs = "p2$($LIC_BISF_CLI_PT_FT) $VDiskName ""$LIC_BISF_CLI_P2V_PT_CUS"" C: /QuitWhenDone" }
				}
				ELSE {
					IF ($LIC_BISF_CLI_P2V_CUS_ARGS -eq "1") { $Global:PVSToolArgs = "p2$($LIC_BISF_CLI_PT_FT) $VDiskName ""$LIC_BISF_CLI_P2V_PT_CUS"" $($LIC_BISF_CLI_P2V_ARGS)" } ELSE { $Global:PVSToolArgs = "p2$($LIC_BISF_CLI_PT_FT) $VDiskName ""$LIC_BISF_CLI_P2V_PT_CUS"" C:" }
				}
			}
			IF ($DiskMode -eq "ReadWrite") {
				$Global:TestDiskMode = $true
			}
			ELSE {
				IF ($DiskMode -match "UNC-Path") {
					$Global:TestDiskMode = $true
				}
				ELSE {
					$Global:TestDiskMode = $false
				}
			}
			Write-BISFLog -Msg "TestDiskMode is set to $TestDiskMode value, based on DiskMode $DiskMode"
		}
		Write-BISFLog -Msg "System BootMode $BootMode detected" -ShowConsole -SubMsg -Color DarkCyan
	}

	function Get-P2PVSLog {
		Param(
			[Parameter(Mandatory = $False)][Alias('P')][switch]$PreCmd
		)
		$P2PVSLogs = @("$env:ALLUSERSPROFILE\Citrix\$($PVSTool)\$($PVSTool).txt", "$env:ALLUSERSPROFILE\Citrix\$($PVSTool)\$($PVSTool).log")
		Write-BISFLog -Msg "Looking for the $($PVSTool) log file" -ShowConsole -Color DarkCyan -SubMsg
		$P2PVSFound = $false
		#$Global:P2PVS_LOGFile=""
		ForEach ($P2PVSLog in $P2PVSLogs) {
			If (!($PreCmd)) {
				IF ($P2PVSFound -eq $false) {
					IF ((Test-Path ("$P2PVSLog") -PathType Leaf )) {
						$DateFromToday = Get-Date | ForEach-Object { $_.ToShortDateString() }
						$DateFromFile = Get-ChildItem "$P2PVSLog" | ForEach-Object { $_.CreationTime } | ForEach-Object { $_.ToShortDateString() }
						If ($DateFromToday -eq $DateFromFile) {
							Write-BISFLog "File $P2PVSLog found" -Color DarkCyan -SubMsg
							$Global:P2PVSLogFile = "$P2PVSLog"
							$P2PVSFound = $true
						}
						ELSE {
							Write-BISFLog "File $P2PVSLog will be created on $DateFromFile and not from today $DateFromToday, it will be deleted now" -Type W -SubMsg
							Remove-Item $P2PVSLog -recurse -ErrorAction SilentlyContinue
							$P2PVSFound = $false
						}
					}
					ELSE {
						Write-BISFLog "LogFile $P2PVSLog does NOT exist" -Type W -SubMsg
						$P2PVSFound = $false
					}
				}
				ELSE {
					Write-BISFLog -Msg "Log file from $($PVSTool) will be detected in $P2PVSLogFile, skipped all other log files"
				}
			}
			ELSE {
				Write-BISFLog -Msg "Starting PreCommand before P2V is running"
				IF ((Test-Path ("$P2PVSLog") -PathType Leaf )) {
					Write-BISFLog -Msg "Delete old Log	file $P2PVSLog" -ShowConsole -Color DarkCyan -SubMsg
					Remove-Item $P2PVSLog -recurse -ErrorAction SilentlyContinue
				}
				ELSE {
					Write-BISFLog -Msg "Log file $P2PVSLog does not exist"
				}
			}
		}

	}


}


####################################################################

Process {

	#### Main Program
	Write-BISFLog -Msg "Build your Base-Image now..." -ShowConsole -Color Cyan
	IF ($ReturnTestXDSoftware -eq "true") {
		IF ($ProductType -eq "1") {
			$PreTXT = "Run Citrix personal vDisk Inventory Update ?"
			Write-BISFLog -Msg "$PreTXT" -Color DarkCyan -SubMsg
			Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
			$VarCLI = $LIC_BISF_CLI_PD
			IF (($VarCLI -eq "YES") -or ($VarCLI -eq "NO")) {
				Write-BISFLog -Msg "GPO value: $VarCLI"
			}
			ELSE {
				Write-BISFLog -Msg "GPO not configured.. using default setting" -SubMsg -Color DarkCyan
				$DefaultValue = "NO"
			}
			if (($DefaultValue -eq "YES") -or ($VarCLI -eq "YES")) {
				Remove-Item $PvdLogFile -recurse -ErrorAction SilentlyContinue
				Start-Process -FilePath 'C:\Program Files\Citrix\personal vDisk\bin\CtxPvD.exe' -ArgumentList '-s inventoryonly'
				Show-BISFProgressBar -CheckProcess "CtxPvd" -ActivityText "run Citrix Personal vDisk Inventory Update"
				$Global:RunPvd = $true
			}
			ELSE {
				Write-BISFLog -Msg "Skipping Citrix Personal vDisk Inventory"
			}
		}
		ELSE { #Not sure what this else belongs to, maybe a leftover?
			Write-BISFLog -Msg "Citrix Personal vDisk could be run on Client-OS (ProductType=1) only"
		}
		

		IF ($RunPvd -eq "true") {
			$CheckPvdLog = Test-BISFLog -CheckLogFile "$PvdLogFile" -SearchString "$PvdLogFileSearch"
			IF ($CheckPvdLog -eq $true) {
				Write-BISFLog -Msg "Successfully Update the Personal vDisk Inventory" -ShowConsole -Color DarkGreen -SubMsg
				Write-BISFLog -Msg "Personal vDisk: $PvdLogFileSearch"
				Write-BISFLog -Msg "Wait $Wait1 seconds to proceed.."
				Start-Sleep -s $Wait1
			}
			ELSE {
				get-BISFLogContent -GetLogFile "$PvdLogFile"
				Write-BISFLog -Msg "Personal vDisk Inventory Update NOT successful, check $PvdLogFile for further details" -Type E -SubMsg
				$CheckPvdLog = $false
			}
		}

		IF ($ReturnTestPVSSoftware -eq $true) {
			IF (($ReturnTestAppLayeringSoftware -eq $false) -or ($UPL -eq $true)) {
				IF ($DiskMode -notmatch "AndSkipImaging") {
					$Global:SkipPVSImaging = $false
					Set-P2VTool
					IF ($TestDiskMode) { $VDiskMode = Test-BootMode }
					IF (($VDiskMode -eq "HD") -or ($TestDiskMode -eq $false)) {
						IF ($TestDiskMode) {
							Write-BISFLog -Msg "Mode $VDiskMode - Boot from HardDisk in Private Mode" -ShowConsole -Color DarkCyan -SubMsg
						}
						ELSE {
							Write-BISFLog -Msg "Mode UNC-Path - Boot from HardDisk" -ShowConsole -Color DarkCyan -SubMsg
						}
						## 12.08.2015 MS: Get-P2PVSLog must be running 2 times for P2V and after that
						Get-P2PVSLog -PreCmd
						Write-BISFLog -Msg "Using $PVSTool with Arguments $PVSToolArgs" -ShowConsole -SubMsg -Color DarkCyan
						Start-P2PVS
						IF (!($DiskMode -match "UNC-Path")) {
							Show-BISFProgressBar -CheckProcess "$PVSTool" -ActivityText "convert $SystemDrive to PVS vDisk...($PVSTool)"
						}
						ELSE {
							Show-BISFProgressBar -CheckProcess "$PVSTool" -ActivityText "convert $SystemDrive to $DiskMode -vDiskName: $VDiskName -UNC-Path: $LIC_BISF_CLI_P2V_PT_CUS...($PVSTool)"
						}
						Get-P2PVSLog
						$Global:CheckP2PVSlog = "True"
					}
					IF ($VDiskMode -eq "P") {
						Write-BISFLog -Msg "Mode $VDiskMode - Boot from vDisk/avhd in Private Mode"
						$Global:CheckP2PVSlog = "FALSE"
					}
					IF ($VDiskMode -eq "S") {
						$a = New-Object -ComObject WScript.Shell
						$b = $a.popup("vDisk in Standard Mode (Mode: $VDiskMode), read access only. After shutdown, change the WriteCacheType to Private Image Mode and run the script again", 0, "Error", 0)
						$Global:CheckP2PVSlog = "ERROR"
						Write-BISFLog -Msg "Mode $VDiskMode - vDisk in Standard Mode, read access only!" -Type E -SubMsg
					}
				}
				ELSE {
					Write-BISFLog -Msg "skipping PVS Master Image creation " -ShowConsole -Color Yellow -Type W
					$Global:SkipPVSImaging = $true
				}
			}
			ELSE {
				Write-BISFLog -Msg "Citrix AppLayering installed, convert to Disk not necessary" -ShowConsole -Color DarkCyan -SubMsg
			}
		}
		ELSE {
			Write-BISFLog -Msg "Skip convert System to vDisk, Citrix Provisioning Services Software not installed"
		}
	}
	ELSE {
		Write-BISFLog -Msg "Skip personal vDisk Inventory Update, Citrix Virtual Desktop Agent is not installed"
	}
}

End {
	Add-BISFFinishLine
}