[CmdletBinding(SupportsShouldProcess = $true)]
param(
)
<#
	.SYNOPSIS
		Prepare PVSWriteCacheDisk
	.DESCRIPTION
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
		Editor: Mike Bijl (Rewritten variable names and script format)


		History:
		28.02.2013 MS: Script created
		07.03.2013 MS: Read from diskpart, error to read substring, write empty uniqueID to registry
		25.06.2013 MS: Change location for temporary Diskpart file to %TEMP%
		12.09.2013 MS: Critical fix to get uniqueid on english display language only
		18.09.2013 MS: replace $date with $(Get-date) to get current timestamp at running script lines write to the log file
		01.10.2013 MS: add function SetRefSrv - Set Reference Server Hostname in registry to detect it in the personalize script to skip reboot
		03.03.2014 BR: Revisited Script
		18.03.2014 BR: revisited Script
		21.03.2014 MS: add setCDROM, last code change before release to web
		13.08.2014 MS: remove $LogFile = Set-LogFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
		13.08.2014 MS: Check if $returnCheckPVSSysVariable exists, then get uniqueID from persistent drive and set it to registry
		20.08.2014 MS: add line 70 -> get-LogContent -GetLogFile "$DiskpartFile"
		31.10.2014 MB: renamed variable: returnCheckPVSSysVariable -> returnTestPVSEnvVariable
		01.10.2015 MS: rewritten script to use central BISF function
		10.01.2017 MS: Fixed 134- PrepareWriteCacheDisk: add space on either side of the DriveLetter variable $SearVol, thx to Jeremy Saunders
		10.01.2017 MS: Fixed 134: PrepareWriteCacheDisk: MBR disk with 8 characters to get the right uniqueID from Diskpart only, PVS does not support GPT disk, see https://support.citrix.com/article/CTX139478 thx to Jeremy Saunders
		04.03.2017 MS: Fixed: DiskID is not language neutral, split string after ":" to read the right side only
		29.07.2017 MS: Feature Request 192: support GPT WriteCacheDisk
		25.08.2019 MS: ENH 128 - Disable any command if WriteCacheDisk is set to NONE
		05.10.2019 MS: HF 69 - If WriteCache disk on master is GPT partition then uniqueid doesn't match
		18.02.2020 JK: Fixed Log output spelling
		18.01.2021 MS: using PoSh standard verbs for functions

	#>

Begin {

	####################################################################
	# Define environment
	# Setting default variables ($PSScriptRoot/$LogFile/$PSCommand,$PSScriptFullname/$ScriptLibrary/LogFileName) independent on running script from console or ISE and the powershell version.
	If ($($host.name) -like "* ISE *") {
		# Running script from Windows Powershell ISE
		$PSScriptFullName = $psISE.CurrentFile.FullPath.ToLower()
		$PSCommand = (Get-PSCallStack).InvocationInfo.MyCommand.Definition
	}
	ELSE {
		$PSScriptFullName = $MyInvocation.MyCommand.Definition.ToLower()
		$PSCommand = $MyInvocation.Line
	}
	[string]$PSScriptName = (Split-Path $PSScriptFullName -leaf).ToLower()
	If (($PSScriptRoot -eq "") -or ($PSScriptRoot -eq $null)) { [string]$PSScriptRoot = (Split-Path $PSScriptFullName).ToLower() }

	$SystemDrive = $env:SystemDrive
	$RegValueUniqueId = "LIC_BISF_UniqueID_Disk"
	$RegValueRefSrvHostname = "LIC_BISF_RefSrv_Hostname"
	$PVSDiskLabel = "PVSWriteCacheDisk"
	$DiskpartFile = "C:\Windows\Temp\$Computer-DiskpartFile.txt"

	####################################################################
	####### functions #####
	####################################################################
	function Get-UniqueDiskID {
		<#
		.SYNOPSIS
		GetUniqueID

		.DESCRIPTION
		Write the UniqueID of the CacheDisk to the registry
		to use it later on the cloned devices


		.NOTES
		Author: Matthias Schlimm



		History:
		dd.mm.yyyy MS: Script created
		18.01.2021 MS: HF 302 using function Get-BISFDiskID instead of the same code here

		#>
		Get-BISFDiskID -DriveLetter $PVSDiskDrive -ThrowWhenNotFound $False
		Write-BISFLog -Msg "Set uniqueID $GetID for volume $VolNbr / DriveLetter $PVSDiskDrive to Registry $HklmBisfScripts"
		Set-ItemProperty -Path $HklmBisfScripts -Name $RegValueUniqueId -Value $DiskID -ErrorAction SilentlyContinue
	}

	function Set-ReferenceServer {
		[CmdletBinding(SupportsShouldProcess = $true)]
		param()

		# Set Reference Server Hostname in registry to detect it in the personalize script to skip reboot
		Write-BISFLog -Msg "Write Reference Server Hostname $Computer to Registry $HklmBisfScripts"
		if ($PSCmdlet.ShouldProcess("$HklmBisfScripts\$RegValueRefSrvHostname", 'Set reference server hostname')) {
			Set-ItemProperty -Path $HklmBisfScripts -Name $RegValueRefSrvHostname -Value $Computer -ErrorAction SilentlyContinue
		}
	}

	function Set-OpticalDrive {
		[CmdletBinding(SupportsShouldProcess = $true)]
		param()

		$CDrom = Get-CimInstance -ClassName Win32_Volume -Filter "DriveType = 5"
		$CDromDriveLetter = $CDrom.DriveLetter
		if ($PSCmdlet.ShouldProcess("$HklmBisfScripts\LIC_BISF_OptDrive", "Set optical DriveLetter $CDromDriveLetter")) {
			Set-ItemProperty -Path $HklmBisfScripts -Name "LIC_BISF_OptDrive" -Value $CDromDriveLetter
			Write-BISFLog -Msg "set optical DriveLetter $CDromDriveLetter"
		}
	}

	####################################################################
	####### end functions #####
	####################################################################
}
Process {

	#### Main Program
	IF (!($LIC_BISF_CLI_WCD -eq "NONE")) {
		IF ($ReturnTestPVSEnvVariable -eq $true) {
			Get-UniqueDiskID
		}
		ELSE {
			Write-BISFLog -Msg "CacheDisk environment variable not defined, skipping configuration"
		}
	}
 ELSE {
		Write-BISFLog -Msg "CacheDisk is set to 'NONE', skipping configuration"
	}
	Set-OpticalDrive
	Set-ReferenceServer
}
END {
	Add-BISFFinishLine
}