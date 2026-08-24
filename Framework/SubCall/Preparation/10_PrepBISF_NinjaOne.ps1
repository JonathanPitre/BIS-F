<#
	.SYNOPSIS
		Prepare NinjaOne Agent for VDI / golden-image sealing
	.DESCRIPTION
		Stops the NinjaRMMAgent service and runs noclone.exe so each clone
		registers as a new device on first startup (NinjaOne clone guidance).

		Expected clone behavior:
		- After seal, NinjaRMMAgent remains stopped on the master image
		- Registration was cleared by noclone.exe
		- On first boot of a clone, the agent starts (Automatic) and registers as a new node

		If Ninja Backup (lockhart) is present, it is stopped and a warning is logged:
		perform cloning before enabling Ninja Backup on the golden image.
	.EXAMPLE
	.NOTES
		Author: Jonathan Pitre

		History:
		12.08.2026 JP: Script created for fork branch refactor/modernize

	.LINK
		https://www.ninjaone.com/docs/endpoint-management/clone-device-with-ninjaone-installed/
	.LINK
		https://ninjarmm.zendesk.com/hc/en-us/articles/115003694572-NinjaOne-Endpoint-Management-Clone-a-Device-with-NinjaOne-Installed
#>

Begin {
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)

	$Product = "NinjaOne Agent"
	$ServiceName = "NinjaRMMAgent"
	$BackupServiceName = "lockhart"
	$AgentDataRoot = Join-Path $env:ProgramData 'NinjaRMMAgent'
	$NoCloneExe = Join-Path $AgentDataRoot 'noclone.exe'
	$InstallRoots = @(
		"${env:ProgramFiles}\NinjaOne"
		"${env:ProgramFiles(x86)}\NinjaOne"
		"${env:ProgramFiles}\NinjaRMMAgent"
		"${env:ProgramFiles(x86)}\NinjaRMMAgent"
	)
}

Process {

	function Test-NinjaOneInstalled {
		if (Test-Path -LiteralPath $AgentDataRoot) { return $true }
		foreach ($Root in $InstallRoots) {
			if (Test-Path -LiteralPath $Root) { return $true }
		}
		$SvcObj = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
		if ($SvcObj) { return $true }
		return $false
	}

	function Stop-NinjaOneAgent {
		[CmdletBinding(SupportsShouldProcess = $true)]
		[OutputType([bool])]
		param()

		Write-BISFLog -Msg "Service $ServiceName state before stop: $((Get-Service -Name $ServiceName -ErrorAction SilentlyContinue).Status)" -SubMsg
		if (-not $PSCmdlet.ShouldProcess($ServiceName, 'Stop service')) {
			return $true
		}

		$Svc = Test-BISFService -ServiceName $ServiceName -ProductName $Product
		IF ($Svc -eq $true) {
			# Keep Automatic so clones start the agent and re-register as new devices
			Invoke-BISFService -ServiceName $ServiceName -Action Stop -StartType Automatic
		}
		else {
			Write-BISFLog -Msg "Service $ServiceName not found via Test-BISFService; attempting Stop-Service if present" -Type W
			$SvcObj = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
			if ($SvcObj -and $SvcObj.Status -ne 'Stopped') {
				Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
			}
		}
		Start-Sleep -Seconds 2
		$After = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
		if ($After) {
			Write-BISFLog -Msg "Service $ServiceName state after stop: $($After.Status)" -ShowConsole -Color DarkCyan -SubMsg
			if ($After.Status -ne 'Stopped') {
				Write-BISFLog -Msg "Failed to stop $ServiceName" -Type E
				return $false
			}
		}
		return $true
	}

	function Invoke-NinjaOneNoClone {
		[CmdletBinding(SupportsShouldProcess = $true)]
		[OutputType([bool])]
		param()

		Write-BISFLog -Msg "noclone path: $NoCloneExe" -SubMsg
		if (-not (Test-Path -LiteralPath $NoCloneExe)) {
			Write-BISFLog -Msg "noclone.exe not found at $NoCloneExe  -  sealing aborted" -Type E
			return $false
		}

		if (-not $PSCmdlet.ShouldProcess($NoCloneExe, 'Run noclone.exe to clear agent registration')) {
			return $true
		}

		try {
			$Proc = Start-Process -FilePath $NoCloneExe -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
			Write-BISFLog -Msg "noclone.exe exit code: $($Proc.ExitCode)" -ShowConsole -Color DarkCyan -SubMsg
			if ($Proc.ExitCode -ne 0) {
				Write-BISFLog -Msg "noclone.exe failed with exit code $($Proc.ExitCode)" -Type E
				return $false
			}
		}
		catch {
			Write-BISFLog -Msg "Failed to run noclone.exe: $($_.Exception.Message)" -Type E
			return $false
		}

		return $true
	}

	function Stop-NinjaOneBackupIfPresent {
		[CmdletBinding(SupportsShouldProcess = $true)]
		param()

		$Backup = Get-Service -Name $BackupServiceName -ErrorAction SilentlyContinue
		if (-not $Backup) {
			return
		}

		Write-BISFLog -Msg "Ninja Backup service '$BackupServiceName' detected  -  stopping. Enable Backup only after cloning (vendor guidance)." -Type W -ShowConsole -Color Yellow
		if ($Backup.Status -eq 'Stopped') {
			return
		}

		if (-not $PSCmdlet.ShouldProcess($BackupServiceName, 'Stop service')) {
			return
		}

		try {
			Invoke-BISFService -ServiceName $BackupServiceName -Action Stop
		}
		catch {
			Stop-Service -Name $BackupServiceName -Force -ErrorAction SilentlyContinue
		}
	}

	#### Main Program
	IF (-not (Test-NinjaOneInstalled)) {
		Write-BISFLog -Msg "$Product not installed  -  skipping"
		return
	}

	Write-BISFLog -Msg "Preparing $Product for imaging (stop service + run noclone.exe)" -ShowConsole -Color Cyan

	$Stopped = Stop-NinjaOneAgent
	if (-not $Stopped) {
		throw "NinjaOne Agent service could not be stopped  -  sealing aborted"
	}

	$Cleared = Invoke-NinjaOneNoClone
	if (-not $Cleared) {
		throw "NinjaOne noclone.exe could not clear registration  -  sealing aborted"
	}

	$AfterNoClone = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
	if ($AfterNoClone -and $AfterNoClone.Status -ne 'Stopped') {
		Write-BISFLog -Msg "Service $ServiceName was running after noclone  -  stopping again before seal" -Type W
		$ReStopped = Stop-NinjaOneAgent
		if (-not $ReStopped) {
			throw "NinjaOne Agent service could not be kept stopped after noclone  -  sealing aborted"
		}
	}

	Stop-NinjaOneBackupIfPresent

	Write-BISFLog -Msg "$Product preparation complete. Leave the agent stopped through snapshot; clones will register as new devices on first start." -ShowConsole -Color Green
}

End {
	Add-BISFFinishLine
}
