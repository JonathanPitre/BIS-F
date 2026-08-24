
<#
	.SYNOPSIS
		Personalize Altiris Agent for Image Management Software
	.DESCRIPTION
	  	If image is in shared mode the service will be started
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
	  	14.10.2014 MS: function created
		29.09.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service


#>

Begin {
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)
	$ServiceName = "Altiris Deployment Agent"
}

Process {

	$Svc = Test-BISFService -ServiceName "$ServiceName" -ProductName "$ServiceName"
	IF ($Svc) {
		Invoke-BISFService -ServiceName "$ServiceName" -Action Start -CheckDiskMode RW
	}
}

End {
	Add-BISFFinishLine
}