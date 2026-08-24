<#
	.SYNOPSIS
		Prepare SCOM Client for Image Management
	.DESCRIPTION
	  	Delete computer specific entries
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
	  	17.11.2014 MS: Script created for OpsManager 2007
		19.02.2015 MS: change line 65 to IF ($svc -And (Test-Path $OpsStateDirOrigin))
		04.05.2015 MS: add SCOM 2012 detection, checks 2007 path only
		30.07.2015 MS: Fix line 39: rename $returnCheckPVSSoftware to $returnTestPVSSoftware
		01.10.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		03.10.2017 MS: Fixed 214: Test path if $OpsStateDirOrigin before delete, instead of complete C: content if if $OpsStateDirOrigin is not available
		29.03.2018 MS: Fixed 37: SCOM 2018, uses new certificate store Microsoft Monitoring Agent
		18.02.2020 JK: Fixed Log output spelling
#>

Begin {
	$OpsStateDir = "$PVSDiskDrive\OpsStateDir"
	$OpsStateDirOrigin2012 = "$env:ProgramFiles\Microsoft Monitoring Agent\Agent\Health Service State"
	$OpsStateDirOrigin2007 = "$ProgramFilesx86\System Center Operations Manager 2007\Health Service State"
	$ServiceName = "HealthService"
	$Product = "Microsoft SCOM Agent"
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)
}
####################################################################
####### functions #####
####################################################################

Process {


	function ReconfigureAgent {
		Write-BISFLog -Msg "Remove existing certificates for $Product"
		Try {
			& Invoke-Expression "certutil -delstore ""Operations Manager"" $env:ComputerName.$env:UserDNSDomain" | Out-Null
		}
		Catch {
			Write-BISFLog -Msg "Certificate Operations Manager can't be removed"
		}

		#required for SCOM 2016 an later too
		Try {
			& Invoke-Expression "certutil -delstore ""Microsoft Monitoring Agent"" 0" | Out-Null
		}
		Catch {
			Write-BISFLog -Msg "Certificate Microsoft Monitoring Agent can't be removed"
		}

		IF ($ReturnTestPVSSoftware -eq "true") {
			Write-BISFLog -Msg "Citrix PVS Target Device detected, Setting StateDirectory to Path $OpsStateDir"
			Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\services\$ServiceName\Parameters" -Name "State Directory" -Value "$OpsStateDir"
		}
		ELSE {
			Write-BISFLog -Msg "Citrix PVS Target Device NOT detected, StateDirectory left on original path $OpsStateDirOrigin"
		}

		if (Test-Path $OpsStateDirOrigin) {
			Write-BISFLog -Msg "Delete Path $OpsStateDirOrigin"
			Remove-Item -Path "$OpsStateDirOrigin\*" -recurse
		}
	}

	####################################################################
	####### end functions #####
	####################################################################

	#### Main Program

	$Svc = Test-BISFService -ServiceName "$ServiceName" -ProductName "$Product"
	IF ($Svc -eq $true) {
		$OpsStateDirOrigin = @()   # set empty variable to check later if Ops/SCOM installed
		IF (Test-Path $OpsStateDirOrigin2012) { $OpsStateDirOrigin = $OpsStateDirOrigin2012 }
		IF (Test-Path $OpsStateDirOrigin2007) { $OpsStateDirOrigin = $OpsStateDirOrigin2007 }

		IF ($null -ne $OpsStateDirOrigin) {
			Write-BISFLog -Msg "Path $OpsStateDirOrigin detected"
			Invoke-BISFService -ServiceName "$ServiceName" -Action Stop -StartType manual
			ReconfigureAgent
		}
		ELSE {
			Write-BISFLog -Msg "$Service $ServiceName detected, but path $OpsStateDirOrigin2012 or $OpsStateDirOrigin2007 not found. $Product will not be optimized for Imaging" -Type E -SubMsg
		}
	}
}

End {
	Add-BISFFinishLine
}