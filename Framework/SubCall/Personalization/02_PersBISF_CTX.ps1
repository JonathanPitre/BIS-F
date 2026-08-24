<#
	.SYNOPSIS
		Personalize Citrix for Image Management Software
	.DESCRIPTION
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
	  	22.08.2013 MS: Script created
		17.09.2013 MS: Added last line to log file and remove Clear-Host
		18.09.2013 MS: Replaced $date with $(Get-Date) to get current timestamp at running script lines write to the log file
		18.03.2014 MS: Review Code and linked to new central functions like Write-BISFLog
		13.08.2014 MS: Removed $LogFile = Set-LogFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
		17.08.2014 MS: Changed line 36 to $Location = "$ProgramFilesx86\Citrix\system32\CtxSta.config"
		06.10.2015 MS: Rewritten script with standard .SYNOPSIS
		03.11.2015 MS: Configure Citrix license file cache location and set NTFS Permissions for NetworkService with full access
		10.11.2016 MS: Typo in Line 76, thx to Mikhail Zuskov - Write-BISFLog -Msg "Error changing access for NetworkService on the folder `"$LIC_BISF_CtxCache`". The output of the action is: $result" -Type W -SubMsg
		18.01.2017 MS: Bug 127; fixed with new script from Citrix - https://docs.citrix.com/en-us/xenapp-and-xendesktop/7-12/whats-new/known-issues.html
		18.04.2017 MS: reset Performance Counters with installed Citrix VDA only
		21.10.2028 MS: Fix 47: MSMQ windows services will fail to start in App Layering
		21.10.2028 MS: Fix 18: XA/ XD 7.x Cache folder will be created
		18.02.2020 JK: Fixed Log output spelling
		23.12.2020 MS: HF 304: WEM Agent 2009 or greater, new startup Options can be used
		08.05.2023 MS: HF 374 - 02_PersBISF_CTX.ps1 never finishes on Azure AD only Azure VMs
#>

Begin {
	# Define environment
	$SystemDrive = Get-Content env:SystemDrive
	$TEMP = Get-Content env:temp
	$Sta = "STA$Computer"
	$Service = "CtxHTTP"
	$PSScriptFullName = $MyInvocation.MyCommand.Path
	$PSScriptRoot = Split-Path -Parent $PSScriptFullName
	$PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)
	$Location = "$ProgramFilesx86\Citrix\system32\CtxSta.config"
	$RegCtxInstall = "$HklmSoftware\WOW6432Node\Citrix\Install"
}

Process {

	# Configure STA-File
	Write-BISFLog -Msg "Check Citrix STA in $Location"
	IF (Test-Path -Path $Location) {

		Write-BISFLog -Msg "Defined STA: $Sta"

		# Replace STA ID with Computer hostname
		(Get-Content $Location) | ForEach-Object { $_ -replace '^UID=.+$', "UID=$Sta" } | Set-Content $Location
		Write-BISFLog -Msg "Set STA in File $Location"

		#Check Service
		If (Get-Service $Service -ErrorAction SilentlyContinue) {
			Restart-Service $Service
			Write-BISFLog -Msg "XenApp Controller Mode - Restart $Service Service" -Color Cyan
		}
		Else {
			Write-BISFLog -Msg "XenApp Session Host Mode - No $Service Service"
		}
	}
	Else {
		Write-BISFLog -Msg "STA file $Location not found"
	}

	#Configure Citrix LicenseFile Cache Location
	IF (!($ReturnTestXDSoftware -eq "true")) {
		If (Test-Path -Path "$LIC_BISF_LogPath") {
			Write-BISFLog -Msg "Configure Citrix cache location"
			If (!(Test-Path -Path $LIC_BISF_CtxCache)) {
				Write-BISFLog -Msg "Create Citrix cache location $LIC_BISF_CtxCache" -SubMsg
				New-Item -Path "$LIC_BISF_CtxCache" -ItemType Directory -Force

				Try {
					$Result = Invoke-Expression -Command "icacls.exe `"$LIC_BISF_CtxCache`" /grant *S-1-5-20:(OI)(CI)(F)"
					Write-BISFLog -Msg "Added NetworkService account permissions on the folder `"$LIC_BISF_CtxCache`" " -ShowConsole -Color DarkCyan -SubMsg
				}
				Catch {
					Write-BISFLog -Msg "Error changing access for NetworkService account on the folder `"$LIC_BISF_CtxCache`". The output of the action is: $Result" -Type W -SubMsg
				}



			}
			Else {
				Write-BISFLog -Msg "Citrix cache location $LIC_BISF_CtxCache already exists" -SubMsg
			}
		}
		Else {
			Write-BISFLog -Msg "PVSWriteCache not available, skipping Citrix license cache location preparation"
		}
	}
	ELSE {
		Write-BISFLog -MSG "Citrix VDA installed, skipping Citrix license cache location"
	}

	$ServiceName = "MSMQ"
	$Svc = Test-BISFService -ServiceName "$ServiceName"
	If ($Svc) {
		Write-BISFLog -Msg "Delete old QMId from registry and set Sysprep flag for MSMQ"
		Remove-ItemProperty -Path $HklmSoftware\Microsoft\MSMQ\Parameters\MachineCache -Name QMId -Force
		Set-ItemProperty -Path $HklmSoftware\Microsoft\MSMQ\Parameters -Name "SysPrep" -Type DWord -Value 1
		Set-ItemProperty -Path $HklmSoftware\Microsoft\MSMQ\Parameters -Name "LogDataCreated" -Type DWord -Value 0
		Write-BISFLog -Msg "Get dependent services"
		$DepServices = Get-Service -Name MSMQ -DependentServices | Select-Object -Property Name
		Write-BISFLog -Msg "Restart MSMQ to get a new QMId"
		Restart-Service -Force MSMQ
		Write-BISFLog -Msg "Start dependent services"
		If ($null -ne $DepServices) {
			Foreach ($DepService in $DepServices) {
				$StartMode = Get-CimInstance -ClassName Win32_Service -Filter "NAME = '$($DepService.Name)'" | Select-Object -Property StartMode
				If ($StartMode.StartMode -eq "Auto") {
					Start-Service $DepService.Name
				}
			}

		}
	}

	## Citrix XenDesktop / XenApp VDA only
	IF ($ReturnTestXDSoftware -eq "true") {
		Write-BISFLog -Msg "Performing actions for Citrix VDA only" -ShowConsole -Color Cyan
		$PerfCounters = $LIC_BISF_CLI_PF
		IF ($PerfCounters -eq "YES") {
			Write-BISFLog -Msg "reset Performance Counters" -ShowConsole -Color DarkCyan -SubMsg
			Start-BISFProcWithProgBar -ProcPath "lodctr.exe" -Args "/r" -ActText "reset Performance Counters"

		}
		ELSE {
			Write-BISFLog -Msg "reset Performance Counters is not enabled in ADMX" -ShowConsole -Type W -SubMsg
		}
	}

	#Citrix Workspace Environment Management Agent
	<#
	.SYNOPSIS
		During personalization the WEM Agent refreshes the cache
	.DESCRIPTION

	.EXAMPLE

	.NOTES
		Author: Matthias Schlimm

		History:
			29.07.2017 MS: ENH 174: on system startup with MCS/PVS and installed WEM Agent - refresh WEM Cache
			24.08.2017 MS: HF: after restart WEM Agents	service, Netlogon must be started also
			11.09.2017 MS: WEM AgentCacheRefresh can be used without the WEM Broker name specified from WEM ADMX
			03.10.2019 MS: ENH 139 - WEM 1909 detection (thx to citrixguyblog / chezzer64)
			08.05.2023 MS: HF 374 - 02_PersBISF_CTX.ps1 never finishes on Azure AD only Azure VMs

