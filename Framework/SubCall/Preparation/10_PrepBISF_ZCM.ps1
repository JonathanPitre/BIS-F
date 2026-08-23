[CmdletBinding(SupportsShouldProcess = $true)]
param(
)
<#
	.SYNOPSIS
		Prepare ZCM Agent for Imaging on Base Image
	.DESCRIPTION
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
		27.05.2015 MS: Script created
		01.10.2015 MS: Rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		12.03.2017 MS: Change $ZCMCliArgs=$LIC_BISF_ZCM_CFG to $ZCMCliArgs=$LIC_BISF_CLI_ZCM to configure ZCM with ADMX
		18.02.2020 JK: Fixed Log output spelling
		23.08.2026 JP: Honor ADMX POL_ZCM ($LIC_BISF_CLI_ZCM); the 2017 rename never landed. Guard empty args and test service status via Get-Service
#>

Begin {

	####################################################################
	# define environment

	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)

	# Product specified
	$Product = "Novell ZCM Agent"
	$ProductPath = $env:zenworks_home
	$ServiceName1 = "Novell ZENworks Agent Service"
	$ServiceName2 = "Novell Identity Store"
	$ServiceName3 = "nzwinvnc"
	$File1 = "$ProductPath\logs\preboot\novell-zisdservice.log"
	$File2 = "DeviceData", "DeviceGUID", "*.sav", "Guid.txt"
	$File3 = "initial-web-service"
	$Folder1 = "$ProductPath\cache\zmd\"
	$RegString1 = "$HklmSoftware\Wow6432Node\Novell\ZCM\PreAgent"
	$RegString2 = "$HklmSoftware\Wow6432Node\Novell\ZCM\Remote Management\Agent"
}

Process {

	####################################################################

	function PrepareAgent {

		If ((Get-Service -Name $ServiceName1 -ErrorAction SilentlyContinue).Status -eq 'Running') {
			Write-BISFLog -Msg "$Product Service is running, execute specified zac commands"
			$ZCMCliArgs = $LIC_BISF_CLI_ZCM
			$ZCMUser = $null
			$ZCMPassword = $null
			If ([string]::IsNullOrWhiteSpace($ZCMCliArgs)) {
				Write-BISFLog -Msg "ADMX POL_ZCM is not configured (LIC_BISF_CLI_ZCM empty); skipping zac unregister" -Type W
			}
			Else {
				Write-BISFLog -Msg "get username and password from configuration URL"
				$ZCMCliArgs = $ZCMCliArgs.Split(' ')
				$Cnt = 0
				ForEach ($Arg in $ZCMCliArgs) {
					IF ($Arg -eq "-u") {
						$ZCMUserCmd = $ZCMCliArgs[$Cnt]
						$ZCMUserVal = $ZCMCliArgs[$Cnt + 1]
						$ZCMUser = $ZCMUserCmd + " " + $ZCMUserVal
						Write-BISFLog -Msg "ZCM User for CLI command $ZCMUser"
					}

					IF ($Arg -eq "-p") {
						$ZCMPasswordCmd = $ZCMCliArgs[$Cnt]
						$ZCMPasswordVal = $ZCMCliArgs[$Cnt + 1]
						$ZCMPassword = $ZCMPasswordCmd + " " + $ZCMPasswordVal
						Write-BISFLog -Msg "ZCM Password for CLI command ********"
					}
					$Cnt++
				}
				If ([string]::IsNullOrWhiteSpace($ZCMUser) -or [string]::IsNullOrWhiteSpace($ZCMPassword)) {
					Write-BISFLog -Msg "ZCM unregister skipped; -u/-p not present in LIC_BISF_CLI_ZCM" -Type W
				}
			}

			Start-Process "zac" -ArgumentList "fsg -d"
			If (-not [string]::IsNullOrWhiteSpace($ZCMUser) -and -not [string]::IsNullOrWhiteSpace($ZCMPassword)) {
				Start-Process "zac" -ArgumentList "unr -f $ZCMUser $ZCMPassword"
			}
			Start-Process "zac" -ArgumentList "cc"

		}
		## stop Novell services
		Invoke-BISFService -ServiceName "$ServiceName1" -Action Stop
		Invoke-BISFService -ServiceName "$ServiceName2" -Action Stop
		Invoke-BISFService -ServiceName "$ServiceName3" -Action Stop


		#delete needed files and registry entries
		if (Test-Path -Path $File1 -PathType Leaf) {
			Write-BISFLog -Msg "delete file $File1"
			Remove-Item -path "$File1" -force
		}
		ELSE {
			Write-BISFLog -Msg "file $File1 NOT exist"
		}

		foreach ($File in $File2) {
			if (Test-Path -Path "$ProductPath\conf\$File" -PathType Leaf) {
				Write-BISFLog -Msg "delete file $ProductPath\conf\$File"
				Remove-Item -path "$ProductPath\conf\$File" -force
			}
			ELSE {
				Write-BISFLog -Msg "file $ProductPath\conf\$File does NOT exist"
			}

		}
		Write-BISFLog -Msg "remove GUID from $RegString1"
		Remove-ItemProperty -Path $RegString1 -Name "GUID" -force -ErrorAction SilentlyContinue

		Write-BISFLog -Msg "remove all custom entries from $RegString2"
		Remove-Item -Path $RegString2 -Exclude *Default*, *Device* -Recurse -Force -ErrorAction SilentlyContinue

		Write-BISFLog -Msg "remove all items in folder $Folder1"
		Remove-Item -Path $Folder1 -Recurse -Force -ErrorAction SilentlyContinue

		Write-BISFLog -Msg "Wipes the ZISD data including the ZISD header, see https://www.novell.com/support/kb/doc.php?id=7007665"
		& "$ProductPath\bin\preboot\ZISWin.exe" "-w"

		if (Test-Path -Path "$ProductPath\conf\$File3.bak" -PathType Leaf) {

			if (Test-Path -Path "$ProductPath\conf\$File3" -PathType Leaf) {
				Write-BISFLog -Msg "remove file $ProductPath\conf\$File3"
				Remove-Item -path "$ProductPath\conf\$File3" -force
			}
			Write-BISFLog -Msg "rename file $ProductPath\conf\$File3.bak"
			Rename-Item -path "$ProductPath\conf\$File3.bak" -NewName "$ProductPath\conf\$File3" -Force
		}
		ELSE {
			Write-BISFLog -Msg "file $ProductPath\conf\$File3.bak NOT exist"
		}


	}

	#### Main Program

	$Svc = Test-BISFService -ServiceName "$ServiceName1" -ProductName "$Product"
	IF ($Svc -eq $true) {
		PrepareAgent
	}

}

End {
	Add-BISFFinishLine
}