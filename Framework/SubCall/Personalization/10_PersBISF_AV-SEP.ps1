<#
	.SYNOPSIS
		Prepare Symantec Endpoint Protection for Image Management Software
	.DESCRIPTION
	  	Create HostID based on MACAddress
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
		24.09.2012 MS: Script created
		18.09.2013 MS: replace $date with $(Get-date) to get current timestamp at running script lines write to the log file
		18.09.2013 MS: replace $PVsWriteCacheDisk to global environment variable $LIC_PVS_HostIDPath
		17.12.2013 MS: change service to smc -start for SEP 12 or higher
		27.01.2014 MS: $HostID_Prfx = "00000000000000000000"
		27.01.2014 MS: Set-Location $SEP_path
		28.01.2014 MS: $service_name = "cmd /c smc -start"
		28.01.2014 MS: $reg_SEP_name
		10.03.2014 MS: Review Code
		11.03.2014 MS: IF (Test-Path ("$SEP_path\smc.exe"))
		18.03.2014 BR: revisited Script
		13.08.2014 MS: remove $LogFile = Set-LogFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
		17.08.2014 MS: change line 32 to $SEP_path = "$ProgramFilesx86\Symantec\Symantec Endpoint Protection"
		31.08.2015 MS: Fixed 89 - symantec fixes the registry location for the SEP-Client to WOW6432Node, fix in line 31-32 and function SetHostID
		01.09.2015 MS: Fixed 89 successful tested
		06.10.2015 MS: rewritten script with standard .SYNOPSIS, central BISF function couldn't used for services, SEP Service must being started with smc.exe
		09.01.2017 MS: Change code to get Mac address to use function Get-BISFMACAddress
		01.07.2018 MS: Hotfix 49: After SEP is started with smc.exe, sometimes the service will not be started. Controlled and logged now with Test-BISFServiceState in Line 58
		18.02.2020 JK: Fixed Log output spelling
		19.02.2020 MS: HF 212 - SEP duplicate HardwareID - Get-BISFMacAddress returns lower- instead of uppercase MACAddress -> compare HardwareID after ServiceStart
		14.04.2023 TR: HF 371 - Support both 32 bit and 64 bit locations. Reduce usage of global variables in functions. Use approved verbs.

#>

Begin {
	# define environment
	$PSScriptFullName = $MyInvocation.MyCommand.Path
	$PSScriptRoot = Split-Path -Parent $PSScriptFullName
	$PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)

	# define product
	$RegSEPString = "Symantec\Symantec Endpoint Protection\SMC\SYLINK\SyLink"	
	$Reg2Check = "SerialNumber"
	$RegSEPName = "HardwareID"
	$HostIDPrfx = "00000000000000000000"	
}

