<#
	.SYNOPSIS
		Configure system startup actions during personalization.
	.DESCRIPTION
		Runs disk-mode-specific startup tasks: start Windows Update on private/read-write
		images, enable or disable the Windows SIH (sihclient.exe) scheduled task to avoid
		CPU load when WSUS is stopped, and optionally run SDelete to zero free space on
		PVS write-cache, MCS IO cache, or MCS system drives in shared image mode.

		When SDelete is enabled and the OS-bitness-matching executable is missing, BIS-F
		downloads the latest build from live.sysinternals.com. An existing copy is updated
		only when LIC_BISF_CLI_SD_UPD is enabled.
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
		11.08.2015 BR: Script created
		06.10.2015 MS: Rewritten script with standard .SYNOPSIS
		22.03.2016 MS: Added SDelete to run on the WriteCacheDisk on PVS Target Devices only
		10.11.2016 MS: SDelete will no longer be distributed by BISF, it must be installed in C:\Windows\system32
		12.03.2017 MS: get WCDrive from $LIC_BISF_CLI_WCD instead of PVSWriteCacheDisk System Variable, it can be configured via ADMX now
		01.08.2017 MS: change sdeletePath, it can be set to a custom value
		02.08.2017 MS: With DiskMode AppLayering in OS-Layer the WSUS Update Service would be start
		29.10.2017 MS: replace VDA instead of MCS in the DiskMode Test
		20.10.2018 MS: Fixed 73: MCS Image in Private Mode does not start the Windows Update Service
		18.08.2019 MS: ENH 101: Use sdelete64.exe on x64 system
		05.10.2019 MS: ENH 12 - Configure sDelete for different environments
		05.10.2019 MS: ENH 43 - sihclient.exe consumes CPU load with disabled WSUS Service (function invoke-sihTask)
		18.02.2020 JK: Fixed Log output spelling
		24.08.2026 JP: Fix SIH task name/path, DiskMode suffixes, SDelete auto-download/update, style and grammar
	.LINK
		https://learn.microsoft.com/sysinternals/downloads/sdelete
#>

Begin {
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)
}

