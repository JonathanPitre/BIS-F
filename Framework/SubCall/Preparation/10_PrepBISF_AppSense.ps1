<#
	.SYNOPSIS
		Prepare AppSense Agent for Image Management
	.DESCRIPTION
		Lookup for the AppSense Client Communications Agent and prepare the agent for imaging
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm


		History
		22.03.2016 MS: Script created
		28.06.2017 MS: Fixed 186 - AppSense Product Path - thx to Matthias Kowalkowski
		18.02.2020 JK: Fixed Log output spelling

#>

Begin {
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)
	$Product = "AppSense"
	$ProductPath = "${env:ProgramFiles}\AppSense\Management Center\Communications Agent"
	$PrepApp = "CcaCmd.exe"
	$ServiceName = "AppSense Client Communications Agent"
}

Process {

	$Svc = Test-BISFService -ServiceName "$ServiceName" -ProductName "$Product"
	IF ($Svc -eq $true) {
		Write-BISFLog -Msg "Preparing $Product for Imaging" -ShowConsole -Color DarkCyan -SubMsg
		IF (Test-Path ("$ProductPath\$PrepApp") -PathType Leaf ) {
			Write-BISFLog -Msg "Preparing $Product for Imaging "
			& Start-Process -FilePath "$ProductPath\$PrepApp" -ArgumentList "/imageprep" -Wait
		}
		ELSE {
			Write-BISFLog -Msg "$ProductPath\$PrepApp does not exist. Image Preparation could not be performed!" -Type E -SubMsg
		}

	}
}

End {
	Add-BISFFinishLine
}