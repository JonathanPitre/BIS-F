<#
	.SYNOPSIS
		Personalize CrowdStrike Falcon Sensor after clone / first boot
	.DESCRIPTION
		Starts CSFalconService on provisioned MCS/PVS clones so the Falcon cloud
		can assign a unique Agent ID (AID) based on the host FQDN and other
		characteristics (CrowdStrike non-persistent VDI guidance).

		Expected clone behavior:
		- Golden image was installed with VDI=1 (Citrix MCS/PVS non-persistent)
		- Host is domain-joined with a unique, stable FQDN
		- This script starts the Falcon service; it does not invent a HostID

		Operator prerequisites (not stored in repo):
		- Sensor Update policy locked to the golden-image version
		- Install used VDI=1 (not NO_START=1 alone; not Horizon-only VDI=1 NO_START=1)
	.EXAMPLE
	.NOTES
		Author: Jonathan Pitre

		History:
		12.08.2026 JP: Script created for fork branch refactor/modernize (EUCweb/BIS-F#404)
	.LINK
		https://github.com/EUCweb/BIS-F/issues/404
	.LINK
		https://docs.crowdstrike.com/r/en-US/iopiipqy/paf4c833
	.LINK
		https://docs.crowdstrike.com/r/en-US/iopiipqy/g821cff2
	.LINK
		https://docs.crowdstrike.com/r/en-US/iopiipqy/s27aa744
	.LINK
		https://docs.crowdstrike.com/r/en-US/iopiipqy/jf3f7cda
	.LINK
		https://www.dell.com/support/kbdoc/en-us/000126124/how-to-install-crowdstrike-falcon-sensor
#>

Begin {
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)

	$Product = "CrowdStrike Falcon Sensor"
	$ServiceName = "CSFalconService"
	$DriverServiceName = "CSAgent"
	$InstallRoots = @(
		"${env:ProgramFiles}\CrowdStrike"
		"${env:ProgramFiles(x86)}\CrowdStrike"
		"${env:WinDir}\System32\drivers\CrowdStrike"
	)
}

Process {

	function Test-CrowdStrikeInstalled {
		foreach ($Root in $InstallRoots) {
			if (Test-Path -LiteralPath $Root) { return $true }
		}
		if (Test-Path -LiteralPath 'HKLM:\SYSTEM\CrowdStrike') { return $true }
		if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) { return $true }
		if (Get-Service -Name $DriverServiceName -ErrorAction SilentlyContinue) { return $true }
		return $false
	}

	function Start-CrowdStrikeFalconService {
		[CmdletBinding(SupportsShouldProcess = $true)]
		[OutputType([bool])]
		param()

		$SvcObj = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
		if (-not $SvcObj) {
			Write-BISFLog -Msg "Service $ServiceName not found  -  cannot start Falcon user-mode service" -Type W
			return $false
		}

		Write-BISFLog -Msg "Service $ServiceName state before start: $($SvcObj.Status)" -SubMsg
		if ($SvcObj.Status -eq 'Running') {
			Write-BISFLog -Msg "Service $ServiceName already running" -ShowConsole -Color DarkCyan -SubMsg
			return $true
		}

		if (-not $PSCmdlet.ShouldProcess($ServiceName, 'Start service')) {
			return $true
		}

		$Svc = Test-BISFService -ServiceName $ServiceName -ProductName $Product
		if ($Svc -eq $true) {
			Invoke-BISFService -ServiceName $ServiceName -Action Start -StartType Automatic
		}
		else {
			try {
				Start-Service -Name $ServiceName -ErrorAction Stop
			}
			catch {
				Write-BISFLog -Msg "Failed to start $ServiceName : $($_.Exception.Message)" -Type E
				return $false
			}
		}

		Start-Sleep -Seconds 2
		$After = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
		if ($After) {
			Write-BISFLog -Msg "Service $ServiceName state after start: $($After.Status)" -ShowConsole -Color DarkCyan -SubMsg
			if ($After.Status -ne 'Running') {
				Write-BISFLog -Msg "Service $ServiceName did not reach Running" -Type W
				return $false
			}
		}
		return $true
	}

	#### Main Program
	if (-not (Test-CrowdStrikeInstalled)) {
		Write-BISFLog -Msg "$Product not installed  -  skipping"
		return
	}

	Write-BISFLog -Msg "Personalizing $Product (start service; cloud assigns AID from FQDN)" -ShowConsole -Color Cyan

	$Driver = Get-Service -Name $DriverServiceName -ErrorAction SilentlyContinue
	if ($Driver) {
		Write-BISFLog -Msg "Driver service $DriverServiceName state: $($Driver.Status)" -SubMsg
	}
	else {
		Write-BISFLog -Msg "Driver service $DriverServiceName not found" -Type W -SubMsg
	}

	$Started = Start-CrowdStrikeFalconService
	if (-not $Started) {
		Write-BISFLog -Msg "$Product personalization could not confirm $ServiceName is running" -Type W
	}
	else {
		Write-BISFLog -Msg "$Product personalization complete. Unique AID is assigned by the CrowdStrike cloud for this FQDN." -ShowConsole -Color Green
	}
}

End {
	Add-BISFFinishLine
}
