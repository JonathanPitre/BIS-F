<#
	.SYNOPSIS
		Prepare SentinelOne Agent for VDI / golden-image sealing
	.DESCRIPTION
		Waits for Certificate Disk Scan (FDCS) to complete, verifies cold-clone identity
		(Randomize UUID on next boot), runs legacy agent_id reset when VDI mode is absent,
		and disables SentinelOne VSS snapshots for pooled images.

		Prefer installing the agent with VDI=true on modern Windows packages; this script
		verifies identity and supports legacy sentinelctl reset when needed.
		Legacy MSI property VDI_MASTER=1 is still recognized.

		Operator prerequisites (not stored in repo):
		- Site / console registration completed on the master image
		- Anti-Tamper disabled on the build-time policy/group assigned to the master
		- Optional anti-tamper passphrase from console (Actions -> Show Passphrase)
		  when running legacy sentinelctl agent_id reset or CLI configure
		- Do not clone until FDCS reports complete (read_fdcs_status = 2)
		- Citrix/UPM exclusions for C:\Program Files\SentinelOne and C:\ProgramData\Sentinel
		  belong in the VDI stack (not this seal script)

		Install examples (deployment tooling, not run by this seal script):
		msiexec /i "SentinelAgent_windows_*.msi" /qn SITE_TOKEN="<token>" VDI=true
		SentinelOneInstaller.exe -t <SITE_TOKEN> -a "VDI=true" /q

		Legacy MSI:
		msiexec /i "SentinelAgent*.msi" VDI_MASTER=1 SITE_TOKEN="<token>" /qn

		Environment overrides:
		- BISF_S1_SCAN_TIMEOUT_MIN — minutes to wait for FDCS (default 180)
		- BISF_S1_PASSPHRASE — anti-tamper passphrase for legacy reset / configure
		- BISF_S1_SKIP_VSS=1 — skip snapshotIntervalMinutes=0 and limit_vss on seal

		References:
		- CTX370621 — complete Certificate Disk Scan before seal (read_fdcs_status -> 2)
		- SentinelOne / SonicWall VDI install (VDI=true; legacy VDI_MASTER)
		- Sentinel-One ansible_collection_s1agents s1_enable_vdi / VDI_MASTER
	.NOTES
		Author: Jonathan Pitre

		History
			08.08.2026 JP: Script created for fork branch 2608
			09.08.2026 JP: Rename local helpers to S1 product prefix (match Get-Sep* style)
			09.08.2026 JP: FDCS gate, VDI=true / Randomize UUID verify, VSS disable-on-seal

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
	# Optional passphrase for legacy agent_id reset / configure (never commit real values)
	$AntiTamperPassphrase = $env:BISF_S1_PASSPHRASE
	$SkipVss = ($env:BISF_S1_SKIP_VSS -match '^(1|true|yes)$')
}

