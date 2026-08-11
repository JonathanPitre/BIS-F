<#
	.SYNOPSIS
		Prepare Rapid7 Insight Agent for VDI / golden-image sealing
	.DESCRIPTION
		Stops the Insight Agent service and removes bootstrap.cfg so each clone
		generates a new Agent ID on first startup (Rapid7 virtualization guidance).

		Expected clone behavior:
		- After seal, bootstrap.cfg is absent on the master image
		- On first boot of a clone, the agent starts and recreates bootstrap.cfg with a new ID

		Optional (console, not this script): configure InsightVM non-persistent VDI correlation.
	.EXAMPLE
	.NOTES
		Author: Jonathan Pitre
		Company: EUCWeb.com

		History:
		08.08.2026 JP: Script created for fork branch 2608

	.LINK
		https://eucweb.com
	.LINK
		https://docs.rapid7.com/insight-agent/virtualization
	.LINK
		https://docs.rapid7.com/insightvm/non-persistent-vdi-correlation
#>

Begin {
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)

	$Product = "Rapid7 Insight Agent"
	$ServiceName = "ir_agent"
	$BootstrapCfg = "${env:ProgramFiles}\Rapid7\Insight Agent\components\bootstrap\common\bootstrap.cfg"
	$AgentRoot = "${env:ProgramFiles}\Rapid7\Insight Agent"
}

Process {

	function Test-BISFRapid7Installed {
		if (Test-Path -LiteralPath $AgentRoot) { return $true }
		$svcObj = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
		if ($svcObj) { return $true }
		return $false
	}

	function Stop-BISFRapid7Agent {
		[CmdletBinding(SupportsShouldProcess = $true)]
		[OutputType([bool])]
		param()

		Write-BISFLog -Msg "Service $ServiceName state before stop: $((Get-Service -Name $ServiceName -ErrorAction SilentlyContinue).Status)" -SubMsg
		if (-not $PSCmdlet.ShouldProcess($ServiceName, 'Stop service')) {
			return $true
		}

		$svc = Test-BISFService -ServiceName $ServiceName -ProductName $Product
		IF ($svc -eq $true) {
			Invoke-BISFService -ServiceName $ServiceName -Action Stop
		}
		else {
			Write-BISFLog -Msg "Service $ServiceName not found via Test-BISFService; attempting Stop-Service if present" -Type W
			$svcObj = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
			if ($svcObj -and $svcObj.Status -ne 'Stopped') {
				Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
			}
		}
		Start-Sleep -Seconds 2
		$after = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
		if ($after) {
			Write-BISFLog -Msg "Service $ServiceName state after stop: $($after.Status)" -ShowConsole -Color DarkCyan -SubMsg
			if ($after.Status -ne 'Stopped') {
				Write-BISFLog -Msg "Failed to stop $ServiceName" -Type E
				return $false
			}
		}
		return $true
	}

	function Remove-BISFRapid7BootstrapCfg {
		[CmdletBinding(SupportsShouldProcess = $true)]
		[OutputType([bool])]
		param()

		Write-BISFLog -Msg "bootstrap.cfg path: $BootstrapCfg" -SubMsg
		if (-not (Test-Path -LiteralPath $BootstrapCfg)) {
			Write-BISFLog -Msg "bootstrap.cfg already absent — nothing to delete" -ShowConsole -Color DarkCyan -SubMsg
			return $true
		}

		if (-not $PSCmdlet.ShouldProcess($BootstrapCfg, 'Remove bootstrap.cfg')) {
			return $true
		}

		try {
			Remove-Item -LiteralPath $BootstrapCfg -Force -ErrorAction Stop
			Write-BISFLog -Msg "Deleted bootstrap.cfg" -ShowConsole -Color Cyan -SubMsg
		}
		catch {
			Write-BISFLog -Msg "Failed to delete bootstrap.cfg: $($_.Exception.Message)" -Type E
			return $false
		}

		if (Test-Path -LiteralPath $BootstrapCfg) {
			Write-BISFLog -Msg "bootstrap.cfg still present after delete" -Type E
			return $false
		}
		Write-BISFLog -Msg "Verified bootstrap.cfg is absent" -ShowConsole -Color DarkCyan -SubMsg
		return $true
	}

	#### Main Program
	IF (-not (Test-BISFRapid7Installed)) {
		Write-BISFLog -Msg "$Product not installed — skipping"
		return
	}

	Write-BISFLog -Msg "Preparing $Product for imaging (stop service + remove bootstrap.cfg)" -ShowConsole -Color Cyan

	$stopped = Stop-BISFRapid7Agent
	if (-not $stopped) {
		throw "Rapid7 Insight Agent service could not be stopped — sealing aborted"
	}

	$removed = Remove-BISFRapid7BootstrapCfg
	if (-not $removed) {
		throw "Rapid7 bootstrap.cfg could not be removed — sealing aborted"
	}

	Write-BISFLog -Msg "$Product preparation complete. Clones will register with a new Agent ID on first start." -ShowConsole -Color Green
}

End {
	Add-BISFFinishLine
}
