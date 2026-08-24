<#
	.SYNOPSIS
		Configure several System Startup Actions (SSA)
	.DESCRIPTION
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
#>

Begin {
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)
	#sdelete
	IF ($OSBitness -eq "32-bit") { $SdeleteVersion = "sdelete.exe" } ELSE { $SdeleteVersion = "sdelete64.exe" }
	IF ($LIC_BISF_CLI_SD_SF -eq "1") {
		$SDeletePath = "$($LIC_BISF_CLI_SD_SF_CUS)\$SdeleteVersion"
	}
 ELSE {
		$SDeletePath = "C:\Windows\system32\$SdeleteVersion"
	}

}

Process {

	# region functions
	function Start-SDelete {
		IF ($RunPersSdelete -eq $true) {
			IF ((Test-Path ("$SDeletePath") -PathType Leaf )) {
				$ProductFileVersion = (Get-Item "$SDeletePath").VersionInfo.FileVersion
				Write-BISFLog -Msg "Product SDelete $ProductFileVersion installed" -ShowConsole -Color Cyan
				IF ($ProductFileVersion -lt "2.02") {
					Write-BISFLog -Msg "WARNING: SDelete $ProductFileVersion is not supported, Please use Version 2.02 or newer !!" -ShowConsole -Type W
					Start-Sleep 20
				}
				ELSE {
					Write-BISFLog -Msg "Supported SDelete Version detected, processing configuration" -ShowConsole

					#Citrix PVS Image on the WriteCache Disk if the image is in shared image mode
					IF (($LIC_BISF_CLI_SD_runPVSCacheDisk -eq 1) -and ($DiskMode -eq "ReadOnly") -and ($LIC_BISF_CLI_WCD -ne "NONE")) {
						Write-BISFLog -Msg "Running SDelete on PVS WriteCacheDisk Drive $LIC_BISF_CLI_WCD" -ShowConsole -Color DarkCyan -SubMsg
						Start-BISFProcWithProgBar -ProcPath "$SDeletePath" -Args "-accepteula -z $($LIC_BISF_CLI_WCD)" -ActText "SDelete is running to Zero Out Free Space on drive $LIC_BISF_CLI_WCD"
					}

					#Citrix MCSIO on persistent CacheDisk if the image is in shared image mode
					IF (($LIC_BISF_CLI_SD_runMCSIO -eq 1) -and ($DiskMode -eq "VDAShared") -and ($LIC_BISF_CLI_MCSIODriveLetter -ne "NONE") -and ($MCSIO -eq $true)) {
						Write-BISFLog -Msg "Running SDelete on MCSIO CacheDisk Drive $LIC_BISF_CLI_MCSIODriveLetter" -ShowConsole -Color DarkCyan -SubMsg
						Start-BISFProcWithProgBar -ProcPath "$SDeletePath" -Args "-accepteula -z $($LIC_BISF_CLI_MCSIODriveLetter)" -ActText "SDelete is running to Zero Out Free Space on drive $LIC_BISF_CLI_MCSIODriveLetter"

					}

					#Citrix MCS on system drive if the image is in shared image mode
					IF (($LIC_BISF_CLI_SD_runMCS -eq 1) -and ($DiskMode -eq "VDAShared") -and ($MCSIO -eq $false)) {
						Write-BISFLog -Msg "Running SDelete on MCS SystemDrive $env:SystemDrive" -ShowConsole -Color DarkCyan -SubMsg
						Start-BISFProcWithProgBar -ProcPath "$SDeletePath" -Args "-accepteula -z $($env:SystemDrive)" -ActText "SDelete is running to Zero Out Free Space on drive $env:SystemDrive"
					}
				}

			}
			ELSE {
				Write-BISFLog -Msg "SDelete could not detected in Path $SDeletePath"
			}
		}
	}

	function Start-WindowsUpdateService {
		Write-BISFLog -Msg "Activating Windows Update Service" -ShowConsole -Color DarkCyan -SubMsg
		Invoke-BISFService -ServiceName wuauserv -Action Start -StartType Automatic
	}

	function Invoke-sihTask {

		param (
			[parameter(Mandatory = $true)][string]$Mode
		)

		$TaskName = "sih"
		$Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
		IF ($Task) {
			Write-BISFLog -Msg "Scheduled Task $TaskName already exists" -ShowConsole -Color Cyan
			$TaskPathName = Get-ScheduledTask -TaskName $Task | ForEach-Object { $_.TaskPath }
			Switch ($Mode) {
				Disable {
					Write-BISFLog -Msg "Disable Scheduled Task $TaskName" -ShowConsole -SubMsg -Color DarkCyan
					Disable-ScheduledTask -TaskName $ScheduledTaskList -TaskPath $TaskPathName | Out-Null
				}
				Enable {
					Write-BISFLog -Msg "Enable Scheduled Task $TaskName" -ShowConsole -SubMsg -Color DarkCyan
					Enable-ScheduledTask -TaskName $ScheduledTaskList -TaskPath $TaskPathName | Out-Null
				}

				Default {
					Write-BISFLog -Msg "Default Action selected, doing nothing" -ShowConsole -Color DarkCy
				}
			}
		}
		ELSE {
			Write-BISFLog -Msg "Scheduled Task $TaskName does NOT exist" -ShowConsole -SubMsg -Color DarkCyan
		}
	}

	#endregion

	Write-BISFLog -Msg "Running system startup actions if needed..." -ShowConsole -Color Cyan
	$Global:DiskMode = Get-BISFDiskMode
	Switch ($DiskMode) {
		ReadWrite {
			Write-BISFLog -Msg "Running Actions for $DiskMode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			Start-WindowsUpdateService
			Invoke-sihTask -Mode Enable
		}
		ReadOnly {
			Write-BISFLog -Msg "Running Actions for $DiskMode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			Invoke-sihTask -Mode Disable
			Start-SDelete
		}
		Unmanaged {
			Write-BISFLog -Msg "Running Actions for $DiskMode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
		}
		VDAPrivate {
			Write-BISFLog -Msg "Running Actions for $DiskMode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			Start-WindowsUpdateService
			Invoke-sihTask -Mode Enable
		}
		VDAShared {
			Write-BISFLog -Msg "Running Actions for $DiskMode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			Invoke-sihTask -Mode Disable
			Start-SDelete
		}
		ReadWriteAppLayering {
			Write-BISFLog -Msg "Running Actions for $DiskMode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			IF ($CTXAppLayerName -eq "OS-Layer") {
				Start-WindowsUpdateService
				Invoke-sihTask -Mode Enable
			}
		}
		ReadOnlyAppLayering {
			Write-BISFLog -Msg "Running Actions for $DiskMode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			Invoke-sihTask -Mode Disable
			Start-SDelete
		}
		UnmanagedAppLayering {
			Write-BISFLog -Msg "Running Actions for $DiskMode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			IF ($CTXAppLayerName -eq "OS-Layer") {
				Start-WindowsUpdateService
				Invoke-sihTask -Mode Enable
			}
		}
		VDAPrivateAppLayering {
			Write-BISFLog -Msg "Running Actions for $DiskMode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			IF ($CTXAppLayerName -eq "OS-Layer") {
				Start-WindowsUpdateService
				Invoke-sihTask -Mode Enable
			}
		}
		VDASharedAppLayering {
			Write-BISFLog -Msg "Running Actions for $DiskMode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			Invoke-sihTask -Mode Disable
		}

		Default { Write-BISFLog -Msg "Default Action selected, doing nothing" -ShowConsole -Color DarkCyan }

	}

}

End {
	Add-BISFFinishLine
}