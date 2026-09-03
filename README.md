# Base Image Script Framework (BIS-F)

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-5391FE.svg?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![Release](https://img.shields.io/badge/release-2608.0-informational)](CHANGELOG.md)
[![Website](https://img.shields.io/badge/docs-eucweb.com-0A66C2)](https://eucweb.com)

Automate **preparation (sealing)** and **personalization** of Windows golden / master
images for non-persistent and provisioned environments.

BIS-F runs vendor-aligned seal and first-boot steps so cloned devices stay unique and
production-ready—whether you build the image from scratch or refresh it with new software.
See the [changelog](CHANGELOG.md) for release history and recent changes.

## 💡 Why BIS-F?

When you clone a Windows master image with Citrix PVS/MCS, App Layering, Omnissa Horizon,
Azure Virtual Desktop, or similar platforms, you copy more than
apps and files. You also clone **machine identity and unique IDs**—Antivirus / EDR client
IDs, agent registrations, certificates, caches, and other device-bound state.

Duplicated identities break or silently weaken security software. Agents may fail to
register, share a single “device” in the console, skip updates, or leave the fleet
under-protected while everything looks fine on the master.

**BIS-F is effectively mandatory** if you want a secure, stable non-persistent environment.
Preparation generalizes and resets the master before seal/shutdown. Personalization restores
unique device state on first boot of each clone.

Teams often assume a few manual steps or a short home-grown script are enough. They usually
are not. BIS-F encodes vendor-aligned seal and personalize steps maintained by EUC/VDI
practitioners with decades of combined field experience—so you are not rediscovering the same
gaps under production pressure.

BIS-F orchestrates that lifecycle with PowerShell you can run interactively or fully
unattended via Group Policy (ADMX).

## 🖥️ Supported environments

| Platform | Notes |
| --- | --- |
| **Citrix** | Virtual Apps and Desktops, PVS, MCS / MCSIO, App Layering, WEM, VDA SSL |
| **Omnissa** | Horizon Agent, OS Optimization Tool (OSOT), TCP/IP optimizations |
| **Microsoft** | Azure Virtual Desktop / Windows 365-style images, Configuration Manager, SCOM, App-V, Sysprep fallback |
| **Other** | Nutanix Frame, Parallels RAS, and environments without image-management software (Sysprep) |

## ⚙️ How it works

BIS-F has two phases:

```text
┌─────────────────────┐         provision / clone          ┌──────────────────────┐
│  Preparation (seal) │  ────────────────────────────────► │  Personalization     │
│  PrepBISF_Start.ps1 │         first boot of device       │  PersBISF_Start.ps1  │
└─────────────────────┘                                    └──────────────────────┘
```

1. **Preparation** — Run on the master image before you convert/seal/shut down. Cleans and
   generalizes the image (AV/EDR, Citrix/Omnissa agents, optimizers, rearm, write-cache prep,
   optional sysprep).
2. **Personalization** — Runs automatically (or on schedule) when a provisioned machine boots
   so device-specific state is restored.

Custom scripts can be dropped into:

- `Framework/SubCall/Preparation/Custom/`
- `Framework/SubCall/Personalization/Custom/`

## ✅ Features

- **Image sealing & personalization** for PVS, MCS, Horizon, AVD, and Sysprep workflows
- **Group Policy control** via ADMX/ADML for silent, unattended runs
- **Shared configuration** — export/import ADMX-driven settings (JSON/XML) across layers or images
- **Third-party integrations**, including:
  - Antivirus / EDR: Microsoft Defender, Symantec Endpoint Protection (Broadcom), Trellix,
    Sophos, Trend Micro, BlackBerry Cylance, CrowdStrike Falcon, WithSecure, Kaspersky, and others
  - Citrix Optimizer, Omnissa OSOT, SDelete, CCleaner, DelProf2, CMTrace
  - FSLogix, Office KMS / Microsoft 365 activation, NVIDIA / Intel graphics VDA support
  - Configuration Manager, SCOM, App-V, Ivanti, OpenText ZENworks, Turbo.net, uberAgent,
    Tanium, Splunk, Rapid7, NinjaOne, and more
- **Write-cache disk** handling for PVS and MCSIO
- **Logging** with optional central log share and PowerShell transcript support
- **Extensible** preparation and personalization script folders

## 🚀 Quick start

### 📋 Prerequisites

- Windows master image (desktop or server) with **administrative** rights
- **PowerShell 5.1+**
- Image-management agent installed when applicable (Citrix VDA / PVS target, Horizon Agent,
  etc.), or plan to use Sysprep
- Recommended: copy `ADMX/` templates into your `PolicyDefinitions` folder for GPO-driven
  automation

### 📦 Install

There is no packaged MSI/winget installer from this fork yet (the old Chocolatey feed is
legacy and will not be updated; a **winget** package is planned later). Use
[`tools/Install-BISF.ps1`](tools/Install-BISF.ps1) to install the latest
`refactor/modernize` sources from
[JonathanPitre/BIS-F](https://github.com/JonathanPitre/BIS-F).

Run **as Administrator**:

```powershell
$Script = Join-Path $env:TEMP 'Install-BISF.ps1'
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/JonathanPitre/BIS-F/refactor/modernize/tools/Install-BISF.ps1' -OutFile $Script
& $Script
```

Or from a local clone:

```powershell
.\tools\Install-BISF.ps1 -SourcePath $PWD
```

The installer copies `Framework\`, `ADMX\`, `PrepareBaseImage.cmd`, and `LICENSE`, writes
`HKLM:\SOFTWARE\Login Consultants\BISF` `Path` and `Version` (from `BISF.psd1`), and creates
an Administrative Tools shortcut to `PrepareBaseImage.cmd` (not shown to standard users).
Docs, CI, and tooling from the zip are discarded.

Copy `ADMX\` into your `PolicyDefinitions` store when you want GPO-driven automation.

### 🔒 Prepare (seal) the base image

1. Install BIS-F on the master image (PowerShell steps above).
2. Configure policies with the ADMX templates under `ADMX/` (recommended for silent
   automation).
3. Run preparation **as Administrator** from the install folder:

   ```cmd
   PrepareBaseImage.cmd
   ```

   Or invoke PowerShell directly:

   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File ".\Framework\PrepBISF_Start.ps1"
   ```

4. Shut down when sealing completes (unless your GPO/automation suppresses shutdown), then
   create/update the provisioned image as usual.

### 🎨 Personalization

Personalization is driven by `Framework/PersBISF_Start.ps1` and the scripts under
`Framework/SubCall/Personalization/`. Configure behavior with the **Configure Personalization**
ADMX settings so first boot applies the right device-specific steps.

## ⚙️ Configuration (ADMX)

ADMX/ADML files live in `ADMX/`:

| Path | Purpose |
| --- | --- |
| `ADMX/BaseImageScriptFramework.admx` | Policy definitions |
| `ADMX/en-US/BaseImageScriptFramework.adml` | English policy strings / help |

Copy them to your central or local PolicyDefinitions store, then configure Computer
Configuration policies for BIS-F (logging, PVS/MCS, App Layering, AV scan, Citrix Optimizer,
FSLogix, shutdown behavior, and more).

> Prefer ADMX over legacy CLI switches. Remaining interactive/debug switches (for example
> `-Verbose` / `-Debug`) are documented in the preparation script header.

## 📁 Repository layout

```text
BIS-F/
├── ADMX/                         # Group Policy templates
├── Framework/
│   ├── PrepBISF_Start.ps1        # Preparation entry point
│   ├── PersBISF_Start.ps1        # Personalization entry point
│   └── SubCall/
│       ├── Global/               # Shared module (BISF.psm1)
│       ├── Preparation/          # Seal scripts (+ Custom/)
│       ├── Personalization/      # First-boot scripts (+ Custom/)
│       └── Template/             # Script template
├── PrepareBaseImage.cmd          # Admin launcher for preparation
├── CHANGELOG.md                  # Version history (Keep a Changelog)
└── LICENSE                       # GPL-3.0
```

Full version history and release notes live in [CHANGELOG.md](CHANGELOG.md).

## 📚 Documentation & community

| Resource | Link |
| --- | --- |
| Project site | [eucweb.com](https://eucweb.com) |
| Online documentation | [BIS-F docs](https://eucweb.com/doc/bis-f-1912) |
| Upstream project | [EUCweb/BIS-F](https://github.com/EUCweb/BIS-F) |
| Issues & feature requests | [GitHub Issues](https://github.com/JonathanPitre/BIS-F/issues) |
| Release history | [CHANGELOG.md](CHANGELOG.md) |

## 🤝 Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup,
extensions, linting, and the pull request workflow. Behavior or public-doc changes should
also get an entry under `[Unreleased]` in [CHANGELOG.md](CHANGELOG.md).

Please follow the [Code of Conduct](.github/CODE_OF_CONDUCT.md).

## ⚖️ License

This project is licensed under the [GNU General Public License v3.0](LICENSE)
([SPDX: GPL-3.0](https://spdx.org/licenses/GPL-3.0.html)).

## 👥 Authors

Originally created and maintained by **Matthias Schlimm**
([EUCweb.com](https://eucweb.com)).

Currently revived and maintained by **Jonathan Pitre**. Significant contributions from the
EUC community—see commit history and the [changelog](CHANGELOG.md) for details.