Process {

	#region functions
	function Start-SDelete {
		[CmdletBinding()]
		param()

		if ($RunPersSdelete -ne $true) {
			return
		}

		$SDeletePath = Save-BISFSDelete
		if ([string]::IsNullOrWhiteSpace($SDeletePath) -or -not (Test-Path -LiteralPath $SDeletePath -PathType Leaf)) {
			Write-BISFLog -Msg "SDelete could not be detected; skipping zero free space" -Type W
			return
		}

		$ProductFileVersion = (Get-Item -LiteralPath $SDeletePath).VersionInfo.FileVersion
		Write-BISFLog -Msg "SDelete $ProductFileVersion found at $SDeletePath" -ShowConsole -Color Cyan
		if ($ProductFileVersion -lt '2.02') {
			Write-BISFLog -Msg "SDelete $ProductFileVersion is not supported; please use version 2.02 or newer" -ShowConsole -Type W
			Start-Sleep -Seconds 20
			return
		}

		Write-BISFLog -Msg "Supported SDelete version detected; processing configuration" -ShowConsole

		$DiskModeBase = $DiskMode -replace 'AndSkipImaging', '' -replace 'AppLayering$', ''

		# Citrix PVS image on the write-cache disk in shared image mode
		if (($LIC_BISF_CLI_SD_runPVSCacheDisk -eq 1) -and ($DiskModeBase -eq 'ReadOnly') -and ($LIC_BISF_CLI_WCD -ne 'NONE')) {
			Write-BISFLog -Msg "Running SDelete on PVS write-cache disk drive $LIC_BISF_CLI_WCD" -ShowConsole -Color DarkCyan -SubMsg
			Start-BISFProcWithProgBar -ProcPath $SDeletePath -Args "-accepteula -z $($LIC_BISF_CLI_WCD)" -ActText "SDelete is zeroing free space on drive $LIC_BISF_CLI_WCD"
		}

		# Citrix MCS IO on persistent cache disk in shared image mode
		if (($LIC_BISF_CLI_SD_runMCSIO -eq 1) -and ($DiskModeBase -eq 'VDAShared') -and ($LIC_BISF_CLI_MCSIODriveLetter -ne 'NONE') -and ($MCSIO -eq $true)) {
			Write-BISFLog -Msg "Running SDelete on MCS IO cache disk drive $LIC_BISF_CLI_MCSIODriveLetter" -ShowConsole -Color DarkCyan -SubMsg
			Start-BISFProcWithProgBar -ProcPath $SDeletePath -Args "-accepteula -z $($LIC_BISF_CLI_MCSIODriveLetter)" -ActText "SDelete is zeroing free space on drive $LIC_BISF_CLI_MCSIODriveLetter"
		}

		# Citrix MCS on system drive in shared image mode
		if (($LIC_BISF_CLI_SD_runMCS -eq 1) -and ($DiskModeBase -eq 'VDAShared') -and ($MCSIO -eq $false)) {
			Write-BISFLog -Msg "Running SDelete on MCS system drive $env:SystemDrive" -ShowConsole -Color DarkCyan -SubMsg
			Start-BISFProcWithProgBar -ProcPath $SDeletePath -Args "-accepteula -z $($env:SystemDrive)" -ActText "SDelete is zeroing free space on drive $env:SystemDrive"
		}
	}

	function Start-WindowsUpdateService {
		[CmdletBinding()]
		param()

		Write-BISFLog -Msg "Starting Windows Update service" -ShowConsole -Color DarkCyan -SubMsg
		Invoke-BISFService -ServiceName wuauserv -Action Start -StartType Automatic
	}

	function Set-SihScheduledTask {
		[CmdletBinding()]
		param (
			[Parameter(Mandatory = $true)]
			[ValidateSet('Enable', 'Disable')]
			[string]$Mode
		)

		$TaskName = 'sih'
		$Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
		if ($Task) {
			Write-BISFLog -Msg "Scheduled task $TaskName exists" -ShowConsole -Color Cyan
			$TaskPathName = $Task.TaskPath
			switch ($Mode) {
				Disable {
					Write-BISFLog -Msg "Disabling scheduled task $TaskName" -ShowConsole -SubMsg -Color DarkCyan
					Disable-ScheduledTask -TaskName $TaskName -TaskPath $TaskPathName | Out-Null
				}
				Enable {
					Write-BISFLog -Msg "Enabling scheduled task $TaskName" -ShowConsole -SubMsg -Color DarkCyan
					Enable-ScheduledTask -TaskName $TaskName -TaskPath $TaskPathName | Out-Null
				}
			}
		}
		else {
			Write-BISFLog -Msg "Scheduled task $TaskName does not exist" -ShowConsole -SubMsg -Color DarkCyan
		}
	}
	#endregion

	Write-BISFLog -Msg "Running system startup actions if needed..." -ShowConsole -Color Cyan
	$Global:DiskMode = Get-BISFDiskMode
	$IsAppLayering = $DiskMode -like '*AppLayering'
	$DiskModeBase = $DiskMode -replace 'AndSkipImaging', '' -replace 'AppLayering$', ''

	switch ($DiskModeBase) {
		ReadWrite {
			Write-BISFLog -Msg "Running actions for $DiskMode disk mode" -ShowConsole -Color DarkCyan -SubMsg
			if (-not $IsAppLayering -or $CTXAppLayerName -eq 'OS-Layer') {
				Start-WindowsUpdateService
				Set-SihScheduledTask -Mode Enable
			}
		}
		ReadOnly {
			Write-BISFLog -Msg "Running actions for $DiskMode disk mode" -ShowConsole -Color DarkCyan -SubMsg
			Set-SihScheduledTask -Mode Disable
			Start-SDelete
		}
		Unmanaged {
			Write-BISFLog -Msg "Running actions for $DiskMode disk mode" -ShowConsole -Color DarkCyan -SubMsg
			if ($IsAppLayering -and $CTXAppLayerName -eq 'OS-Layer') {
				Start-WindowsUpdateService
				Set-SihScheduledTask -Mode Enable
			}
		}
		VDAPrivate {
			Write-BISFLog -Msg "Running actions for $DiskMode disk mode" -ShowConsole -Color DarkCyan -SubMsg
			if (-not $IsAppLayering -or $CTXAppLayerName -eq 'OS-Layer') {
				Start-WindowsUpdateService
				Set-SihScheduledTask -Mode Enable
			}
		}
		VDAShared {
			Write-BISFLog -Msg "Running actions for $DiskMode disk mode" -ShowConsole -Color DarkCyan -SubMsg
			Set-SihScheduledTask -Mode Disable
			Start-SDelete
		}
		Default {
			Write-BISFLog -Msg "Default action selected; doing nothing" -ShowConsole -Color DarkCyan
		}
	}
}

End {
	Add-BISFFinishLine
}
