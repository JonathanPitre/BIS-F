<#
	.SYNOPSIS
		Hydrate and optionally cold-start files for Citrix PVS and MCS IO
	.DESCRIPTION
		Binary-reads configured folders into the file system cache and optionally
		cold-starts processes from a JSON template. Runs on Citrix PVS shared
		vDisks and Citrix MCS IO shared images. Uses a PowerShell runspace pool
		when enabled by policy (default).
	.NOTES
		Author: Matthias Schlimm / Jonathan Pitre / community (PR 363, Jeremy Saunders)

		History:
		2019.08.16 TT: Script created
		18.08.2019 MS: integrate into BIS-F
		03.02.2020 MS: HF 201 - Hydration not starting if configured
		23.05.2020 MS: HF 231 - Skipping file precache if vDisk is in private Mode
		21.08.2026 JP: Runspace multithreading, MCS IO, JSON cold-start (PR 363 / Jeremy Saunders)
		https://github.com/EUCweb/BIS-F/issues/129
		https://github.com/EUCweb/BIS-F/pull/363
	.LINK
		https://github.com/EUCweb/BIS-F/issues/129
#>

Begin {
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)
	$PathsToCache = $LIC_BISF_CLI_PVSHydration_Paths
	$ExtensionsToCache = $LIC_BISF_CLI_PVSHydration_Extensions
	$DefaultJsonPath = Join-Path -Path $ScriptDir -ChildPath 'BISF-Hydration.json'

	####################################################################
	####### functions #####
	####################################################################

	function Expand-BISFHydrationEnvPath {
		[CmdletBinding()]
		[OutputType([string])]
		param(
			[Parameter(Mandatory = $true)]
			[AllowEmptyString()]
			[string]$Path
		)

		end {
			if ([string]::IsNullOrWhiteSpace($Path)) {
				return $Path
			}

			$Resolved = $Path
			$Resolved = $Resolved.Replace('%ProgramFiles(x86)%', ${env:ProgramFiles(x86)})
			$Resolved = $Resolved.Replace('%ProgramFiles%', $env:ProgramFiles)
			$Resolved = $Resolved.Replace('%ProgramData%', $env:ProgramData)
			$Resolved = $Resolved.Replace('%SystemDrive%', $env:SystemDrive)
			$Resolved = $Resolved.Replace('%SystemRoot%', $env:SystemRoot)
			$Resolved = $Resolved.Replace('%CommonProgramFiles(x86)%', ${env:CommonProgramFiles(x86)})
			$Resolved = $Resolved.Replace('%CommonProgramFiles%', $env:CommonProgramFiles)
			return $Resolved
		}
	}

	function Resolve-BISFHydrationExecutable {
		[CmdletBinding()]
		[OutputType([string])]
		param(
			[Parameter(Mandatory = $true)]
			[string]$Path,
			[Parameter(Mandatory = $true)]
			[string]$Executable
		)

		end {
			$ExpandedPath = Expand-BISFHydrationEnvPath -Path $Path
			$Candidate = Join-Path -Path $ExpandedPath -ChildPath $Executable

			if ((-not ($ExpandedPath -like '*`**')) -and (Test-Path -LiteralPath $Candidate -PathType Leaf)) {
				return (Get-Item -LiteralPath $Candidate).FullName
			}

			$Parent = Split-Path -Parent $ExpandedPath
			$LeafPattern = Split-Path -Leaf $ExpandedPath
			if ([string]::IsNullOrWhiteSpace($Parent) -or -not (Test-Path -LiteralPath $Parent -PathType Container)) {
				if ($Executable -ieq 'olk.exe') {
					try {
						$Appx = Get-AppxPackage -AllUsers -Name 'Microsoft.OutlookForWindows' -ErrorAction Stop |
							Sort-Object -Property Version -Descending |
							Select-Object -First 1
						if ($null -ne $Appx -and -not [string]::IsNullOrWhiteSpace($Appx.InstallLocation)) {
							$AppxExe = Join-Path -Path $Appx.InstallLocation -ChildPath $Executable
							if (Test-Path -LiteralPath $AppxExe -PathType Leaf) {
								return (Get-Item -LiteralPath $AppxExe).FullName
							}
						}
					}
					catch {
						Write-Verbose "AppX Outlook lookup failed: $($_.Exception.Message)"
					}
				}
				return [string]::Empty
			}

			$Matches = @(Get-ChildItem -Path $Parent -Directory -Filter $LeafPattern -ErrorAction SilentlyContinue |
					Sort-Object -Property LastWriteTime -Descending)
			foreach ($Dir in $Matches) {
				$ExePath = Join-Path -Path $Dir.FullName -ChildPath $Executable
				if (Test-Path -LiteralPath $ExePath -PathType Leaf) {
					return (Get-Item -LiteralPath $ExePath).FullName
				}
			}

			if ($Executable -ieq 'olk.exe') {
				try {
					$Appx = Get-AppxPackage -AllUsers -Name 'Microsoft.OutlookForWindows' -ErrorAction Stop |
						Sort-Object -Property Version -Descending |
						Select-Object -First 1
					if ($null -ne $Appx -and -not [string]::IsNullOrWhiteSpace($Appx.InstallLocation)) {
						$AppxExe = Join-Path -Path $Appx.InstallLocation -ChildPath $Executable
						if (Test-Path -LiteralPath $AppxExe -PathType Leaf) {
							return (Get-Item -LiteralPath $AppxExe).FullName
						}
					}
				}
				catch {
					Write-Verbose "AppX Outlook lookup failed: $($_.Exception.Message)"
				}
			}

			return [string]::Empty
		}
	}

	function Get-BISFHydrationMaxThreads {
		[CmdletBinding()]
		[OutputType([int])]
		param(
			[Parameter(Mandatory = $false)]
			$Configured
		)

		end {
			$ConfiguredInt = 0
			if ($null -ne $Configured -and $Configured -ne '') {
				[void][int]::TryParse([string]$Configured, [ref]$ConfiguredInt)
			}

			if ($ConfiguredInt -gt 0) {
				return [Math]::Min($ConfiguredInt, 128)
			}

			$Logical = 0
			try {
				$Processors = @(Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop)
				foreach ($Proc in $Processors) {
					$Logical += [int]$Proc.NumberOfLogicalProcessors
				}
			}
			catch {
				$Logical = 0
			}

			if ($Logical -gt 1) {
				return ($Logical - 1)
			}
			if ($Logical -eq 1) {
				return 1
			}
			return 4
		}
	}

	function Get-BISFHydrationExtensions {
		[CmdletBinding()]
		[OutputType([string[]], [System.Object[]])]
		param(
			[Parameter(Mandatory = $false)]
			$Extensions
		)

		end {
			[string[]]$DefaultExtensions = @('*.exe', '*.dll')
			if ($null -eq $Extensions) {
				return $DefaultExtensions
			}

			if ($Extensions -is [System.Array] -and -not ($Extensions -is [string])) {
				[string[]]$FromArray = @($Extensions | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ -ne '' })
				return $FromArray
			}

			$Text = [string]$Extensions
			if ([string]::IsNullOrWhiteSpace($Text)) {
				return $DefaultExtensions
			}

			[string[]]$FromText = @($Text.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
			return $FromText
		}
	}

	function Get-BISFHydrationFiles {
		[CmdletBinding()]
		[OutputType([string[]], [System.Object[]])]
		param(
			[Parameter(Mandatory = $true)]
			[string]$Path,
			[Parameter(Mandatory = $true)]
			[string[]]$Extensions,
			[Parameter(Mandatory = $false)]
			[bool]$Recurse = $true
		)

		end {
			$Expanded = Expand-BISFHydrationEnvPath -Path $Path
			if (-not (Test-Path -LiteralPath $Expanded -PathType Container)) {
				Write-BISFLog -Msg "Hydration path does not exist: $Expanded" -Type W -ShowConsole -Color Yellow
				[string[]]$Empty = @()
				return $Empty
			}

			if ($Recurse) {
				[string[]]$Files = @(Get-ChildItem -LiteralPath $Expanded -Recurse -File -Include $Extensions -ErrorAction SilentlyContinue |
						ForEach-Object { $_.FullName })
			}
			else {
				[string[]]$Files = @(Get-ChildItem -Path (Join-Path -Path $Expanded -ChildPath '*') -File -Include $Extensions -ErrorAction SilentlyContinue |
						ForEach-Object { $_.FullName })
			}
			return $Files
		}
	}

	function Invoke-BISFHydrationReadFile {
		[CmdletBinding()]
		[OutputType([hashtable])]
		param(
			[Parameter(Mandatory = $true)]
			[string]$File
		)

		end {
			$Result = @{
				File    = $File
				Success = $false
				Message = ''
			}
			try {
				if (-not [System.IO.File]::Exists($File)) {
					$Result.Message = 'File does not exist'
					return $Result
				}
				$null = [System.IO.File]::ReadAllBytes($File)
				$Result.Success = $true
				$Result.Message = 'Read successfully'
			}
			catch {
				$Result.Message = $_.Exception.Message
			}
			return $Result
		}
	}

	function Invoke-BISFHydrationColdStart {
		[CmdletBinding()]
		[OutputType([hashtable])]
		param(
			[Parameter(Mandatory = $true)]
			[string]$ApplicationName,
			[Parameter(Mandatory = $true)]
			[string]$ProcessPath,
			[Parameter(Mandatory = $true)]
			[string]$ProcessExecutable,
			[Parameter(Mandatory = $false)]
			[string]$CommandLineContains = '',
			[Parameter(Mandatory = $false)]
			[string[]]$ExtraProcessesToTerminate = @(),
			[Parameter(Mandatory = $false)]
			[int]$TerminateAfterInSeconds = 1
		)

		end {
			$Result = @{
				Name    = $ApplicationName
				Success = $false
				Message = ''
			}

			$FullPath = Join-Path -Path $ProcessPath -ChildPath $ProcessExecutable
			if (-not (Test-Path -LiteralPath $FullPath -PathType Leaf)) {
				$Result.Message = "Executable not found: $FullPath"
				return $Result
			}

			$PInfo = New-Object System.Diagnostics.ProcessStartInfo
			$PInfo.FileName = $FullPath
			$PInfo.UseShellExecute = $false
			$Process = New-Object System.Diagnostics.Process
			$Process.StartInfo = $PInfo
			try {
				$Started = $Process.Start()
			}
			catch {
				$Started = $false
				$Result.Message = $_.Exception.Message
			}
			finally {
				$Process.Dispose()
			}

			if (-not $Started) {
				if ([string]::IsNullOrWhiteSpace($Result.Message)) {
					$Result.Message = 'Process failed to start'
				}
				return $Result
			}

			if ($TerminateAfterInSeconds -lt 1) {
				$TerminateAfterInSeconds = 1
			}
			Start-Sleep -Seconds $TerminateAfterInSeconds

			$NamesToKill = @($ProcessExecutable) + @($ExtraProcessesToTerminate | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
			foreach ($ProcName in $NamesToKill) {
				try {
					$Filter = "name='$ProcName'"
					$Targets = @(Get-CimInstance -ClassName Win32_Process -Filter $Filter -ErrorAction Stop)
					if (-not [string]::IsNullOrWhiteSpace($CommandLineContains) -and ($ProcName -eq $ProcessExecutable)) {
						$Targets = @($Targets | Where-Object { $_.CommandLine -like "*$CommandLineContains*" })
					}
					foreach ($Target in $Targets) {
						$null = Invoke-CimMethod -InputObject $Target -MethodName Terminate -ErrorAction SilentlyContinue
					}
				}
				catch {
					Write-Verbose "Best-effort terminate failed for ${ProcName}: $($_.Exception.Message)"
				}
			}

			$Result.Success = $true
			$Result.Message = "Started and terminated after $TerminateAfterInSeconds second(s)"
			return $Result
		}
	}

	# Script blocks for runspaces (no Write-BISFLog inside)
	$ScriptBlockReadBatch = {
		param([string[]]$Files)
		$Read = 0
		$Failed = 0
		foreach ($File in $Files) {
			try {
				if ([System.IO.File]::Exists($File)) {
					$null = [System.IO.File]::ReadAllBytes($File)
					$Read++
				}
				else {
					$Failed++
				}
			}
			catch {
				$Failed++
			}
		}
		[PSCustomObject]@{
			Read   = $Read
			Failed = $Failed
		}
	}

	$ScriptBlockColdStart = {
		param(
			[string]$ApplicationName,
			[string]$FullPath,
			[string]$ProcessExecutable,
			[string]$CommandLineContains,
			[string[]]$ExtraProcessesToTerminate,
			[int]$TerminateAfterInSeconds
		)

		$Output = "Starting `"$ApplicationName`""
		if (-not [System.IO.File]::Exists($FullPath)) {
			$Output += "`r`n- File does not exist"
			return $Output
		}

		$PInfo = New-Object System.Diagnostics.ProcessStartInfo
		$PInfo.FileName = $FullPath
		$PInfo.UseShellExecute = $false
		$Process = New-Object System.Diagnostics.Process
		$Process.StartInfo = $PInfo
		try {
			$Started = $Process.Start()
		}
		catch {
			$Started = $false
		}
		finally {
			$Process.Dispose()
		}

		if (-not $Started) {
			$Output += "`r`n- Process failed to start"
			return $Output
		}

		if ($TerminateAfterInSeconds -lt 1) {
			$TerminateAfterInSeconds = 1
		}
		$Output += "`r`n- Waiting for $TerminateAfterInSeconds seconds"
		Start-Sleep -Seconds $TerminateAfterInSeconds
		$Output += "`r`n- Terminating `"$ApplicationName`""

		$NamesToKill = @($ProcessExecutable)
		if ($null -ne $ExtraProcessesToTerminate) {
			$NamesToKill += @($ExtraProcessesToTerminate | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
		}

		foreach ($ProcName in $NamesToKill) {
			try {
				$Filter = "name='$ProcName'"
				$Targets = @(Get-CimInstance -ClassName Win32_Process -Filter $Filter -ErrorAction Stop)
				if (-not [string]::IsNullOrWhiteSpace($CommandLineContains) -and ($ProcName -eq $ProcessExecutable)) {
					$Targets = @($Targets | Where-Object { $_.CommandLine -like "*$CommandLineContains*" })
				}
				foreach ($Target in $Targets) {
					$null = Invoke-CimMethod -InputObject $Target -MethodName Terminate -ErrorAction SilentlyContinue
				}
			}
			catch {
				Write-Verbose "Best-effort terminate failed for ${ProcName}: $($_.Exception.Message)"
			}
		}

		$Output += "`r`n- Completed"
		return $Output
	}

	function Wait-BISFHydrationRunspaces {
		[CmdletBinding()]
		param(
			[Parameter(Mandatory = $true)]
			[System.Collections.ArrayList]$Runspaces,
			[Parameter(Mandatory = $true)]
			$RunspacePool
		)

		end {
			$SleepTimer = 500
			while ($true) {
				$Pending = @($Runspaces | Where-Object { $null -ne $_.Handle })
				if ($Pending.Count -eq 0) {
					break
				}

				foreach ($Item in $Pending) {
					if ($Item.Handle.IsCompleted) {
						try {
							$Output = $Item.PowerShell.EndInvoke($Item.Handle)
							if ($null -ne $Output) {
								foreach ($Line in @($Output)) {
									if ($null -eq $Line) {
										continue
									}
									if ($Line.PSObject.Properties.Name -contains 'Read') {
										Write-BISFLog -Msg "$($Item.Id): read $($Line.Read), failed $($Line.Failed)" -ShowConsole -Color DarkCyan -SubMsg
									}
									elseif ([string]$Line -ne '') {
										Write-BISFLog -Msg ([string]$Line) -ShowConsole -Color DarkCyan -SubMsg
									}
								}
							}
						}
						catch {
							Write-BISFLog -Msg "Runspace error ($($Item.Id)): $($_.Exception.Message)" -Type W
						}
						finally {
							$Item.Handle = $null
							$Item.PowerShell.Dispose()
						}
					}
				}
				Start-Sleep -Milliseconds $SleepTimer
			}

			$RunspacePool.Close()
			$RunspacePool.Dispose()
		}
	}

	function Test-BISFHydrationPlatformEligible {
		[CmdletBinding()]
		[OutputType([bool])]
		param()

		end {
			$PvsInstalled = Test-BISFPVSSoftware
			if ($PvsInstalled) {
				try {
					$WriteCacheType = Get-BISFPVSWriteCacheType
				}
				catch {
					$WriteCacheType = -1
				}

				# Private (0) and Private async (10)
				if (($WriteCacheType -eq 0) -or ($WriteCacheType -eq 10)) {
					Write-BISFLog -Msg "PVS vDisk is in Private Mode (WriteCacheType $WriteCacheType). Skipping file precache." -ShowConsole -Color Yellow
				}
				else {
					Write-BISFLog -Msg 'Platform: Citrix PVS shared vDisk' -ShowConsole -Color Cyan
					return $true
				}
			}

			$DiskModeLocal = $DiskMode
			if ([string]::IsNullOrWhiteSpace($DiskModeLocal)) {
				$DiskModeLocal = Get-BISFDiskMode
			}

			if (($MCSIO -eq $true) -and ($DiskModeLocal -like 'VDAShared*')) {
				Write-BISFLog -Msg "Platform: Citrix MCS IO shared image (DiskMode $DiskModeLocal)" -ShowConsole -Color Cyan
				return $true
			}

			if (-not $PvsInstalled) {
				Write-BISFLog -Msg 'PVS Software not found and MCS IO shared image not detected. Skipping file precache.' -ShowConsole -Color Yellow
			}
			else {
				Write-BISFLog -Msg 'Eligible PVS/MCS IO platform not detected for hydration. Skipping.' -ShowConsole -Color Yellow
			}
			return $false
		}
	}

	####### end functions #####
}

Process {
	#### Main Program

	if (-not ($LIC_BISF_CLI_PVSHydration -eq 'YES')) {
		Write-BISFLog -Msg 'File precache configuration not found. Skipping.' -ShowConsole -Color Yellow
		return
	}

	if (-not (Test-BISFHydrationPlatformEligible)) {
		return
	}

	$Method = 'FOLDERS'
	if (-not [string]::IsNullOrWhiteSpace($LIC_BISF_CLI_PVSHydration_Method)) {
		$Method = ([string]$LIC_BISF_CLI_PVSHydration_Method).Trim().ToUpperInvariant()
	}
	if ($Method -notin @('FOLDERS', 'JSON', 'BOTH')) {
		Write-BISFLog -Msg "Unknown hydration method '$Method'; using FOLDERS" -Type W
		$Method = 'FOLDERS'
	}

	$UseRunspaces = ($LIC_BISF_CLI_PVSHydration_Runspaces -ne 0) -and ($LIC_BISF_CLI_PVSHydration_Runspaces -ne '0')
	$MaxThreads = Get-BISFHydrationMaxThreads -Configured $LIC_BISF_CLI_PVSHydration_MaxThreads

	Write-BISFLog -Msg "Hydration method: $Method | Runspaces: $UseRunspaces | MaxThreads: $MaxThreads" -ShowConsole -Color Cyan

	$StartTime = Get-Date
	$AllFiles = New-Object System.Collections.Generic.List[string]
	$ColdStartJobs = New-Object System.Collections.Generic.List[object]
	$SingleReadFiles = New-Object System.Collections.Generic.List[string]

	# ADMX folder hydration
	if ($Method -in @('FOLDERS', 'BOTH')) {
		$AdmxPaths = @()
		if (-not [string]::IsNullOrWhiteSpace($PathsToCache)) {
			$AdmxPaths = @($PathsToCache.Split('|') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
		}
		if ($AdmxPaths.Count -eq 0) {
			$AdmxPaths = @('C:\Program Files', 'C:\Program Files (x86)')
		}

		$AdmxExtensions = Get-BISFHydrationExtensions -Extensions $ExtensionsToCache
		foreach ($Path in $AdmxPaths) {
			Write-BISFLog -Msg "Enumerating ADMX hydration path: $Path (extensions: $($AdmxExtensions -join ','))" -ShowConsole -Color Cyan
			$Found = Get-BISFHydrationFiles -Path $Path -Extensions $AdmxExtensions -Recurse $true
			foreach ($File in $Found) {
				$AllFiles.Add($File) | Out-Null
			}
			Write-BISFLog -Msg "Found $($Found.Count) file(s) under $Path" -ShowConsole -Color DarkCyan -SubMsg
		}
	}

	# JSON processes / folders
	if ($Method -in @('JSON', 'BOTH')) {
		$JsonPath = $LIC_BISF_CLI_PVSHydration_JsonPath
		if ([string]::IsNullOrWhiteSpace($JsonPath)) {
			$JsonPath = $DefaultJsonPath
		}
		$JsonPath = Expand-BISFHydrationEnvPath -Path ([string]$JsonPath)
		Write-BISFLog -Msg "JSON hydration path: $JsonPath" -ShowConsole -Color Cyan

		$JsonConfig = $null
		if (-not (Test-Path -LiteralPath $JsonPath -PathType Leaf)) {
			Write-BISFLog -Msg "JSON hydration file not found: $JsonPath" -Type E -ShowConsole -Color Yellow
		}
		else {
			try {
				$JsonText = Get-Content -LiteralPath $JsonPath -Raw -ErrorAction Stop
				$JsonConfig = $JsonText | ConvertFrom-Json -ErrorAction Stop
				if ($null -eq $JsonConfig -or ($JsonConfig -is [System.Array])) {
					Write-BISFLog -Msg 'JSON hydration file must be a JSON object' -Type E -ShowConsole -Color Yellow
					$JsonConfig = $null
				}
			}
			catch {
				Write-BISFLog -Msg "Failed to parse JSON hydration file: $($_.Exception.Message)" -Type E -ShowConsole -Color Yellow
				$JsonConfig = $null
			}
		}

		if ($null -ne $JsonConfig) {
			if ($null -ne $JsonConfig.folders) {
				foreach ($Folder in @($JsonConfig.folders)) {
					if ($null -eq $Folder -or [string]::IsNullOrWhiteSpace([string]$Folder.path)) {
						continue
					}
					$FolderPath = [string]$Folder.path
					$FolderExtensions = Get-BISFHydrationExtensions -Extensions $Folder.extensions
					$Recurse = $true
					if ($null -ne $Folder.recurse) {
						try {
							$Recurse = [System.Convert]::ToBoolean($Folder.recurse)
						}
						catch {
							$Recurse = $true
						}
					}
					Write-BISFLog -Msg "Enumerating JSON folder: $FolderPath (recurse=$Recurse)" -ShowConsole -Color Cyan
					$Found = Get-BISFHydrationFiles -Path $FolderPath -Extensions $FolderExtensions -Recurse $Recurse
					foreach ($File in $Found) {
						$AllFiles.Add($File) | Out-Null
					}
					Write-BISFLog -Msg "Found $($Found.Count) file(s) under $FolderPath" -ShowConsole -Color DarkCyan -SubMsg
				}
			}

			if ($null -ne $JsonConfig.processes) {
				foreach ($Proc in @($JsonConfig.processes)) {
					if ($null -eq $Proc) {
						continue
					}
					$ProcName = [string]$Proc.name
					if ([string]::IsNullOrWhiteSpace($ProcName)) {
						$ProcName = [string]$Proc.executable
					}
					$ResolvedExe = Resolve-BISFHydrationExecutable -Path ([string]$Proc.path) -Executable ([string]$Proc.executable)
					if ([string]::IsNullOrWhiteSpace($ResolvedExe)) {
						Write-BISFLog -Msg "Skipping process '$ProcName' (executable not found)" -ShowConsole -Color Yellow -SubMsg
						continue
					}

					$ReadOnly = $false
					if ($null -ne $Proc.read) {
						try {
							$ReadOnly = [System.Convert]::ToBoolean($Proc.read)
						}
						catch {
							$ReadOnly = $false
						}
					}

					if ($ReadOnly) {
						$SingleReadFiles.Add($ResolvedExe) | Out-Null
						Write-BISFLog -Msg "Queued binary read for '$ProcName': $ResolvedExe" -ShowConsole -Color DarkCyan -SubMsg
					}
					else {
						$TerminateAfter = 1
						if ($null -ne $Proc.terminateAfterInSeconds) {
							[void][int]::TryParse([string]$Proc.terminateAfterInSeconds, [ref]$TerminateAfter)
						}
						if ($TerminateAfter -lt 1) {
							$TerminateAfter = 1
						}

						$Extra = @()
						if ($null -ne $Proc.extraProcessesToTerminate) {
							if ($Proc.extraProcessesToTerminate -is [string]) {
								$Extra = @($Proc.extraProcessesToTerminate.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
							}
							else {
								$Extra = @($Proc.extraProcessesToTerminate | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
							}
						}

						$ColdStartJobs.Add([PSCustomObject]@{
								Name                     = $ProcName
								FullPath                 = $ResolvedExe
								ProcessExecutable        = [System.IO.Path]::GetFileName($ResolvedExe)
								CommandLineContains      = [string]$Proc.commandLineContains
								ExtraProcessesToTerminate = $Extra
								TerminateAfterInSeconds  = $TerminateAfter
							}) | Out-Null
						Write-BISFLog -Msg "Queued cold start for '$ProcName': $ResolvedExe (wait ${TerminateAfter}s)" -ShowConsole -Color DarkCyan -SubMsg
					}
				}
			}
		}
		elseif ($Method -eq 'JSON') {
			Write-BISFLog -Msg 'JSON method selected but no valid JSON configuration loaded. Nothing to do.' -ShowConsole -Color Yellow
			return
		}
	}

	foreach ($File in $SingleReadFiles) {
		$AllFiles.Add($File) | Out-Null
	}

	$UniqueFiles = @($AllFiles | Select-Object -Unique)
	Write-BISFLog -Msg "Total unique files to hydrate: $($UniqueFiles.Count); cold-start processes: $($ColdStartJobs.Count)" -ShowConsole -Color Cyan

	if (($UniqueFiles.Count -eq 0) -and ($ColdStartJobs.Count -eq 0)) {
		Write-BISFLog -Msg 'No hydration or cold-start work queued. Skipping.' -ShowConsole -Color Yellow
		return
	}

	if ($UseRunspaces) {
		Write-BISFLog -Msg "Starting runspace pool (1..$MaxThreads)" -ShowConsole -Color Cyan
		$RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
		$RunspacePool.Open()
		$Runspaces = New-Object System.Collections.ArrayList

		if ($UniqueFiles.Count -gt 0) {
			$BatchCount = [Math]::Min($MaxThreads, $UniqueFiles.Count)
			$BatchSize = [Math]::Ceiling($UniqueFiles.Count / $BatchCount)
			for ($Index = 0; $Index -lt $UniqueFiles.Count; $Index += $BatchSize) {
				$End = [Math]::Min($Index + $BatchSize - 1, $UniqueFiles.Count - 1)
				$Batch = @($UniqueFiles[$Index..$End])
				$PsInstance = [PowerShell]::Create().AddScript($ScriptBlockReadBatch).AddArgument($Batch)
				$PsInstance.RunspacePool = $RunspacePool
				$null = $Runspaces.Add([PSCustomObject]@{
						Id         = "HydrateBatch_$Index"
						PowerShell = $PsInstance
						Handle     = $PsInstance.BeginInvoke()
					})
			}
			Write-BISFLog -Msg "Queued $BatchCount hydration batch(es)" -ShowConsole -Color DarkCyan -SubMsg
		}

		foreach ($Job in $ColdStartJobs) {
			$PsInstance = [PowerShell]::Create().AddScript($ScriptBlockColdStart)
			$null = $PsInstance.AddArgument($Job.Name)
			$null = $PsInstance.AddArgument($Job.FullPath)
			$null = $PsInstance.AddArgument($Job.ProcessExecutable)
			$null = $PsInstance.AddArgument($Job.CommandLineContains)
			$null = $PsInstance.AddArgument($Job.ExtraProcessesToTerminate)
			$null = $PsInstance.AddArgument($Job.TerminateAfterInSeconds)
			$PsInstance.RunspacePool = $RunspacePool
			$null = $Runspaces.Add([PSCustomObject]@{
					Id         = $Job.Name
					PowerShell = $PsInstance
					Handle     = $PsInstance.BeginInvoke()
				})
		}

		Wait-BISFHydrationRunspaces -Runspaces $Runspaces -RunspacePool $RunspacePool
	}
	else {
		Write-BISFLog -Msg 'Running hydration sequentially (runspaces disabled)' -ShowConsole -Color Cyan
		$ReadCount = 0
		$FailCount = 0
		foreach ($File in $UniqueFiles) {
			$Result = Invoke-BISFHydrationReadFile -File $File
			if ($Result.Success) {
				$ReadCount++
			}
			else {
				$FailCount++
			}
		}
		Write-BISFLog -Msg "Sequential hydration complete: $ReadCount read, $FailCount failed" -ShowConsole -Color DarkCyan -SubMsg

		foreach ($Job in $ColdStartJobs) {
			$ProcessDir = Split-Path -Parent $Job.FullPath
			$Result = Invoke-BISFHydrationColdStart -ApplicationName $Job.Name -ProcessPath $ProcessDir `
				-ProcessExecutable $Job.ProcessExecutable -CommandLineContains $Job.CommandLineContains `
				-ExtraProcessesToTerminate $Job.ExtraProcessesToTerminate -TerminateAfterInSeconds $Job.TerminateAfterInSeconds
			Write-BISFLog -Msg "$($Job.Name): $($Result.Message)" -ShowConsole -Color DarkCyan -SubMsg
		}
	}

	$Elapsed = (Get-Date) - $StartTime
	Write-BISFLog -Msg ("Hydration finished in {0:N1} seconds" -f $Elapsed.TotalSeconds) -ShowConsole -Color Cyan
}

End {
	Add-BISFFinishLine
}
