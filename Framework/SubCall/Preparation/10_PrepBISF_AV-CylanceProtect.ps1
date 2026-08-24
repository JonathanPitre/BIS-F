<#
    .SYNOPSIS
        Prepare Cylance PROTECT Agent for Image Management
	.DESCRIPTION
      	Delete computer specific entries
    .EXAMPLE
    .NOTES
		Author:  Mathias Kowalkowski

		History
			09.05.2019 MK: Script created
			14.08.2019 MS: ENH 98: add function Set-CompatibilityMode
			02.01.2020 MS: HF 164: Wrong Command for Compatibility Mode
			01.06.2020 MS: HF 238: VDI Fingerprinting support
			01.08.2020 MS: HF 261 - fix error handling
#>

Begin {
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)

	# Product specific parameters
	$ProductName = "Cylance PROTECT"
	$ProductPath = "${env:ProgramFiles}\Cylance\Desktop"
	$ServiceName = "CylanceSvc"
	[array]$ToDelete = @(
		[PSCustomObject]@{type = "REG"; value = "HKLM:\SOFTWARE\Cylance\Desktop"; data = "FP" },
		[PSCustomObject]@{type = "REG"; value = "HKLM:\SOFTWARE\Cylance\Desktop"; data = "FPMask" },
		[PSCustomObject]@{type = "REG"; value = "HKLM:\SOFTWARE\Cylance\Desktop"; data = "FPVersion" },
		[PSCustomObject]@{type = "REG"; value = "HKLM:\SOFTWARE\Cylance\Desktop"; data = "SelfProtectionLevel" }
	)
}

Process {


	####################################################################
	####### Functions #####
	####################################################################

	function Remove-Data {
		Write-BISFLog -Msg "Delete specified items "
		Foreach ($DeleteItem in $ToDelete) {
			IF ($DeleteItem.type -eq "REG") {
				Write-BISFLog -Msg "Processing registry item to delete" -ShowConsole -SubMsg -Color DarkCyan
				$VerifyRegistryItem = Test-BISFRegistryValue -Path $DeleteItem.value -Value $DeleteItem.data
				IF ($VerifyRegistryItem) {
					Write-BISFLog -Msg "Deleting registry item -Path($DeleteItem.value) -Name($DeleteItem.data)"
					Remove-ItemProperty -Path $DeleteItem.value -Name $DeleteItem.data -ErrorAction SilentlyContinue
				}
			}

			IF ($DeleteItem.type -eq "FILE") {
				Write-BISFLog -Msg "Processing file item to delete" -ShowConsole -SubMsg -Color DarkCyan
				$FullFileName = "$DeleteItem.value\$DeleteItem.data"
				IF (Test-Path ($FullFileName) -PathType Leaf) {
					Write-BISFLog -Msg "Deleting File $FullFileName"
					Remove-Item $FullFileName | Out-Null
				}
			}
		}
	}
	function Stop-Service {
		$Svc = Test-BISFService -ServiceName "$ServiceName"
		IF ($Svc -eq $true) { Invoke-BISFService -ServiceName "$($ServiceName)" -Action Stop }
	}

	function Set-CompatibilityMode {
		<#
		.SYNOPSIS
		Set Cylance Compatibility Mode

		.DESCRIPTION
		As described in https://support.citrix.com/article/CTX232722
		you must take ownership of the registry and add a value to enable
		compatibility mode

		.NOTES
			Author: Matthias Schlimm

				14.08.2019 MS: function created
				01.08.2020 MS: HF 261 - fix error handling
		#>

		$CompatibilityMode = (Get-ItemProperty HKLM:\SOFTWARE\Cylance\Desktop).CompatibilityMode
        IF ($CompatibilityMode -ne 0) {
            $ErrorActionPreference = "Stop"
            Write-BISFLog -Msg "Take Registry Ownership" -ShowConsole -Color DarkCyan -SubMsg
		    #Adjust current user privileges
		    $null = Enable-BISFprivilege -Privilege SeTakeOwnershipPrivilege

		    #Take Ownership of Registry Key
		    $Key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SOFTWARE\Cylance\Desktop", [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership)
		    try {
			    $Acl = $Key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None)
                $Me = [System.Security.Principal.NTAccount]"$env:username"
		        $Acl.SetOwner($Me)
		        $Key.SetAccessControl($Acl)
		    }

            catch {
			    Write-BISFLog "ACL Error: $_" -Type W -ShowConsole -SubMsg
		    }



		    #Read current ACL and add rule for Builtin\Administrators
		    try {
                $Acl = $Key.GetAccessControl()
		        $Rule = New-Object System.Security.AccessControl.RegistryAccessRule ("$env:username", "FullControl", "Allow")
		        $Acl.SetAccessRule($Rule)
		        $Key.SetAccessControl($Acl)
		        $Key.Close()
            }

            catch {
			    Write-BISFLog "ACL Error: $_" -Type W -ShowConsole -SubMsg
		    }


		    Write-BISFLog -Msg "Set Compatibility Mode" -ShowConsole -Color DarkCyan -SubMsg
		    try {
                New-ItemProperty -Path "HKLM:\SOFTWARE\Cylance\Desktop" -Name "CompatibilityMode" -Value 01 -PropertyType Binary -Force
             }

            catch {
			    Write-BISFLog "ACL Error: $_" -Type W -ShowConsole -SubMsg
		    }
            $ErrorActionPreference = "Continue"
        } ELSE  {
            Write-BISFLog -Msg "Compatibility Mode is already set to $CompatibilityMode" -ShowConsole -Color DarkCyan -SubMsg
        }
}

	####################################################################
	####### End functions #####
	####################################################################

	#### Main Program
	$Svc = Test-BISFService -ServiceName $ServiceName -ProductName $ProductName
	If ($Svc -eq $true) {
		Write-BISFLog -Msg "Product $ProductName installed" -ShowConsole -Color Cyan
		$VDIType = (Get-ItemProperty HKLM:\SOFTWARE\Cylance\Desktop).VDIType
		IF (!($VDIType -eq 0)) {
			Stop-Service
			Set-CompatibilityMode
			Remove-Data
		} Else {
			Write-BISFLog -Msg "Skipping ProductName sealing operations !" -ShowConsole -Type W -SubMsg
		}


	}
 Else {
		Write-BISFLog -Msg "Product $ProductName NOT installed"
	}
}

End {
	Add-BISFFinishLine
}