Process {

	function Get-S1InstallRoot {
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

	function Get-S1SentinelCtl {
		$installRoot = Get-S1InstallRoot
		if (-not $installRoot) { return $null }
		$ctl = Join-Path $installRoot 'sentinelctl.exe'
		if (Test-Path -LiteralPath $ctl) { return $ctl }
		return $null
	}

	function Get-S1AgentVersion {
		param ([string]$SentinelCtl)
		if (-not $SentinelCtl) { return $null }
		try {
			$out = & $SentinelCtl version 2>&1 | Out-String
			if ($out -match '(\d+\.\d+\.\d+(\.\d+)?)') { return $Matches[1] }
		}
		catch {
			Write-BISFLog -Msg "Could not read SentinelOne version: $($_.Exception.Message)" -Type W -SubMsg
		}
		return $null
	}

	function Get-S1AgentIdVerifyOutput {
		param ([string]$SentinelCtl)
		if (-not $SentinelCtl) { return $null }
		try {
			return (& $SentinelCtl agent_id -v 2>&1 | Out-String)
		}
		catch {
			Write-BISFLog -Msg "sentinelctl agent_id -v failed: $($_.Exception.Message)" -Type W -SubMsg
			return $null
		}
	}

	function Test-S1RandomizeUuidOnBoot {
		param ([string]$AgentIdOutput)
		if ([string]::IsNullOrWhiteSpace($AgentIdOutput)) { return $false }
		# Primary: "Randomize UUID on next boot: true"
		if ($AgentIdOutput -match '(?i)randomize\s+uuid\s+on\s+next\s+boot\s*:\s*true') { return $true }
		# Alternate VDI wording seen on some builds
		if ($AgentIdOutput -match '(?i)(vdi\s*(mode|master|enabled)|cold[- ]?clone).{0,40}(true|yes|enabled|1)') { return $true }
		return $false
	}

	function Test-S1VdiRegistryMarker {
		# VDI=true / VDI_MASTER=1 are install properties; registry keys vary by agent build.
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
			catch {
				Write-BISFLog -Msg "Could not read VDI marker from $($p): $($_.Exception.Message)" -Type W -SubMsg
			}
		}
		return $false
	}

	function Test-S1VdiMode {
		param ([string]$SentinelCtl)

		$agentIdOut = Get-S1AgentIdVerifyOutput -SentinelCtl $SentinelCtl
		if (Test-S1RandomizeUuidOnBoot -AgentIdOutput $agentIdOut) {
			Write-BISFLog -Msg "VDI/cold-clone mode confirmed via agent_id -v (Randomize UUID on next boot)" -SubMsg
			return $true
		}

		if (Test-S1VdiRegistryMarker) {
			Write-BISFLog -Msg "VDI install marker found in registry (VDI=true / VDI_MASTER)" -SubMsg
			return $true
		}

		return $false
	}

	function Test-S1FdcsComplete {
		# CTX370621: read_fdcs_status -> 2 means Certificate Disk Scan completed
		param ([string]$SentinelCtl)
		if (-not $SentinelCtl) { return $null }

		try {
			$fdcsOut = & $SentinelCtl read_fdcs_status 2>&1 | Out-String
			if ([string]::IsNullOrWhiteSpace($fdcsOut)) { return $null }

			# Reject unknown / error output that is not a status code
			if ($fdcsOut -match '(?i)(unknown|not\s+recognized|invalid|error|failed)') {
				return $null
			}

			# Prefer a lone status digit (possibly with whitespace / labels)
			if ($fdcsOut -match '(?m)^\s*([0-9])\s*$') {
				return ([int]$Matches[1] -eq 2)
			}
			if ($fdcsOut -match '(?i)(?:status|fdcs|value)\s*[:=]?\s*([0-9])') {
				return ([int]$Matches[1] -eq 2)
			}
			# Bare digit anywhere if output is short
			$trimmed = $fdcsOut.Trim()
			if ($trimmed -match '^([0-9])$') {
				return ([int]$Matches[1] -eq 2)
			}
			if ($trimmed -match '\b2\b' -and $trimmed -notmatch '\b[013456789]\b') {
				return $true
			}
			if ($trimmed -match '\b[013456789]\b') {
				return $false
			}
			return $null
		}
		catch {
			return $null
		}
	}

	function Test-S1ScanComplete {
		param ([string]$SentinelCtl)
		if (-not $SentinelCtl) { return $false }

		# Prefer FDCS status (manufacturer / Citrix CTX370621)
		$fdcs = Test-S1FdcsComplete -SentinelCtl $SentinelCtl
		if ($fdcs -eq $true) { return $true }
		if ($fdcs -eq $false) { return $false }

		# Fallback: agent status text when read_fdcs_status unavailable
		try {
			$statusOut = & $SentinelCtl status 2>&1 | Out-String
			if ([string]::IsNullOrWhiteSpace($statusOut)) { return $null }

			if ($statusOut -match '(?i)(full\s*disk\s*scan|on[- ]?demand\s*scan|scan\s*status|certificate\s*disk\s*scan).{0,80}(complet|finished|idle|none|not\s*running)') {
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

	function Wait-S1FullDiskScan {
		param (
			[string]$SentinelCtl,
			[int]$TimeoutMinutes
		)

		Write-BISFLog -Msg "Waiting for SentinelOne Certificate Disk Scan / FDCS to finish (timeout ${TimeoutMinutes}m; read_fdcs_status=2). Do not clone while a scan is active." -ShowConsole -Color Cyan
		$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
		$pollSeconds = 60
		$unknownStreak = 0

		while ((Get-Date) -lt $deadline) {
			$result = Test-S1ScanComplete -SentinelCtl $SentinelCtl
			if ($result -eq $true) {
				Write-BISFLog -Msg "SentinelOne FDCS / scan appears complete (read_fdcs_status=2 or status idle)" -ShowConsole -Color DarkCyan -SubMsg
				return $true
			}
			if ($result -eq $false) {
				$unknownStreak = 0
				Write-BISFLog -Msg "SentinelOne FDCS / scan still in progress; waiting ${pollSeconds}s..." -ShowConsole -Color DarkCyan -SubMsg
			}
			else {
				$unknownStreak++
				Write-BISFLog -Msg "Could not parse FDCS/scan status from sentinelctl (attempt $unknownStreak); waiting ${pollSeconds}s..." -Type W -SubMsg
				if ($unknownStreak -ge 3) {
					Write-BISFLog -Msg "Scan status unavailable via CLI. Ensure Certificate Disk Scan completed in console (read_fdcs_status=2) before sealing. Continuing after remaining timeout window checks..." -Type W
				}
			}
			Start-Sleep -Seconds $pollSeconds
		}

		$final = Test-S1ScanComplete -SentinelCtl $SentinelCtl
		if ($final -eq $true) { return $true }

		Write-BISFLog -Msg "SentinelOne FDCS / full disk scan did not report complete within ${TimeoutMinutes} minutes. Aborting seal to avoid bad clones." -Type E -ShowConsole -Color Red
		return $false
	}

	function Reset-S1AgentIdentity {
		[CmdletBinding(SupportsShouldProcess = $true)]
		[OutputType([bool])]
		param (
			[string]$SentinelCtl,
			[bool]$VdiMode
		)

		if ($VdiMode) {
			Write-BISFLog -Msg "VDI/cold-clone mode detected — identity reset expected via VDI install; verifying Randomize UUID on next boot" -ShowConsole -Color DarkCyan -SubMsg
		}

		if (-not $SentinelCtl) {
			Write-BISFLog -Msg "sentinelctl.exe not found; cannot reset or verify agent_id" -Type E
			return $false
		}

		# Legacy / edge: explicit agent_id reset (approx. 3.1–3.3.2 or when VDI flag unavailable)
		$needLegacyReset = -not $VdiMode
		if ($needLegacyReset) {
			if (-not $PSCmdlet.ShouldProcess($SentinelCtl, 'Reset SentinelOne agent_id')) {
				return $true
			}
			Write-BISFLog -Msg "Running legacy sentinelctl agent_id reset (-r -b -k). Anti-Tamper should be off on the build policy, or set BISF_S1_PASSPHRASE." -ShowConsole -Color Cyan -SubMsg
			$argList = @('agent_id', '-r', '-b', '-k')
			if (-not [string]::IsNullOrWhiteSpace($AntiTamperPassphrase)) {
				$argList += @('-p', $AntiTamperPassphrase)
			}
			else {
				Write-BISFLog -Msg "BISF_S1_PASSPHRASE not set; if Anti-Tamper is enabled, reset will fail — disable tamper on build policy or set env / console passphrase" -Type W
			}
			try {
				& $SentinelCtl @argList 2>&1 | ForEach-Object { Write-BISFLog -Msg "$_" -SubMsg }
			}
			catch {
				Write-BISFLog -Msg "sentinelctl agent_id reset failed: $($_.Exception.Message)" -Type E
				return $false
			}
		}

		Write-BISFLog -Msg "Verifying agent_id with sentinelctl agent_id -v (require Randomize UUID on next boot: true)" -ShowConsole -Color DarkCyan -SubMsg
		try {
			$verify = Get-S1AgentIdVerifyOutput -SentinelCtl $SentinelCtl
			if ([string]::IsNullOrWhiteSpace($verify)) {
				Write-BISFLog -Msg "agent_id -v returned no output — cannot confirm cold-clone identity" -Type E
				return $false
			}
			Write-BISFLog -Msg "agent_id -v: $($verify.Trim())" -SubMsg
			if (-not (Test-S1RandomizeUuidOnBoot -AgentIdOutput $verify)) {
				Write-BISFLog -Msg "agent_id -v does not show Randomize UUID on next boot: true. Reinstall with VDI=true (cold clone) or complete legacy agent_id reset with Anti-Tamper unlocked. Aborting seal." -Type E -ShowConsole -Color Red
				return $false
			}
			Write-BISFLog -Msg "Cold-clone identity confirmed (Randomize UUID on next boot)" -ShowConsole -Color DarkCyan -SubMsg
			return $true
		}
		catch {
			Write-BISFLog -Msg "agent_id verify failed: $($_.Exception.Message)" -Type E
			return $false
		}
	}

	function Disable-S1VssSnapshots {
		[CmdletBinding(SupportsShouldProcess = $true)]
		[OutputType([bool])]
		param ([string]$SentinelCtl)

		if ($SkipVss) {
			Write-BISFLog -Msg "BISF_S1_SKIP_VSS set — skipping SentinelOne VSS snapshot disable" -ShowConsole -Color DarkCyan -SubMsg
			return $true
		}

		if (-not $SentinelCtl) {
			Write-BISFLog -Msg "sentinelctl.exe not found; cannot configure VSS — continuing (best-effort)" -Type W
			return $true
		}

		if (-not $PSCmdlet.ShouldProcess($SentinelCtl, 'Disable SentinelOne VSS snapshots for pooled seal')) {
			return $true
		}

		Write-BISFLog -Msg "Disabling SentinelOne VSS snapshots for pooled VDI (agent.snapshotIntervalMinutes=0)" -ShowConsole -Color Cyan -SubMsg
		try {
			& $SentinelCtl configure -p agent.snapshotIntervalMinutes -v 0 2>&1 | ForEach-Object { Write-BISFLog -Msg "$_" -SubMsg }
		}
		catch {
			Write-BISFLog -Msg "sentinelctl configure snapshotIntervalMinutes failed: $($_.Exception.Message). Prefer site/group policy; Anti-Tamper may block CLI." -Type W
		}

		Write-BISFLog -Msg "Best-effort sentinelctl limit_vss (cap shadow storage)" -ShowConsole -Color DarkCyan -SubMsg
		try {
			& $SentinelCtl limit_vss 2>&1 | ForEach-Object { Write-BISFLog -Msg "$_" -SubMsg }
		}
		catch {
			Write-BISFLog -Msg "sentinelctl limit_vss failed: $($_.Exception.Message) — non-fatal; set VSS caps in SentinelOne policy if needed" -Type W
		}

		return $true
	}

	#### Main Program
	$svc = Test-BISFService -ServiceName $ServiceName -ProductName $Product
	IF ($svc -ne $true) {
		Write-BISFLog -Msg "$Product not installed (service $ServiceName missing) — skipping"
		return
	}

	$sentinelCtl = Get-S1SentinelCtl
	$version = Get-S1AgentVersion -SentinelCtl $sentinelCtl
	if ($version) {
		Write-BISFLog -Msg "$Product version: $version" -ShowConsole -Color Cyan
	}
	else {
		Write-BISFLog -Msg "$Product detected; version unknown (sentinelctl missing or unreadable)" -ShowConsole -Color Cyan
	}

	Write-BISFLog -Msg "Ensure Anti-Tamper is disabled on the master build policy before seal (re-enable via production Dynamic Group after clone)." -Type W -SubMsg

	$vdiMode = Test-S1VdiMode -SentinelCtl $sentinelCtl
	Write-BISFLog -Msg "VDI/cold-clone mode: $vdiMode" -SubMsg

	$scanOk = Wait-S1FullDiskScan -SentinelCtl $sentinelCtl -TimeoutMinutes $ScanTimeoutMinutes
	if (-not $scanOk) {
		throw "SentinelOne full disk scan incomplete — sealing aborted"
	}

	$resetOk = Reset-S1AgentIdentity -SentinelCtl $sentinelCtl -VdiMode $vdiMode
	if (-not $resetOk) {
		throw "SentinelOne identity reset/verify failed — sealing aborted"
	}

	$null = Disable-S1VssSnapshots -SentinelCtl $sentinelCtl

	Write-BISFLog -Msg "$Product preparation complete. Shut down master and clone only after FDCS + identity steps succeeded." -ShowConsole -Color Green
}

End {
	Add-BISFFinishLine
}
