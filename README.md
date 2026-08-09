# Base Image Script Framework (BIS-F)

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-5391FE.svg?logo=powershell&logoColor=white)](https://docs.microsoft.com/powershell/)
[![Release](https://img.shields.io/badge/release-7.1912-informational)](CHANGELOG.md)
[![Website](https://img.shields.io/badge/docs-eucweb.com-0A66C2)](https://eucweb.com)

Automate **preparation (sealing)** and **personalization** of Windows golden / master images for non-persistent and provisioned environments.

BIS-F runs vendor-aligned seal and first-boot steps so cloned devices stay unique and production-ready—whether you build the image from scratch or refresh it with new software.

## Why BIS-F?

Before you distribute a master image with Citrix PVS/MCS, App Layering, VMware Horizon, AVD, or similar, the image must be sealed (services stopped, AV identity reset, caches cleaned, optimizations applied). After clone/boot, personalization makes each device unique again (write cache, agent re-registration, FSLogix rules, and more).

BIS-F orchestrates that lifecycle with PowerShell scripts you can run interactively or fully unattended via Group Policy (ADMX).

## Supported environments

| Platform | Notes |
| --- | --- |
| **Citrix** | Virtual Apps and Desktops, PVS, MCS / MCSIO, App Layering, WEM, VDA SSL |
| **VMware** | Horizon View Agent, OS Optimization Tool (OSOT), TCP/IP optimizations |
| **Microsoft** | Azure Virtual Desktop / Windows 365-style images, SCCM/ConfigMgr, SCOM, App-V, Sysprep fallback |
| **Other** | Nutanix Frame, Parallels RAS, and environments without image-management software (Sysprep) |

## How it works

BIS-F has two phases:

```text
┌─────────────────────┐         provision / clone          ┌──────────────────────┐
│  Preparation (seal) │  ────────────────────────────────► │  Personalization     │
│  PrepBISF_Start.ps1 │         first boot of device       │  PersBISF_Start.ps1  │
└─────────────────────┘                                    └──────────────────────┘
```

1. **Preparation** — Run on the master image before you convert/seal/shut down. Cleans and generalizes the image (AV, Citrix/VMware agents, optimizers, rearm, write-cache prep, optional sysprep).
2. **Personalization** — Runs automatically (or on schedule) when a provisioned machine boots so device-specific state is restored.

Custom scripts can be dropped into:

- `Framework/SubCall/Preparation/Custom/`
- `Framework/SubCall/Personalization/Custom/`

## Features

- **Image sealing & personalization** for PVS, MCS, Horizon, AVD, and Sysprep workflows
- **Group Policy control** via ADMX/ADML for silent, unattended runs
- **Shared configuration** — export/import ADMX-driven settings (JSON/XML) across layers or images
- **Third-party integrations**, including:
  - Antivirus: Windows Defender, Symantec SEP, McAfee, Sophos, Trend Micro, Cylance, F-Secure, Kaspersky, and others
  - Citrix Optimizer, VMware OSOT, SDelete, CCleaner, DelProf2, CMTrace
  - FSLogix, Office KMS / Microsoft 365 activation, NVIDIA / Intel graphics VDA support
  - SCCM, SCOM, App-V, Ivanti / RES, Novell ZCM, Turbo.net, uberAgent, Tanium, Splunk, and more
- **Write-cache disk** handling for PVS and MCSIO
- **Logging** with optional central log share and PowerShell transcript support
- **Extensible** preparation and personalization script folders

## Quick start

### Prerequisites

- Windows master image (desktop or server) with **administrative** rights
- **PowerShell 5.1+**
- Image-management agent installed when applicable (Citrix VDA / PVS target, Horizon Agent, etc.), or plan to use Sysprep
- Recommended: copy `ADMX/` templates into your `PolicyDefinitions` folder for GPO-driven automation

### Prepare (seal) the base image

1. Install BIS-F on the master image (MSI/EXE release from [EUCweb](https://eucweb.com), or use this repository layout).
1. Configure policies with the ADMX templates under `ADMX/` (recommended for silent automation).
1. Run preparation **as Administrator**:

   ```cmd
   PrepareBaseImage.cmd
   ```

   Or invoke PowerShell directly:

   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File ".\Framework\PrepBISF_Start.ps1"
   ```

1. Shut down when sealing completes (unless your GPO/automation suppresses shutdown), then create/update the provisioned image as usual.

### Personalization

Personalization is driven by `Framework/PersBISF_Start.ps1` and the scripts under `Framework/SubCall/Personalization/`. Configure behavior with the **Configure Personalization** ADMX settings so first boot applies the right device-specific steps.

## Configuration (ADMX)

ADMX/ADML files live in `ADMX/`:

| Path | Purpose |
| --- | --- |
| `ADMX/BaseImageScriptFramework.admx` | Policy definitions |
| `ADMX/en-US/BaseImageScriptFramework.adml` | English policy strings / help |

Copy them to your central or local PolicyDefinitions store, then configure Computer Configuration policies for BIS-F (logging, PVS/MCS, App Layering, AV scan, Citrix Optimizer, FSLogix, shutdown behavior, and more).

> Prefer ADMX over legacy CLI switches. Remaining interactive/debug switches (for example `-Verbose` / `-Debug`) are documented in the preparation script header.

## Repository layout

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

## Documentation & community

| Resource | Link |
| --- | --- |
| Project site & docs | [eucweb.com](https://eucweb.com) |
| Online documentation | [eucweb.com/docs](http://eucweb.com/docs) |
| Upstream project | [EUCweb/BIS-F](https://github.com/EUCweb/BIS-F) |
| Issues & feature requests | [GitHub Issues](https://github.com/EUCweb/BIS-F/issues) |
| Chocolatey | Community package via [eucweb.com](https://eucweb.com) |
| Release history | [CHANGELOG.md](CHANGELOG.md) |

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](.github/CONTRIBUTING.md) for the workflow (fork, topic branch, tests, pull request).

Please follow the [Code of Conduct](.github/CODE_OF_CONDUCT.md).

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).

## Authors

Originally created and maintained by **Matthias Schlimm** ([EUCweb.com](https://eucweb.com)). Significant contributions from the EUC community—see commit history and release notes for details.
