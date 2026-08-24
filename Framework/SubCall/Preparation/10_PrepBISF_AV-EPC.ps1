<#
	.SYNOPSIS
		Prepare Microsoft Security Client for Image Management
	.DESCRIPTION
	  	Reconfigure the Microsoft Security Client
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
	  	25.03.2014 MS: Script created
		01.04.2014 MS: Changed Console message
		12.05.2014 MS: Changed full scan from Windows Defender directory to '$MSC_path\...'
		13.05.2014 MS: Added Silent switch -AVFullScan (YES|NO)
		11.06.2014 MS: Syntax error to start silent pattern update and full scan, fix read variable LIC_BISF_CLI_AV
		13.08.2014 MS: Removed $LogFile = Set-LogFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
		20.02.2015 MS: Added progress bar during full scan
		30.09.2015 MS: Rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		06.03.2017 MS: Fixed read Variable $varCLI = ...
		16.08.2019 MS: FRQ 3 - Remove message box and using default setting if GPO is not configured
		03.10.2019 MS: ENH 51 - ADMX Extension: select AntiVirus full scan or custom Scan arguments
		18.02.2020 JK: Fixed Log output spelling
#>

Begin {
	$PSScriptFullName = $MyInvocation.MyCommand.Path
	$PSScriptRoot = Split-Path -Parent $PSScriptFullName
	$PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)
	$Product = "Microsoft Security Client"
	$MSCPath = "C:\Program Files\$Product"
}

Process {

	function Invoke-SecurityClientScan {

		Write-BISFLog -Msg "Update VirusSignatures"
		& "$MSCPath\MpCMDrun.exe" -SignatureUpdate

		Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
		$VarCLI = $LIC_BISF_CLI_AV

		IF (($VarCLI -eq "YES") -or ($VarCLI -eq "NO")) {
			Write-BISFLog -Msg "GPO value:: $VarCLI"
		}
		ELSE {
			Write-BISFLog -Msg "GPO not configured.. using default setting" -SubMsg -Color DarkCyan
			$AVScan = "YES"
		}

		if (($AVScan -eq "YES" ) -or ($VarCLI -eq "YES")) {
			IF ($LIC_BISF_CLI_AV_VIE_CusScanArgsb -eq 1) {
				Write-BISFLog -Msg "Enable Custom Scan Arguments"
				$args = $LIC_BISF_CLI_AV_VIE_CusScanArgs
			}
			ELSE {
				$args = "-scan -scantype 2"
			}

			Write-BISFLog -Msg "Running Scan with arguments: $args"
			Start-Process -FilePath "$MSCPath\MpCMDrun.exe" -ArgumentList $args
			Show-BISFProgressBar -CheckProcess "MpCMDrun" -ActivityText "$Product is scanning the system...please wait"
		}
		ELSE {
			Write-BISFLog -Msg "No Scan will be performed"
		}
	}

	####################################################################
	####### end functions #####
	####################################################################

	#### Main Program
	IF (Test-Path ("$MSCPath\MpCMDRun.exe") -PathType Leaf ) {
		Write-BISFLog -Msg "$Product installed" -ShowConsole -Color Cyan
		Invoke-SecurityClientScan
	}
	ELSE {
		Write-BISFLog -Msg "$Product is not installed"
	}

}

End {
	Add-BISFFinishLine
}