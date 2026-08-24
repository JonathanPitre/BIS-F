<#
	.SYNOPSIS
		Prepare Microsoft AppV for Image Management
	.DESCRIPTION
	  	Reconfigure the Microsoft AppV
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
		21.08,2015 MS: function created
		30.09.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		03.03.2016 MS: Issue 113 - AppVClient Cache did not resolve to correct service status, thx to @valentinop
		10.01.2017 MS: add CLI command or message box to delete PreCached App-V Packages
		24.11.2017 MS: add SubMSg do Write-BISFLog -Msg "The App-V PackageInstallationRoot $PckInstRoot Folder not exist, nothing to clean up." -Type W -SubMsg
		14.08.2019 MS: FRQ 3 - Remove message box and using default setting if GPO is not configured
		18.02.2020 JK: Fixed Log output spelling
		20.02.2020 MS: HF 210 - App-V PackageInstallationRoot not detected properly
		23.05.2020 MS: HF 226 - App-V Powershell Module Could Not Be Loaded
#>

Begin {
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)
	$Product = "Microsoft App-V Client"
	$ServiceName = "AppVClient"
}

Process {

	function PrepareAgent {
		$AppvsvcStatus = Get-Service -Name $ServiceName
		If ($AppvsvcStatus.Status -ne "Running") {
			Write-BISFLog "The client service is not running. The Script cannot clean up package files." -Type W -SubMsg
		}
		ELSE {
			$HklmPath = "HKLM:\Software\Microsoft\AppV\Client"
			$InstallPath = (Get-ItemProperty -path $HklmPath).InstallPath
			$ModuleFile = "AppvClient.psd1"
			$AppVPath = (Get-ChildItem -Path $InstallPath -Recurse -Filter $ModuleFile -ErrorAction SilentlyContinue).Directory.FullName
			$ModulePath = "$AppVPath\$ModuleFile"
			Write-BISFLog -Msg "AppV Module is located in path $AppVPath"
			$PckInstRoot = (Get-AppvClientConfiguration -name PackageInstallationRoot).value
			$PckInstRoot = [Environment]::ExpandEnvironmentVariables($PckInstRoot)
			if (!$PckInstRoot) {
				Write-BISFLog -Msg "PackageInstallationRoot is required for removing packages" -Type E -SubMsg
			}
			IF (Test-Path $PckInstRoot) {

				Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
				$VarCLI = Get-Variable -Name LIC_BISF_CLI_AR -ValueOnly
				IF (($VarCLI -eq "YES") -or ($VarCLI -eq "NO")) {
					Write-BISFLog -Msg "GPO value:: $VarCLI"
				}
				ELSE {
					Write-BISFLog -Msg "GPO not configured.. using default setting""
					$AppVRemoval = "NO
				}
				if (($AppVRemoval -eq "YES" ) -or ($VarCLI -eq "YES")) {
					$PackageFiles = Get-ChildItem ([System.Environment]::ExpandEnvironmentVariables($PckInstRoot));
					if (!$PackageFiles -or $PackageFiles.Count -eq 0) {
						Write-BISFLog -Msg "No package files found, nothing to clean up." -Type W -SubMsg
					}
					ELSE {
						Write-BISFLog -Msg "Removing App-V packages" -ShowConsole -Color DarkGreen -SubMsg
						$error.clear();
						# load the client
						Import-Module $ModulePath;
						# shutdown all active Connection Groups
						Write-BISFLog -Msg "Stopping all connection groups.";
						Get-AppvClientConnectionGroup -all | Stop-AppvClientConnectionGroup -Global;

						# shutdown all active Connection Groups
						Write-BISFLog -Msg "Stopping all connection groups.";
						Get-AppvClientConnectionGroup -all | Stop-AppvClientConnectionGroup -Global;

						# poll while there are still active connection groups
						$ConnectionGroups = Get-AppvClientConnectionGroup -all
						$ConnectionGroupsInUse = $FALSE;
						do {
							$ConnectionGroupsInUse = $FALSE;
							ForEach ($ConnectionGroup in $ConnectionGroups) {
								if ($ConnectionGroup.InUse -eq $TRUE) {
									$ConnectionGroupsInUse = $TRUE;
									Write-BISFLog -Msg "Stopping connection groups" $ConnectionGroup.Name;
									Stop-AppvClientConnectionGroup $ConnectionGroup -Global;

									# allow 1 second for the VE to tear down before we continue polling
									Start-Sleep 1;
								}
							}
						} while ($ConnectionGroupsInUse);

						# shutdown all active Packages
						Write-BISFLog -Msg "Stopping all packages";
						Get-AppvClientPackage -all | Stop-AppvClientPackage -Global;

						# poll while there are still active packages
						$Packages = Get-AppvClientPackage -all;
						$PackagesInUse = $FALSE;
						do {
							$PackagesInUse = $FALSE;
							ForEach ($Package in $Packages) {
								if ($Package.InUse -eq $TRUE) {
									$PackagesInUse = $TRUE;
									Write-BISFLog -Msg "Stopping package " $Package.Name;
									Stop-AppvClientPackage $Package -Global;

									# allow 1 second for the VE to tear down before we continue polling
									Start-Sleep 1;
								}
							}
						} while ($PackagesInUse);

						Write-BISFLog -Msg "Removing all App-V Connection Groups";
						ForEach ($ConnectionGroup in Get-AppvClientConnectionGroup -all) {
							Remove-AppvClientConnectionGroup $ConnectionGroup;
						}

						Write-BISFLog -Msg "Removing all App-V Packages";
						ForEach ($Package in Get-AppvClientPackage -all) {
							Remove-AppvClientPackage $Package;
						}
					}
				}
				ELSE {
					Write-BISFLog -Msg "Skip removing the preCached App-V Packages"

				}
				$Error.Clear();
			}
			ELSE {
				Write-BISFLog -Msg "The App-V PackageInstallationRoot $PckInstRoot Folder does not exist, nothing to clean up." -Type W -SubMsg
			}
		}
	}

	#### Main Program

	$Svc = Test-BISFService -ServiceName "$ServiceName" -ProductName "$Product"
	IF ($Svc -eq $true) {
		PrepareAgent
	}
}


End {
	Add-BISFFinishLine
}