<#
	.SYNOPSIS
		Reset the Remote Desktop Services licensing grace-period counter.
	.DESCRIPTION
		On Windows Server, deletes the protected L$RTMTIMEBOMB* value under
		HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod
		so a sealed golden image does not ship a depleted 120-day RDS grace period.
		Windows recreates the value on next boot. This does not replace RDS CALs.
		Compatible with Windows Server 2016 through 2025 (same registry contract).
	.NOTES
		Author: Matthias Schlimm

		History:
		14.04.2016 BR: Script created
		17.06.2016 BR: Added Filter for Operating System Type
		31.07.2020 MS: HF 268 - Using SID to translate it to the real name to support MUI Systems
		24.08.2026 JP: Reuse Enable-BISFPrivilege; target TIMEBOMB values only; Server 2016-2025 same key
#>

Begin {
	$GracePeriodPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod'
	$GracePeriodSubKey = 'SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod'
	$AdministratorsSid = 'S-1-5-32-544'
}

Process {
	if ($ProductType -ne 3) {
		Write-BISFLog -Msg "Skipping RDS grace period reset (ProductType $ProductType is not a member server)"
		return
	}

	Write-BISFLog -Msg "Resetting RDS licensing grace period" -ShowConsole -Color Cyan

	$null = Enable-BISFPrivilege -Privilege SeTakeOwnershipPrivilege
	$null = Enable-BISFPrivilege -Privilege SeRestorePrivilege

	$Key = $null
	try {
		$Key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
			$GracePeriodSubKey,
			[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
			[System.Security.AccessControl.RegistryRights]::TakeOwnership
		)

		if ($null -eq $Key) {
			Write-BISFLog -Msg "Registry key $GracePeriodSubKey was not yet created. It will be created when RDS Session Host is used. Reset is not required."
			return
		}

		$Administrators = (New-Object System.Security.Principal.SecurityIdentifier($AdministratorsSid)).Translate(
			[System.Security.Principal.NTAccount]
		)

		$OwnerAcl = $Key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None)
		$OwnerAcl.SetOwner($Administrators)
		$Key.SetAccessControl($OwnerAcl)

		$Acl = $Key.GetAccessControl()
		$Rule = New-Object System.Security.AccessControl.RegistryAccessRule(
			$Administrators,
			[System.Security.AccessControl.RegistryRights]::FullControl,
			[System.Security.AccessControl.AccessControlType]::Allow
		)
		$Acl.SetAccessRule($Rule)
		$Key.SetAccessControl($Acl)
	}
	catch {
		Write-BISFLog -Msg "Failed to take ownership of $GracePeriodSubKey : $($_.Exception.Message)" -Type W -ShowConsole -SubMsg
		return
	}
	finally {
		if ($null -ne $Key) {
			$Key.Close()
		}
	}

	try {
		$TsSetting = Get-CimInstance -Namespace 'root/CIMV2/TerminalServices' -ClassName Win32_TerminalServiceSetting -ErrorAction SilentlyContinue
		if ($null -ne $TsSetting) {
			$GraceDays = Invoke-CimMethod -InputObject $TsSetting -MethodName GetGracePeriodDays -ErrorAction SilentlyContinue
			if ($null -ne $GraceDays -and $null -ne $GraceDays.DaysLeft) {
				Write-BISFLog -Msg "RDS grace period days remaining before reset: $($GraceDays.DaysLeft)" -ShowConsole -Color DarkCyan -SubMsg
			}
		}
	}
	catch {
		# Best-effort only; plain member servers may lack TerminalServices WMI
	}

	$GracePeriodKey = Get-Item -Path $GracePeriodPath
	$TimebombValues = @($GracePeriodKey.Property | Where-Object { $_ -like '*TIMEBOMB*' })
	if ($TimebombValues.Count -eq 0) {
		Write-BISFLog -Msg "No TIMEBOMB value found under $GracePeriodSubKey"
		return
	}

	foreach ($ValueName in $TimebombValues) {
		Write-BISFLog -Msg "Deleting $ValueName" -ShowConsole -Color DarkCyan -SubMsg
		Remove-ItemProperty -Path $GracePeriodPath -Name $ValueName
	}
}

End {
	Add-BISFFinishLine
}
