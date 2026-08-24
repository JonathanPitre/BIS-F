<#
    .SYNOPSIS
        Prepare F-Secure AntiVirus for Image Management
	.DESCRIPTION
      	Scan system and stop services
    .EXAMPLE
    .NOTES
		Author: Matthias Schlimm

		History:
		  29.07.2017 MS: Script created
		  14.08.2019 MS: FRQ 3 - Remove message box and using default setting if GPO is not configured
			03.10.2019 MS: ENH 51 - ADMX Extension: select AntiVirus full scan or custom Scan arguments
			18.02.2020 JK: Fixed Log output spelling
#>

Begin {
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)

	# Product specified
	$Product = "F-Secure Anti-Virus"
	$InstPath = "$ProgramFilesx86\F-Secure\Anti-Virus"
	$ServiceNames = @("FSAUA", "FSMA", "F-Secure Network Request Broker", "FSORSPClient", "F-Secure WebUI Daemon", "F-Secure Gatekeeper Handler Starter")
}

Process {

	####################################################################
	####### functions #####
	####################################################################


	function RunFullScan {

		Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
		$VarCLI = $LIC_BISF_CLI_AV
		IF (($VarCLI -eq "YES") -or ($VarCLI -eq "NO")) {
			Write-BISFLog -Msg "GPO value:: $VarCLI"
		}
		ELSE {
			Write-BISFLog -Msg "GPO not configured.. using default setting" -SubMsg
			$AVScan = "YES"
		}
		if (($AVScan -eq "YES" ) -or ($VarCLI -eq "YES")) {
			IF ($LIC_BISF_CLI_AV_VIE_CusScanArgsb -eq 1) {
				Write-BISFLog -Msg "Enable Custom Scan Arguments"
				$args = $LIC_BISF_CLI_AV_VIE_CusScanArgs
			}
			ELSE {
				$args = "c:\ /REPORT=C:\Windows\Logs\fsavlog.txt"
			}

			Write-BISFLog -Msg "Running Scan with arguments: $args"
			Start-Process -FilePath "$InstPath\fsav.exe" -ArgumentList $args
			Show-BISFProgressBar -CheckProcess "$ScanProcess" -ActivityText "$Product is scanning the system...please wait"
			IF (Test-Path "C:\Windows\Logs\fsavlog.txt") {
				Get-BISFLogContent -GetLogFile "C:\Windows\Logs\fsavlog.txt"
				Remove-Item -Path "C:\Windows\Logs\fsavlog.txt" -Force
			}
		}
		ELSE {
			Write-BISFLog -Msg "No Scan will be performed"
		}

	}



	function StopService {
		ForEach ($ServiceName in $ServiceNames) {
			$Svc = Test-BISFService -ServiceName "$ServiceName"
			IF ($Svc -eq $true) { Invoke-BISFService -ServiceName "$($ServiceName)" -Action Stop }
		}
	}

	####################################################################
	####### end functions #####
	####################################################################

	#### Main Program
	$Svc = Test-BISFService -ServiceName $ServiceNames[1] -ProductName "$Product"
	IF ($Svc -eq $true) {
		RunFullScan
		StopService
	}
}


End {
	Add-BISFFinishLine
}
