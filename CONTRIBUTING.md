# Contributing to BIS-F

Thanks for helping improve **Base Image Script Framework (BIS-F)**. This guide covers
environment setup, local quality checks, and how to open a pull request.

## Code of Conduct

Please read and follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Ways to contribute

- Report bugs or request features via [GitHub Issues](https://github.com/EUCweb/BIS-F/issues)
- Improve documentation (`README.md`, `CHANGELOG.md`, ADMX help text)
- Fix or extend preparation / personalization scripts under `Framework/`
- Add custom hooks in the `Custom/` folders (see below)

## Development setup

1. Fork the repository and clone your fork.
2. Open the repo in **Cursor** or **VS Code**.
3. Install recommended extensions (spell check, markdownlint, PowerShell):
   - Accept the workspace prompt when the editor suggests extensions, **or**
   - Run:

     ```powershell
     .\tools\Install-BISFDevExtensions.ps1
     ```

4. Install PSScriptAnalyzer (used by the editor and CI):

   ```powershell
   Install-Module PSScriptAnalyzer -Scope CurrentUser
   ```

## Local quality checks

### Markdown

Markdown is linted with [markdownlint](https://github.com/DavidAnson/markdownlint) using
[`.markdownlint.json`](../.markdownlint.json) and [`.markdownlint-cli2.jsonc`](../.markdownlint-cli2.jsonc)
(which ignores the root `LICENSE` file so GPLv3 stays verbatim). With the recommended extension
installed, fixes run on save.

### PowerShell

Analyze Framework scripts with the same settings CI uses:

```powershell
.\tools\Invoke-BISFScriptAnalyzer.ps1
```

Check variable casing (PascalCase) the same way CI does:

```powershell
.\tools\Test-BISFVariableCasing.ps1
```

On a PR-style ratchet (added/modified Framework scripts only):

```powershell
.\tools\Test-BISFVariableCasing.ps1 -ChangedOnly
```

Ensure PowerShell files are **UTF-8 with BOM** (required so Windows PowerShell 5.1
parses non-ASCII characters correctly):

```powershell
.\tools\Test-BISFUtf8Bom.ps1
```

Rewrite any that are missing the BOM:

```powershell
.\tools\Test-BISFUtf8Bom.ps1 -Fix
```

Workspace settings and `.editorconfig` set `charset = utf-8-bom` for `*.ps1` /
`*.psm1` / `*.psd1`. Do not save those files as UTF-8 without BOM.

Settings live in [`.vscode/PSScriptAnalyzerSettings.psd1`](../.vscode/PSScriptAnalyzerSettings.psd1).
Some rules are excluded because BIS-F intentionally uses legacy patterns: `$Global:` state across
prep/pers scripts (`PSAvoidGlobalVars`), compatibility cmdlet shims
(`PSAvoidOverwritingBuiltInCmdlets`), `$PSScriptRoot`/`$args` bootstrap
(`PSAvoidAssignmentToAutomaticVariable`), ADMX-driven `Invoke-Expression`
(`PSAvoidUsingInvokeExpression`), WMI pagefile/sealing paths (`PSAvoidUsingWMICmdlet`), and
non-interactive helpers without `-WhatIf` (`PSUseShouldProcessForStateChangingFunctions`).

#### PowerShell naming

Use **PascalCase** for PowerShell variables and parameters (for example `$LogPath`,
`$Computer`, `$ModuleName`), matching the
[PowerShell Practice and Style Guide](https://poshcode.gitbook.io/powershell-practice-and-style/style-guide/code-layout-and-formatting).

- Scope modifiers use canonical casing: `$Global:`, `$Script:`, `$Env:`.
- Automatic and preference variables use Microsoft’s spelling (`$PSScriptRoot`,
  `$ErrorActionPreference`, `$PSBoundParameters`).
- Do **not** introduce new underscore-separated variable names; prefer `$MainFolder`
  over `$Main_Folder` in new scripts.
- New scripts should start from
  [Framework/SubCall/Template/BISF_TEMPLATE.ps1](../Framework/SubCall/Template/BISF_TEMPLATE.ps1).
- Do not add `.LINK https://eucweb.com` on functions or scripts. The module
  `HelpInfoURI` in `BISF.psd1` is the single project URL.

**Exceptions** (leave as-is; the casing checker allowlists them):

| Pattern | Why |
| --- | --- |
| `$LIC_BISF_*`, `$CHK_*`, `$DST_*` | ADMX / policy / registry value mirrors |
| Legacy path globals such as `$Main_Folder`, `$SubCall_Folder`, `$LIB_Folder` | Existing shared Framework state |
| Trivial loop counters (`$i`, `$a`, `$x`) | Idiomatic |
| Public function names (`Get-BISF*`, `Write-BISFLog`, …) | Do not rename without a migration plan |

### What CI runs

| Workflow | Purpose |
| --- | --- |
| `markdownlint.yml` | Lint Markdown on PRs; auto-fix on push to `master` / `main` / `develop` / `refactor/modernize` |
| `validate-scripts.yml` | PSScriptAnalyzer (Error severity), variable PascalCase, and UTF-8 BOM check on PowerShell files (auto-fix BOM on push) |
| `codeql-powershell.yml` | Experimental Microsoft PowerShell CodeQL; uploads SARIF when code scanning is enabled |
| `dependabot.yml` + `dependabot-auto-merge.yml` | Daily GitHub Actions updates on the default branch; squash auto-merge when checks pass |
| `update-tool-pins.yml` | Weekly bump of PSScriptAnalyzer / CodeQL PowerShell pins in `.github/tool-versions.env` |

Shared non-Action pins live in [`.github/tool-versions.env`](tool-versions.env). Refresh them locally
with `.\tools\Update-BISFToolPins.ps1`.

CodeQL SARIF upload requires GitHub code scanning / Advanced Security on the repository. The
workflow still uploads a SARIF artifact when available.

For full automation on this fork:

1. Enable **Dependabot version updates** (Settings → Advanced Security). A `dependabot.yml`
   file does not turn this on by itself on a fork.
2. Enable **Allow auto-merge** so `dependabot-auto-merge.yml` can squash-merge when checks pass.
3. Optionally add an `AUTOMATION_TOKEN` secret (PAT with `contents` + `pull-requests`) so
   tool-pin PRs trigger CI and auto-merge. Dependabot Action PRs do not need that secret.

## Making changes

1. Create a topic branch from the default branch (`refactor/modernize` on this fork;
   `develop` or `master` on other remotes). Avoid committing directly to the default branch.
2. Prefer small, focused commits that follow existing Framework style and PascalCase variable naming.
3. Keep preparation and personalization scripts in their existing numbered folders.
4. Do not rename public functions or ADMX-backed identifiers without a clear migration plan.
5. Run `.\tools\Test-BISFVariableCasing.ps1 -ChangedOnly` before opening a PR that touches Framework scripts.
6. Run `.\tools\Test-BISFUtf8Bom.ps1` (or `-Fix`) so PowerShell files keep UTF-8 with BOM.
7. Check whitespace before committing: `git diff --check`.

### Custom scripts

Drop site-specific logic into:

- `Framework/SubCall/Preparation/Custom/`
- `Framework/SubCall/Personalization/Custom/`

Use [Framework/SubCall/Template/BISF_TEMPLATE.ps1](../Framework/SubCall/Template/BISF_TEMPLATE.ps1)
as a starting point when adding new scripts.

## Pull requests

1. Push your topic branch to your fork.
2. Open a pull request against the upstream default branch.
3. Fill out the pull request template.
4. Ensure CI is green (markdownlint, validate-scripts, CodeQL where applicable).
5. Link related issues when possible.

## Documentation updates

Doc fixes and clarifications are welcome. Prefer Keep a Changelog style entries in
`CHANGELOG.md` under `[Unreleased]` when behavior or public docs change.

## Additional resources

- [Project README](../README.md)
- [EUCweb documentation](https://eucweb.com/doc/bis-f-1912)
- [GitHub Flow](https://docs.github.com/en/get-started/using-github/github-flow)
- [Fork a repo](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/fork-a-repo)
