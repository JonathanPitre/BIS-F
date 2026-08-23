<#
	.SYNOPSIS
		perform Microsoft steps during Startup
	.DESCRIPTION
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
	  	27.10.2014 BR: Script created
		15.10.2014 JP: Added wait:0 parameter fo gpupdate
		06.10.2015 MS: Rewritten script with standard .SYNOPSIS
		26.10.2015 BR: Delay between Time sync and GPO apply
		02.08.2016 MS: With AppLayering in OS-Layer do nothing
		31.08.2017 MS: Change sleep timer from 60 to 5 seconds after time sync on startup
		11.09.2017 MS: Change sleep timer from 5 to 20 seconds after time sync on startup
		21.09.2019 MS: ENH 9 - LAPS Support for Non-Persistent VDI
		04.08.2020 MS: HF 271 - 00_PersBISF_WriteCacheDisk.ps1 fails, due to timing issue with registry values
		24.11.2020 MS: HF 285 - Join AAD if enabled in GPO
#>

Begin {
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)

}

Process {

	if ($CTXAppLayerName -ne 'OS-Layer') {
		if ($LIC_BISF_CLI_LAPSExpirationTime -eq 'YES') { Set-BISFLAPSExpirationTime }
		# Resync Time with Domain
		Write-BISFLog -Msg "Syncing Time from Domain"
		& "$env:SystemRoot\system32\w32tm.exe" /config /update
		& "$env:SystemRoot\system32\w32tm.exe" /resync /nowait
		Start-Sleep 30
		# Reapply Computer GPO
		Write-BISFLog -Msg "Apply Computer GPO" -showConsole -Color Cyan
		Start-BISFProcWithProgBar -ProcPath "$env:SystemRoot\system32\gpupdate.exe" -Args "/Target:Computer /Force /Wait:0" -ActText "Apply Computer GPO"

		if ($LIC_BISF_CLI_MS_AAD_HybridJoinb -eq 'YES') {
			Write-BISFLog -Msg "Join Azure Active Dirctory " -showConsole -Color Cyan
			Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\dsregcmd.exe" -Args "/join" -ActText "Join Azure AD Domain"
			Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\dsregcmd.exe" -Args "/status" -ActText "Get Azure AD Domain status"
		}
		else {
			Write-BISFLog -Msg "Join Azure Active Directory is NOT enabled in BIS-F GPO" -showConsole -Color Cyan
		}
	}
	else {
		Write-BISFLog -Msg "Do nothing in AppLayering $CTXAppLayerName"
	}
}

End {
	Add-BISFFinishLine
}