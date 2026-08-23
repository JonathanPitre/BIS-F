[CmdletBinding(SupportsShouldProcess = $true)]
param(
)
<#
	.SYNOPSIS
	  Prepare Citrix for Image Management Software, like PVS or MCS
	.DESCRIPTION
	.EXAMPLE
    .Inputs
    .Outputs
	.NOTES
		Author: Matthias Schlimm
		Editor: Mike Bijl (Rewritten variable names and script format)


      History
	21.09.2012 MS: Script created
     	18.09.2013 MS: Replaced $date with $(Get-date) to get current timestamp at running script lines write to the log file
      	17.12.2013 MS: Check Citrix XenApp 6.5 Installation
        18.03.2014 BR: Revisited Script
      : 02.04.2014 MS: Redirect Citrix Cache to persistent drive
        03.04.2014 MS: Redirect LHC.mdb and RadeOffline.mdb to persistent drive
        13.05.2014 BR: Cleanup Citrix Group Policy Cache > function CleanUpCTXPolCache
        13.08.2014 MS: Removed $LogFile = Set-LogFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
        09.02.2015 MS: Renamed Script from XenApp to Citrix to have all CTX Modules in one script
        09.02.2015 MS: Moved SetSTA from single to the CTX Script
        09.02.2015 JP/MS: Cleanup Citrix Application Streaming offline database > dsmaint recreaterade
        09.02.2015 JP/MS: Cleanup Citrix Profile Management cache and logs > function CleanUpProfileManagement
        09.02.2015 JP/MS: Cleanup Citrix streamed application cache > function CleanUpRadeCache
        09.02.2015 JP/MS: Cleanup Citrix EdgeSight > function CleanUpEdgeSight
        15.04.2015 MS: Added fix for MSMQ Service if occurred with XD FP1 and session recording, the VDA has the same QMId as the MSMQ (http://support.citrix.com/proddocs/topic/xenapp-xendesktop-76fp1/xad-xaxd76fp1-knownissues.html)
        10.08.2015 MS/BR: ReAdded "Removing Local Citrix Group Policy Settings" in function CleanUpCTXPolCache
        01.10.2015 MS: Change Line 239 to Set-ItemProperty -Path HKLM:Software\Microsoft\MSMQ\Parameters\MachineCache -Name "QMId" -Value ([byte[]]$new_QMID) -Force
		01.10.2015 MS: Change Line 103 to create Cache Directory to store the CTX License File: New-Item -path "$LIC_BISF_CtxCache" -ItemType Directory -Force
		01.10.2015 MS: Rewritten script to use central BISF function
		10.11.2016 MS: Set-QMID would never be processed, wrong syntax in IF (($returnTestXDSoftware -eq "true") -or ($returnTestPVSSoftware -eq "true"))
		09.01.2017 MS: Bug fix 136; If EdgeSight DataPath not exist, it removes all under the C drive !!
		09.01.2017 MS: Bug fix 135; If PVS Target Device Driver is installed, XA LicenseFile  would be redirected to WriteCacheDisk, otherwise leave it in origin path
		10.01.2017 MS: Review 140; During Prepare XenApp for Provisioning you can remove RemoveCurrentServer and ClearLocalDatabaseInformation, this would be set with this Parameter or prompted to administrator to choose
		18.01.2017 MS: Bug 127; Removed Set-QMID, replaced with Test-MSMQ, a random QMId would be set during system startup with BIS-F
		18.01.2017 JP: Bug 127; Removed /PrepMsmq:False for XenApp 65, a random QMId would be set during system startup with BIS-F
		06.03.2017 MS: Fixed read Variable $varCLI = ...
		13.06.2017 FF: Add Citrix System Optimizer Engine
		28.06.2017 MS: Feature Request 169: add AppLayering Support
		03.07.2017 FF: CTXOE can be executed on every device (if "installed" + not disabled by GPO/skipped by user)
		26.07.2017 MS: Fixed Citrix Applayering: check Universervice ProcessID instead of ProcessName
		31.07.2017 MS: Show ConsoleMessage during prepare Citrix AppLayering if installed
		01.08.2017 MS: CTXOE: using custom search folder from ADMX if enabled
		10.09.2017 MS: Delay Citrix Desktop Service if configured through ADMX
		11.09.2017 MS: Fixed Delay Citrix Desktop Service must be stopped also
		12.09.2017 MS: Invoke-CDS Changing to $servicename = "BrokerAgent"
		16.10.2017 MS: Fixed Applayering, check if the Layer finalize is allowed before continue, thx to Brandon Mitchell
		29.10.2017 MS: Fixed AppLayering, Outside ELM no UniService must be running
		07.11.2017 MS: enable 3rd Party Optimizations, if CTXO is executed, this disabled BIS-F own optimizations
		01.07.2018 MS: Fixed 44: Pickup the right Citrix Optimizer Default Template, like Citrix_Windows10_1803.xml, also prepared for Server 2019 Template, like Citrix_WindowsServer2019_1803.xml
		08.10.2018 MS: Fixed 44: fix $template typo
		21.10.2018 MS: Fixed 75: CTXO: If template not exist, end BIS-F execution
		05.11.2018 MS: Fixed 75: CTXO: If template not exist, end BIS-F execution - add .xml for all $templates
		17.12.2018 MS: Fixed 80: CTXO: Template names are changed in order to support auto-selection
		30.05.2019 MS: FRQ 111: Support for multiple Citrix Optimizer Templates
		31.05.2019 MS: HF 24: reconfigure Citrix Broker Service if disabled / not configured in ADMX
		12.07.2019 MS: ENH 112: CTX optimizer: Multiple Templates with AutoSelect for OS Template
		26.07.2019 MS: ENH 122: Citrix Optimizer Template Prefix support
		14.08.2019 MS: FRQ 3 - Remove message box and using default setting if GPO is not configured
		03.10.2019 MS: ENH 65 - ADMX Extension to delete the log files for Citrix Optimizer
		27.01.2020 MS: HF 167 - Moving AppLayering Layer Finalize to Post BIS-F script
		18.02.2020 JK: Fixed Log output spelling
		16.12.2020 MW: Registry Hack for Not so fast reconnect Bug in Windows Server 2019


	.Link
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

	##XenApp
	$XACfgCon = "${env:ProgramFiles(x86)}\Citrix\XenApp\ServerConfig\XenAppConfigConsole.exe"
	$RegCtxInstall = "$HklmSoftware\WOW6432Node\Citrix\Install"

	#STA
	$Sta = "UNKNOWN"
	$Service = "CtxHTTP"
	$Location = "$ProgramFilesx86\Citrix\system32\CtxSta.config"

	#Citrix User profile Manager
	$CPMPath = "${env:ProgramFiles}\Citrix\User Profile Manager"
	$RegCPMPol = "$HklmSoftware\Policies\Citrix\UserProfileManager"

	#Citrix Streaming
	$RadeCachePath = "$ProgramFilesx86\Citrix\Streaming Client"

	#Citrix EdgeSight Agent
	$EdgeSightPath = "$ProgramFilesx86\Citrix\System Monitoring\Agent\Core"

	#Registry Citrix
	$HklmCitrix = "HKLM:\SOFTWARE\Citrix\Reconnect"
	####################################################################

	####################################################################
	####### functions #####

	#Prepare XenApp for Citrix Provisioning
	function XenAppPrep {
		Write-BISFLog -Msg "Check for Citrix XenApp 6.5 installation"
		IF (Test-Path -Path $XACfgCon) {
			Write-BISFLog -Msg "Prepare XenApp for Provisioning" -ShowConsole -Color Cyan

			Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
			$VarCLI = $LIC_BISF_CLI_RM
			IF (($VarCLI -eq "YES") -or ($VarCLI -eq "NO")) {
				Write-BISFLog -Msg "GPO value:: $VarCLI"
			}
			ELSE {
				Write-BISFLog -Msg "Silent switch not defined, show message box"
				Write-BISFLog -Msg "GPO not configured.. using default setting" -SubMsg -Color DarkCyan
				$XARemoval = "NO"
			}
			if (($XARemoval -eq "YES" ) -or ($VarCLI -eq "YES")) {
				Write-BISFLog -Msg "Execute $XACfgCon /ExecutionMode:ImagePrep /RemoveCurrentServer:True /PrepMsmq:True /ClearLocalDatabaseInformation:True"
				& $XACfgCon /ExecutionMode:ImagePrep /RemoveCurrentServer:True /PrepMsmq:False /ClearLocalDatabaseInformation:True
			}
			ELSE {
				Write-BISFLog -Msg "Execute $XACfgCon /ExecutionMode:ImagePrep /RemoveCurrentServer:False /PrepMsmq:True /ClearLocalDatabaseInformation:False"
				& $XACfgCon /ExecutionMode:ImagePrep /RemoveCurrentServer:False /PrepMsmq:False /ClearLocalDatabaseInformation:False
			}


			Write-BISFLog -Msg "Recreate LocalHostCache"
			& dsmaint recreatelhc

			Write-BISFLog -Msg "Recreate Application Streaming offline database"
			& dsmaint recreaterade

			return $true
		}
		ELSE {
			Write-BISFLog -Msg "XenApp 6.5 is not installed"
			return $false
		}
	}

	#redirect XenApp License File
	function RedirectLicFile {
		IF ($ReturnTestPVSSoftware -eq "true") {
			Write-BISFLog -Msg "Redirecting Citrix license file" -ShowConsole -Color DarkCyan -SubMsg
			Write-BISFLog -MSG "Checking folder to redirect Citrix cache... $LIC_BISF_CtxCache"
			New-Item -path "$LIC_BISF_CtxCache" -ItemType Directory -Force
			Write-BISFLog -Msg "Configuring cache location $LIC_BISF_CtxCache in registry $RegCtxInstall"
			Set-ItemProperty -Path $RegCtxInstall -Name "CacheLocation" -Value $LIC_BISF_CtxCache -ErrorAction SilentlyContinue
		}
	}

	#Cleanup Citrix Group Policy Cache
	function CleanUpCTXPolCache {
		Write-BISFLog -Msg "Cleanup Citrix Group Policy in file system and registry" -ShowConsole -Color DarkCyan -SubMsg

		Write-BISFLog -Msg "Removing Citrix Group Policy cache"
		Get-ChildItem $env:ProgramData\Citrix\GroupPolicy | Remove-Item -Force -Recurse

		Write-BISFLog -Msg "Removing Citrix Group Policy registry cache"
		Get-ChildItem HKLM:\SOFTWARE\Policies\Citrix\ | Remove-Item -Recurse -Force

		Write-BISFLog -Msg "Removing Local Citrix Group Policy settings"
		Add-PSSnapIn Citrix.Common.GroupPolicy -ErrorAction SilentlyContinue
		Get-ChildItem LocalGPO:\Computer -Recurse | Clear-Item -ErrorAction SilentlyContinue
	}

	#set Citrix STA
	function SetSTA {
		Write-BISFLog -Msg "Check Citrix STA in $Location"
		IF (Test-Path -Path $Location) {
			Write-BISFLog -Msg "Reconfigure Citrix STA" -ShowConsole -Color DarkCyan -SubMsg
			Write-BISFLog -Msg "Set STA: $Sta"
			# Replace STA ID with Value 'UNKNOWN' for PVS Cloning
			(Get-Content $Location) | ForEach-Object { $_ -replace '^UID=.+$', "UID=$Sta" } | Set-Content $Location
			Write-BISFLog -Msg "Set STA file in $Location"
			#Check Service
			if (Get-Service $Service -ErrorAction SilentlyContinue) {
				Restart-Service $Service
				Write-BISFLog -Msg "XenApp Controller Mode - Restart $Service Service"
			}
			ELSE {
				Write-BISFLog -Msg "XenApp Session Host Mode - No $Service Service"
			}
		}
		ELSE {
			Write-BISFLog -Msg "STA file $Location not found"
		}
	}

	#Cleanup Citrix Profile Management cache and logs
	function CleanUpProfileManagement {
		$Product = "Citrix User Profile Manager"
		$ServiceName = "ctxProfile"
		$Svc = Test-BISFService -ServiceName "$ServiceName" -ProductName "$Product"
		IF ($Svc -eq $true) {
			Invoke-BISFService -ServiceName "$ServiceName" -Action Stop
		}
		IF (Test-Path -Path $RegCPMPol) {
			$CPMCachePath = (Get-ItemProperty $RegCPMPol).USNDBPath
			$CPMLogsPath = (Get-ItemProperty $RegCPMPol).PathToLogFile
			Write-BISFLog -Msg "Removing Citrix Profile Management cache and logs"
			Remove-Item  $CPMCachePath\UserProfileManager_?.cache, $CPMLogsPath\*pm*.log* -Force -ErrorAction SilentlyContinue
		}

	}

	#Cleanup Citrix Streamed application cache
	#http://support.citrix.com/proddocs/topic/xenapp-application-streaming-edocs-v6-0/ps-stream-plugin-radecache.html
	function CleanUpRadeCache {
		IF (Test-Path ("$RadeCachePath\RadeCache.exe") -PathType Leaf ) {
			Write-BISFLog -Msg "Removing Citrix Streamed application cache" -ShowConsole -Color DarkCyan -SubMsg
			Start-Process "$RadeCachePath\RadeCache.exe" -ArgumentList "/flushall" -NoNewWindow -Wait -RedirectStandardOutput "C:\Windows\Logs\CTX_RadeCache.log"
			Get-BISFLogContent "C:\Windows\Logs\CTX_RadeCache.log"
		}
	}

	# Not so fast Reconnect in Windows Server 2019
	# https://www.mycugc.org/blogs/brandon-mitchell1/2019/09/22/not-so-fast-reconnect 
	function NotSoFastReconnect {
		IF ($Global:OSName -like "*Server 2019*") { #Windows Server 2019
			IF (!(Test-Path ("$HklmCitrix"))) {
				Write-BISFLog -Msg "Write RegKey to Disable FastReconnect" -ShowConsole -Color DarkCyan -SubMsg
				New-Item "$HklmCitrix"
				New-ItemProperty -Path "$HklmCitrix" -Name "FastReconnect" -Value ”0”  -PropertyType "DWord"
			}
		}
	}

	function CleanUpEdgeSight {
		$Product = "Citrix EdgeSight Agent"
		$ServiceName = "RSCorSvc"
		$Svc = Test-BISFService -ServiceName "$ServiceName" -ProductName "$Product"
		IF ($Svc -eq $true) {
			Invoke-BISFService -ServiceName "$ServiceName" -Action Stop
		}
		Write-BISFLog -Msg "Removing Citrix EdgeSight Agent old data"
		$RegEdgeSight = "$HklmSoftwareX86\Citrix\System Monitoring\Agent\Core\4.00"
		$EdgeSightDataPath = (Get-ItemProperty $RegEdgeSight).DataPath
		IF ($EdgeSightDataPath) { Remove-Item $EdgeSightDataPath\* -Force -Recurse -ErrorAction SilentlyContinue | Out-Null }
	}


	function Test-MSMQ {
		$ServiceName = "MSMQ"
		$Svc = Test-BISFService -ServiceName "$ServiceName"
		IF ($Svc) { Write-BISFLog -Msg "Random QMID will be generated during system startup" -ShowConsole -Color Cyan }
	}


	#Citrix Workspace Environment Management Agent

	function Set-WEMAgent {
		<#
	.SYNOPSIS
		During Preparation the WEM Agent is prepared for imaging
	.DESCRIPTION

	.EXAMPLE
		SET-WEMAgent
	.NOTES
		Author: Matthias Schlimm

		History:
			10.11.2016 MS: Added Citrix Workspace Environment Agent detection, to reconfigure AgentAlternateCacheLocation
			20.02.2017 MS: Removing configure WEMBrokerName with BIS-F, must be configured with WEM ADMX or AMD from Citrix, not here !!
			11.09.2017 MS: WEM AgentCacheRefresh can be using without the WEM Broker name specified from WEM ADMX
			03.10.2019 MS: ENH 139 - WEM 1909 detection (tx to citrixguyblog / chezzer64)
			04.10.2019 MS: ENH 11 - ADMX extension: Configure WEM Cache to persistent drive
			10.01.2020 MS: HF 180 - IF WEM Config is not configured it's processes to reconfigure too
			02.02.2020 MS: fix description for WEMCache
#>

		IF ($LIC_BISF_CLI_WEMCfg -eq "YES") {
			$Services = "Norskale Agent Host Service", "WemAgentSvc"
			$AgentCacheFolder = "WEMAgentCache"  # ->  $LIC_BISF_CtxPath\$AgentCacheFolder

			foreach ($Service in $Services) {
				if ($Service -eq "Norskale Agent Host Service") {
					$Product = "Citrix Workspace Environment Management (WEM) Legacy Agent"
				}

				else { $Product = "Citrix Workspace Environment Management (WEM) Agent" }

				$Svc = Test-BISFService -ServiceName "$Service" -ProductName "$Product"
				IF ($Svc -eq $true) {
					$ServiceName = $Service
					Invoke-BISFService -ServiceName "$ServiceName" -Action Stop


					#read WEM AgentAlternateCacheLocation from registry
					$RegWEMAgent = "HKLM:\SYSTEM\CurrentControlSet\Control\Norskale\Agent Host"
					$WEMAgentLocation = (Get-ItemProperty $RegWEMAgent).AgentLocation
					Write-BISFLog -Msg "WEM Agent Location: $WEMAgentLocation"

					$WEMAgentCacheLocation = (Get-ItemProperty $RegWEMAgent).AgentCacheAlternateLocation
					Write-BISFLog -Msg "WEM Agent cache location: $WEMAgentCacheLocation"

					$WEMAgentCacheDrive = $WEMAgentCacheLocation.Substring(0, 2)
					Write-BISFLog -Msg "WEM Agent cache drive: $WEMAgentCacheDrive"


					#Read WEM Agent Host BrokerName from registry
					#Check if WEM is installed On-Prem or in Cloud Mode
					$RegWEMAgentHost = "HKLM:\SOFTWARE\Policies\Norskale\Agent Host"


					if (Get-ItemProperty $RegWEMAgentHost -Name "BrokerSvcName") {
						$WEMAgentHostBrokerName = (Get-ItemProperty $RegWEMAgentHost).BrokerSvcName
						IF (!$WEMAgentHostBrokerName) { Write-BISFLog -Msg "WEM Agent BrokerName not specified through WEM ADMX" } ELSE { Write-BISFLog -Msg "WEM Agent BrokerName: $WEMAgentHostBrokerName" }
					}


					if (Get-ItemProperty $RegWEMAgentHost -Name "CloudConnectorList") {
						$WEMAgentHostBrokerName = (Get-ItemProperty $RegWEMAgentHost).CloudConnectorList
						IF (!$WEMAgentHostBrokerName) { Write-BISFLog -Msg "WEM Agent Cloud Connector not specified through WEM ADMX" } ELSE { Write-BISFLog -Msg "WEM Agent CloudConnector: $WEMAgentHostBrokerName" }
					}



					IF (($Redirection -eq $true) -and ($LIC_BISF_CLI_WEMCache -eq 1)) {
						IF ($PVSDiskDrive -ne $WEMAgentCacheDrive) {
							IF ($LIC_BISF_CLI_WEMb -eq 1) {
								Write-BISFLog -Msg "Use custom WEM Cache Folder"
								$NewWEMAgentCacheLocation = "$LIC_BISF_CtxPath\" + $LIC_BISF_CLI_WEMFolder
							}
							ELSE {
								$NewWEMAgentCacheLocation = "$LIC_BISF_CtxPath\$AgentCacheFolder"
							}

							Write-BISFLog -Msg "The WEM Agent cache drive ($WEMAgentCacheDrive) is not equal to the CacheDisk ($PVSDiskDrive)" -Type W -SubMsg
							Write-BISFLog -Msg "The AgentCacheAlternateLocation value will be reconfigured to $NewWEMAgentCacheLocation" -Type W -SubMsg

							IF (!(Test-Path "$NewWEMAgentCacheLocation")) {
								Write-BISFLog -Msg "Creating folder $NewWEMAgentCacheLocation" -ShowConsole -Color DarkCyan -SubMsg
								New-Item -Path "$NewWEMAgentCacheLocation" -ItemType Directory | Out-Null
							}

							$WEMAgentLclDb = "$WEMAgentLocation" + "Local Databases"
							Write-BISFLog -Msg "Moving the local database files (*sdf) from $WEMAgentLclDb to $NewWEMAgentCacheLocation" -ShowConsole -Color DarkCyan -SubMsg
							Move-Item -Path "$WEMAgentLclDb\*.sdf" -Destination "$NewWEMAgentCacheLocation"
							Set-ItemProperty -Path "$RegWEMAgent" -Name "AgentCacheAlternateLocation" -Value "$NewWEMAgentCacheLocation"
							Set-ItemProperty -Path "$RegWEMAgent" -Name "AgentServiceUseNonPersistentCompliantHistory" -Value "1"
							$WEMAgentCacheUtil = "$WEMAgentLocation" + "AgentCacheUtility.exe"
						}
						ELSE {
							Write-BISFLog -Msg "The WEM Agent cache drive ($WEMAgentCacheDrive) is equal to the CacheDisk ($PVSDiskDrive) and must not be reconfigured" -ShowConsole -SubMsg -Color DarkCyan
						}

						Write-BISFLog -Msg "Running Agent Cache Management Utility with $Product" -ShowConsole -Color DarkCyan -SubMsg
						Start-BISFProcWithProgBar -ProcPath "$WEMAgentCacheUtil" -Args "-RefreshCache" -ActText "Running Agent Cache Management Utility"
					}
					ELSE {
						IF ($PVSDiskDrive -eq $WEMAgentCacheDrive) {
							Write-BISFLog -Msg "Redirection is disabled, configure the WEM Cache back to the origin path" -ShowConsole -Color DarkCyan -SubMsg
							$WEMAgentLclDb = "$WEMAgentLocation" + "Local Databases"
							Write-BISFLog -Msg "Origin path is set to $WEMAgentLclDb" -ShowConsole -Color DarkCyan -SubMsg
							Set-ItemProperty -Path "$RegWEMAgent" -Name "AgentCacheAlternateLocation" -Value $WEMAgentLclDb
							Remove-ItemProperty -Path "$RegWEMAgent" -Name "AgentServiceUseNonPersistentCompliantHistory"
							$WEMAgentCacheUtil = "$WEMAgentLocation" + "AgentCacheUtility.exe"
							Write-BISFLog -Msg "Running Agent Cache Management Utility with $Product" -ShowConsole -Color DarkCyan -SubMsg
							Start-BISFProcWithProgBar -ProcPath "$WEMAgentCacheUtil" -Args "-RefreshCache" -ActText "Running Agent Cache Management Utility"
							Write-BISFLog -Msg "Removing old path $WEMAgentCacheLocation" -ShowConsole -Color DarkCyan -SubMsg
							Remove-Item "$WEMAgentCacheLocation" -Recurse -Force
						}
					}


				}
			}
		} ELSE {
			Write-BISFLog "GPO for WEM Agent is disabled or not configured"
		}
	}


	# Citrix System Optimizer Engine (CTXOE)
	function Start-CTXOE {
		Write-BISFLog -Msg "Executing Citrix Optimizer (CTXO)..."

		IF ($LIC_BISF_CLI_CTXOE_SF -eq "1") {
			$SearchFolders = $LIC_BISF_CLI_CTXOE_SF_CUS
		}
		ELSE {
			$SearchFolders = @("C:\Program Files", "C:\Program Files (x86)", "C:\Windows\system32")
		}

		$AppName = "Citrix Optimizer (CTXO)"
		$Found = $false
		$TmpPS1 = "C:\Windows\temp\runCTXOE.ps1"

		$VarCLI = $LIC_BISF_CLI_CTXOE
		IF (!($VarCLI -eq "NO")) {
			Write-BISFLog -Msg "Searching for $AppName on local System" -ShowConsole -Color Cyan
			#Write-BISFLog -Msg "This can run a long time based on the size of your root drive, you can skip this in the ADMX configuration (Citrix)" -ShowConsole -Color DarkCyan -SubMsg
			ForEach ($SearchFolder in $SearchFolders) {
				If ($Found -eq $false) {
					Write-BISFLog -Msg "Looking in $SearchFolder"
					$FileExists = Get-ChildItem -Path "$SearchFolder" -filter "CtxOptimizerEngine.ps1" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
					$CTXOTemplatePath = (Get-ChildItem -Path "$SearchFolder" -filter "CtxOptimizerEngine.ps1" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.DirectoryName }) + "\Templates"

					IF (($null -ne $FileExists) -and ($Found -ne $true)) {

						Write-BISFLog -Msg "Product $($AppName) installed" -ShowConsole -Color Cyan
						$Found = $true

						Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan

						IF (($VarCLI -eq "YES") -or ($VarCLI -eq "NO")) {
							Write-BISFLog -Msg "GPO value:: $VarCLI"
						}
						ELSE {
							Write-BISFLog -Msg "GPO not configured.. using default setting" -SubMsg -Color DarkCyan
							$CTXOE = "NO"
						}

						If (($CTXOE -eq "YES" ) -or ($VarCLI -eq "YES")) {
							Write-BISFLog -Msg "Running $AppName... please Wait"

							#Template
							if (($LIC_BISF_CLI_CTXOE_TP -eq "") -or ($null -eq $LIC_BISF_CLI_CTXOE_TP)) {
								$Templates = "AutoSelect"
								Write-BISFLog -Msg "No Template for $AppName is configured by GPO, using $Templates"
							}
							else {
								$Templates = $LIC_BISF_CLI_CTXOE_TP
								Write-BISFLog -Msg "Template(s) for $AppName is configured by GPO: $Templates"
							}

							#TemplatePrefix
							IF (($LIC_BISF_CLI_CTXOE_TP_PREFIX -eq "") -or ($null -eq $LIC_BISF_CLI_CTXOE_TP_PREFIX)) {
								$TemplatePrefix = $null

							}
							ELSE {
								$TemplatePrefix = $LIC_BISF_CLI_CTXOE_TP_PREFIX
								Write-BISFLog -Msg "Using Template prefix: $TemplatePrefix" -ShowConsole -SubMsg -Color DarkCyan
							}


							#Groups
							if (($LIC_BISF_CLI_CTXOE_GROUPS -eq "") -or ($null -eq $LIC_BISF_CLI_CTXOE_GROUPS)) {
								Write-BISFLog -Msg "No groups for $AppName are configured by GPO. We will execute all available groups"
								$Groups = ""
							}
							else {
								Write-BISFLog -Msg "Groups for $AppName configured by GPO: $LIC_BISF_CLI_CTXOE_GROUPS"
								$GroupsReg = ($LIC_BISF_CLI_CTXOE_GROUPS).Split(',')
								$Groups = $null
								foreach ($Entry in $GroupsReg) {
									$Groups += """$Entry"","
								}
								$Groups = $Groups.Substring(0, ($Groups.Length - 1))
								$Groups = " -Groups $Groups "
							}

							#Mode
							if ($LIC_BISF_CLI_CTXOE_Analyze -ne "true") {
								$Mode = "execute"
							}
							else {
								$Mode = "analyze"
							}

							#Commandline
							ForEach ($Template in $Templates.split(",")) {
								Write-BISFLog "Processing Template $Template" -ShowConsole -SubMsg -Color DarkCyan
								IF ($Template -eq "AutoSelect") {
									$CTXAutoSelect = $true
								}
								Else {
									$CTXAutoSelect = $false
								}

								Write-BISFLog -Msg "Create temporary CMD-File ($TmpPS1) to run $AppName from them"
								$LogFolderBisf = (Get-Item -Path $LogFile | Select-Object -ExpandProperty Directory).FullName
								$Timestamp = Get-Date -Format yyyyMMdd-HHmmss
								$XMLtemplate = $Template.split(".")[0]
								$OutputXml = "$LogFolderBisf\Prep_BIS_CTXO_$($Computer)_$($XMLtemplate)_$Timestamp.xml"

								IF ((Test-Path "$CTXOTemplatePath\$Template") -or ($CTXAutoSelect -eq $true)) {
									IF ($CTXAutoSelect -eq $true) {
										IF ($null -eq $TemplatePrefix) {
											Write-BISFLog "Using AutoSelect for OS Optimization " -ShowConsole -SubMsg -Color DarkCyan
											"& ""$FileExists"" $Groups -mode $Mode -OutputXml ""$OutputXml""" | Out-File $TmpPS1 -Encoding default
										}
										ELSE {
											Write-BISFLog "Using AutoSelect for OS Optimization with Template Prefix" -ShowConsole -SubMsg -Color DarkCyan
											"& ""$FileExists"" $Groups -mode $Mode -OutputXml ""$OutputXml"" -TemplatePrefix ""$TemplatePrefix""" | Out-File $TmpPS1 -Encoding default
										}
									}
									ELSE {
										Write-BISFLog -Msg "Using Template $CTXOTemplatePath\$Template with Tem" -ShowConsole -SubMsg -Color DarkCyan
										"& ""$FileExists"" -Source ""$Template""$Groups -mode $Mode -OutputXml ""$OutputXml""" | Out-File $TmpPS1 -Encoding default
									}


									$Global:LIC_BISF_3RD_OPT = $true # BIS-F own optimization will be disabled, if 3rd Party Optimization is true
									$CtxoeProc = Start-Process -FilePath powershell.exe -ArgumentList "-file $TmpPS1" -WindowStyle Hidden -PassThru
									Show-BISFProgressBar -CheckProcessId $CtxoeProc.Id -ActivityText "Running $AppName...please wait"
									Remove-Item $TmpPS1 -Force

									#CTXOE log file
									$ScriptFolder = (Get-Item -Path $FileExists | Select-Object -ExpandProperty Directory).FullName
									$LogFolder = "$ScriptFolder\Logs"
									$CtxoeLogPath = Get-ChildItem -Path $LogFolder -Filter "Log_Debug_CTXOE.log" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName } | Select-Object -Last 1
									Write-BISFLog -Msg "Add $AppName log file from $CtxoeLogPath to BIS-F log file"
									Get-BISFLogContent -GetLogFile $CtxoeLogPath
									IF ($LIC_BISF_CLI_CTXOE_LogDelete -eq 1) {
										Write-BISFLog -Msg "Removing $AppName log file $CtxoeLogPath "
										Remove-Item $CtxoeLogPath -Force
									}
								}
								ELSE {
									Write-BISFLog -Msg "ERROR: Citrix Optimizer Template $CTXOTemplatePath\$Template does NOT exist!" -Type E -SubMsg
								}
							}
						}
						ELSE {
							Write-BISFLog -Msg "No optimization by $AppName"
						}
					}
				}
			}
		}
		ELSE {
			Write-BISFLog -Msg "Skip searching and running $AppName"
		}
	}

	function Invoke-CDS {
		$ServiceName = "BrokerAgent"
		IF ($LIC_BISF_CLI_CDS -eq "1") {
			Write-BISFLog -Msg "The $ServiceName is configured through ADMX.. delay operation configured" -ShowConsole -Color Cyan
			Invoke-BISFService -ServiceName "$ServiceName" -StartType disabled -Action stop
		}
		ELSE {
			Write-BISFLog -Msg "The $ServiceName is not configured through ADMX.. normal operation state"
			Invoke-BISFService -ServiceName "$ServiceName" -StartType Automatic -Action start
		}

	}



	####################################################################
}

Process {

	#### Main Program
	$ReturnXenAppPrep = XenAppPrep

	IF ($ReturnXenAppPrep -eq "true") {
		#XenApp Installation
		SetSTA
		RedirectLicFile
		CleanUpRadeCache
		CleanUpCTXPolCache
		CleanUpProfileManagement
		CleanUpEdgeSight
		NotSoFastReconnect
	}

	IF (($ReturnTestXDSoftware -eq "true") -or ($ReturnTestPVSSoftware -eq "true")) {
		#Citrix PVS or Citrix VDA installed
		Test-MSMQ
		Set-WEMAgent

		IF ($ReturnTestXDSoftware -eq "true") {
			# Citrix VDA only
			Invoke-CDS
		}

	}
	Start-CTXOE
}
End {
	Add-BISFFinishLine
}
