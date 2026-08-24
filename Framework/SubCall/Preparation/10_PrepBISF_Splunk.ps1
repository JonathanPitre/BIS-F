<#
	.SYNOPSIS
		Prepare Splunk Universal Forwarder for Image Management
	.DESCRIPTION
	  	Delete computer specific entries
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
	  	15.12.2014 JP: Script created
		06.02.2015 MS: review script
		01.10.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		28.05.2018 MS: Fixed 41: Set SplunkForwarder to StartType Automatic
#>

Begin {
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)
	$Product = "Splunk Universal Forwarder"
	$ProductPath = "${env:ProgramFiles}\SplunkUniversalForwarder\bin"
	$ServiceName = "SplunkForwarder"
}

Process {

	$Svc = Test-BISFService -ServiceName "$ServiceName" -ProductName "$Product"
	IF ($Svc -eq $true) {
		Invoke-BISFService -ServiceName "$ServiceName" -Action Stop -StartType Automatic
		Write-BISFLog -Msg "Clear $Product config"
		& Start-Process -FilePath "$ProductPath\splunk.exe" -ArgumentList "clone-prep-clear-config" -Wait -WindowStyle Hidden
	}
}

End {
	Add-BISFFinishLine
}