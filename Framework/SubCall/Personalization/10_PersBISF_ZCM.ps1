<#
	.SYNOPSIS
		Prepare Novell ZCM Agent for Image Management Software
	.DESCRIPTION
	.EXAMPLE
	.NOTES
		Author: Benjamin Ruoff


		History:
	  	04.03.2014 BR: Script created
		11.03.2014 MS: IF (Test-Path ("C:\Program Files (x86)\Novell\ZENworks\bin\zac.exe"))
		21.03.2014 MS: last code change before release to web
		12.05.2014 MS: Change from $ZCMConfigPath = "D:\ZCM\" to $ZCMConfigPath = "$PVSDiskDrive\ZCM\"
		12.05.2014 MS: get ZCM argument list from custom specified registry value -->> $LIC_PVS_ZCM_CFG
		13.08.2014 MS: remove $LogFile = Set-LogFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
		15.08.2014 MS: Add Else condition -> Write-BISFLog -Msg "ZENworks Configuration Management not installed"
		17.08.2014 MS: rewrite script for 32 bit and 64 bit, use $ProgramFilesx86 from function Get-OSInfo instead of hardcoded path
		10.02.2015 MS: rename syntax from PVS to BISF - $LIC_PVS_ZCM_CFG -> $LIC_BISF_ZCM_CFG
		06.10.2015 MS: rewritten script with standard .SYNOPSIS
		12.03.2017 MS: using $LIC_BISF_CLI_ZCM to configure ZCM with ADMX
		29.10.2017 MS: replace $DiskMode -eq "VDAShared", instead of MCSShared
		23.08.2026 JP: Skip zac register when ADMX POL_ZCM (LIC_BISF_CLI_ZCM) is empty
#>

Begin {
	$Product = "Novell ZCM Agent"
	$ServiceName = "Novell ZENworks Agent Service"
	$ZCMConfigPath = "$PVSDiskDrive\ZCM\"
	$ZCMConfigFiles = "DeviceData", "DeviceGUID", "initial-web-service"
	$PSScriptFullName = $MyInvocation.MyCommand.Path
	$PSScriptRoot = Split-Path -Parent $PSScriptFullName
	$PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)
}

Process {

	####################################################################
	####### functions #####
	####################################################################
	function CheckConfigFiles {
		$Result = $true
		foreach ($File in $ZCMConfigFiles) {
			if (!(Test-Path -Path $ZcmConfigPath$File -PathType Leaf)) {
				$Result = $false
			}
		}
		return $Result
	}

	####################################################################

	#### Main Program
	$Svc = Test-BISFService -ServiceName "$ServiceName" -ProductName "$Product"
	IF ($Svc -eq $true) {
		# Check Disk Mode
		$DiskMode = Get-BISFDiskMode


		if (($DiskMode -eq "ReadOnly") -or ($DiskMode -eq "VDAShared")) {
			Write-BISFLog -Msg "vDisk in Standard Mode, Processing ZCM Agent"
			if (!(CheckConfigFiles)) {
				Write-BISFLog -Msg "ZCM Config Files not valid, Clean Directory $ZCMConfigPath" -Type W  -SubMsg
				Get-ChildItem $ZCMConfigPath | Remove-Item -Force -ErrorAction SilentlyContinue

				Write-BISFLog -Msg "Starting ZCM Agent"
				Start-Service -Name 'Novell ZENworks Agent Service' -PassThru

				If ([string]::IsNullOrWhiteSpace($LIC_BISF_CLI_ZCM)) {
					Write-BISFLog -Msg "ADMX POL_ZCM is not configured (LIC_BISF_CLI_ZCM empty); skipping ZCM register" -Type W
				}
				Else {
					Write-BISFLog -Msg "Registering ZCM Agent with Arguments $LIC_BISF_CLI_ZCM"
					Start-Process -FilePath "$ProgramFilesx86\Novell\ZENworks\bin\zac.exe" -ArgumentList $LIC_BISF_CLI_ZCM
				}

				# Wait 3 Minutes before File Backup
				Start-Sleep -Seconds 180

				Write-BISFLog -Msg "Backup Config Files to $ZCMConfigPath"
				foreach ($File in $ZCMConfigFiles) {
					Copy-Item -Path "$ProgramFilesx86\Novell\ZENworks\conf\$File" -Destination $ZCMConfigPath -Force
				}

			}
			else {
				Write-BISFLog -Msg "Valid Backup Date Found in $ZCMConfigPath, Restoring"
				Get-ChildItem $ZCMConfigPath | Copy-Item -Destination "$ProgramFilesx86\Novell\ZENworks\conf" -Force

				Write-BISFLog -Msg "Starting ZCM Agent"
				Start-Service -Name 'Novell ZENworks Agent Service' -PassThru

			}
		}
		else {
			Write-BISFLog -Msg "vDisk in not in Standard Mode ($DiskMode), Skipping ZCM Agent preparation" -Type W -SubMsg
		}

	}

}
End {
	Add-BISFFinishLine
}