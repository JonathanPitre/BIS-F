<#
	.SYNOPSIS
		Prepare Altiris Agent for Image Management
	.DESCRIPTION
	  	Reconfigure the Altiris Deployment Agent. If Service is installed, it would be stopped and set to manual startup
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
	  	14.10.2014 MS: function created
		02.09.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		09.11.2016 MS: add preparation for Altiris Inventory Agent
		12.07.2017 FF: Create $RegKeys as an array (was a hashtable before)
		18.02.2020 JK: Fixed Log output spelling
#>


Begin {
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)
	$ServiceName1 = "Altiris Deployment Agent"

	$ServiceName2 = "AeXNSClient"
	$ProductName2 = "Altiris Inventory Agent"
	$RegKeys = @("HKLM:\SOFTWARE\Altiris\Altiris Agent", "HKLM:\SOFTWARE\Altiris\eXpress", "HKLM:\SOFTWARE\Altiris\eXpress\NS Client")

}

Process {

	$Svc1 = Test-BISFService -ServiceName "$ServiceName1" -ProductName "$ServiceName1"
	IF ($Svc1 -eq $true) {
		Invoke-BISFService -ServiceName "$ServiceName1" -Action Stop -StartType manual
	}


	$Svc2 = Test-BISFService -ServiceName "$ServiceName2" -ProductName "$ProductName2"
	IF ($Svc2 -eq $true) {
		Invoke-BISFService -ServiceName "$ServiceName2" -Action Stop -StartType manual
		foreach ($RegKey in $RegKeys) {
			Try {
				Remove-ItemProperty -Path $RegKey -Name "MachineGUID" -ErrorAction Stop
				Write-BISFLog -Msg "$($RegKey) Successfully deleted" -ShowConsole -Color DarkCyan -SubMsg
			}
			catch [System.Security.SecurityException] {
				Write-BISFLog -Msg "Permission Denied for $($RegKey)" -ForegroundColor Red -SubMsg
			}
		}
	}

}

End {
	Add-BISFFinishLine
}