#>

	$Services = "Norskale Agent Host Service", "WemAgentSvc"

	foreach ($Service in $Services) {
		if ($Service -eq "Norskale Agent Host Service") {
			$Product = "Citrix Workspace Environment Management (WEM) Legacy Agent"
		}

		else { $Product = "Citrix Workspace Environment Management (WEM) Agent" }

		$Svc = Test-BISFService -ServiceName "$Service" -ProductName "$Product" -RetrieveVersion

		IF ($Svc[0] -eq $true) {
			$ServiceName = $Service
			Invoke-BISFService -ServiceName "$ServiceName" -Action Stop
			Start-Sleep $Wait1
			Invoke-BISFService -ServiceName "$ServiceName" -Action Start
			IF ((Get-BISFDSRegState -Key "AzureAdJoined" -eq "YES") -and (Get-BISFDSRegState -Key "DomainJoined" -eq "NO")) {
				Write-BISFLog -Msg "VM is AAD joined only, Netlogon Service will not be started."
			} else {
				Write-BISFLog -Msg "VM is Hybrid joined (AAD + AD), Netlogon Service will be started now."
				Invoke-BISFService -ServiceName "Netlogon" -Action Start
				Start-Sleep $Wait1
			}


			#read WEM AgentAlternateCacheLocation from registry
			$RegWEMAgent = "HKLM:\SYSTEM\CurrentControlSet\Control\Norskale\Agent Host"
			$WEMAgentLocation = (Get-ItemProperty $RegWEMAgent).AgentLocation
			Write-BISFLog -Msg "WEM Agent Location: $WEMAgentLocation"


			#Read WEM Agent Host BrokerName from registry
			#Check if WEM is installed On-Prem or in Cloud Mode
			$RegWEMAgentHost = "HKLM:\SOFTWARE\Policies\Norskale\Agent Host"

			if (Get-ItemProperty $RegWEMAgentHost -Name "BrokerSvcName") {
				$WEMAgentHostBrokerName = (Get-ItemProperty $RegWEMAgentHost).BrokerSvcName
				IF (!$WEMAgentHostBrokerName) { Write-BISFLog -Msg "WEM Agent BrokerName not specified through WEM ADMX" } ELSE { Write-BISFLog -Msg "WEM Agent BrokerName: $WEMAgentHostBrokerName" }
			}


			if (Get-ItemProperty $RegWEMAgentHost -Name "CloudConnectorList") {
				$WEMAgentHostBrokerName = (Get-ItemProperty $RegWEMAgentHost).CloudConnectorList
				IF (!$WEMAgentHostBrokerName) { Write-BISFLog -Msg "WEM Agent CloudConnector not specified through WEM ADMX" } ELSE { Write-BISFLog -Msg "WEM Agent CloudConnector: $WEMAgentHostBrokerName" }
			}

			$WEMAgentCacheUtil = "$WEMAgentLocation" + "AgentCacheUtility.exe"
			$WEMAgentVersion = $Svc[1]  #HF 304: new Startup Options via BIS-F ADMX
			IF ($WEMAgentVersion -gt "2012*" ) {
				$AgentArgs = $LIC_BISF_CLI_WEMCacheStartupOption
			}

			IF ([String]::IsNullOrEmpty($AgentArgs)) {
				$AgentArgs = "-RefreshCache"
				Write-BISFLog -Msg "WEM Agent Startup Options set to default value: $AgentArgs" -ShowConsole -Color Yellow -SubMsg -Type W
			}


			Write-BISFLog -Msg "WEM Agent Version $WEMAgentVersion detected, StartupOption: $AgentArgs used" -ShowConsole -Color DarkCyan -SubMsg

			Write-BISFLog -Msg "Running Agent Cache Management Utility with $Product BrokerName $WEMAgentHostBrokerName " -ShowConsole -Color DarkCyan -SubMsg
			Start-BISFProcWithProgBar -ProcPath "$WEMAgentCacheUtil" -Args $AgentArgs -ActText "Running Agent Cache Management Utility" | Out-Null
		}
	}

}

End {
	Add-BISFFinishLine
}