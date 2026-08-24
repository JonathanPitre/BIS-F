<#
	.SYNOPSIS
		Personalize Sophos AntiVirus for Image Management Software
	.DESCRIPTION
	  	Create HostID based on MACAddress and start services
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
		09.01.2017 MS: Script created
		18.08.2017 FF: Use $ServiceNameS instead of $ServiceName for first Test-BISFService

#>

Begin {
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)

	# Product specified
	$Product = "Sophos AntiVirus"
	$InstPath = "$ProgramFilesx86\Sophos\Sophos Anti-Virus"
	$ServiceNames = @("Sophos Agent", "Sophos AutoUpdate Service", "Sophos Message Router")
	$HostIDPrfx = "00000000-0000-0000-0000-00"
	$HostIDFile = "$env:ProgramData\Sophos\AutoUpdate\data\machine_ID.txt"

}

Process {

	####################################################################
	####### functions #####
	####################################################################

	function CreateGUID {
		Write-BISFLog -Msg "GUID Prefix: $HostIDPrfx"
		$Mac = Get-BISFMacAddress
		$RegHostID = $HostIDPrfx + $Mac
		Write-BISFLog -Msg "Write Sophos GUID $RegHostID to file $HostIDFile"
		Out-File -FilePath $HostIDFile -InputObject "$RegHostID" -Encoding default
	}

	function StartService {
		ForEach ($ServiceName in $ServiceNames) {
			$Svc = Test-BISFService -ServiceName "$ServiceName"
			IF ($Svc -eq $true) { Invoke-BISFService -ServiceName "$($ServiceName)" -Action Start }
		}
	}

	####################################################################
	####### end functions #####
	####################################################################

	#### Main Program
	$Svc = Test-BISFService -ServiceName $ServiceNames[0] -ProductName "$Product"
	IF ($Svc -eq $true) {
		CreateGUID
		StartService

	}
}


End {
	Add-BISFFinishLine
}