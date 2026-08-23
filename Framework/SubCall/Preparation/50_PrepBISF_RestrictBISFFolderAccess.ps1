<#
	.SYNOPSIS
		Restrict standard user access to the BIS-F installation folder.
	.DESCRIPTION
		During preparation, removes inherited permissions and the Users group from the
		BIS-F root folder (parent of the Framework path). This keeps preparation scripts
		and tooling out of reach for non-administrator accounts on sealed images.

		Uses icacls with /inheritance:d and /remove users when the folder exists.
	.EXAMPLE
		Runs automatically during Prepare Base Image when this script is invoked by the framework.
	.INPUTS
		None
	.OUTPUTS
		None
	.NOTES
		Author: Matthias Schlimm

		History:
		28.05.2015 MB: Script created
		12.08.2015 MS: integrated in BIS-F
		01.10.2015 MS: rewritten script with standard
		23.08.2026 JP: Renamed from 50_PrepBISF_SecureBISFFolder.ps1; refined comment-based help
#>

Begin {
	$RootBISFFolder = Split-Path (Split-Path $LIC_BISF_MAIN_PersScript)
	$Product = $FrameworkName
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)
}

Process {

	IF ((Test-Path $RootBISFFolder) -eq $true) {
		Write-BISFLog -Msg "$Product installed, securing folder" -ShowConsole -Color Cyan
		try {
			$Result = Invoke-Expression -command "icacls.exe `"$RootBISFFolder`" /inheritance:d /remove users"
			Write-BISFLog -Msg "User access on the folder `"$RootBISFFolder`" is removed." -ShowConsole -Color DarkCyan -SubMsg
		}
		catch {
			Write-BISFLog -Msg "Error removing User access on the folder `"$RootBISFFolder`". The output of the action is: $Result" -Type W -SubMsg
		}
	}
	ELSE {
		Write-BISFLog -Msg "$Product NOT installed" -Type E

	}

}

End {
	Add-BISFFinishLine
}