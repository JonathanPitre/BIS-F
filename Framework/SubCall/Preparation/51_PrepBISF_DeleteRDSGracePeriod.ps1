<#
	.SYNOPSIS
		Delete RDS Grace Period Registry Key
	.DESCRIPTION
		Delete RDS Timebomb Key for never ending grace Period
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
		14.04.2016 BR: Script created
		17.06.2016 BR: Added Filter for Operating System Type
		31.07.2020 MS: HF 268 - Using SID to translate it to the real name to support MUI Systems
#>

Begin {
	$RootBISFFolder = Split-Path (Split-Path $LIC_BISF_MAIN_PersScript)
	$Product = $FrameworkName
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)

	function Enable-Privilege {
		param(
			# The privilege to adjust. This set is taken from
			# https://msdn.microsoft.com/en-us/library/bb530716(VS.85).aspx
			[ValidateSet(
				"SeAssignPrimaryTokenPrivilege", "SeAuditPrivilege", "SeBackupPrivilege",
				"SeChangeNotifyPrivilege", "SeCreateGlobalPrivilege", "SeCreatePagefilePrivilege",
				"SeCreatePermanentPrivilege", "SeCreateSymbolicLinkPrivilege", "SeCreateTokenPrivilege",
				"SeDebugPrivilege", "SeEnableDelegationPrivilege", "SeImpersonatePrivilege", "SeIncreaseBasePriorityPrivilege",
				"SeIncreaseQuotaPrivilege", "SeIncreaseWorkingSetPrivilege", "SeLoadDriverPrivilege",
				"SeLockMemoryPrivilege", "SeMachineAccountPrivilege", "SeManageVolumePrivilege",
				"SeProfileSingleProcessPrivilege", "SeRelabelPrivilege", "SeRemoteShutdownPrivilege",
				"SeRestorePrivilege", "SeSecurityPrivilege", "SeShutdownPrivilege", "SeSyncAgentPrivilege",
				"SeSystemEnvironmentPrivilege", "SeSystemProfilePrivilege", "SeSystemtimePrivilege",
				"SeTakeOwnershipPrivilege", "SeTcbPrivilege", "SeTimeZonePrivilege", "SeTrustedCredManAccessPrivilege",
				"SeUndockPrivilege", "SeUnsolicitedInputPrivilege")]
			$Privilege,
			# The process on which to adjust the privilege. Defaults to the current process.
			$ProcessId = $pid,
			# Switch to disable the privilege, rather than enable it.
			[Switch] $Disable
		)

		# Taken from P/Invoke.NET with minor adjustments.
		$Definition = @'
	 using System;
	 using System.Runtime.InteropServices;

	 public class AdjPriv
	 {
		[DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
		internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
		 ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);

		[DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
		internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
		[DllImport("advapi32.dll", SetLastError = true)]
		internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
		[StructLayout(LayoutKind.Sequential, Pack = 1)]
		internal struct TokPriv1Luid
		{
		 public int Count;
		 public long Luid;
		 public int Attr;
		}

		internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
		internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
		internal const int TOKEN_QUERY = 0x00000008;
		internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
		public static bool EnablePrivilege(long processHandle, string privilege, bool disable)
		{
		 bool retVal;
		 TokPriv1Luid tp;
		 IntPtr hproc = new IntPtr(processHandle);
		 IntPtr htok = IntPtr.Zero;
		 retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
		 tp.Count = 1;
		 tp.Luid = 0;
		 if(disable)
		 {
		tp.Attr = SE_PRIVILEGE_DISABLED;
		 }
		 else
		 {
		tp.Attr = SE_PRIVILEGE_ENABLED;
		 }
		 retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
		 retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
		 return retVal;
		}
	 }
'@

		$ProcessHandle = (Get-Process -id $ProcessId).Handle
		$Type = Add-Type $Definition -PassThru
		$Type[0]::EnablePrivilege($ProcessHandle, $Privilege, $Disable)
	}
}

Process {

	if ((Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -eq "3") {
		# Adjust current uSer privileges
		Enable-Privilege SeTakeOwnershipPrivilege

		# Take Ownership of Registry Key
		$Key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod", [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::takeownership)
		if($null -eq $Key) {
			Write-BISFLog "Registry key SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod was not yet created. It will be created as soon as a user logs on. Reset will not be required."
			return
		}
		$Acl = $Key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None)
		$SID = "S-1-5-32-544" # Builtin\Administrators
		$ObjSID = New-Object System.Security.Principal.SecurityIdentifier($SID)
		$ObjUser = $ObjSID.Translate([System.Security.Principal.NTAccount])
		$LocalName = $ObjUser.Value
		$Me = [System.Security.Principal.NTAccount]$LocalName
		$Acl.SetOwner($Me)
		$Key.SetAccessControl($Acl)

		# Read current ACL and add rule for Builtin\Administrators
		$Acl = $Key.GetAccessControl()
		$Rule = New-Object System.Security.AccessControl.RegistryAccessRule ($LocalName, "FullControl", "Allow")
		$Acl.SetAccessRule($Rule)
		$Key.SetAccessControl($Acl)
		$Key.Close()

		# Search Timebomb Key and delete it
		$Items = $null
		$Item = $null

		$Items = Get-Item "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod"
		foreach ($Item in $Items) {
			if ($Item.Property -like "*TIMEBOMB*") {
				Write-BISFLog -Msg "Deleting $($Item.Property)"
				Remove-ItemProperty -path $Item.PSPath -Name $Item.Property #-WhatIf
			}
		}
	}
}

End {
	Add-BISFFinishLine
}