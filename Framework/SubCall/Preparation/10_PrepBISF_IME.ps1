[CmdletBinding(SupportsShouldProcess = $true)]
param(
)
<#
	.SYNOPSIS
		Delete Office 2010 IME Keyboards from startup
	.DESCRIPTION
	.EXAMPLE
	.NOTES
		Author: Benjamin Ruoff

		History
		26.10.2015 MS: Script created
#>

Begin {

	####################################################################
	# define environment

	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)

	# Product specified
	$Product = "Office IME Languages Clean-up"
	[array]$RegIMEString = "$HklmSoftware\Microsoft\Windows\CurrentVersion\Run"
	[array]$RegIMEString += "$HklmSoftware\Wow6432Node\Microsoft\Windows\CurrentVersion\Run"

	[array]$RegIMEName = "IME14 JPN Setup"
	[array]$RegIMEName += "IME14 KOR Setup"
	[array]$RegIMEName += "IME14 CHS Setup"
	[array]$RegIMEName += "IME14 CHT Setup"

	####################################################################

	function deleteOfficeIME {
		# Delete specified Data
		foreach ($Path in $RegIMEString) {
			foreach ($Key in $RegIMEName) {
				Write-BISFLog -Msg "delete specified registry items in $($Path)..."
				Write-BISFLog -Msg "delete $Key"
				Remove-ItemProperty -Path $Path -Name $Key -ErrorAction SilentlyContinue
			}

		}

	}

	####################################################################
}

Process {

	#### Main Program
	deleteOfficeIME

}

End {
	Add-BISFFinishLine
}