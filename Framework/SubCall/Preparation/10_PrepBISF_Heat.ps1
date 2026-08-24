<#
	.Synopsis
		Prepare Heat DSM Agent for Imaging Management
	.DESCRIPTION
		Lookup for the Heat DSM Core Service and prepare the Agent for Imaging
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
		17.02.2015 MS: Script created
		30.09.2015 MS: Rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		04.11.2015 MS: Syntax error -> replace WriteBISF-Log with Write-BISFLog
		10.12.2015 MS: Change product name from "Frontrange DSM " to "Heat DSM"
		18.02.2020 JK: Fixed Log output spelling
#>

Begin {
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)
	$Product = "Heat DSM"
	$ProductPath = "$ProgramFilesx86\NetInst"
	$PrepApp = "niprep.exe"
	$ServiceName = "esiCore"
}

Process {

	$Svc = Test-BISFService -ServiceName "$ServiceName" -ProductName "$Product"
	IF ($Svc -eq $true) {
		Write-BISFLog -Msg "Preparing $Product for Imaging" -ShowConsole -Color DarkCyan -SubMsg
		IF (Test-Path ("$ProductPath\$PrepApp") -PathType Leaf ) {
			Write-BISFLog -Msg "Preparing $Product for Imaging "
			& Start-Process -FilePath "$ProductPath\$PrepApp" -ArgumentList "/r" -Wait
		}
		ELSE {
			Write-BISFLog -Msg "$ProductPath\$PrepApp does not exists. Image Preparation could not be performed!" -Type E -SubMsg
		}

	}
}

End {
	Add-BISFFinishLine
}