<#
	.SYNOPSIS
		Prepare CrowdStrike Falcon Sensor for VDI / golden-image sealing
	.DESCRIPTION
		Detects the Falcon sensor (CSFalconService / CSAgent), logs version and
		registry state for Citrix MCS/PVS non-persistent sealing, and best-effort
		stops CSFalconService for a clean shutdown.

		CrowdStrike non-persistent VDI (Citrix MCS/PVS) guidance:
		- Install on the golden image with VDI=1 (not NO_START=1 alone)
		- Hosts must be domain-joined with a stable FQDN
		- Allow the sensor to reach the cloud and Sensor Update policy version,
		  then power off and snapshot
		- Lock the Sensor Update policy to the golden-image sensor version
		- Refreshing an existing image: uninstall (maintenance token if required)
		  then reinstall with VDI=1 before BIS-F seal  -  do not wipe AG registry keys

		This seal script does NOT install, uninstall, or delete AID registry values.
		Sensor Tampering Protection may block service stop; that is logged and is
		non-fatal for VDI=1 installs.

		Install example (deployment tooling, not run by this seal script):
		WindowsSensor.exe /install /quiet /norestart CID=<CID> VDI=1
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
	$CrowdStrikeRegRoot = 'HKLM:\SYSTEM\CrowdStrike\{9b03c1d9-3138-44ed-9fae-d9f4c034b88d}\{16e0423f-7058-48c9-a204-725362b67639}\Default'
	$AgSimPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\CSAgent\Sim'
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

	function Get-CrowdStrikeSensorInfo {
		$Info = [ordered]@{
			AgentVersion = $null
			CidPresent    = $false
			AgPresent     = $false
			AgSimPresent  = $false
		}

		if (Test-Path -LiteralPath $CrowdStrikeRegRoot) {
			try {
				$Props = Get-ItemProperty -LiteralPath $CrowdStrikeRegRoot -ErrorAction Stop
				if ($Props.PSObject.Properties.Name -contains 'AgentVersion') {
					$Info.AgentVersion = [string]$Props.AgentVersion
				}
				elseif ($Props.PSObject.Properties.Name -contains 'Version') {
					$Info.AgentVersion = [string]$Props.Version
				}
				if ($Props.PSObject.Properties.Name -contains 'CID' -and $Props.CID) {
					$Info.CidPresent = $true
				}
				if ($Props.PSObject.Properties.Name -contains 'AG') {
					$Info.AgPresent = $true
				}
			}
			catch {
				Write-BISFLog -Msg "Could not read Falcon registry at $CrowdStrikeRegRoot : $($_.Exception.Message)" -Type W -SubMsg
			}
		}

		if (Test-Path -LiteralPath $AgSimPath) {
			try {
				$Sim = Get-ItemProperty -LiteralPath $AgSimPath -ErrorAction SilentlyContinue
				if ($Sim -and ($Sim.PSObject.Properties.Name -contains 'AG')) {
					$Info.AgSimPresent = $true
				}
			}
			catch {
				Write-BISFLog -Msg "Could not read CSAgent Sim AG marker: $($_.Exception.Message)" -Type W -SubMsg
			}
		}

		return [PSCustomObject]$Info
	}

	function Write-CrowdStrikeSealGuidance {
		param (
			[PSCustomObject]$SensorInfo
		)

		Write-BISFLog -Msg "Citrix MCS/PVS non-persistent: install with VDI=1 (domain-joined, stable FQDN). See CrowdStrike non-persistent VDI article." -ShowConsole -Color DarkCyan -SubMsg
		Write-BISFLog -Msg "Lock Sensor Update policy to the golden-image sensor version before cloning." -SubMsg
		Write-BISFLog -Msg "Refreshing an image with Falcon already installed: uninstall (maintenance token if needed) then reinstall with VDI=1 before seal. Do not delete AG registry keys." -Type W -SubMsg
		Write-BISFLog -Msg "NO_START=1 alone is for persistent VM templates; VDI=1 NO_START=1 is for Horizon linked/instant clones  -  not Citrix MCS/PVS pooled." -SubMsg

		if ($SensorInfo.AgPresent -or $SensorInfo.AgSimPresent) {
			Write-BISFLog -Msg "AID registry marker (AG) is present on this image. For VDI=1 non-persistent installs this is expected after cloud registration on the golden image. Duplicate AIDs across clones indicate a wrong install path (missing VDI=1) or a template that was rebooted after NO_START=1." -Type W -SubMsg
		}
	}

	function Stop-CrowdStrikeFalconService {
		[CmdletBinding(SupportsShouldProcess = $true)]
		[OutputType([bool])]
		param()

		$SvcObj = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
		if (-not $SvcObj) {
			Write-BISFLog -Msg "Service $ServiceName not found  -  nothing to stop" -SubMsg
			return $true
		}

		Write-BISFLog -Msg "Service $ServiceName state before stop: $($SvcObj.Status) (StartType=$($SvcObj.StartType))" -SubMsg
		if ($SvcObj.Status -eq 'Stopped') {
			Write-BISFLog -Msg "Service $ServiceName already stopped" -ShowConsole -Color DarkCyan -SubMsg
			return $true
		}

		if (-not $PSCmdlet.ShouldProcess($ServiceName, 'Stop service (keep Automatic start type)')) {
			return $true
		}

		try {
			# Keep Automatic so clones start Falcon and receive a unique AID via VDI mode
			$Svc = Test-BISFService -ServiceName $ServiceName -ProductName $Product
			if ($Svc -eq $true) {
				Invoke-BISFService -ServiceName $ServiceName -Action Stop -StartType Automatic
			}
			else {
				Stop-Service -Name $ServiceName -Force -ErrorAction Stop
			}
		}
		catch {
			Write-BISFLog -Msg "Could not stop $ServiceName (Sensor Tampering Protection may be enabled): $($_.Exception.Message). Continuing  -  VDI=1 seal does not require a stopped sensor." -Type W -ShowConsole -Color Yellow
			return $true
		}

		Start-Sleep -Seconds 2
		$After = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
		if ($After) {
			Write-BISFLog -Msg "Service $ServiceName state after stop attempt: $($After.Status)" -ShowConsole -Color DarkCyan -SubMsg
			if ($After.Status -ne 'Stopped') {
				Write-BISFLog -Msg "Service $ServiceName still running after stop attempt (tamper protection likely). Continuing seal." -Type W
			}
		}
		return $true
	}

	#### Main Program
	if (-not (Test-CrowdStrikeInstalled)) {
		Write-BISFLog -Msg "$Product not installed  -  skipping"
		return
	}

	Write-BISFLog -Msg "Preparing $Product for imaging (verify VDI install guidance + best-effort service stop)" -ShowConsole -Color Cyan

	$SensorInfo = Get-CrowdStrikeSensorInfo
	if ($SensorInfo.AgentVersion) {
		Write-BISFLog -Msg "$Product version: $($SensorInfo.AgentVersion)" -ShowConsole -Color Cyan -SubMsg
	}
	else {
		Write-BISFLog -Msg "$Product detected; version unknown (registry unreadable or missing AgentVersion)" -ShowConsole -Color Cyan -SubMsg
	}
	Write-BISFLog -Msg "CID present in registry: $($SensorInfo.CidPresent); AG present: $($SensorInfo.AgPresent); CSAgent Sim AG present: $($SensorInfo.AgSimPresent)" -SubMsg

	$Driver = Get-Service -Name $DriverServiceName -ErrorAction SilentlyContinue
	if ($Driver) {
		Write-BISFLog -Msg "Driver service $DriverServiceName state: $($Driver.Status)" -SubMsg
	}

	Write-CrowdStrikeSealGuidance -SensorInfo $SensorInfo

	$null = Stop-CrowdStrikeFalconService

	Write-BISFLog -Msg "$Product preparation complete. Power off the golden image and snapshot after Sensor Update policy version is correct. Clones must use unique FQDNs for AID assignment." -ShowConsole -Color Green
}

End {
	Add-BISFFinishLine
}
