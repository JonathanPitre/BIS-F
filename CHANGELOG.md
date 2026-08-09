# Changelog

All notable changes to the Base Image Script Framework (BIS-F) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses a custom versioning scheme (`major.LTSR.build`).

## [Unreleased]

### Added

- SentinelOne VDI sealing script `10_PrepBISF_AV-SentinelOne.ps1` (scan wait, VDI_MASTER / legacy `sentinelctl` identity reset)
- Rapid7 Insight Agent sealing script `10_PrepBISF_Rapid7.ps1` (stop `ir_agent`, remove `bootstrap.cfg`)

### Changed

- Fork branch `2608`: merge Pascal PDQ fixes, DennisHirsch Office 2019/2021/2024 paths, EUCweb PRs [#364](https://github.com/EUCweb/BIS-F/pull/364) / [#379](https://github.com/EUCweb/BIS-F/pull/379), selective micswe Get-WinEvent event-log clear
- Port EUCweb `5fe4abd` intent: `Set-NetAdapterRSS -NoRestart` in `52_PrepBISF_VMWareTCPIPOptimizations.ps1`

### Fixed

- Refactored README.md so it's aligned with GitHub best practices
- Converted existing README.md to CHANGELOG.md so it's aligned with GitHub best practices
- Added PSScriptAnalyzer
- Added automatic markdownlinting
- Fixed all typos, spelling and grammar error

- [#374](https://github.com/EUCweb/BIS-F/issues/374): 02_PersBISF_CTX.ps1 never finishes on Azure AD only Azure VMs (MS)
- CimInstance `.put()` volume label failure — use `Get-Volume` / `Set-Volume` (Pascal PDQ)
- Get-BISFDiskID options for missing disks (Pascal PDQ)
- [#367](https://github.com/EUCweb/BIS-F/issues/367) / [#368](https://github.com/EUCweb/BIS-F/issues/368): dangling ELSE / nvfbcenable on CVAD 2203+ (Pascal PDQ)
- RDS timebomb not created when reset attempted (Pascal PDQ)
- [#371](https://github.com/EUCweb/BIS-F/issues/371): New SEP client not recognized (trondr / EUCweb #379)
- Office 2019/2021/2024 / LTSC OSPPREARM path detection (DennisHirsch26 / EUCweb #393)

## [7.1912.7.11042] - 2022-11-19

### Fixed

- [#345](https://github.com/EUCweb/BIS-F/issues/345): Fix RES One AM agent not being registered (MS)
- [#348](https://github.com/EUCweb/BIS-F/issues/348): Add Symantec to VIE search folders (MS)
- [#347](https://github.com/EUCweb/BIS-F/issues/347): Add cleanup Empirum patch cache location (MS)
- [#353](https://github.com/EUCweb/BIS-F/issues/353): AV-WinDefender fix typo to use the right procID for the progress bar (MS)
- [#340](https://github.com/EUCweb/BIS-F/issues/340): Multiple FQDN machine certificates break EnableSSLVDA.ps1 (MS)
- [#310](https://github.com/EUCweb/BIS-F/issues/310): Update readme.txt (MS)
- [#330](https://github.com/EUCweb/BIS-F/issues/330): Fix for MS_AAD_HybridLeave (MS)

## [7.1912.6.11041] - 2021-01-19

### Fixed

- [#302](https://github.com/EUCweb/BIS-F/issues/302): Fixing MCS Cache formatting personalization (MS)
- [#304](https://github.com/EUCweb/BIS-F/issues/304): WEM Agent 2012, add new startup options to ADMX (MS)
- [#303](https://github.com/EUCweb/BIS-F/issues/303): Updated CheckCDRom function to allow for builds where CDROM drive letter has already been removed (JS)
- [#302](https://github.com/EUCweb/BIS-F/issues/302): WriteCache disk access validated in Set-Logfile function before log move (JS)
- [#42](https://github.com/EUCweb/BIS-F/issues/42): EventLog is moved, but Path is never changed (MW)
- [#299](https://github.com/EUCweb/BIS-F/issues/299): Not so fast reconnect in Windows Server 2019 (MW)
- [#297](https://github.com/EUCweb/BIS-F/issues/297): MCS CacheDisk is not formatted correctly (MS)
- [#296](https://github.com/EUCweb/BIS-F/issues/296): 10_PrepBISF_SCCM.ps1 - additional sealing steps (MS)
- [#294](https://github.com/EUCweb/BIS-F/issues/294): 10_PersBISF_FSlogix.ps1 / using registry policy value from $LIC_BISF_CLI_RS to get the central rules share (MS)
- [#294](https://github.com/EUCweb/BIS-F/issues/294): 10_PrepBISF_FSlogix.ps1 / function Set-RulesShare no longer required, RulesShare is set in registry policy path (MS)
- [#285](https://github.com/EUCweb/BIS-F/issues/285): AAD Hybrid Support to Leave / Join (MS)
- [#288](https://github.com/EUCweb/BIS-F/issues/288): Ngen executes extremely long -> ADMX Update to specify .NET Settings (MS)
- [#280](https://github.com/EUCweb/BIS-F/issues/280): Log Message for "pending reboot error" (MS)
- [#284](https://github.com/EUCweb/BIS-F/issues/284): MPCmdRun Process monitor with the current user only, exclude other accounts (MS)
- [#289](https://github.com/EUCweb/BIS-F/issues/289): Terminate ccmexec process before stopping the service (MS)

## [7.1912.5.11040] - 2020-09-16

### Fixed

- [#278](https://github.com/EUCweb/BIS-F/issues/278): Citrix AppLayering Finalize - Change NGEN Option (MS)
- [#272](https://github.com/EUCweb/BIS-F/issues/272): Central PERS Logs are missing the beginning (MS)
- [#271](https://github.com/EUCweb/BIS-F/issues/271): 00_PersBISF_WriteCacheDisk.ps1 fails, due to timing issue with registry values (MS)
- [#270](https://github.com/EUCweb/BIS-F/issues/270): PersBISF_Start.ps1 Script Causing all installed Applications to Reconfigure (MS)
- [#255](https://github.com/EUCweb/BIS-F/issues/255): MSI installer creates two entries under the Uninstall key (MS)
- [#252](https://github.com/EUCweb/BIS-F/issues/252): Supporting new NVIDIA Drivers (MS)
- [#265](https://github.com/EUCweb/BIS-F/issues/265): Office 2010 rearm is not performed (MS)
- [#269](https://github.com/EUCweb/BIS-F/issues/269): Office detection takes too long, using reg instead of WMI (MS)
- [#258](https://github.com/EUCweb/BIS-F/issues/258): ADML: typo in Configure Personalization (MS)
- [#260](https://github.com/EUCweb/BIS-F/issues/260): McAfee add support for 5.6.x (MS)
- [#261](https://github.com/EUCweb/BIS-F/issues/261): CylanceProtect fix error handling (MS)
- [#262](https://github.com/EUCweb/BIS-F/issues/262): UPL + PVS Target Device Driver doesn't convert VHDX (MS)
- [#268](https://github.com/EUCweb/BIS-F/issues/268): Using SID to translate it to the real name to support MUI Systems (MS)
- [#266](https://github.com/EUCweb/BIS-F/issues/266): Typo in 97_PrepBISF_PRE_BaseImage.ps1 (MS)
- [#267](https://github.com/EUCweb/BIS-F/issues/267): Personalization action is running twice (Script 01_PersBISF_TimeAndGPO.ps1 removed) (MS)
- [#253](https://github.com/EUCweb/BIS-F/issues/253): VDA SSL Wildcard Cert Case Sensitive (Line 176 & 178) (MS)
- [#257](https://github.com/EUCweb/BIS-F/issues/257): Azure WVD not detected (MS)

## [7.1912.4.11038] - 2020-06-21

### Fixed

- [#249](https://github.com/EUCweb/BIS-F/issues/249): WEMCache folder will be reconfigured if UPL is installed (Use-PVSConfig/Use-MCSConfig) (MS)
- [#251](https://github.com/EUCweb/BIS-F/issues/251): Wrong Citrix AppLayering Layer detected with UPL and on Server OS (MS)
- [#250](https://github.com/EUCweb/BIS-F/issues/250): VDA SSL Wildcard Support (Line 177 - 179) (MS)
- [#247](https://github.com/EUCweb/BIS-F/issues/247): Function Test-AppLayeringSoftware - DomainMember output - missing $ (MS)

## [7.1912.3.11037] - 2020-06-15

### Fixed

- Fix evaluation notification in MSI installer (MS)

## [7.1912.3.11036] - 2020-06-15

### Fixed

- Fix evaluation notification in EXE installer (MS)

## [7.1912.3.11034] - 2020-06-13

### Added

- [#225](https://github.com/EUCweb/BIS-F/issues/225): Providing MSI Installer (MS)

## [7.1912.3.11033] - 2020-06-13

### Added

- [#241](https://github.com/EUCweb/BIS-F/issues/241): Skip PVS UNC vDisk Size if PVS Master Image is skipped (MS)

### Fixed

- [#233](https://github.com/EUCweb/BIS-F/issues/233): Skipping ApexOne, see https://github.com/EUCweb/BIS-F/issues/233 for further information (MS)
- [#240](https://github.com/EUCweb/BIS-F/issues/240): SSLVDA optimization with Certificate determination, Auto enrollment option, Skip certificate verification (DS)
- [#233](https://github.com/EUCweb/BIS-F/issues/233): TM Process not killed, using new function Stop-BISFProcesses (MS)
- [#187](https://github.com/EUCweb/BIS-F/issues/187): VDA 1912 inside AppLayering Packaging VM wrong Layer back (MS)
- [#238](https://github.com/EUCweb/BIS-F/issues/238): CylanceProtect - VDI Fingerprinting support (MS)
- [#239](https://github.com/EUCweb/BIS-F/issues/239): Invoke-FolderScripts is relying on the default order from Get-ChildItem (MS)
- [#242](https://github.com/EUCweb/BIS-F/issues/242): Shared Configuration error handling if FilePath is Null Or Empty (MS)
- [#229](https://github.com/EUCweb/BIS-F/issues/229): Shut Down after generalization is not completing if PVS image creation is skipped (MS)
- [#236](https://github.com/EUCweb/BIS-F/issues/236): No MSFT_NetAdapterRssSettingData objects found (MS)
- [#226](https://github.com/EUCweb/BIS-F/issues/226): App-V PowerShell Module Could Not Be Loaded (MS)
- [#217](https://github.com/EUCweb/BIS-F/issues/217): PowerShell Version 5 Notification (MS)
- [#214](https://github.com/EUCweb/BIS-F/issues/214): McAfee MOVE Self Protection blocks the modification of the registry (MS)
- [#231](https://github.com/EUCweb/BIS-F/issues/231): Skipping file precache if vDisk is in private Mode (MS)
- [#220](https://github.com/EUCweb/BIS-F/issues/220): Fix typo for DirtyShutdown Flag (MS)
- [#232](https://github.com/EUCweb/BIS-F/issues/232): CacheDisk not formatted (MS)
- [#222](https://github.com/EUCweb/BIS-F/issues/222): Fixing encoding (MS)
- [#223](https://github.com/EUCweb/BIS-F/issues/223): Advanced Installer: Empty Folder in Program Menu (MS)

## [7.1912.2.11029] - 2020-02-26

### Added

- [#200](https://github.com/EUCweb/BIS-F/issues/200): New Advanced Installer fix Trial Popup (MS)

## [7.1912.2.11028] - 2020-02-25

### Added

- [#200](https://github.com/EUCweb/BIS-F/issues/200): New Advanced Installer - change to get $InstallLocation and $BISFversion (MS)

## [7.1912.2.011025] - 2020-02-24

### Added

- [#208](https://github.com/EUCweb/BIS-F/issues/208): ADMX/ADML fix FSLogix grammar (JK)

### Removed

- [#213](https://github.com/EUCweb/BIS-F/issues/213): Remove git stash lines (KT)

### Fixed

- [#206](https://github.com/EUCweb/BIS-F/issues/206): ADML: WEM AgentCache better description (MS)
- [#210](https://github.com/EUCweb/BIS-F/issues/210): App-V PackageInstallationRoot not detected properly (MS)
- [#137](https://github.com/EUCweb/BIS-F/issues/137): TM OfficeScan wrong GUID -> using Get-BISFMacaddress -ConvertToLower to get the lowercase MAC (MS)
- [#212](https://github.com/EUCweb/BIS-F/issues/212): SEP duplicate HardwareID - Get-BISFMacaddress returns lower- instead of uppercase MACAddress (MS)
- [#211](https://github.com/EUCweb/BIS-F/issues/211): Fixed Log output spelling (JK)
- [#206](https://github.com/EUCweb/BIS-F/issues/206): Reboot loop if central logshare is configured (MS)
- [#207](https://github.com/EUCweb/BIS-F/issues/207): Pagefile not set (MS)
- [#201](https://github.com/EUCweb/BIS-F/issues/201): Hydration not starting if configured (MS)

## [7.1912.1.011024] - 2020-01-31

### Added

- [#165](https://github.com/EUCweb/BIS-F/issues/165): Detect UPL - new feature with VDA 1912 LTSR (MS)

### Removed

- [#173](https://github.com/EUCweb/BIS-F/issues/173): Remove DHCP Information if 3P Optimizer is configured too (MS)

### Fixed

- [#196](https://github.com/EUCweb/BIS-F/issues/196): WEM Agent: GPO help description (MS)
- [#195](https://github.com/EUCweb/BIS-F/issues/195): Shared Configuration not imported (MS)
- [#194](https://github.com/EUCweb/BIS-F/issues/194): Format WriteCacheDisk didn't run if "skip PVS master image creation" enabled (MS)
- [#167](https://github.com/EUCweb/BIS-F/issues/167): Moving AppLayering Layer Finalize to Post BIS-F script (MS)
- [#191](https://github.com/EUCweb/BIS-F/issues/191): MaxExecution is not set correctly (MS)
- [#186](https://github.com/EUCweb/BIS-F/issues/186): Deletion of C:\Windows\temp without GPO control is not possible (MS)
- [#183](https://github.com/EUCweb/BIS-F/issues/183): Fix defrag arguments for Server 2012 R2 (MS)
- [#188](https://github.com/EUCweb/BIS-F/issues/188): Async WriteCacheType not detected for shared Images to format the disk and ending up in a reboot loop (MS)
- [#172](https://github.com/EUCweb/BIS-F/issues/172): Function Set-BISFNTFSRights: Resolve SID S-1-5-19 to localized name to set proper NTFS ACLRights (MS/AS)
- [#186](https://github.com/EUCweb/BIS-F/issues/186): Deletion of C:\Windows\temp without GPO control is not possible (MS)
- [#183](https://github.com/EUCweb/BIS-F/issues/183): Fix defrag arguments for Server 2012 R2 (MS)
- [#181](https://github.com/EUCweb/BIS-F/issues/181): Show-ProgressBar function never ends if it triggers from MDT cscript (MS)
- [#182](https://github.com/EUCweb/BIS-F/issues/182): If LogRotate is set to 0 it doesn't keep all logs (MS)
- [#180](https://github.com/EUCweb/BIS-F/issues/180): IF WEM Config is not configured it also processes reconfiguration (MS)
- [#178](https://github.com/EUCweb/BIS-F/issues/178): No default value is set if GPO for Additional Citrix Desktop Service delay is not configured (MS)
- [#174](https://github.com/EUCweb/BIS-F/issues/174): Office detection general change (MS)
- [#176](https://github.com/EUCweb/BIS-F/issues/176): $Global:ImageSW request is set one time only (MS)
- [#177](https://github.com/EUCweb/BIS-F/issues/177): Typo in DiskMode (00_persBISF_writeCacheDisk.ps1) (MS)
- [#175](https://github.com/EUCweb/BIS-F/issues/175): GPO ADML file typo and grammar check (MS)
- [#172](https://github.com/EUCweb/BIS-F/issues/172): Using S-1-5-19 instead of local Service (MS)
- [#171](https://github.com/EUCweb/BIS-F/issues/171): VMware TCPIP Optimizations failed (MS)
- [#170](https://github.com/EUCweb/BIS-F/issues/170): C:\Windows\Logs does not exist - function Test-BISFWriteCacheDisk (MS)
- [#169](https://github.com/EUCweb/BIS-F/issues/169): Disable redirection if MCS GPO is disabled (MS)
- [#168](https://github.com/EUCweb/BIS-F/issues/168): VMware Optimizations 52_PrepBISF_VMwareTCPIPOptimization not executed (MS)
- [#166](https://github.com/EUCweb/BIS-F/issues/166): CylanceProtect - Wrong Command for Compatibility Mode (MS)
- [#164](https://github.com/EUCweb/BIS-F/issues/164): Layer finalize is blocked with VDA 1912 LTSR and activated UPL (MS)

## [7.1912.0.011023] - 2019-12-28

### Added

- [#154](https://github.com/EUCweb/BIS-F/issues/154): Adjust for compositing engine change in AppLayering 1911 and higher (MS/SF)
- [#93](https://github.com/EUCweb/BIS-F/issues/93): Detect Citrix Cloud Connector installation and prevent BIS-F from running (MS)
- [#146](https://github.com/EUCweb/BIS-F/issues/146): Move Get-PendingReboot to earlier phase of preparation (MS)
- [#145](https://github.com/EUCweb/BIS-F/issues/145): ADMX: Disable Redirection for Citrix PVS Target (MS)
- [#52](https://github.com/EUCweb/BIS-F/issues/52): Citrix AppLayering - different shared configuration based on Layer (MS)
- [#144](https://github.com/EUCweb/BIS-F/issues/144): ADMX Extension: Enable PowerShell Transcript (MS)
- [#22](https://github.com/EUCweb/BIS-F/issues/22): Get DiskIDs of the system - for monitoring only -> for later use to fix 'Endless Reboot with VMware Paravirtual SCSI disk' (MS)
- [#143](https://github.com/EUCweb/BIS-F/issues/143): Add Intel Graphics Support for Citrix VDA (MS)
- [#16](https://github.com/EUCweb/BIS-F/issues/16): Add NVIDIA GRID Support for Citrix VDA (MS)
- [#43](https://github.com/EUCweb/BIS-F/issues/43): Sihclient.exe consumes CPU load with disabled WSUS Service (function invoke-sihTask) (MS)
- [#11](https://github.com/EUCweb/BIS-F/issues/11): ADMX extension: Configure WEM Cache to persistent drive (PVS and MCSIO) (MS)
- [#94](https://github.com/EUCweb/BIS-F/issues/94): Add sysprep command-line options to ADMX (MS)
- [#28](https://github.com/EUCweb/BIS-F/issues/28): Check if there's enough disk space on P2V Custom UNC-Path (MS)
- [#101](https://github.com/EUCweb/BIS-F/issues/101): Test sdelete64.exe or sdelete.exe during preparation if it exists (MS)
- [#102](https://github.com/EUCweb/BIS-F/issues/102): Use CCleaner64.exe on x64 system (MS)
- [#139](https://github.com/EUCweb/BIS-F/issues/139): WEM 1909 detection (MS)
- [#140](https://github.com/EUCweb/BIS-F/issues/140): FSLogix: cleanup redirected CloudCache empty directories on startup (MS)
- [#141](https://github.com/EUCweb/BIS-F/issues/141): FSLogix: Add App Masking URL Rule Files for personalization (MS)
- [#84](https://github.com/EUCweb/BIS-F/issues/84): Azure Activation for all Office 365 users and during personalization displays the device join status (MS)
- [#126](https://github.com/EUCweb/BIS-F/issues/126): MCSIO with persistent CacheDisk (MS)
- [#127](https://github.com/EUCweb/BIS-F/issues/127): Personalization is in Active State Override (MS)
- [#9](https://github.com/EUCweb/BIS-F/issues/9): LAPS Support for Non-Persistent VDI (MS)
- [#36](https://github.com/EUCweb/BIS-F/issues/36): Shared Configuration - JSON Export and Import (MS)
- [#136](https://github.com/EUCweb/BIS-F/issues/136): Detect PVS Private Image with Asynchronous IO (MS)
- [#128](https://github.com/EUCweb/BIS-F/issues/128): PVS configuration without Persistent drive (MS)
- [#132](https://github.com/EUCweb/BIS-F/issues/132): Windows 10 Enterprise for Virtual Desktops (WVD) Support (MS)
- [#8](https://github.com/EUCweb/BIS-F/issues/8): VMware RSS and TCPIP Optimizations integrated into BIS-F (MS)
- [#129](https://github.com/EUCweb/BIS-F/issues/129): PVS Hydration Personalization stage (MS)
- [#101](https://github.com/EUCweb/BIS-F/issues/101): Use sdelete64.exe on x64 system (MS)
- [#54](https://github.com/EUCweb/BIS-F/issues/54): ADMX: Configure BIS-F Desktop Shortcut (MS)
- [#78](https://github.com/EUCweb/BIS-F/issues/78): Sealing for Ivanti Automation agent can be disabled in ADMX (MS)
- [#88](https://github.com/EUCweb/BIS-F/issues/88): Supporting McAfee Endpoint Security (MS)
- [#118](https://github.com/EUCweb/BIS-F/issues/118): Add Tanium Support (MS)
- [#6](https://github.com/EUCweb/BIS-F/issues/6): Parallels RAS Support (MS)
- [#98](https://github.com/EUCweb/BIS-F/issues/98): Add function Set-CompatibilityMode (MS)
- [#108](https://github.com/EUCweb/BIS-F/issues/108): Set NTFS Rights for redirected Eventlog and spool directory (MS)
- [#98](https://github.com/EUCweb/BIS-F/issues/98): Skip execution of PVS Target OS Optimization (MS)
- [#46](https://github.com/EUCweb/BIS-F/issues/46): Make any PVS conversion work Optional (AS)
- [#97](https://github.com/EUCweb/BIS-F/issues/97): Nutanix Xi Frame Support (MS)
- [#89](https://github.com/EUCweb/BIS-F/issues/89): Cylance PROTECT generalization (MK)
- [#83](https://github.com/EUCweb/BIS-F/issues/83): Supporting McAfee Move integration (MS)
- [#14](https://github.com/EUCweb/BIS-F/issues/14): ADMX Extension - enable additional time to delay the Citrix Desktop Service (MS)
- [#17](https://github.com/EUCweb/BIS-F/issues/17): Read $MaximumExecutionMinutes from ADMX if not internal override during BIS-F Call (MS)
- [#15](https://github.com/EUCweb/BIS-F/issues/15): Support for Office 365 Click-to-Run (MS)
- Added the removal of ACLs for BUILTIN\USERS to C:\ (TT)

### Changed

- [#12](https://github.com/EUCweb/BIS-F/issues/12): Configure sDelete for different environments (MS)
- [#107](https://github.com/EUCweb/BIS-F/issues/107): Configures Citrix VDA for SSL communication during computer startup (MS)
- [#121](https://github.com/EUCweb/BIS-F/issues/121): Change filename extension from bis to log (MS)
- [#104](https://github.com/EUCweb/BIS-F/issues/104): Updated service detection in 10_PrepBISF_Empirum.ps1 (MK)
- ENH76 - detect the platform of the running computer (MS)
- [#91](https://github.com/EUCweb/BIS-F/issues/91): Moved FSLogix settings to Microsoft ADMX category (JP)
- Updated Group Policy templates, fixed typos and errors, removed the German one since it's in English anyway (JP)
- Updated Write-BISFProgressBar to include the options MaximumExecutionMinutes and TerminateRunawayProcess (TT)

### Removed

- [#77](https://github.com/EUCweb/BIS-F/issues/77): Removing Wsus ClientSide Targeting and reset it during every sealing process (MS)
- [#142](https://github.com/EUCweb/BIS-F/issues/142): Remove DirtyShutdown Flag (MS)
- [#65](https://github.com/EUCweb/BIS-F/issues/65): ADMX Extension to delete the log files for Citrix Optimizer (MS)
- [#133](https://github.com/EUCweb/BIS-F/issues/133): Removing Disable scheduled Task (MS)
- [#134](https://github.com/EUCweb/BIS-F/issues/134): Removing Disable Cortana (MS)
- [#3](https://github.com/EUCweb/BIS-F/issues/3): VerySilent is no longer necessary in ADMX; because all MessageBoxes are removed completely (MS)
- [#3](https://github.com/EUCweb/BIS-F/issues/3): Remove Message box and using default setting if GPO is not configured (MS)
- Removed the disabling of Receive Side Scaling (TT)

### Fixed

- [#160](https://github.com/EUCweb/BIS-F/issues/160): Calculation of free space for the VHDX on UNC-Path (MS/MN)
- [#162](https://github.com/EUCweb/BIS-F/issues/162): Note when logging on to a created VDisk (after ENH142) (MS/MN)
- [#161](https://github.com/EUCweb/BIS-F/issues/161): Quotation marks are different in Move-BISFEvtLogs (MS/MN)
- [#159](https://github.com/EUCweb/BIS-F/issues/159): C:\Windows\temp not deleted (MS/MN)
- [#153](https://github.com/EUCweb/BIS-F/issues/153): SCCM Agent preparation - fix Test-BISFService - parameter cannot be found (MS/SF)
- [#15](https://github.com/EUCweb/BIS-F/issues/15): Bug fix with Office 365 Implementation, overwrite the value for Office 2016 detection (MS)
- [#20](https://github.com/EUCweb/BIS-F/issues/20): Installer - Scripts not in custom folders being kept during Update and fix to keep the content of the custom folder now (MS)
- [#69](https://github.com/EUCweb/BIS-F/issues/69): If WriteCache disk on master is GPT partition then uniqueid doesn't match (MS)
- [#30](https://github.com/EUCweb/BIS-F/issues/30): Format CacheDisk on shared Images only to prevent reboot loop (MS)
- [#138](https://github.com/EUCweb/BIS-F/issues/138): UberAgent: didn't change the startup type to automatic (MS)
- [#137](https://github.com/EUCweb/BIS-F/issues/137): Generated GUID based on MAC-Address return in lowercase (MS)
- [#21](https://github.com/EUCweb/BIS-F/issues/21): Endless Reboot with wrong count of Partitions (MS)
- [#125](https://github.com/EUCweb/BIS-F/issues/125): ADMX: Wrong description in Global -> Configure Personalization (MS)
- Fixed encoding, tabs (4), format, style, a few typos, merging errors and removed eof extra lines (JP)
- [#87](https://github.com/EUCweb/BIS-F/issues/87): Symantec Endpoint Protection 14.0 MP2 prevents graceful Citrix session logoff (MS)
- [#32](https://github.com/EUCweb/BIS-F/issues/32): FSLogix - When in the GPO specify "Configure FSLogix central rule share" to Disabled, the script still prompts for the path when is executed (MS)
- [#33](https://github.com/EUCweb/BIS-F/issues/33): If sysprep is enabled and other Management SW like Citrix VDA, PVS Target Device Driver, VMware View Agent is installed, the script breaks (MS)
- Fixed typos in the ADMX/ADML file, moved settings back to the MS Cat, reordered the Cat alphanumerically (JP)
- Event logs would be moved for both States (Prep and Pers) now, after changing it in V6.1.0 build 03.101 (MS)

## [6.1.3+01.110] - 2019-08-11

### Added

- [#122](https://github.com/EUCweb/BIS-F/issues/122): Citrix Optimizer Template prefix support (MS)

## [6.1.2+01.109] - 2019-07-24

### Added

- [#112](https://github.com/EUCweb/BIS-F/issues/112): CTX optimizer: Multiple Templates with AutoSelect for OS Template (MS)
- [#117](https://github.com/EUCweb/BIS-F/issues/117): WinSxS hide DISM process and get logfile of the DISM Process into BIS-F log (MS)
- [#115](https://github.com/EUCweb/BIS-F/issues/115): ADMX: Control of WinSxS Optimization (MS)

### Fixed

- [#116](https://github.com/EUCweb/BIS-F/issues/116): During Preparation, BIS-F Shows Version number instead of OSName (MS)
- [#82](https://github.com/EUCweb/BIS-F/issues/82): RES ONE Automation Agent - Action is missing (MS)

## [6.1.1+01.105] - 2019-05-31

### Added

- [#105](https://github.com/EUCweb/BIS-F/issues/105): Keep Windows Administrative Tools in Start menu (MS)
- [#92](https://github.com/EUCweb/BIS-F/issues/92): Server 2019 Support (MS)
- [#111](https://github.com/EUCweb/BIS-F/issues/111): Support for multiple Citrix Optimizer Templates (MS)

### Changed

- Update link to new webpage https://eucweb.com (MS)

### Removed

- [#106](https://github.com/EUCweb/BIS-F/issues/106): Remove unnecessary out-null command function Optimize-WinSxs (MS)

### Fixed

- [#24](https://github.com/EUCweb/BIS-F/issues/24): Reconfigure Citrix Broker Service if disabled / not configured in ADMX (MS)
- [#87](https://github.com/EUCweb/BIS-F/issues/87): Symantec Endpoint Protection 14.0 MP2 prevents graceful Citrix session logoff (MS)

## [6.1.0+01.104] - 2019-03-31

### Added

- [#86](https://github.com/EUCweb/BIS-F/issues/86): Office 2019 Support (MS)

## [6.1.0+01.103] - 2018-12-17

### Fixed

- [#80](https://github.com/EUCweb/BIS-F/issues/80): CTXO: Template names are changed in order to support auto-selection (MS)

## [6.1.0+01.102] - 2018-12-10

### Fixed

- [#79](https://github.com/EUCweb/BIS-F/issues/79): BIS-F Installer can be used on x86 systems (MS)
- [#75](https://github.com/EUCweb/BIS-F/issues/75): CTXO: If template does does not exist, end BIS-F execution (MS)
- [#18](https://github.com/EUCweb/BIS-F/issues/18): XA/ XD 7.x Cache folder will be created (MS)
- [#47](https://github.com/EUCweb/BIS-F/issues/47): MSMQ windows services will fail to start in App Layering (MS)
- [#62](https://github.com/EUCweb/BIS-F/issues/62): BIS-F AppLayering - Layer Finalized is blocked with MCS - Booting Layered Image (MS)
- [#74](https://github.com/EUCweb/BIS-F/issues/74): The Version from the Service could not extracted (MS)
- [#66](https://github.com/EUCweb/BIS-F/issues/66): Vietool.exe - custom searchpath not working correctly (MS)
- [#55](https://github.com/EUCweb/BIS-F/issues/55): Windows Defender -ArgumentList failing (MS)
- [#63](https://github.com/EUCweb/BIS-F/issues/63): Citrix AppLayering - Create C:\Windows\Logs folder automatically if it doesn't exist (MS)
- [#56](https://github.com/EUCweb/BIS-F/issues/56): Office C2R or other AppX issue after BIS-F seal (MS)
- [#73](https://github.com/EUCweb/BIS-F/issues/73): MCS Image in Private Mode does not start the Windows Update Service (MS)
- [#71](https://github.com/EUCweb/BIS-F/issues/71): Not to process ANY scheduled task disable actions (MS)
- [#72](https://github.com/EUCweb/BIS-F/issues/72): MCS Deployment: SCOM Agent - creates OpsStateDir in C: drive (MS)
- [#58](https://github.com/EUCweb/BIS-F/issues/58): McAfee - remove hardcoded maconfig.exe path (MS)
- [#40](https://github.com/EUCweb/BIS-F/issues/40): PendingReboot - give an empty value back (MS)
- [#48](https://github.com/EUCweb/BIS-F/issues/48): AppLayering RunMode + Get-DiskMode from PVS / MCS Deployment needed, to get the right layer (MS)
- [#50](https://github.com/EUCweb/BIS-F/issues/50): Set Global Variable after Registry is set (After LogShare is changed in ADMX, the old path will also be checked and skips execution) (MS)
- [#44](https://github.com/EUCweb/BIS-F/issues/44): Pickup the right Citrix Optimizer Default Template, like Citrix_Windows10_1803.xml, also prepared for Server 2019 Template, like Citrix_WindowsServer2019_1803.xml (MS)
- [#49](https://github.com/EUCweb/BIS-F/issues/49): After SEP is started with smc.exe, sometimes the service will not be started. Controlled and logged now with Test-BISFServiceState in Line 58 (MS)
- [#49](https://github.com/EUCweb/BIS-F/issues/49): Running Test-BISFServiceState after changing Service to get the right Status back (MS)
- [#48](https://github.com/EUCweb/BIS-F/issues/48): Using RunMode to detect the right AppLayer, persistent between AppLayering updates (MS)
- [#41](https://github.com/EUCweb/BIS-F/issues/41): Set SplunkForwarder to StartType Automatic (MS)
- [#40](https://github.com/EUCweb/BIS-F/issues/40): New Script to get pending reboot state (MS)
- [#38](https://github.com/EUCweb/BIS-F/issues/38): MachineState 3 not detected, Pre-ELM State, Layer finalized must not run (MS)
- [#37](https://github.com/EUCweb/BIS-F/issues/37): SCOM 2016, uses new certificate store Microsoft Monitoring Agent (MS)

## [6.1.0+01.101] - 2018-03-20

### Changed

- Migrated BIS-F to GitHub, new IDs for Issue (MS)
- Updated Write-BISFProgressBar to include the options MaximumExecutionMinutes and TerminateRunawayProcess (TT)

### Fixed

- [#29](https://github.com/EUCweb/BIS-F/issues/29): AppLayering does not detect the right layer (MS)
- [#32](https://github.com/EUCweb/BIS-F/issues/32): FSLogix - When in the GPO specify "Configure FSLogix central rule share" to Disabled, the script still prompts for the path when is executed (MS)
- [#33](https://github.com/EUCweb/BIS-F/issues/33): If sysprep is enabled and other Management SW like Citrix VDA, PVS Target Device Driver, VMware View Agent is installed, the script breaks (MS)
- [#38](https://github.com/EUCweb/BIS-F/issues/38): MachineState 3 not detected, Pre-ELM State, Layer finalized must not run (MS)
- [#37](https://github.com/EUCweb/BIS-F/issues/37): SCOM 2016, uses new certificate store Microsoft Monitoring Agent (MS)
- [#24](https://github.com/EUCweb/BIS-F/issues/24): Reconfigure Citrix Broker Service if disabled / not configured in ADMX (MS)
- [#29](https://github.com/EUCweb/BIS-F/issues/29): AppLayering does not detect the right layer (MS)
- [#32](https://github.com/EUCweb/BIS-F/issues/32): FSLogix - When in the GPO specify "Configure FSLogix central rule share" to Disabled, the script still prompts for the path when is executed (MS)
- [#33](https://github.com/EUCweb/BIS-F/issues/33): If sysprep is enabled and other Management SW like Citrix VDA, PVS Target Device Driver, VMware View Agent is installed, the script breaks (MS)
- Event logs would be moved for both States (Prep and Pers) now, after changing it in V6.1.0 build 03.101 (MS)

## [6.1.0+01.100] - 2017-11-26

### Added

- Added XML tag in ADMX, ADML files (JP)
- .NET Optimization controlled in ADMX, Category Microsoft (MS)
- Support now for Office x64 and x86, Read Office Installation path from registry instead of hardcoded Filepath (MS)
- Added $LIC_BISF_3RD_OPT = $false, if vmOSOT or CTXO is enabled and found, $LIC_BISF_3RD_OPT = $true and disable BIS-F own optimizations (MS)
- Function Use-BISFPVSConfig - if PVS Target Device Driver not installed, write info to BIS-F log and set the value $Global:Redirection=$true; $Global:RedirectionCode="NoPVS" (MS)
- Function Get-BISFBootMode - writing BootMode (UEFI or Legacy) in Function to BISF log (MS)
- Preparation: get detailed OS License Information and write them to the BIS-F Log (MS)
- Preparation: Office Rearm state writes to BIS-F Log (MS)
- Personalization - get Office activation state and License state back to the BIS-F log (MS)
- Added check if Defrag Service is running, thanks to Lejkin Dmitrij (MS)

### Changed

- ADMX: change Category Ivanti Automation to Ivanti (MS)
- 10_PrepBISF_AV-SEP.ps1 - Change Name in Log and Display from VIEtool.exe to Symantec Virtual Image Exception (VIE) Tool (MS)
- Replaced DiskMode MCS with VDA value (MS)

### Removed

- [#216](https://github.com/EUCweb/BIS-F/issues/216): During uninstall of BIS-F, the schedule task is deleted also (MS)

### Fixed

- Fixed spelling and grammar errors in ADMX, ADML files (JP)
- If Error appears, exit script with Exit 1 (MS)
- On the Mounted Disk, the same UniqueID must be set to fix boot record issues (https://blogs.technet.microsoft.com/markrussinovich/2011/11/06/fixing-disk-signature-collisions/) (MS)
- Show the right Eventlog during move to the WCD (MS)
- Retry 30 times if Logshare on network path is not found with fallback after max. is reached (MS)
- If booting up in private Mode the vhdx and custom unc-path for P2V is configured, defrag runs on the UNC-Path and not on the BaseDisk itself (MS)
- IF $DiskNameExtension -eq "noVirtualDisk" and custom UNC-Path is enabled, running OfflineDefrag on custom UNC-Path (MS)
- AppLayering, Outside ELM no UniService must be running (MS)
- Custom UNC-Path get the wrong value back and does not perform a defrag on the vhd(x) and set the right value now $Global:TestDiskMode (MS)

## [6.1.0+02.103] - 2017-10-19

### Changed

- MSMQ show in Console Front instead SubMsg (MS)

### Fixed

- Defrag select the right vDisk on the custom UNC-Path or the direct conversion (MS)

## [6.1.0+02.102] - 2017-10-19

### Added

- Add Offline VHD Defrag on custom unc path, thanks to Dennis Span (MS)
- ADMX change RES to ivanti Automation, thanks to Chris Twiest (MS)
- ADM extension PVS Target Device: select vDisk Type VHDX/VHD that can be using for P2PVS only, thanks to Christian Schuessler (MS)
- AV-SEP.ps1: VIETool - using custom search folder from ADMX if enabled (MS)

### Fixed

- Running Office rearm first and second OS rearm, thanks to Bernd Baedermann (MS)
- Error handling - script will stop now after -Type E for Write-BISFLog (MS)
- AppLayering, check if the Layer finalize is allowed before continue, thanks to Brandon Mitchell (MS)
- OS rearm never run, path to slmgr.vbs must be entered before, thanks to Bernd Baedermann (MS)
- Detecting wrong PowerShell Version if running BIS-F remotely, using $PSVersionTable.PSVersion.Major, thanks to Fabian Danner (MS)
- [#214](https://github.com/EUCweb/BIS-F/issues/214): SCOM Preparation - Test path if $OpsStateDirOrigin before delete, instead of complete C: content if $OpsStateDirOrigin is not available (MS)
- [#215](https://github.com/EUCweb/BIS-F/issues/215): Personalization - writing wrong PersState to registry, preparation does not run in that case, thanks to Ewald Bracko (MS)

## [6.1.0+02.101] - 2017-09-22

### Fixed

- [#0](https://github.com/EUCweb/BIS-F/issues/0): _PersBISF_WriteCacheDisk.ps1 - change reboot command to use shutdown /r instead of restart-computer (MS)

## [6.1.0+02.100] - 2017-09-22

### Added

- RES Automation Agent Service could be controlled from ADMX (MS)
- CMTrace - using custom search folder from ADMX if enabled (MS)

### Changed

- After WriteCacheDisk would formatted during personalization, wait after reboot (MS)
- Invoke-CDS Changing to $service name = "BrokerAgent" to control the delay of the Service (MS)

### Fixed

- Central logshare enabled for preparation also (MS)
- Fix some typos (MS)
- [#212](https://github.com/EUCweb/BIS-F/issues/212): If personality.ini does does not exist, run Set-PVSTool otherwise check vDiskMode (MS)

## [6.1.0+03.106] - 2017-09-12

### Changed

- Using progressbar during wait for the personalization is finished (MS)
- Using Array in Initialize-BISFConfiguration $Global:TaskStates= @("AfterInst","AfterPrep","Active","Finished") instead of hardcoded values (MS)

## [6.1.0+03.105] - 2017-09-11

### Added

- Control flag for preparation to run it after the personalization is finished first (MS)

### Changed

- Change sleep timer from 5 to 20 seconds after time sync on startup (MS)
- WEM AgentCacheRefresh can be using without the WEM Brokername specified from WEM ADMX (MS)

### Fixed

- Delay Citrix Desktop Service must be stopped also (MS)

## [6.1.0+03.104] - 2017-09-11

### Added

- Add missing function name for Invoke-Service (FF)

## [6.1.0+03.103] - 2017-09-10

### Added

- [#211](https://github.com/EUCweb/BIS-F/issues/211): VDA Configuration (ADMX) - Delay Citrix Desktop Service, start this Service after personalization is finished (MS)
- [#182](https://github.com/EUCweb/BIS-F/issues/182): Windows Defender Signature will only be updated if Defender is enabled to run (FF)
- Added the TmPfw (OfficeScan NT Firewall) service to the array

### Changed

- This should be implemented for both RDS and VDI workloads, especially if using published
- Applications, as it prevents the PccNTMon.exe process from running in user sessions, which
- Means that the OfficeScan (OSCE) Agent or WFBS-SVC (Worry-Free Business Security Services)
- Icon is unavailable in the system tray
- Function and modified the StopService function to make it reliable

### Fixed

- [#205](https://github.com/EUCweb/BIS-F/issues/205): 10_PersBISF_AV-TM.ps1 - Added the TmPfw (OfficeScan NT Firewall) service to the array (JS)
- [#205](https://github.com/EUCweb/BIS-F/issues/205): 10_PrepBISF_AV-TM.ps1 - Updated ini file and delete run value as per https://success.trendmicro.com/solution/1102736 (JS)
- [#205](https://github.com/EUCweb/BIS-F/issues/205): 10_PrepBISF_AV-TM.ps1 - I found that the services were not being stopped and set to manual, so added a new TerminateProcess (JS)

## [6.1.0+03.102] - 2017-09-06

### Added

- [#203](https://github.com/EUCweb/BIS-F/issues/203): ADMX - Custom Arguments for P2PVS / ImagingWizard (MS)

### Changed

- [#204](https://github.com/EUCweb/BIS-F/issues/204): Replaced AdminGuide.pdf with Online eDocs http://edocs.eucweb.com (MS)
- PowerShell Progressbar, sleep time during preparation only, change it from 10 to 5 seconds (MS)
- Change sleep timer from 60 to 5 seconds after time sync on startup (MS)

### Fixed

- [#201](https://github.com/EUCweb/BIS-F/issues/201): Enable maximumExecutionTime in Write-BISFProgressBar, if not specified the default value of 60 minutes would be set (TT)
- Event logs would be moved for both States (Prep and Pers) now, after changing it in V6.1.0 build 03.101 (MS)

## [6.1.0+03.101] - 2017-08-31

### Changed

- Clear all Event logs (MS)

### Fixed

- Event logs would be moved during Preparation only, this saved time during personalization (MS)
- P2V with UNC Path failed with space is in UNC Path (MS)
- VHDX on UNC-Path would be created with double .vhdx extension (MS)

## [6.1.0+03.100] - 2017-08-24

### Added

- 97_PrepBISF_PRE_BaseImage.ps1 - cleanup various directories, like temp, thanks to Trentent Tye (MS)

### Fixed

- If AppLayering is installed and running not inside ELM, the VM is build first time, run defrag on systemdrive (MS)
- If OS and Platform/Application Layer not detected, VM is not running inside ELM, give back $Global:CTXAppLayerName="No-ELM" (MS)
- After restart WEM Agentservice, Netlogon must be started also (MS)
- Fixed typos in the ADMX/ADML file, optimized folder structure, removed duplicate definition (WindowsVista) (JP)
- Create or update BIS-F schedule Task to run with highest privileges (MS)
- If defrag not run, write-out the DiskMode to the BIS-F log for further analysis if possible to run (MS)

## [6.1.0+04.113] - 2017-08-18

### Changed

- (PERS Sophos) Use $ServiceNameS instead of $ServiceName for first Test-BISFService (FF)
- Program is named "Windows Defender", not "Microsoft Windows Defender", fixed typos (FF)

### Fixed

- Fix for Bug 200: Popup shouldn't show up if Central Logshare is enabled OR disabled (FF)

## [6.1.0+04.112] - 2017-08-16

### Added

- DiskMode: extend Diskmode with AppLayering, ReadOnlyAppLayering, ReadWriteAppLayering, etc (MS)

### Changed

- Skip Device Personalization, based on Diskmode selected in ADMX (MS)
- Moved all BIS-F logs to the BISF logfolder, local and UNC-Path, previous only personalization logs would be moved to the UNC-Path (MS)

### Fixed

- Personalization: If Citrix AppLayering is installed, skip reboot (MS)
- From every P2V conversion, the logfile would be included into the BIS-F log, instead of error only (MS)
- ADMX: in some textbox fields, they starting with empty space (MS)
- If Custom UNC-Path in ADMX is enabled, during "Personalization" the wrong $returnvalue like MCSPrivate is given back, instead of "UNC-Path" (MS)

## [6.1.0+04.111] - 2017-08-04

### Added

- [#150](https://github.com/EUCweb/BIS-F/issues/150): Function Get-BISFDiskMode: If Custom UNC-Path in ADMX is enabled, get back 'UNC-Path' as $returnvalue (MS)
- P2V : Get-BISFBootMode get back UEFI or Legacy to using different command line switches for ImagingWizard or P2PVS (MS)
- P2V : Automatic fallback to ImagingWizard with UEFI BootMode, if P2PVS in ADMX is selected (MS)
- System Startup : In AppLayering OS-Layer only, do not Resync Time with Domain and do not Reapply Computer GPO, Computer is mostly not domain joined (MS)
- System Startup : With DiskMode AppLayering in OS-Layer the WSUS Update Service would be starteded (MS)
- [#150](https://github.com/EUCweb/BIS-F/issues/150): IF ADMX for custom VHDX UNC-Path is enabled, Defrag can't performed (MS)
- [#150](https://github.com/EUCweb/BIS-F/issues/150): IF ADMX for custom VHDX UNC-Path is enabled, the arguments for the P2V Tool must be changed, this vDisk Mode must not being checked (MS)
- [#152](https://github.com/EUCweb/BIS-F/issues/152): ADMX - Set Logfile Retention via ADMX (MS)
- [#193](https://github.com/EUCweb/BIS-F/issues/193): ADMX - Eventlog and Log Configuration, change PowerShell Code to use new reg values (MS)
- [#196](https://github.com/EUCweb/BIS-F/issues/196): ADMX - delprof2 edit custom arguments (MS)

### Changed

- Change BIS-F Icon on Admin Desktop, thanks to Marco Zimmermann (MS)
- Change ADMX to new structure, each vendor has his own folder (MS)

### Removed

- Removing XenConvert completely and using settings from new ADMX to choose ImagingWizard or P2PVS (MS)

### Fixed

- Windows Defender Script: too many " at the end of Line 44, breaks defender script to fail (MS)

## [6.1.0+04.110] - 2017-08-01

### Added

- [#197](https://github.com/EUCweb/BIS-F/issues/197): Add Progressbar for .NET Optimization (MS)
- [#159](https://github.com/EUCweb/BIS-F/issues/159): ADMX - specify VMware OS Optimization Template (MS)
- [#196](https://github.com/EUCweb/BIS-F/issues/196): ADMX - specify custom search folder for Citrix System Optimizer (CTXOE) (MS)
- [#196](https://github.com/EUCweb/BIS-F/issues/196): ADMX - specify custom search folder for each 3rd Party Tool (MS)
- [#193](https://github.com/EUCweb/BIS-F/issues/193): ADMX - specify custom eventlog and spool foldername (MS)

### Fixed

- Fix some typos (JP)

## [6.1.0+04.109] - 2017-08-01

### Fixed

- Test-AppLayeringSoftware, too many brackets.. complete execution of BISF failed ! (MS)

## [6.1.0+04.108] - 2017-07-31

### Changed

- Show ConsoleMessage during prepare Citrix AppLayering if installed (MS)

### Fixed

- If Citrix PVS Target Device Driver and Citrix AppLayering is installed, PostCommand would not be executed (MS)
- If Citrix AppLayering is installed, in the Platform Layer the wrong Drive letter would given back (MS)
- 10_PrepBISF_AV-SEP.ps1 - typo in search folders for the SEP vietool.exe (MS)

## [6.1.0+04.107] - 2017-07-29

### Added

- Add schedule Task "ServerCeipAssistant" to disable, thanks to Trentent Tye (MS)
- [#173](https://github.com/EUCweb/BIS-F/issues/173): Add Support for F-Secure Anti-Virus, thanks to Thorsten Witsch (MS)
- [#174](https://github.com/EUCweb/BIS-F/issues/174): On system startup with MCS/PVS and installed WEM Agent - refresh WEM Cache (MS)
- [#179](https://github.com/EUCweb/BIS-F/issues/179): Enable all Eventlog and move Event logs to the PVS WriteCacheDisk if Redirection is enabled in function Use-BISFPVSConfig , thanks to Bernd Braun (MS)
- [#192](https://github.com/EUCweb/BIS-F/issues/192): Support GPT WriteCacheDisk (MS)

### Removed

- [#168](https://github.com/EUCweb/BIS-F/issues/168): Add Support for PrinterLogic PrinterInstaller Client to remove all files in C:\Windows\Temp\PPP (MS)

### Fixed

- [#187](https://github.com/EUCweb/BIS-F/issues/187): Wrong search folders for the SEP vietool.exe (MS)

## [6.1.0+04.106] - 2017-07-28

### Fixed

- [#195](https://github.com/EUCweb/BIS-F/issues/195): If Citrix AppLayering is installed get back DiskMode $returnValue = "AppLayering" (MS)

## [6.1.0+04.105] - 2017-07-27

### Added

- Add new Function Use-BISFPVSConfig for Checking Redirection of Files is needed in combination with PVS and Citrix AppLayering (MS)

### Changed

- If Citrix AppLayering and PVS Target Device Driver installed, skip vDisk Operations (MS)
- Replace redirection of spool and event logs with central function Use-BISFPVSConfig, if using Citrix AppLayering with PVS it's a complex matrix to redirect or not (MS)

### Fixed

- Citrix AppLayering: check UniService ProcessID instead of ProcessName (MS)

## [6.1.0+04.104] - 2017-07-25

### Added

- With new Installerbuild (incremental version) in each DTAP Stage the build number also written to the log and the Windows Title, replace the manual change of the $ReleaseType in BISF.psm1 (MS)

### Fixed

- Create central Function Test-BISFAppLayeringSoftware to give back $Global:CTXAppLayeringSW true or false value (MS)

## [6.1.0 DEV]

### Added

- Add Script to remove ghost devices, thanks to Trentent Tye (MS)
- [#169](https://github.com/EUCweb/BIS-F/issues/169): Add AppLayering Support in PrepBISF_CTX.ps1 (MS)
- [#181](https://github.com/EUCweb/BIS-F/issues/181): Add support for Citrix System Optimizer Engine (CTXOE) (FF)
- [#176](https://github.com/EUCweb/BIS-F/issues/176): Running ImagingWizard instead of P2PVS to support UEFI Boot on Hyper-V (MS)
- [#172](https://github.com/EUCweb/BIS-F/issues/172): Stopping Shell Hardware Detection Service before ImagingWizard/XenConvert is starting, message box to format the disk suppressed now (MS)
- [#182](https://github.com/EUCweb/BIS-F/issues/182): Add 10_PrepBISF_AV-WindowsDefender.ps1 to support Windows Defender (FF)

### Changed

- Prep_Altiris: Create $RegKeys as an array (was a hashtable before) (FF)

### Fixed

- Prep_RES: Bug fix for Redirecting RES Cache (Setting Cache Path to WCD) (FF)
- CTXOE can be executed on every device (if "installed" + not disabled by GPO/skipped by user) (FF)
- [#186](https://github.com/EUCweb/BIS-F/issues/186): AppSense Product Path - thanks to Matthias Kowalkowski (MS)

## [6.0.2]

### Removed

- Removing BIS-F Version from ADMX, no longer showing the version in the GPO editor (MS)

### Fixed

- [#178](https://github.com/EUCweb/BIS-F/issues/178): Defrag arguments are different between client and server os, thanks to Jeremy Saunders (MS)
- After successful sysprep, running PostCommand now for defrag and shutdown (MS)

## [6.0.1]

### Fixed

- [#175](https://github.com/EUCweb/BIS-F/issues/175): After Patchday in April 2017 powershell command stop-computer does not work as expected (privilege not held), using shutdown /s now - tested on Windows 2008 R2 and Server 2016 (MS)

## [6.0.0]

### Added

- [#146](https://github.com/EUCweb/BIS-F/issues/146): Add progressbar to defrag (MS)
- Added Support for RES ONE Automation Agent Version 10 with new path in registry and filesystem (MS)
- Added $Global:Wait1= "10" time in seconds in BISF.psm1 (MS)
- Added check for admin privileges before script execution (MS)
- Create BIS-F Admin shortcut on personal Desktop (MS)
- Added ADMX templates to configure all silent commands with Group Policies, it's easier for BIS-F Updates and central configuration. CLI Commands are currently included but will be removed in a future release (MS)
- [#133](https://github.com/EUCweb/BIS-F/issues/133): Creating Installer for Base Image Script Framework, you can use /silent command to easily install from command line (MS)
- [#134](https://github.com/EUCweb/BIS-F/issues/134): Prepare RES One Workspace Management, RES ONE Automation and RES ONE Service Store Software for Image Management Software, Thanks to Company RES Germany: Oliver Lomberg & Nina Metz for additional enhancements information to create this script (MS)
- [#140](https://github.com/EUCweb/BIS-F/issues/140): Added CLI command 'XAImagePrepRemoval YES | NO' or MessageBox during Prepare XenApp for Provisioning/Image Management you can choose RemoveCurrentServer and ClearLocalDatabaseInformation, this would be set with this Parameter or prompted to administrator (MS)
- [#139](https://github.com/EUCweb/BIS-F/issues/139): Added McAfee 5.X Agent Support (JP/MS)
- [#137](https://github.com/EUCweb/BIS-F/issues/137): Added Sophos preparation and personalization for Image Management, thanks to Marco Zimmermann, Tim Franken and Mark Bos (MS)
- [#137](https://github.com/EUCweb/BIS-F/issues/137): Added UberAgent preparation, thanks to Marco Zimmermann (MS)
- Added Office 2016 KMS support (MS)
- [#129](https://github.com/EUCweb/BIS-F/issues/129): Added Citrix Workspace Environment Manager Agent (WEM) support (MS)
- Added defrag support for Windows 10.X (MS)
- Added VHDX support for Citrix PVS (MS)
- Create-BISFTask running in its own function (MS)
- Added Pre-Commands for Windows Server 2016 and Windows 10 (MS)
- Added preparation for Altiris Inventory Agent (MS)
- Added AppSense Support (MS)
- Added Delprof support (MS)
- Added turbo.net support (MS)
- Added function Invoke_BISFLogRotate to Cleanup Logfiles and keep only a configured value of files (BR)
- Added CLI-commands to the BISF-Log (MS)
- Added CLI Switch DisableConsoleCheck to disable the check of the console session (MS)
- [#111](https://github.com/EUCweb/BIS-F/issues/111): Added nvspbind.exe to unbind IPV6 from AdapterGuid (MS)
- Added DebugMode for developer (MS)

### Changed

- Final Test passed with Server 2016 / XA 7.13 and Server 2008 R2 / XA 6.5 (MS)
- For P2PVS reconfigure Microsoft Software Shadow Copy Provider Service and VSS Service, needed them for P2PVS (MS)
- After update on 13.03.2017 Bugfix WriteCacheDisk detection (MS)
- Failure when opening ADMX (MS)
- Updated graphical Design and Logo for BIS-F, thanks to Marco Zimmermann (MS)
- Extended unneeded services for Windows 10 and Server 2016 to disable (MS)
- Extended unneeded scheduled tasks for Windows 10 and Server 2016 to disable (MS)
- ADMX: Configure Novell ZCM Agent web-based registration URL (MS)
- Change defrag arguments to support Windows 10 and Server 2016 (MS)
- Get file version of Service ImagePath (MS)
- Get file version of 3rd Party Apps (MS)
- ADMX: configure PVS WriteCacheDisk driveletter, thanks to Marco Zimmermann (MS)
- RES Workspace Manager; Changed Remove-Item -Path "$InstallDir_REG\Data\DBCache\Resources\custom_resources\*" -recurse (MS)
- RES ONE Automation Console; Added stop service command (MS)
- RES Workspace Manager; Added IF (Test-Path "$HKLM_WIN_CVN\WUID") {Remove-Item -Path "$HKLM_WIN_CVN\WUID"} (MS)
- Excluded cleanmgr.exe for now - currently buggy, restart needed to delete superseded updates (MS)
- VMware OS Optimization Tool limit search folders to "C:\Program Files","C:\Program Files (x86)","C:\Windows\system32" and their subfolders (MS)
- RES Workspace Manager and Automation Manager; In Citrix PVS if an alternate DBCache Path is already configured, BIS-F will use it (MS)
- [#126](https://github.com/EUCweb/BIS-F/issues/126): MCS only: IF Diskmode is set to "MCSPrivate" no personalization is running (MS)
- Test-PVS Drive letter running on preparation state only (MS)
- Migrated BISF Registry Items to a new location (MS)
- Post-Sysprep: Added check for Windows 10 for running after sysprep actions (MS)
- 3rd party tools like sdelete, ccleaner, nvpsbind, vietool would no longer be distributed by BIS-F, customer must have them in their environment installed (MS)
- If NoVirtualDisk is detected, the Drive for Defrag if used would be set to SystemDrive (MS)
- Enhanced the defrag to run on NoVirtualDisk, previous Version PVS BaseDisk only (MS)
- Global Re-Design of the folder structure, removed Custom folder and put them in the Personalization and Preparation folder, custom scripts are now placed in this folder only for future scripts only, they don't touch during updates of BIS-F (MS)
- Updated SEP preparation Script (BR)
- Modify BIS-F scheduled task if it already exist, thanks to Valentino Pemoni (MS)
- Extended CLI command, you can now use -LogShare NO if you prefer not to use a central LogShare (MS)
- Changed SDelete to run on the WriteCacheDisk on PVS Target Devices only (MS)
- Get duplicate AdapterGUID back, instead unique of each adapter (MS)
- Check PVS DiskMode at Prerequisites, to get a warning on startup if Disk is in ReadOnly Mode and exit script (MS)

### Removed

- Remove System Environment Variable PVSWriteCacheDisk, configured with ADMX and use new registry location to save and use information (MS)
- Removed WEMBrokerName configuration with BIS-F, must be configured with WEM ADMX or ADM from Citrix, not here !! (MS)
- Removed CLI parameters, this can be configured with the ADMX File. Exclude -DebugMode and -Verbose CLI Switches are available only (MS)
- [#127](https://github.com/EUCweb/BIS-F/issues/127): Removed /PrepMsmq:False for XenApp 65, a random QMId would be set during system startup with BIS-F (JP)
- [#121](https://github.com/EUCweb/BIS-F/issues/121): Added CLI command 'AppVPckRemoval YES | NO 'or message box to delete pre-cached App-V Packages (MS)

### Fixed

- [#2](https://github.com/EUCweb/BIS-F/issues/2): _PersBISF_CTX.ps1 - reset Performance Counters with installed Citrix VDA on system startup (MS)
- ADMX - PVSWriteCache Drive letter is now enabled to choose letter B: - Z: (MS)
- [#97](https://github.com/EUCweb/BIS-F/issues/97): _PrepBISF_PRE_BaseImage.ps1 - Line 659 using $prepCommand instead of $PostCommand (MS)
- RES Workspace: wrong Path in Workspace Agent, change from DBCache to LocalCachePath (MS)
- RES Workspace: delete not all folders in the CachePath (MS)
- List of services not disabled, must be under extra control from the administrator $ServicesList = @("AJRouter","ALG","BthHFSrv","Eaphost","DiagTrack","PeerDistSvc","PeerDistSvc","EFS","msiscsi","WSearch","ALG","BDESVC","fhsvc","lfsvc","MSiSCSI","smphost","SharedAccess","wlidsvc","wbengine","bthserv","Browser","DeviceAssociationService","DsmSvc","DPS","WdiServiceHost","WdiSystemHost","QWAVE","SensorDataService","RetailDemo","PcaSvc","TrkWks","WPCSvc","Fax","FDResPub","svsvc","HomeGroupListener","ShellHWDetection","SensorService","HomeGroupProvider","TabletInputService","WiaRpc","CscService","SstpSvc","wscsvc","icssvc","stisvc","SensrSvc","XblAuthManager","XblGameSave","XboxNetApiSvc","WlanSvc","ShellHWDetection","SNMPTRAP","SSDPSRV","SysMain","TapiSrv","upnphost","SDRSVC","WcsPlugInService","wcncsvc","WinDefend","WerSvc","WMPNetworkSvc","Wlansvc","WwanSvc") (MS)
- Get the right status of Pending Reboot with the configured ADMX (MS)
- To read the right State from personality.ini if used VDA with PVS (MS)
- Do not disable defragsvc, VSS, swprv services (MS)
- Start-BISFProcWithProgBar: remove -Wait from Start-Process (MS)
- Start-BISFProcWithProgBar: using $ArgList instead of $Args at the Write-BISFLog command here (MS)
- [#164](https://github.com/EUCweb/BIS-F/issues/164): For Image Prep (disable useless Services and Scheduled Tasks) (FF)
- In Get-BISFDiskNameExtension to get vhd,avhd, vhdx or avhdx only (MS)
- Defrag not run via ADMX (MS)
- Move $Pvd_LOGFile_search="Update Inventory completed" from 99_PrepBISF_PostBaseImage.ps1 to 98_PrepBISF_BuildBaseImage.ps1 thanks to Mathias Kowalkowski (MS)
- [#112](https://github.com/EUCweb/BIS-F/issues/112): Kaspersky AntiVirus - wrong path to get from executable (MS)
- In ADMX - configure PVS WriteCacheDisk driveletter (MS)
- Syntax error in 97_PrepBISF_PRE_BaseImage.ps1 (MS)
- Read Variable $varCLI = ... in all affected preparation scripts (MS)
- Detecting WSUS TargetGroup (MS)
- Prepare Citrix PVS WriteCacheDisk - Bug fix: DiskID is not language neutral, split string after ":" to read the right side only, thanks to Marco Zimmermann (MS)
- Sophos Preparation - Fixed typos to get the right service name -> $ServiceNames[0] (MS)
- Get-BISFMacaddress - Fixed empty space given back from $mac, thanks to Valentino Pemoni (MS)
- Wrong syntax for RES ONE Automation Console (MS)
- Fixed typo in 10_PrepBISF_uberAgent.ps1 - $PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName) (MS)
- [#149](https://github.com/EUCweb/BIS-F/issues/149): Added $Global:LIC_BISF_CLI_LSb="" to define the variable, required for the ADMX templates (MS)
- [#127](https://github.com/EUCweb/BIS-F/issues/127): MSMQ QMId not unique, fixed with new script from Citrix - https://docs.citrix.com/en-us/xenapp-and-xendesktop/7-12/whats-new/known-issues.html (MS)
- If the Citrix PVS Target Device Driver is detected and no vDisk is assigned (DiskMode = Unmanaged), BIS-F exit script on start-up with an error message (MS)
- [#134](https://github.com/EUCweb/BIS-F/issues/134): PrepareWriteCacheDisk: Add space on either side of the Drive letter variable $searvol, thanks to Jeremy Saunders (MS)
- [#134](https://github.com/EUCweb/BIS-F/issues/134): PrepareWriteCacheDisk: MBR disk with 8 characters to get the right uniqueID from Diskpart only, PVS does not support GPT disk, see https://support.citrix.com/article/CTX139478 thanks to Jeremy Saunders (MS)
- [#135](https://github.com/EUCweb/BIS-F/issues/135): IF PVS Target Device Driver is installed, spool and EventLogs like Application, System, Security and XA LicenseFile would be redirected to WriteCacheDisk, otherwise leave it the original path (MS)
- Defrag does not identify the right driveletter of the vDisk after P2PVS if the drivelabel is empty (MS)
- [#114](https://github.com/EUCweb/BIS-F/issues/114): Variables must be cleared after each step, to not store the value in the variable and use them in the next $prepCommand or $PostCommand (MS)
- Set-QMID would never be processed, wrong syntax in IF (($returnTestXDSoftware -eq "true") -or ($returnTestPVSSoftware -eq "true")) (MS)
- Fixed typo in Line 76, thanks to Mikhail Zuskov -> Write-BISFLog -Msg "Error changing access for NetworkService on the folder `"$LIC_BISF_CtxCache`". The output of the action is: $result" -Type W -SubMsg (MS)
- After successful sysprep, computer shutdown would be performed only, if not suppressed by CLI command (MS)
- Sysprep is not running in earlier BIS-F Version. Adding error handling, checking setuperr.log for errors and from postCommands (MS)
- RDS TimeBob Added Filter for Operating System type, running on member server, not specified on W2K12 only (BR)
- Kaspersky AntiVirus Fix: Added -Recurse to search for files (MS)
- Syntax error Invoke-BISFService: Set-Service -Name $svc.Name -StartupType $StartType | Out-Null (BR)
- Give wrong variable back, switch RO and RW (function Invoke-BISFService) (MS)
- Heavy bug in function Invoke-BISFService, services would not be started if needed (MS)
- Fixed issue SCOM service would be starteded on every Image Mode if installed (MS)
- [#113](https://github.com/EUCweb/BIS-F/issues/113): AppVClient Cache did not resolve to the correct service status, thanks to Valentino Pemoni (MS)

## [5.1.2]

### Fixed

- [#136](https://github.com/EUCweb/BIS-F/issues/136): If EdgeSight DataPath do does does not exist, it removes all files under the C drive !! (MS)

## [5.1.1]

### Changed

- Moved $State -eq "Preparation" from BISF.ps1 to function Test-BISFPVSDriveLetter (MS)

### Fixed

- Fixed wrong syntax to check if Image Management Software like VDA, PVS Target Device Driver or VMware View Agent is installed (MS)
- Fixed bug in function invoke-service, services would not be started if needed (MS)

## [5.1.0]

### Added

- Added function Get-OSCSessionType to run BIS-F from console session only (MS)
- [#21](https://github.com/EUCweb/BIS-F/issues/21): If no image management software is detected; the service startup type would not change to manual (MS)
- [#20](https://github.com/EUCweb/BIS-F/issues/20): Added VMware Horizon View detection, thanks to Bertram Wöhrmann (MS)
- [#105](https://github.com/EUCweb/BIS-F/issues/105): Added Office 2016 x86 rearm support (MS)
- [#79](https://github.com/EUCweb/BIS-F/issues/79): Added Optimize-BISFWinSxs to cleanup and reduce WinSxs Folder (Win8, Win2012 R2 only), thanks to Vincent Szabang (MS)
- [#100](https://github.com/EUCweb/BIS-F/issues/100): Disabled Data Execution Prevention (DEP), disable Startup Repair option, Disabled New Network dialog, Set Power Saving Scheme to High Performance, thanks to Thomas Krampe (MS)
- [#100](https://github.com/EUCweb/BIS-F/issues/100): Disabled unnecessary Windows services, thanks to Thomas Krampe (MS)
- [#100](https://github.com/EUCweb/BIS-F/issues/100): Disabled useless scheduled tasks, thanks to Thomas Krampe (MS)
- [#100](https://github.com/EUCweb/BIS-F/issues/100): Added disk cleanup execution for Win8, thanks to Thomas Krampe (MS)
- [#97](https://github.com/EUCweb/BIS-F/issues/97): Added support to hide PVS status tray icon, http://forums.citrix.com/thread.jspa?threadID=273278, thanks to Ingmar Verheij - http://www.ingmarverheij.com (MS)
- [#101](https://github.com/EUCweb/BIS-F/issues/101): Redirect spool directory to PVS WriteCacheDisk, if PVS Target Device Driver is installed only (MS)
- [#102](https://github.com/EUCweb/BIS-F/issues/102): Redirect event logs (Application, Security, System) to PVS WriteCacheDisk, if PVS Target Device Driver is installed only (MS)
- [#99](https://github.com/EUCweb/BIS-F/issues/99): Added registry value to increase UDP packet size to 1500 bytes for FastSend - http://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=2040065, thanks to Ingmar Verheij - http://www.ingmarverheij.com (MS)
- [#99](https://github.com/EUCweb/BIS-F/issues/99): Set multiplication factor to the default UDP scavenge value (MaxEndpointCountMult), http://support.microsoft.com/kb/2685007/en-us , thanks to Ingmar Verheij - http://www.ingmarverheij.com (MS)
- [#99](https://github.com/EUCweb/BIS-F/issues/99): Added disable Receive Side Scaling (RSS), http://support.microsoft.com/kb/951037/en-us, thanks to Ingmar Verheij - http://www.ingmarverheij.com (MS)
- [#99](https://github.com/EUCweb/BIS-F/issues/99): Added support to disable IPv6 completely, thanks to Ingmar Verheij - http://www.ingmarverheij.com (MS)
- [#96](https://github.com/EUCweb/BIS-F/issues/96): Added VMware Tools optimizations, thanks to Ingmar Verheij - http://www.ingmarverheij.com (MS)
- [#94](https://github.com/EUCweb/BIS-F/issues/94): Added Script 10_PrepBISF_KAVS.ps1 - Prepare Kaspersky Antivirus for Image Management Software (MS)
- Added support to reset Distributed Transaction Coordinator service if installed (MS)
- Added support to clear DHCP entries of network adapter, to prevent blue screen on some PVS target devices https://www.citrix.com/blogs/2015/09/29/pvs-target-devices-the-blue-screen-of-death-rest-easy-we-can-fix-that (MS)
- Added silent option 'delAllUsersStart menue' to delete all Objects in C:\ProgramData\Microsoft\Windows\Start Menu\* (MS)
- Added delay between time sync and GPO execution to successfully apply the GPO after DST (BR)
- Added username to each log file entry (MS)
- Added function Get-DiskNameExtension, to get BaseDisk or ParentDisk, defrag would be performed on BaseDisk only (MS)
- Added function Test-RegistryValue to test if the registry value exist (needed for SEP Client, WoW6432Node or native 64 Bit client) (MS)

### Changed

- PrepareBaseImage.cmd: remove duplicated CLI command for -DisableIPv6 NO (MS)
- Changed ExecutionPolicy from unrestricted to bypass (MS)
- Changed product name from "FrontRange DSM " to "Heat DSM" (MS)
- XenApp 6.x only: Personalization on each device -> Configure Citrix LicenseFile Cache Location and set NTFS Permissions for NetworkService with full access (MS)
- 10_PrepBISF_IME.ps1; Added new script to delete Office 2010 IME Keyboards from Autorun (BR)
- 10_PersBISF_Services.ps1; Rewritten script with standard .SYNOPSIS (MS)
- 10_PersBISF_TimeAndGPO.ps1; Rewritten script with standard .SYNOPSIS (MS)
- 10_PersBISF_OfficeKMS.ps1; Rewritten script with standard .SYNOPSIS (MS)
- 10_PersBISF_CTX.ps1; Rewritten script with standard .SYNOPSIS (MS)
- 10_PersBISF_WriteCacheDisk.ps1; Rewritten script with standard .SYNOPSIS (MS)
- 10_PersBISF_ZCM.ps1; Rewritten script with standard .SYNOPSIS (MS)
- 10_PersBISF_TM.ps1; Rewritten script with standard .SYNOPSIS (MS)
- 10_PersBISF_SEP.ps1; Rewritten script with standard .SYNOPSIS, central BISF function couldn't be usedd for services, SEP Service must be started with smc.exe (MS)
- 10_PersBISF_SCOM.ps1; Rewritten script with standard .SYNOPSIS, use central BISF function to configure service (MS)
- 10_PersBISF_SCCM.ps1; Rewritten script with standard .SYNOPSIS, use central BISF function to configure service (MS)
- 10_PersBISF_FSLogix.ps1; Rewritten script with standard .SYNOPSIS, use central BISF function to configure service (MS)
- 99_PreBISF_Pre_BaseImage.ps1; Rewritten script to use central BISF function (MS)
- 98_PreBISF_Pre_BaseImage.ps1; Rewritten script to use central BISF function (MS)
- 97_PreBISF_Pre_BaseImage.ps1; Rewritten script to use central BISF function (MS)
- 96_PreBISF_REARM.ps1; Rewritten script to use central BISF function (MS)
- 90_PreBISF_CTX.ps1; Rewritten script to use central BISF function (MS)
- 10_PrepBISF_WriteCacheDisk.ps1; Rewritten script to use central BISF function (MS)
- 10_PrepBISF_SecureBISFfolder.ps1; Rewritten script with standard .SYNOPSIS, use central BISF function to configure service (MS)
- 10_PrepBISF_TM.ps1; Rewritten script with standard .SYNOPSIS, use central BISF function to configure service (MS)
- 10_PrepBISF_ZCM.ps1; Rewritten script with standard .SYNOPSIS, use central BISF function to configure service (MS)
- 10_PrepBISF_VSE.ps1; Rewritten script with standard .SYNOPSIS, use central BISF function to configure service (MS)
- 10_PrepBISF_Splunk.ps1; Rewritten script with standard .SYNOPSIS, use central BISF function to configure service (MS)
- 10_PrepBISF_SEP.ps1; Rewritten script with standard .SYNOPSIS, central BISF function couldn't be usedd for services, SEP Service must be stopped with smc.exe (MS)
- 10_PrepBISF_SCOM.ps1; Rewritten script with standard .SYNOPSIS, use central BISF function to configure service (MS)
- 90_PreBISF_CTX.ps1; Changed line 103 to create Cache Directory to store the CTX License File: New-Item -path "$LIC_BISF_CtxCache" -ItemType Directory -Force (MS)
- 90_PreBISF_CTX.ps1; Changed line 236 to Set-ItemProperty -Path HKLM:Software\Microsoft\MSMQ\Parameters\MachineCache -Name "QMId" -Value ([byte[]]$new_QMID) -Force (MS)
- 10_PrepBISF_SCCM.ps1; Rewritten script with standard .SYNOPSIS, use central BISF function to configure service (MS)
- 10_PrepBISF_FSLogix.ps1; Rewritten script with standard .SYNOPSIS, use central BISF function to configure service (MS)
- 10_PrepBISF_FrontRange.ps1; Rewritten script with standard .SYNOPSIS, use central BISF function to configure service (MS)
- 10_PrepBISF_EPC.ps1; Rewritten script with standard .SYNOPSIS, use central BISF function to configure service (MS)
- 10_PrepBISF_Empirum.ps1; Rewritten script with standard .SYNOPSIS, use central BISF function to configure service (MS)
- 10_PrepBISF_CMTrace.ps1; Rewritten script with standard .SYNOPSIS, use central BISF function to configure service (MS)
- 10_PrepBISF_AppVClient.ps1; Rewritten script with standard .SYNOPSIS, use central BISF function to configure service (MS)
- 10_PersBISF_Altiris.ps1; Rewritten script with standard .SYNOPSIS, use central BISF function to configure service (MS)
- 10_PrepBISF_Altiris.ps1; Rewritten script with standard .SYNOPSIS, use central BISF function to configure service (MS)
- [#88](https://github.com/EUCweb/BIS-F/issues/88): Defrag runs on BaseDisk only (MS)

### Removed

- Removed function NimbleFastReclaim, would be replaced with Write-ZeroesToFreeSpace, see Bug 62 (MS)
- [#77](https://github.com/EUCweb/BIS-F/issues/77): Removed prefix XX,XA,XD from all files and scripts (MS)

### Fixed

- Fixed wrong syntax to check if Image Management Software like VDA, PVS Target Device Driver or VMware View Agent is installed (MS)
- Fixed delAllUsersStart menu, typos in variable (MS)
- In Feature 99: Wrong Dword to completely disable IPv6 - 0x000000FF (JP/MS)
- Misspelled CLI switch change from delAllUsersStart menue to delAllUsersStart menu (MS)
- BISF.psm1; $ImageSW would be set to false, wrong order (MS)
- BISF.psm1; Fixed code error 1133 Write-Progress "Done" "Done" -completed (MS)
- Stop DHCP client Service, see https://www.citrix.com/blogs/2015/09/29/pvs-target-devices-the-blue-screen-of-death-rest-easy-we-can-fix-that/ (MS)
- [#93](https://github.com/EUCweb/BIS-F/issues/93): Check if preparation phase is running to run $Global:returnTestPVSDriveLetter=Test-PVSDriveLetter -Verbose:$VerbosePreference (added in Bug fix 50 10.08.2015; Version 5.0.2) (MS)
- [#42](https://github.com/EUCweb/BIS-F/issues/42): SCCM: Fixed deleteCCMCache, this must be running before service stops (MS)
- [#89](https://github.com/EUCweb/BIS-F/issues/89): SEP Preparation: Symantec fixes the registry location for the SEP-Client to WOW6432Node, fix in line 48-50 and function DeleteSEPData (MS)
- [#89](https://github.com/EUCweb/BIS-F/issues/89): SEP Personalization: Fixed the registry location for the SEP-Client to WoW6432Node, Fix in line 31-32 and function SetHostID (MS)
- [#76](https://github.com/EUCweb/BIS-F/issues/76): FSLogix: Do not check PVS or MCS DiskMode, Service is already running or would be starteded if stopped (MS)
- [#76](https://github.com/EUCweb/BIS-F/issues/76): FSLogix: remove to set FSLogix service to manual, stopped service only (MS)

## [5.0.2]

### Added

- Added function Show-CustomInputBox to show a message box to enter a value (needed for FSLogix central rules share) (MS)
- Added new Script 00_XX_PrepBISF_SecureBISFFolder.ps1 to remove user access to the BIS-F installation Folder (MB)
- [#63](https://github.com/EUCweb/BIS-F/issues/63): On Base Image only, the WSUS Service would be startededed, on shared image devices the service would be stopped and disabled (BR)
- Executing all queued .NET compilation jobs; Precompiling assemblies with Ngen.exe can improve the startup time for some applications (MS)
- [#44](https://github.com/EUCweb/BIS-F/issues/44): Added CLI Option "FSXdelRules" to purge the FSLogix Rules from CLI (MS)
- [#45](https://github.com/EUCweb/BIS-F/issues/45): Windows Server 2012 R2 only; Fixed the no Remote Desktop License Server issue available on RD Session Host server 2012 (MS)
- [#39](https://github.com/EUCweb/BIS-F/issues/39): Added CLI Option VERYSILENT to suppress all message boxes for fully automation, show error if the needed CLI switch not defined (MS)

### Changed

- FSLogix copy rules and assignment files from central share, use CLI command FSXRulesShare or waiting for the GUI prompt during preparation phase, the rules and assignment files would be copied on computer startup (MS)
- BIS-F Logviewer; Search on specified path and their subfolders only, for a better performance (MS)
- Change; Renamed Scripts from CCM to SCCM and OpsMgr to SCOM (MS)
- Renamed Scripts from ...vDisk.ps1 to ...BaseImage.ps1 (MS)

### Removed

- [#44](https://github.com/EUCweb/BIS-F/issues/44): Add FSLogix detection to ask for deleting of the Rules, The FSLogix Service would only be starting if the cloned device is in shared mode or not equal the Base Image computer (MS)

### Fixed

- [#70](https://github.com/EUCweb/BIS-F/issues/70): The FSLogix rules are copied from the central share but not applied, in the FSLogix personalization script, the copy must be performed after starting the FSLogix service, to resolve this issue (MS)
- [#65](https://github.com/EUCweb/BIS-F/issues/65): If Office not installed and CLI switch would be set to rearm Office, an error occurs. Check if Office is installed, before starting rearm process (MS)
- Support for PVS 7.7: $P2PVS_LOGFile_search="Conversion was successful" must be changed to $P2PVS_LOGFile_search="successful" to get ready for PVS7.7 and earlier (MS)
- Fixed P2PVS/XenConvert define LogfilePath, before P2PVS/XenConvert would be startededed, existing log file would be deleted (MS)
- Fixed code for .NET compilation jobs (MS)
- [#52](https://github.com/EUCweb/BIS-F/issues/52): Changed code for P2PVS or XenConvert Logfile detection, looking in all paths and deleted older files (MS)
- [#62](https://github.com/EUCweb/BIS-F/issues/62): Added new function Write-ZeroesToFreeSpace instead of NimbleFastReclaim -> buggy on Windows Server 2012 R2 (MS)
- [#50](https://github.com/EUCweb/BIS-F/issues/50): Added existing function $Global:returnTestPVSDriveLetter=Test-PVSDriveLetter -Verbose:$VerbosePreference (MS)
- [#61](https://github.com/EUCweb/BIS-F/issues/61): TrendMicro preparation; Kill Tasks of each TM Process before stops the services, define array for TM services for better script handling (MS)
- [#51](https://github.com/EUCweb/BIS-F/issues/51): Re-added "Removing Local Citrix Group Policy Settings" in function CleanUpCTXPolCache (MS)
- [#52](https://github.com/EUCweb/BIS-F/issues/52): XenConvert, script is looking in provisioning server path and not in installed directory (MS)
- [#49](https://github.com/EUCweb/BIS-F/issues/49): SCOM preparation : Fix line 39: rename $returnCheckPVSSoftware to $returnTestPVSSoftware (MS)
- Different path for OSSPREAM.exe not valid for Office 2013, for Office 2010 only (MS)
- Running from SCCM or MDT -> Changing to $logpath only (prev. $LogFilePath = "$logPath\$LogFolderName"), only files directly in the folder are preserved, not subfolders (MS)
- [#48](https://github.com/EUCweb/BIS-F/issues/48): Novell ZCM: Duplicated GUID after ZCM Agent update, designed a new script for ZCM Agent preparation (MS)
- [#43](https://github.com/EUCweb/BIS-F/issues/43): Wrong CLI variable for P2PVS -> Line 150 must be changed from $LIC_PVS_CLI_PT to $LIC_BISF_CLI_PT (MS)
- [#41](https://github.com/EUCweb/BIS-F/issues/41): VIETool is slow to execute, separated Log and ConsoleLog, deactivated get-LogContent (MS)

## [5.0.1]

### Added

- Added SCOM 2012 detection previously checked for 2007 path only (MS)

### Changed

- Temp. Deactivated DeleteCCMCache, some errors more testing (MS)

### Fixed

- Running BIS-F from local drives only, show error if running from unc path or mapped drive (MS)

## [5.0.0]

### Added

- Added advanced commands to diskpartfile to bring the disk online if the WriteCacheDisk is not formatted (MS)
- Added fix for MSMQ Service if running XD FP1 and session recording, the VDA has the same QMId as the MSMQ (http://support.citrix.com/proddocs/topic/xenapp-xendesktop-76fp1/xad-xaxd76fp1-knownissues.html) (MS)
- Added CLI Option to perform or suppress a system shutdown after successfully build the Base Image (MS)
- Added deletion of CCM Package Cache (MS)
- Added CLI switch -SuppressPndReboot to suppress a pending reboot (MS)
- Added custom script for Microsoft AppV Client (MS)
- Added custom script for Frontrange DSM (NetInstall) (MS)
- Added convert-settings to migrate PVS to BISF (MS)
- Added CLI Option for reset performance counters (MS)
- New PreBuildAction: Ask to reset performance counters (MS)
- Added CLI Option for CCleaner to clean temp files (MS)
- Added CLI Option for Symantec Endpoint Protection VIEScan to flag the scanned files (MS)
- New PreBuildAction: run CCleaner for temp files (JP/MS)
- New PreBuildAction; Clear the Windows event logs (JP/MS)
- New PreBuildAction; Use NimbleFastReclaim instead of sdelete (MS)
- Added check for pending reboot and exit script if value set to true (MS)
- Added new script to activate Office against KMS server at system personalization (MB)
- Added McAfee Virus Scan Enterprise support (JP/MS)
- Added Splunk Universal Forwarder support (JP/MS)

### Changed

- Replaced trace32 with CMTrace latest version (MS)
- Detect if running from SCCM/MDT task sequence, if so it sets the log file location to the task sequence LogPath (MS)
- Defrag is no longer running on the hard disk, now it's running on the vDisk in POST script (MS)
- SCCM/MDT Task sequence detection to suppress a shutdown of the Base Image after successful build (MS)
- CCleaner; New version of WinApp2.ini v5.04.150325 and CCleaner 5.4.0 (MS)
- Get PowerShell minimum Major version from PowerShell Data File instead of global variable (MS)
- Symantec Endpoint Protection; Show progress bar on full scan and VIETool (MS)
- Microsoft Operations Manager; Changed line 65 to IF ($svc -And (Test-Path $OpsStateDirOrigin)) (MS)
- Recreate Application Streaming offline database (JP/MS)
- Detect Citrix User Profile Manager cache path and delete existing cache (JP/MS)
- Renamed Script from XenApp to Citrix to have all CTX Modules in one script (MS)
- Moved SetSTA from single script to the CTX script (MS)
- Symantec Endpoint Protection; Added VIE Tool to improve scan performance on base image files (BR)
- Recent code changes (MB)

### Removed

- Remove Citrix Streaming Cache (RadeCache) (JP/MS)
- Remove Citrix EdgeSight Client Data (JP/MS)

### Fixed

- PowerShell minimum version must be set to v3, with v2 the psd1 would not be loaded correctly (MS)
- Copy CMTrace only, if trace32 or CMTrace does does not exist on the system. register extension *.bis with the available Viewer on the system (trace32 or CMTrace) (MS)
- Symantec Prep Script; Fixed syntax error on line 108 (MS)
- McAfee Antivirus; Fixed syntax error and show progress bar on full scan (MS)
- SCCM Prep/Pers Script; Fixed syntax error and error handling (MS)
- Fixed Empirum Agent script, syntax error at line 33 (MS)

## [4.5.2]

### Added

- Added Microsoft System Center Operations Manager (SCOM) support (MS)
- Added personalization script to Update Time and Re-apply GPO (BR)
- Added registry value to fix -> Applying Group Policies Fails After Symantec Endpoint Protection Client Installation from http://www.symantec.com/business/support/index?page=content&id=TECH200321 (MS)
- Added Trend Micro OfficeScan to prepare and personalize the system to prevent duplicate GUIDs' (MS)
- Added Matrix 42 Empirum Agent support, prepare and read LocalCache from XML file (MS)

### Changed

- Altiris Deployment Agent preparation, stop service and set it to manual (MS)
- Altiris Deployment Agent personalization, check agent status and start it, if vDisk is in private Mode (MS)
- WSUS; Check TargetGroupEnabled to delete WSUS-ID or set Windows Update Service to manual (MS)
- Show script version number in Windows Title (MS)

### Fixed

- Fixed wrong $cachelocation from XML-File (thanks to David Rosenthal) (MS)

## [4.5.1]

### Added

- Added CLI switch -verbose -> $LIC_PVS_CLI_VB to show suppressed messages in console (MS)
- Added CLI Switch -P2PVS to use P2PVS instead of XenConvert if installed (MS)

### Changed

- P2PVS.log or XenConvert.log would be checked if PVS Target Device is installed and the Device boot up from hard disk only (MS)

### Removed

- Removed XenConvert from Tools folder... to continue using you must install XenConvert on your base image in "C:\Program Files\Citrix\XenConvert" (MS)

### Fixed

- Run PvDcheck directly after PVD Inventory Update and not after PVS vDisk Build (MS)

## [4.5.0]

### Added

- New version ready for Citrix XenDesktop 7.5, PVS, MCS and other Image Management Software (MS)

### Changed

- 10_XX_PersPVS_WriteCacheDisk.ps1; Prevent reboot loop, check log file folder it can be created and reboot (MS)
- Final changes before web release (MS)

### Fixed

- 98_XX_PrepPVS_BUILD_vDisk.ps1; Added and use XenConvert to reduce vDisk storage, older technology but do not capture free space of the Base Image. If XenConvert does does not exist, P2PVS that comes with PVS71 would be used (MS)

## [4.2.2]

### Added

- Added Script for default Logviewer 10_XX_PrepPVS_SMSTrace.ps1 as external log file viewer (MS)

### Changed

- 10_XX_PersPVS_WriteCacheDisk.ps1; Changed to $LOGfile = Set-Logfile (MS)
- 10_XX_LIB_Functions.psm1; Added function ChangeNetworkProviderOrder (MS)
- 10_XX_PrepPVS_SEP.ps1; Changed NetworkProviderOrder SnacNp and add Silentswitch -AVFullScan (YES|NO) (MS)
- PrepareXAforPVS.cmd; Supressed message for set-executionpolicy remoteSigned (MS)
- Revisited all scripts to replace Write-Host for Write-Log (MS)
- 10_XA_Main_PrepPVS.ps1 and 20_XA_Main_PersPVS.ps1; Changed logging for Preparation and Personalization to a single file, previously set to one log file per script (MS)
- 10_XA_Main_PrepPVS.ps1 / 20_XA_Main_PersPVS.ps1; Changed log filename from .log to .bis (BIS = BaseImageScripts) (MS)
- All scripts; Removed $logfile = Set-logFile, it would be used in the 10_XX_LIB_Config.ps1 Script only (MS)

### Removed

- Removed $returnCheckPVSDriveLetter (MS)

### Fixed

- If you added a new XenApp server, the WriteCacheDisk would not be automatically formatted (MS)

## [4.2.1]

### Changed

- PrepareXAforPVS.cmd; Changed ExecutionPolicy from unrestricted to RemoteSigned, thanks to Frank Fette (MS)
- 96_XX_PrepPVS_REARM.ps1; Fixed read variable LIC_PVS_CLI_AV and LIC_PVS_CLI_OF (MS)
- 10_XX_PersPVS_WriteCacheDisk.ps1; Added WriteCache Option Check for PVS Device RAM with Overflow to Device HardDisk (BR)
- 10_XX_PersPVS_WriteCacheDisk.ps1; Use Write-Log function for Logging (BR)

### Fixed

- 10_XX_PrepPVS_EPC.ps1; Fixed syntax error to start silent pattern update and full scan, fixed read variable LIC_PVS_CLI_AV (MS)

## [4.2]

### Changed

- 10_XX_LIB_Functions.psm1; Added function get-version, to display this in the console window (MS)
- 10_XX_LIB_Config.ps1; Added get-Version to show current running version (MS)
- 97_XX_PrepPVS_PRE-vDisk.ps1; Changed console output to get-adaptername, line 91 -> Write-Log -Msg " Read AdapterName: $element" (MS)

## [4.1]

### Added

- Added silent mode switches to suppress message boxes, example: PowerShell.exe -file "%Files.PT%\10_XA_MAIN_PrepPVS.ps1" -sDelete NO -defrag NO -AVFullScan NO -OSrearm YES -OFrearm YES (MS)

### Changed

- Updated documentation; detailed script description added (MS)
- 10_XX_PrepPVS_CCM.ps1; Fixed certstore SMS certstore deletion > & Invoke-Expression 'certutil -delstore SMS "SMS"' (MS)

## [4.0.1]

### Changed

- 97_XX_PrepPVS_PRE-vDisk.ps1; Added multihoming support to read adaptername from each network adapter, see line 80 (MS)
- 90_XA_PrepPVS_XenApp.ps1; Cleanup Citrix Group Policy Cache > function CleanUpCTXPolCache (BR)

## [4.0]

### Changed

- Official Release to Web, for further details see the documentation (MS/BR)

## [3.5]

### Changed

- 10_XX_PersPVS_ZCM.ps1; Get ZCM argument list from custom specified registry value -->> $LIC_PVS_ZCM_CFG (MS)
- 10_XX_PrepPVS_MSC.ps1; Changed full scan from Windows Defender directory to '$MSC_path\...' (MS)
- Documentation: Added reference list for global variables and functions (MS)

## [3.4]

### Changed

- 90_XA_PersPVS_XenApp.ps1; Added check for redirected MDB-Files for LHC and RadeOffline and Start IMAService (MS)
- 90_XA_PrepPVS_XenApp.ps1; Redirect LHC (MS)
- 90_XA_PrepPVS_XenApp.ps1; Redirect Citrix Cache to persistent drive (MS)
- 98_XX_PrepPVS_BUILD_vDisk.ps1; Run TargetOSOptimizer.exe if booted from hard disk only (MS)
- 97_XX_PrepPVS_PRE-vDisk.ps1; [array]$PreMSG = "N" #<<-- display a message box to perform these step, set Y = YES or N = NO (MS)
- 97_XX_PrepPVS_PRE-vDisk.ps1; Added question to run Defrag on Systemdisk (MS)
- 97_XX_PrepPVS_PRE-vDisk.ps1; Added question to run Sysinternals SDelete to zero out empty vDisk areas and reduce storage (MS)
- 10_XA_Main_PrepPVS.ps1; Removed Title, this would be implemented in the central functions (MS)
- 10_XX_LIB_Config.ps1; Moved central functions to 10_XX_LIB_Functions.psm1 (MS)
- 10_XX_LIB_Functions.ps1; Added central functions and global environment variables from 10_XX_LIB_Config.ps1 (MS)
- 97_XX_PrepPVS_PRE-vDisk.ps1; Added array to remove Windows Update information (MS)
- 10_XX_PrepPVS_CCM.ps1; Show Console Message (MS)
- 10_XX_PrepPVS_MSC.ps1; Show Console Message (MS)
- 10_XX_PrepPVS_SEP.ps1; Show Console Message (MS)

### Fixed

- 10_XX_PrepPVS_CCM.ps1; BUG code-error certstore SMS not deleted > & Invoke-Expression 'certutil -delstore SMS "SMS"' (MS)
- 10_XX_LIB_Config.ps1; Fixed wrong Log-Location (MS)

## [3.3]

### Changed

- 10_XX_PrepPVS_CCM.ps1; Created new script to prepare SCCM client compatible with SCCM 2007 to 2012 R2 (MS)
- 10_XX_PersPVS_CCM.ps1; Created new script to personalize SCCM client compatible with SCCM 2007 to 2012 R2 (MS)

## [3.2]

### Changed

- 10_XX_PrepPVS_MSC.ps1; Created new Script for Microsoft Security Client (MS)

## [3.1]

### Changed

- MS/BR: Reviewed all scripts; New central Functions, tested whole environment
- MS: 10_XX_PrepPVS_WriteCacheDisk.ps1; Added CDrom function
- MS: 10_XX_PersPVS_WriteCacheDisk.ps1; Added CDrom function

## [3.0]

### Changed

- 96_XX_PrepPVS_REARM; Removed function MigrateValues > Add message box to OS rearm and office rearm (MS)
- Reviewed all scripts (MS/BR)
- 10_XX_PersPVS_SEP.ps1; IF (Test-Path ("$SEP_path\smc.exe")) (MS)
- 10_XX_PrepPVS_SEP.ps1; IF (Test-Path ("$SEP_path\smc.exe")) (MS)
- 10_XX_PersPVS_ZCM.ps1; Script created / MS: IF (Test-Path ("$SEP_path\smc.exe")) (BR)

## [2.7]

### Changed

- 96_XX_PrepPVS_REARM.ps1; Created new function MigrateValues > Migrate old values from earlier script version to new one (MS)
- 10_XX_PersPVS_SEP.ps1; Changed Function StopService (BR)
- 10_XX_PrepPVS_SEP.ps1; Changed Function StartService (BR)

## [2.6]

### Changed

- 10_XX_PersPVS_SEP.ps1; MS: $HostID_Prfx = "00000000000000000000" (MS)
- 10_XX_PersPVS_SEP.ps1; Set-Location $SEP_path (MS)
- 10_XX_PrepPVS_SEP.ps1; Set-Location $SEP_path (MS)

## [2.5]

### Changed

- MS: 20_XA_PrepPVS_SetSTA.ps1; Check if file exists

### Fixed

- MS: 10_XX_LIB_Config.ps1; MS: Error handling; added return $false for exit script
- MS: 10_XA_MAIN_PrepPVS.ps1; Add $return for Error handling and exiting script

## [2.4]

### Changed

- 10_XX_PrepPVS_WriteCacheDisk.ps1; Added function SetRefSrv; Set reference server Hostname in registry to detect it in the personalize script to skip reboot (MS)
- 10_XX_PersPVS_WriteCacheDisk.ps1; Added function GetRefSrv; Get reference server Hostname in registry to detect it and skip reboot (MS)
- 10_XX_LIB_Config.ps1; Added global value LIC_PVS_RefSrv_HostName to detect reference server (MS)

## [2.3]

### Changed

- All Scripts; Replaced $date with $(Get-date) to get current timestamp at running script lines write to the log file (MS)
- 10_XX_LIB_Config.ps1; Created Global Library to set global variables gotten from registry and from script (MS)
- 95_XA_Prep_Redirect.ps1; Created new script to redirect Local Host Cache to persistent drive (MS)

## [2.2]

### Changed

- 98_XX_PrepPVS_BUILD_vDisk.ps1; Check personality.ini if Device boot up from hard disk or vDisk (MS)

## [2.1]

### Changed

- 98_XX_PrepPVS_BUILD_vDisk.ps1; Add progress bar during P2PVS (MS)

### Fixed

- 10_XX_PrepPVS_WriteCacheDisk.ps1; Critical fix to get UniqueID on English display language only (MS)

## [2.0]

### Fixed

- Official release, simplified folder structure, added documentation and bug fixes (MS)

## [1.9]

### Changed

- 10_XX_GenPVS_WriteCacheDisk; Read WriteCacheDrive from vDisk inside registry PVSAgent and check it with the whole environment to set the UniqueID of the disk (MS)

## [1.8]

### Fixed

- Folder 10_XX_LIB: Deleted all scripts, that were not used (MS)

## [1.7]

### Changed

- 20_XA_GenPVS_SetSTA.ps1; Set STA based on computer name like STA%COMPUTERNAME% (MS)
- 20_XA_PrepPVS_SetSTA.ps1; Set STA to UNKNOWN for prepare with PVS (MS)

## [1.6]

### Changed

- 10_XA_MAIN_PrepPVS.ps1; Write script path to registry $hklm_software\PS-SCRIPTS\COMMON to use in whole environment (MS)

## [1.5]

### Changed

- 10_XX_GenPVS_WriteCacheDisk; Changed location for temporary Diskpartfile to %TEMP% (MS)
- 10_XX_PrepPVS_WriteCacheDisk; Changed location for temporary Diskpartfile to %TEMP% (MS)

### Fixed

- 96_XX_PrepPVS_REARM; Added Office 2010 rearm support: OSPPREARM.EXE added, but not tested (MS)

## [1.4]

### Fixed

- 10_XX_PrepPVS_WriteCacheDisk; Error in script to read the correct volume to identify the Unique ID and set it to registry (MS)

## [1.3]

### Changed

- 10_XX_GenPVS_WriteCacheDisk; Read UniqueID from Registry and use it in diskpart (MS)
- 10_XX_PrepPVS_WriteCacheDisk; Read UniqueID from PVSWriteCacheDisk and write it to registry (MS)
- 99_XX_PrepPVS_POST_vDisk; Check vDisk conversion successful, then shutdown (MS)
- 98_XX_PrepPVS_BUILD_vDisk1; Delete P2PVS log file > Remove-Item $P2PVS_LOGFile -recurse -ErrorAction SilentlyContinue (MS)

## [1.2]

### Changed

- Script creation for SCCM Client; Tested with SCCM 2007 (MS)
- 98_XX_PrepPVS_BUILD_vDisk; Function CheckvDisk: check if Citrix PVS personality file exists (MS)

## [1.1]

### Changed

- 97_XX_PrepPVS_PRE_vDisk; Delete all Citrix Cached files $CTX_SYS32_CACHE_PATH (MS)

## [1.0]

### Changed

- Library created (MS)

## Contributors

| Initials | Name |
|----------|------|
| MS | Matthias Schlimm |
| BR | Benjamin Ruoff |
| MB | Mike Bijl |
| JP | Jonathan Pitre |
| FF | Florian Frank |
| TT | Trentent Tye |
| JS | Jeremy Saunders |
| MK | Mathias Kowalkowski |
| AS | Andre Sicking |
| JK | James Kindon |

Additional contributor initials appearing in entries: DS, KT, MN, MW, SF.

[Unreleased]: https://github.com/JonathanPitre/BIS-F/compare/v7.1912.7.11042...HEAD
[7.1912.7.11042]: https://github.com/JonathanPitre/BIS-F/releases/tag/v7.1912.7.11042
[7.1912.6.11041]: https://github.com/JonathanPitre/BIS-F/releases/tag/v7.1912.6.11041
[7.1912.5.11040]: https://github.com/JonathanPitre/BIS-F/releases/tag/v7.1912.5.11040
[7.1912.4.11038]: https://github.com/JonathanPitre/BIS-F/releases/tag/v7.1912.4.11038
[7.1912.3.11037]: https://github.com/JonathanPitre/BIS-F/releases/tag/v7.1912.3.11037
[7.1912.3.11036]: https://github.com/JonathanPitre/BIS-F/releases/tag/v7.1912.3.11036
[7.1912.3.11034]: https://github.com/JonathanPitre/BIS-F/releases/tag/v7.1912.3.11034
[7.1912.3.11033]: https://github.com/JonathanPitre/BIS-F/releases/tag/v7.1912.3.11033
[7.1912.2.11029]: https://github.com/JonathanPitre/BIS-F/releases/tag/v7.1912.2.11029
[7.1912.2.11028]: https://github.com/JonathanPitre/BIS-F/releases/tag/v7.1912.2.11028
[7.1912.2.011025]: https://github.com/JonathanPitre/BIS-F/releases/tag/v7.1912.2.011025
[7.1912.1.011024]: https://github.com/JonathanPitre/BIS-F/releases/tag/v7.1912.1.011024
[7.1912.0.011023]: https://github.com/JonathanPitre/BIS-F/releases/tag/v7.1912.0.011023
[6.1.3+01.110]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.3%2B01.110
[6.1.2+01.109]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.2%2B01.109
[6.1.1+01.105]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.1%2B01.105
[6.1.0+01.104]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B01.104
[6.1.0+01.103]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B01.103
[6.1.0+01.102]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B01.102
[6.1.0+01.101]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B01.101
[6.1.0+01.100]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B01.100
[6.1.0+02.103]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B02.103
[6.1.0+02.102]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B02.102
[6.1.0+02.101]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B02.101
[6.1.0+02.100]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B02.100
[6.1.0+03.106]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B03.106
[6.1.0+03.105]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B03.105
[6.1.0+03.104]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B03.104
[6.1.0+03.103]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B03.103
[6.1.0+03.102]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B03.102
[6.1.0+03.101]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B03.101
[6.1.0+03.100]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B03.100
[6.1.0+04.113]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B04.113
[6.1.0+04.112]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B04.112
[6.1.0+04.111]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B04.111
[6.1.0+04.110]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B04.110
[6.1.0+04.109]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B04.109
[6.1.0+04.108]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B04.108
[6.1.0+04.107]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B04.107
[6.1.0+04.106]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B04.106
[6.1.0+04.105]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B04.105
[6.1.0+04.104]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%2B04.104
[6.1.0 DEV]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.1.0%20DEV
[6.0.2]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.0.2
[6.0.1]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.0.1
[6.0.0]: https://github.com/JonathanPitre/BIS-F/releases/tag/v6.0.0
[5.1.2]: https://github.com/JonathanPitre/BIS-F/releases/tag/v5.1.2
[5.1.1]: https://github.com/JonathanPitre/BIS-F/releases/tag/v5.1.1
[5.1.0]: https://github.com/JonathanPitre/BIS-F/releases/tag/v5.1.0
[5.0.2]: https://github.com/JonathanPitre/BIS-F/releases/tag/v5.0.2
[5.0.1]: https://github.com/JonathanPitre/BIS-F/releases/tag/v5.0.1
[5.0.0]: https://github.com/JonathanPitre/BIS-F/releases/tag/v5.0.0
[4.5.2]: https://github.com/JonathanPitre/BIS-F/releases/tag/v4.5.2
[4.5.1]: https://github.com/JonathanPitre/BIS-F/releases/tag/v4.5.1
[4.5.0]: https://github.com/JonathanPitre/BIS-F/releases/tag/v4.5.0
[4.2.2]: https://github.com/JonathanPitre/BIS-F/releases/tag/v4.2.2
[4.2.1]: https://github.com/JonathanPitre/BIS-F/releases/tag/v4.2.1
[4.2]: https://github.com/JonathanPitre/BIS-F/releases/tag/v4.2
[4.1]: https://github.com/JonathanPitre/BIS-F/releases/tag/v4.1
[4.0.1]: https://github.com/JonathanPitre/BIS-F/releases/tag/v4.0.1
[4.0]: https://github.com/JonathanPitre/BIS-F/releases/tag/v4.0
[3.5]: https://github.com/JonathanPitre/BIS-F/releases/tag/v3.5
[3.4]: https://github.com/JonathanPitre/BIS-F/releases/tag/v3.4
[3.3]: https://github.com/JonathanPitre/BIS-F/releases/tag/v3.3
[3.2]: https://github.com/JonathanPitre/BIS-F/releases/tag/v3.2
[3.1]: https://github.com/JonathanPitre/BIS-F/releases/tag/v3.1
[3.0]: https://github.com/JonathanPitre/BIS-F/releases/tag/v3.0
[2.7]: https://github.com/JonathanPitre/BIS-F/releases/tag/v2.7
[2.6]: https://github.com/JonathanPitre/BIS-F/releases/tag/v2.6
[2.5]: https://github.com/JonathanPitre/BIS-F/releases/tag/v2.5
[2.4]: https://github.com/JonathanPitre/BIS-F/releases/tag/v2.4
[2.3]: https://github.com/JonathanPitre/BIS-F/releases/tag/v2.3
[2.2]: https://github.com/JonathanPitre/BIS-F/releases/tag/v2.2
[2.1]: https://github.com/JonathanPitre/BIS-F/releases/tag/v2.1
[2.0]: https://github.com/JonathanPitre/BIS-F/releases/tag/v2.0
[1.9]: https://github.com/JonathanPitre/BIS-F/releases/tag/v1.9
[1.8]: https://github.com/JonathanPitre/BIS-F/releases/tag/v1.8
[1.7]: https://github.com/JonathanPitre/BIS-F/releases/tag/v1.7
[1.6]: https://github.com/JonathanPitre/BIS-F/releases/tag/v1.6
[1.5]: https://github.com/JonathanPitre/BIS-F/releases/tag/v1.5
[1.4]: https://github.com/JonathanPitre/BIS-F/releases/tag/v1.4
[1.3]: https://github.com/JonathanPitre/BIS-F/releases/tag/v1.3
[1.2]: https://github.com/JonathanPitre/BIS-F/releases/tag/v1.2
[1.1]: https://github.com/JonathanPitre/BIS-F/releases/tag/v1.1
[1.0]: https://github.com/JonathanPitre/BIS-F/releases/tag/v1.0
