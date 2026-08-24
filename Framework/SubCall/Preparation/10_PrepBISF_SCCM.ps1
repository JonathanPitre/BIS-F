#requires -version 3
<#
	.SYNOPSIS
		Prepare SCCM Client for Image Management
	.DESCRIPTION
		Delete computer specific entries
	.EXAMPLE
		./10_PrepBISF_SCCM.ps1
	.NOTES
		Author: Matthias Schlimm

		History:
		26.03.2014 MS: Script created for SCCM 2012 R2
		01.04.2014 MS: Change Console message
		02.05.2014 MS: BUG code-error certstore SMS not deleted > & Invoke-Expression 'certutil -delstore SMS "SMS"'
		11.08.2014 MS: Remove Write-Host change to Write-BISFLog
		13.08.2014 MS: Remove $LogFile = Set-LogFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
		19.02.2015 MS: Syntax error and error handling
		06.03.2015 MS: Delete CCM Package Cache
		05.05.2015 MS: #temp. deactivate Remove-CCMCache , some errors more testing
		01.09.2015 MS: Fixed 42 - Fixed deleteCCMCache, this must be running before service stops
		30.09.2015 MS: Rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		10.05.2019 JP: Added command to remove hardware inventory as recommended by Citrix https://support.citrix.com/article/CTX238513
		10.05.2019 JP: Converted wmic commands to Get-CimInstance and reworked script syntax
		14.05.2019 JP: The CcmExec service is no longer set to manual
		08.12.2019:JP: Fixed error on line 74, thanks to Brian Timp
		20.12.2019 MS/SF: HF 153 (PR) - SCCM Agent preparation - fix Test-BISFService - parameter cannot be found
		21.11.2020 MS: HF 289 - terminate ccmexec process before stopping the service
		09.12.2020 MS: HF 296 - additional sealing steps are required
#>

Begin {
	$PSScriptFullName = $MyInvocation.MyCommand.Path
	$PSScriptRoot = Split-Path -Parent $PSScriptFullName
	$PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)
	[string]$AppVendor = 'Microsoft'
	[string]$AppName = "SCCM Agent"
	[string]$AppInstallPath = "$env:windir\CCM"
	[string]$AppService = 'CcmExec'
	[string]$AppRegKey = "$HklmSoftware\Microsoft\SystemCertificates\SMS\Certificates"
	$CryptoPath = "C:\ProgramData\Microsoft\Crypto"
	$CryptoKey = "Keys"
	$OldCryptoKey = "KeysOLD"
	$CryptoKeyPath = $CryptoPath + "\" + $CryptoKey
	$OldCryptoKeyPath = $CryptoPath + "\" + $OldCryptoKey
}

Process {

	function Remove-CCMData {
		Write-BISFLog -Msg "$AppVendor $AppName SMSCFG.ini was deleted"
		Remove-Item -Path "$env:windir\SMSCFG.ini" -Force -ErrorAction SilentlyContinue

		Write-BISFLog -Msg "$AppVendor $AppName certificates from SMS store were removed"
		Remove-Item -Path $AppRegKey\* -Force

		Write-BISFLog -Msg "$AppVendor $AppName site key information was reset"
		Get-CimInstance -Namespace root\ccm\locationservices -Class TrustedRootKey | Remove-CimInstance

		Write-BISFLog -Msg "$AppVendor $AppName hardware inventory was deleted"
		Get-CimInstance -Namespace root\ccm\invagt -Class InventoryActionStatus | Where-Object { $_.InventoryActionID -eq "{00000000-0000-0000-0000-000000000001}" } | Remove-CimInstance

		Write-BISFLog -Msg "$AppVendor $AppName scheduler history deleted"
		Get-CimInstance -Namespace root\ccm\scheduler -Class CCM_Scheduler_History | Where-Object { $_.ScheduleID -eq "{00000000-0000-0000-0000-000000000001}" } | Remove-CimInstance

		$DSRegValue = Get-BISFDSRegState -Key "AzureADjoined"
		IF ($DSRegValue -eq "YES") {
			Write-BISFLog -Msg "Leaving AAD"
			Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\dsregcmd.exe" -Args "/leave" -ActText "leaving AAD"
			Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\dsregcmd.exe" -Args "/status" -ActText "Displays the device join status"
		}

		Write-BISFLog -Msg "Rename Folder $CryptoKeyPath to $OldCryptoKey"
		Rename-Item -Path $CryptoKeyPath -NewName $OldCryptoKey -Force

		Write-BISFLog -Msg "Create folder Rename $CryptoKeyPath"
		New-Item -Path $CryptoKeyPath -ItemType Directory

		Write-BISFLog -Msg "Set ACL to $CryptoKeyPath"
		Get-Acl -Path $OldCryptoKeyPath | Set-Acl -Path $CryptoKeyPath

	}

	# Original source http://www.david-obrien.net/2013/02/how-to-configure-the-configmgr-client
	function Remove-CCMCache {
		[CmdletBinding()]
		$UIResourceMgr = New-Object -ComObject UIResource.UIResourceMgr
		$Cache = $UIResourceMgr.GetCacheInfo()
		$CacheElements = $Cache.GetCacheElements()
		foreach ($Element in $CacheElements) {
			Write-BISFLog -Msg "$AppVendor $AppName deleted Cache Element with PackageID $($Element.ContentID)"
			Write-BISFLog -Msg "from folder $($Element.Location)"
			$Cache.DeleteCacheElement($Element.CacheElementID)
		}
	}

	$Svc = Test-BISFService -ServiceName $AppService
	IF ($Svc -eq $true) {
		Remove-CCMCache # 01.09.2015 MS: Remove-CCMCache must be run before stopping the service
		Write-BISFLog -Msg "Terminating process $AppService" -ShowConsole -Color DarkCyan -SubMsg
		Stop-Process -Name $AppService -Force -ErrorAction SilentlyContinue
		Invoke-BISFService -ServiceName $AppService -Action Stop
		Remove-CCMData
	}
}

End {
	Add-BISFFinishLine
}
