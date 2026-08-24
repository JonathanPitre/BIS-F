<#
	.SYNOPSIS
		Personalize TrendMicro OfficeScan for Image Management Software
	.DESCRIPTION
		Create HostID based on MACAddress
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
	  	17.09.2014 MS: Script created
		10.08.2015 MS: Define array for TM services for better script handling
		06.10.2015 MS: Rewritten script with standard .SYNOPSIS
		09.01.2017 MS: Change code to get MAC Address to use function Get-BISFMacAddress
		01.08.2017 JS: Added the TmPfw (OfficeScan NT Firewall) service to the array
		19.02.2020 MS: HF 212 - MACAddress in lowercase with separated switch to fix HF 137
		29.05.2020 MS: HF 233 - TrendMicro Apex One Services not started
		05.06.2020 MS: HF 233 - Skipping ApexOne, checkout https://github.com/EUCweb/BIS-F/issues/233 for further information
#>


Begin {
	$RegTMString = "$HklmSoftwareX86\TrendMicro\PC-cillinNTCorp\CurrentVersion"
	$RegTMName = "GUID"
	$Product = "Trend Micro Office Scan"
	$Product1 = "Trend Micro Apex ONE"
	# The main 4 services are:
	# - TmListen (OfficeScan NT Listener)
	# - NTRTScan (OfficeScan NT RealTime Scan)
	# - TmPfw (OfficeScan NT Firewall)
	# - TmProxy (OfficeScan NT Proxy Service)
	$TMServices = @("TmListen", "NTRTScan", "TmProxy", "TmPfw", "TmCCSF", "TMBMServer")
	$HostIDPrfx = "00000000-0000-0000-0000-"
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)

}

Process {


	## Start TM Service
	function StartService {
		ForEach ($TMService in $TMServices) {
			# check if service exist

			$Svc = Test-BISFService -ServiceName "$TMService"
			IF ($Svc -eq $true) {
				Invoke-BISFService -ServiceName "$TMService" -Action Start
			}
		}
	}


	## set HostID in Registry
	function SetHostID {
		$Mac = Get-BISFMacAddress -ConvertToLower
		Write-BISFLog -Msg "$RegSEPName Prefix: $HostIDPrfx"
		$RegHostID = $HostIDPrfx + $Mac
		Write-BISFLog -Msg "set TrendMicro $RegTMName in Registry $RegHostIDString..."
		Set-ItemProperty -Path $RegTMString -Name $RegTMName -Value $RegHostID -ErrorAction SilentlyContinue
	}
	####################################################################

	#### Main Program
	$Svc = Test-BISFService -ServiceName $TMServices[0] -ProductName "$Product"
	$ApexOne = Test-BISFService -ServiceName $TMServices[5] -ProductName "$Product1"

	IF ($ApexOne) {
		Write-BISFLog -Msg "Skipping $Product1 personalization" -Type W -ShowConsole -SubMsg
		Write-BISFLog -M Msg "Please Checkout ApexOne Support https://github.com/EUCweb/BIS-F/issues/233 for further information" -Type W -ShowConsole -SubMsg
		start-sleep 10
		} ELSE {

		IF ($Svc) {
			# Note that if the services start before the GUID is set it won't register with the OfficeScan Management Server
			SetHostID
			StartService
		}
	}

}

End {
	Add-BISFFinishLine
}