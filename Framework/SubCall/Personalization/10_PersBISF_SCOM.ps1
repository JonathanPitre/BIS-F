<#
	.SYNOPSIS
		Personalize SCOM Client for Image Management Software
	.DESCRIPTION

	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
	  	17.11.2014 MS: Script created for OpsMagr2k7
		06.10.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		04.03.2016 MS: fixed issue SCOM service would be start on every Image Mode if installed
		19.10.2018 MS: Fixed 72: MCS Deployment: SCOM Agent - creates OpsStateDir in C: drive
		18.02.2020 JK: Fixed Log output spelling

#>

Begin {
	$OpsStateDir = "$PVSDiskDrive\OpsStateDir"
	$ServiceName = "HealthService"
	$Product = "Microsoft SCOM Agent"
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)
}

Process {

	$Svc = Test-BISFService -ServiceName "$ServiceName" -ProductName "$Product"
	IF ($Svc) {
		$OpsStateDir = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\services\$ServiceName\Parameters")."State Directory"
		IF ($ReturnTestPVSSoftware -eq "true") {
			Write-BISFLog -Msg "Citrix PVS Target Device detected, Set StateDirectory to Path $OpsStateDir"
			If (!(Test-Path -Path $OpsStateDir)) {
				Write-BISFLog -Msg "Create Directory $OpsStateDir"
				New-Item -path "$OpsStateDir" -ItemType Directory -Force
			}
		}
		ELSE {
			Write-BISFLog -Msg "Citrix PVS Target Device NOT detected, leaving StateDirectory on original path $OpsStateDir"
		}
		Invoke-BISFService -ServiceName "$ServiceName" -Action Start
	}
}

End {
	Add-BISFFinishLine
}