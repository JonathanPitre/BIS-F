<#
	.SYNOPSIS
		Prepare SentinelOne Agent for VDI / golden-image sealing
	.DESCRIPTION
		Waits for on-image full disk scan to complete (when detectable), then resets
		agent identity for cloning. Prefer installing the agent with VDI_MASTER=1
		(msiexec property) on modern agents; this script still verifies identity reset
		and supports legacy sentinelctl reset when needed.

		Operator prerequisites (not stored in repo):
		- Site / console registration completed on the master image
		- Optional anti-tamper passphrase from console (Actions -> Show Passphrase)
		  when running legacy sentinelctl agent_id reset
		- Do not clone while a full disk scan is still running

		Install example (deployment tooling, not run by this seal script):
		msiexec /i "SentinelAgent*.msi" VDI_MASTER=1 SITE_TOKEN="<token>" /qn

		References:
		- Sentinel-One ansible_collection_s1agents s1_enable_vdi / VDI_MASTER
	.NOTES
		Author: Jonathan Pitre

		History
			08.08.2026 JP: Script created for fork branch 2608

	.LINK
		https://eucweb.com
#>

Begin {
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)

	$Product = "SentinelOne"
	$ServiceName = "SentinelAgent"
	# Minutes to wait for full disk scan before failing seal (override via env BISF_S1_SCAN_TIMEOUT_MIN)
	$ScanTimeoutMinutes = 180
	if ($env:BISF_S1_SCAN_TIMEOUT_MIN -match '^\d+$') {
		$ScanTimeoutMinutes = [int]$env:BISF_S1_SCAN_TIMEOUT_MIN
	}
	# Optional passphrase for legacy agent_id reset (never commit real values)
	$AntiTamperPassphrase = $env:BISF_S1_PASSPHRASE
}