Process {

	function Get-SepPath
	{
		if(Test-Path -Path "C:\Program Files\Symantec\Symantec Endpoint Protection")
		{
			"C:\Program Files\Symantec\Symantec Endpoint Protection"
		}
		elseif (Test-Path -Path "C:\Program Files (x86)\Symantec\Symantec Endpoint Protection") {
			"C:\Program Files (x86)\Symantec\Symantec Endpoint Protection"
		}
		else {
			$null
		}
	}

	function Get-SepSmcExePath
	{
		$SepPath = Get-SepPath
		if($null -ne $SepPath)
		{
			"$SepPath\smc.exe"
		}
		else {
			$null
		}
	}

	function Get-SepRegPath
	{
		if(Test-Path -Path "HKLM:\SOFTWARE\$RegSEPString")
		{
			"HKLM:\SOFTWARE\$RegSEPString"
		}
		elseif (Test-Path -Path "HKLM:\WOW6432Node\$RegSEPString") {
			"HKLM:\WOW6432Node\$RegSEPString"
		}
		else
		{
			$null
		}		
	}

	function Test-SepIsInstalled
	{
		$RegPath = Get-SepRegPath
		$RegPathExists = ($null -ne $RegPath)
		Write-Verbose "RegPathExists ('$RegPath'): $RegPathExists"
		$SmcExe = Get-SepSmcExePath
		$SmcExeExists = ($null -ne $SmcExe) -and (Test-Path -Path $SmcExe -PathType Leaf)
		Write-Verbose "smcExeExists ('$SmcExe'): $SmcExeExists"
		$RegPathExists -and $SmcExeExists
	}

	function Test-SepHasSerialNumber
	{
		$SepRegPath = Get-SepRegPath
		if($null -ne $SepRegPath)
		{			
			Test-BISFRegistryValue -Path $SepRegPath -Value $Reg2Check
		}
		else {
			$false
		}
	}
	
	function Get-SepHostId
	{
		Get-ItemPropertyValue -Path $(Get-SepRegPath) -Name $RegSEPName
	}

	function Set-SepHostId
	{
		param(
			[Parameter(Mandatory=$true)]
			[string]
			$RegHostID
			)
		Set-ItemProperty -Path $(Get-SepRegPath) -Name $RegSEPName -Value $RegHostID -ErrorAction SilentlyContinue
	}

	## set HostID in Registry
	function New-SEPHostID {
		param(
			[Parameter(Mandatory=$true)]
			$MacAddress
		)	
		
		$TestSEPinReg = Test-SepHasSerialNumber		

		IF ($TestSEPinReg -eq $true) {
			Write-BISFLog -Msg "Registry Location for specified SEP Keys will be set to $(Get-SepRegPath))"			
			Write-BISFLog -Msg "$RegSEPName Prefix: $HostIDPrfx"
			$RegHostID = $HostIDPrfx + $MacAddress
			Write-BISFLog -Msg "$RegSEPName will be defined as: $RegHostID"
			Write-BISFLog -Msg "set $RegSEPName in Registry $(Get-SepRegPath)"
			Set-SEPHostId -RegHostID $RegHostID | Out-Null
			Write-Output -InputObject $RegHostID
		}
		ELSE {
			Write-BISFLog -Msg "Registry Location for specified SEP Keys could not be set to $(Get-SepRegPath)" -Type W -SubMsg
			Write-BISFLog -Msg "The Value $Reg2Check does not exist in the above location!" -Type W -SubMsg
			Write-BISFLog -Msg "The SEP Service will be started, but each boot will create ghost entries in the SEP Management Server" -Type W -SubMsg
			Write-Output -InputObject $null
		}
	}

	

	## Start SEP Service
	function Start-SEP 
	{
		param(
			[Parameter(Mandatory=$false)]
			[string]
			$RegHostID=""
			)
		$ServiceName = "SepMasterService"
		Write-BISFLog -Msg "Start Service $($ServiceName)"
		& "$(Get-SepSmcExePath)" "-start"
		Test-BISFServiceState -ServiceName $ServiceName -Status "Running" | Out-Null
		$TestHardwareID = Get-SEPHostId
		IF ($TestHardwareID -eq $RegHostID) {
			Write-BISFLog -Msg "HardwareID in registry is set correctly: $TestHardwareID"
		} ELSE {
			Write-BISFLog -Msg "After the AV-Service is started, HardwareID in registry is NOT set correctly: Registry HardwareID $TestHardwareID <-> Defined HardwareID '$RegHostID'" -Type W -SubMsg
		}
	}
	####################################################################
	#TEST
	#$global:logFile = "c:\temp\bisf.log"
	#Import-Module ".\Framework\SubCall\Global\BISF.psd1"
	#### Main Program
	IF (Test-SepIsInstalled) {
		Write-BISFLog -Msg "Symantec Endpoint Protection installed" -ShowConsole -Color Cyan
		$RegHostId = New-SEPHostID -MacAddress $(Get-BISFMacAddress)
		Start-SEP -RegHostID $RegHostId
	}
	ELSE {
		Write-BISFLog -Msg "Symantec Endpoint Protection NOT installed"
	}
}


End {
	Add-BISFFinishLine
}
