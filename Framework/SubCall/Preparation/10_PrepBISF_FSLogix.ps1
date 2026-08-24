<#
	.SYNOPSIS
		Prepare FSLogix Apps for Image Management
	.DESCRIPTION
		The script detects the installation of FSLogix  and deletes the FSLogix Rules on the Master Image.
		You can set a Central Rules Share to copy centralized Rules during the BIS-F personalization phase to the Images.
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
		03.06.2015 MS: Initial script development
		13.08.2015 MS: Central rules share defined and stored in registry location to use at computer startup
		21.08.2015 MS: Remove to set FSLogix service to manual, stopped service only.
		30.09.2015 MS: Rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		06.03.2017 MS: Fixed read Variable $varCLI = ...
		15.02.2017 MS: Fixed 237: When in the GPO specify "Configure FSLogix central rule share" to Disabled, the script still prompt for the path when is executed
		15.05.2019 JP: Fixed format and deleted junk lines
		14.08.2019 MS: FRQ 3 - Remove message box and using default setting if GPO is not configured
		13.02.2020 JK: Fixed Grammar
		05.12.2020 MS: HF 294 - function Set-RulesShare no longer required, RulesShare is set in registry policy path
#>

Begin {
	$ErrorActionPreference = "SilentlyContinue"
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)
	$Product = "FSLogix Apps"
	$ProductPath = "${env:ProgramFiles}\FSLogix\Apps"
	$ServiceName = "FSLogix Apps Services"
}

Process {

	function ClearConfig {
		Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
		$VarCLIFS = $LIC_BISF_CLI_FS
		IF (($VarCLIFS -eq "YES") -or ($VarCLIFS -eq "NO")) {
			Write-BISFLog -Msg "GPO value: $VarCLIFS"
		}
		ELSE {
			Write-BISFLog -Msg "GPO is not configured.. using default setting" -SubMsg -Color DarkCyan
			$VarCLIFS = "NO"
		}

		if ($VarCLIFS -eq "YES") {
			Write-BISFLog -Msg "Delete $Product Rules" -ShowConsole -Color DarkCyan -SubMsg
			Remove-Item -Path "$ProductPath\Rules\*" -Recurse
		}
		ELSE {
			Write-BISFLog -Msg "Skipping $Product Rules deletion"
		}
	}


	$Svc = Test-BISFService -ServiceName "$ServiceName" -ProductName "$Product"
	IF ($Svc -eq $true) {
		Invoke-BISFService -ServiceName "$ServiceName" -Action Stop
		ClearConfig

	}
}

End {
	Add-BISFFinishLine
}