Process {

	function Get-BISFS1InstallRoot {
		$roots = @(
			"${env:ProgramFiles}\SentinelOne",
			"${env:ProgramFiles(x86)}\SentinelOne"
		)
		foreach ($root in $roots) {
			if (Test-Path -LiteralPath $root) {
				$agentDir = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
					Where-Object { $_.Name -like 'Sentinel Agent*' } |
					Sort-Object Name -Descending |
					Select-Object -First 1
				if ($agentDir) { return $agentDir.FullName }
			}
		}
		return $null
	}

	function Get-BISFS1SentinelCtl {
		$installRoot = Get-BISFS1InstallRoot
		if (-not $installRoot) { return $null }
		$ctl = Join-Path $installRoot 'sentinelctl.exe'
		if (Test-Path -LiteralPath $ctl) { return $ctl }
		return $null
	}

	function Get-BISFS1AgentVersion {
		param ([string]$SentinelCtl)
		if (-not $SentinelCtl) { return $null }
		try {
			$out = & $SentinelCtl version 2>&1 | Out-String
			if ($out -match '(\d+\.\d+\.\d+(\.\d+)?)') { return $Matches[1] }
		}
		catch { }
		return $null
	}

	function Test-BISFS1VdiMasterInstall {
		# VDI_MASTER=1 is an MSI property; registry keys vary by agent build.
		# Treat presence of documented VDI markers as "modern cold-clone" path.
		$paths = @(
			'HKLM:\SOFTWARE\SentinelLabs',
			'HKLM:\SOFTWARE\SentinelOne',
			'HKLM:\SOFTWARE\WOW6432Node\SentinelLabs',
			'HKLM:\SOFTWARE\WOW6432Node\SentinelOne'
		)
		foreach ($p in $paths) {
			if (-not (Test-Path -LiteralPath $p)) { continue }
			try {
				$props = Get-ItemProperty -LiteralPath $p -ErrorAction SilentlyContinue
				foreach ($name in @('VDI_MASTER', 'VdiMaster', 'IsVdiMaster', 'VDI')) {
					if ($null -ne $props.$name -and "$($props.$name)" -match '^(1|true|yes)$') {
						return $true
					}
				}
			}
			catch { }
		}
		return $false
	}

	function Test-BISFS1ScanComplete {
		param ([string]$SentinelCtl)
		if (-not $SentinelCtl) { return $false }

		# Prefer agent status output; treat "scan" + completed/idle language as done.
		# If status cannot be parsed, return $null so caller can warn and continue with timeout policy.
		try {
			$statusOut = & $SentinelCtl status 2>&1 | Out-String
			if ([string]::IsNullOrWhiteSpace($statusOut)) { return $null }

			if ($statusOut -match '(?i)(full\s*disk\s*scan|on[- ]?demand\s*scan|scan\s*status).{0,80}(complet|finished|idle|none|not\s*running)') {
				return $true
			}
			if ($statusOut -match '(?i)(scanning|scan\s*in\s*progress|full\s*disk\s*scan.{0,40}(running|active|progress))') {
				return $false
			}
			# Status available but no scan activity indicated — assume idle
			if ($statusOut -match '(?i)agent') { return $true }
			return $null
		}
		catch {
			return $null
		}
	}

	function Wait-BISFS1FullDiskScan {
		param (
			[string]$SentinelCtl,
			[int]$TimeoutMinutes
		)

		Write-BISFLog -Msg "Waiting for SentinelOne full disk scan to finish (timeout ${TimeoutMinutes}m). Do not clone while a scan is active." -ShowConsole -Color Cyan
		$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
		$pollSeconds = 60
		$unknownStreak = 0

		while ((Get-Date) -lt $deadline) {
			$result = Test-BISFS1ScanComplete -SentinelCtl $SentinelCtl
			if ($result -eq $true) {
				Write-BISFLog -Msg "SentinelOne scan appears complete / idle" -ShowConsole -Color DarkCyan -SubMsg
				return $true
			}
			if ($result -eq $false) {
				$unknownStreak = 0
				Write-BISFLog -Msg "SentinelOne scan still in progress; waiting ${pollSeconds}s..." -ShowConsole -Color DarkCyan -SubMsg
			}
			else {
				$unknownStreak++
				Write-BISFLog -Msg "Could not parse scan status from sentinelctl (attempt $unknownStreak); waiting ${pollSeconds}s..." -Type W -SubMsg
				# After several unknown polls, require operator confirmation via timeout only
				if ($unknownStreak -ge 3) {
					Write-BISFLog -Msg "Scan status unavailable via CLI. Ensure full disk scan completed in console before sealing. Continuing after remaining timeout window checks..." -Type W
				}
			}
			Start-Sleep -Seconds $pollSeconds
		}

		$final = Test-BISFS1ScanComplete -SentinelCtl $SentinelCtl
		if ($final -eq $true) { return $true }

		Write-BISFLog -Msg "SentinelOne full disk scan did not report complete within ${TimeoutMinutes} minutes. Aborting seal to avoid bad clones." -Type E -ShowConsole -Color Red
		return $false
	}

	function Reset-BISFS1AgentIdentity {
		param (
			[string]$SentinelCtl,
			[bool]$VdiMasterInstall
		)

		if ($VdiMasterInstall) {
			Write-BISFLog -Msg "VDI_MASTER install marker detected — identity reset expected via VDI cold-clone mode; verifying agent_id" -ShowConsole -Color DarkCyan -SubMsg
		}

		if (-not $SentinelCtl) {
			Write-BISFLog -Msg "sentinelctl.exe not found; cannot reset or verify agent_id" -Type E
			return $false
		}

		# Legacy / edge: explicit agent_id reset (approx. 3.1–3.3.2 or when VDI flag unavailable)
		$needLegacyReset = -not $VdiMasterInstall
		if ($needLegacyReset) {
			Write-BISFLog -Msg "Running legacy sentinelctl agent_id reset (-r -b -k)" -ShowConsole -Color Cyan -SubMsg
			$argList = @('agent_id', '-r', '-b', '-k')
			if (-not [string]::IsNullOrWhiteSpace($AntiTamperPassphrase)) {
				$argList += @('-p', $AntiTamperPassphrase)
			}
			else {
				Write-BISFLog -Msg "BISF_S1_PASSPHRASE not set; if anti-tamper is enabled, reset may fail — set env or unlock from console" -Type W
			}
			try {
				& $SentinelCtl @argList 2>&1 | ForEach-Object { Write-BISFLog -Msg "$_" -SubMsg }
			}
			catch {
				Write-BISFLog -Msg "sentinelctl agent_id reset failed: $($_.Exception.Message)" -Type E
				return $false
			}
		}

		Write-BISFLog -Msg "Verifying agent_id with sentinelctl agent_id -v" -ShowConsole -Color DarkCyan -SubMsg
		try {
			$verify = & $SentinelCtl agent_id -v 2>&1 | Out-String
			Write-BISFLog -Msg "agent_id -v: $($verify.Trim())" -SubMsg
			return $true
		}
		catch {
			Write-BISFLog -Msg "agent_id verify failed: $($_.Exception.Message)" -Type E
			return $false
		}
	}

	#### Main Program
	$svc = Test-BISFService -ServiceName $ServiceName -ProductName $Product
	IF ($svc -ne $true) {
		Write-BISFLog -Msg "$Product not installed (service $ServiceName missing) — skipping"
		return
	}

	$sentinelCtl = Get-BISFS1SentinelCtl
	$version = Get-BISFS1AgentVersion -SentinelCtl $sentinelCtl
	if ($version) {
		Write-BISFLog -Msg "$Product version: $version" -ShowConsole -Color Cyan
	}
	else {
		Write-BISFLog -Msg "$Product detected; version unknown (sentinelctl missing or unreadable)" -ShowConsole -Color Cyan
	}

	$vdiMaster = Test-BISFS1VdiMasterInstall
	Write-BISFLog -Msg "VDI_MASTER install marker: $vdiMaster" -SubMsg

	$scanOk = Wait-BISFS1FullDiskScan -SentinelCtl $sentinelCtl -TimeoutMinutes $ScanTimeoutMinutes
	if (-not $scanOk) {
		throw "SentinelOne full disk scan incomplete — sealing aborted"
	}

	$resetOk = Reset-BISFS1AgentIdentity -SentinelCtl $sentinelCtl -VdiMasterInstall $vdiMaster
	if (-not $resetOk) {
		throw "SentinelOne identity reset/verify failed — sealing aborted"
	}

	Write-BISFLog -Msg "$Product preparation complete. Shut down master and clone only after scan + identity steps succeeded." -ShowConsole -Color Green
}

End {
	Add-BISFFinishLine
}
