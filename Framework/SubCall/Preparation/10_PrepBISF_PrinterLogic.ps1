<#
	.SYNOPSIS
		Prepare PrinterLogic PrinterInstaller
	.DESCRIPTION
		Delete PrinterLogic Printer Installer log files on Base Image
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
		29.07.2017 MS: Script created
		01.08.2017 JP: Fixed typo on line 36
#>

Begin {
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)
	$Product = "PrinterLogic PrinterInstaller Client Launcher"
	$ServiceName = "PrinterInstallerLauncher"
	$ProductPath = "$env:WinDir\Temp\PPP"
}

Process {

	$Svc = Test-BISFService -ServiceName "$ServiceName" -ProductName "$Product"
	If ($Svc -eq $true) {
		Write-BISFLog -Msg "Delete all files in $ProductPath" -ShowConsole -Color DarkCyan -SubMsg
		Remove-Item "$ProductPath\*" -Force -Recurse
	}
}

End {
	Add-BISFFinishLine
}