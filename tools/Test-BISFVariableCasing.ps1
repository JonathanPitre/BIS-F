<#
.SYNOPSIS
  Validates PascalCase PowerShell variable naming in BIS-F Framework scripts.

.DESCRIPTION
  Uses the PowerShell AST to find variable identifiers. Names must start with an
  uppercase letter (PascalCase), with allowlists for ADMX/registry mirrors,
  legacy path globals, trivial counters, and automatic/preference variables.

  Exit code 1 when violations are found.

.PARAMETER Path
  Root path to scan. Default: Framework under the repo root.

.PARAMETER ChangedOnly
  Scan only added/modified Framework .ps1/.psm1 files vs the merge base
  (GITHUB_BASE_REF / origin/<base> when present, otherwise HEAD~1).

.PARAMETER BaseRef
  Optional git ref to diff against when -ChangedOnly is set.
#>
[CmdletBinding()]
param(
    [string]$Path,

    [switch]$ChangedOnly,

    [string]$BaseRef
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')
if (-not $Path) {
    $Path = Join-Path $repoRoot 'Framework'
}

$allowedExact = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
@(
    # Automatic / preference variables (Microsoft canonical names)
    'true', 'false', 'null', 'this', 'input', 'args', 'foreach', 'switch',
    'Error', 'Host', 'Home', 'PID', 'PSVersionTable', 'PWD', 'ShellID',
    'StackTrace', 'MyInvocation', 'PSScriptRoot', 'PSCommandPath', 'PSBoundParameters',
    'PSCmdlet', 'PSItem', 'PSSenderInfo', 'PSCulture', 'PSUICulture',
    'ExecutionContext', 'Matches', 'LASTEXITCODE',
    'ErrorActionPreference', 'WarningPreference', 'VerbosePreference',
    'DebugPreference', 'InformationPreference', 'ProgressPreference',
    'WhatIfPreference', 'ConfirmPreference', 'ErrorView', 'FormatEnumerationLimit',
    'PSDefaultParameterValues', 'PSEmailServer', 'PSSessionApplicationName',
    'PSSessionConfigurationName', 'PSSessionOption', 'OutputEncoding',
    'MaximumAliasCount', 'MaximumDriveCount', 'MaximumErrorCount',
    'MaximumFunctionCount', 'MaximumHistoryCount', 'MaximumVariableCount',
    'OFS', 'NestedPromptLevel',
    # Windows PowerShell ISE automatic variable
    'psISE',

    # Legacy shared Framework path / registry globals (underscore contracts)
    'Main_Folder', 'SubCall_Folder', 'LIB_Folder', 'LogFileName',
    'hklm_software_LIC_CTX_BISF_SCRIPTS', 'hklm_software_Pol_LIC_CTX_BISF_SCRIPTS',
    'HKLM_Hardware_KeyboardType', 'HKLM_Software_Citrix_fmd',
    'HKLM_Software_Policies_PVS', 'HKLM_System_CurrentControlSet_Services',
    'HKLM_System_CCS_Control_LSA', 'HKLM_System_CurrentControlSet_Control_Citrix',
    'HKLM_Software_MS_NET_FW_AV', 'HKLM_Software_MS_NET_FW_AV_Domain',
    'HKLM_Software_MS_NET_FW_AV_Standard', 'HKLM_Software_MS_NET_FW_AV_Public',

    # Common env-driven / special names referenced as variables
    '_'
) | ForEach-Object { [void]$allowedExact.Add($_) }

$allowedPrefixes = @(
    'LIC_BISF_',
    'CHK_',
    'DST_',
    'hklm_',
    'HKLM_',
    'HKCU_',
    'hku_',
    'cu_',
    'AppLay'
)

# Single-letter and trivial numeric-style loop counters
$allowedCounter = [regex]::new('^[a-z]$', [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)

function Test-IsAllowedVariableName {
    param([Parameter(Mandatory)][string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { return $true }
    if ($allowedExact.Contains($Name)) { return $true }
    if ($allowedCounter.IsMatch($Name)) { return $true }

    foreach ($prefix in $allowedPrefixes) {
        if ($Name.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    # PascalCase: first character must be uppercase A-Z (ASCII)
    if ($Name[0] -cmatch '[A-Z]') {
        return $true
    }

    return $false
}

function Get-ChangedFrameworkScripts {
    param([string]$RepoRoot, [string]$Base)

    Push-Location $RepoRoot
    try {
        $resolvedBase = $Base
        if (-not $resolvedBase) {
            if ($env:GITHUB_BASE_REF) {
                $resolvedBase = "origin/$($env:GITHUB_BASE_REF)"
            }
            elseif ($env:GITHUB_EVENT_BEFORE -and $env:GITHUB_EVENT_BEFORE -ne ('0' * 40)) {
                $resolvedBase = $env:GITHUB_EVENT_BEFORE
            }
            else {
                $resolvedBase = 'HEAD~1'
            }
        }

        git rev-parse --verify $resolvedBase 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Base ref '$resolvedBase' not found; scanning all Framework scripts."
            return $null
        }

        $files = @(
            git diff --name-only --diff-filter=AM "$resolvedBase" -- Framework |
                Where-Object { $_ -match '\.(ps1|psm1)$' }
        )
        return $files | ForEach-Object { Join-Path $RepoRoot ($_ -replace '/', [IO.Path]::DirectorySeparatorChar) }
    }
    finally {
        Pop-Location
    }
}

function Get-ScriptVariableViolations {
    param([Parameter(Mandatory)][string]$FilePath)

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$tokens, [ref]$errors)
    if (-not $ast) {
        return @()
    }

    $violations = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)

    $variableAsts = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.VariableExpressionAst]
        }, $true)

    foreach ($varAst in $variableAsts) {
        $varPath = $varAst.VariablePath
        if ($varPath.IsDriveQualified) {
            # $Env:ComputerName, $Function:..., etc. — skip drive-qualified names
            continue
        }

        $name = $varPath.UserPath
        if ([string]::IsNullOrWhiteSpace($name)) { continue }

        # Strip scope qualifiers already handled by UserPath (Global:Name -> Name in some hosts);
        # VariablePath.UserPath is the name without $.
        $unscoped = $name
        if ($unscoped -match '^(Global|Script|Local|Private|Using|Workflow):(?<n>.+)$') {
            $unscoped = $Matches['n']
        }

        if (Test-IsAllowedVariableName -Name $unscoped) {
            continue
        }

        $line = $varAst.Extent.StartLineNumber
        $key = "${FilePath}:${line}:`$$unscoped"
        if (-not $seen.Add($key)) { continue }

        $violations.Add([PSCustomObject]@{
                File    = $FilePath
                Line    = $line
                Name    = $unscoped
                Message = "Variable `$$unscoped must be PascalCase (start with uppercase A-Z), or match an allowlisted ADMX/legacy/automatic name."
            })
    }

    return $violations
}

# Resolve files to scan
$filesToScan = @()
if ($ChangedOnly) {
    $changed = Get-ChangedFrameworkScripts -RepoRoot $repoRoot -Base $BaseRef
    if ($null -eq $changed) {
        $filesToScan = @(Get-ChildItem -Path $Path -Recurse -Include *.ps1, *.psm1 -File | Select-Object -ExpandProperty FullName)
    }
    else {
        $filesToScan = @($changed | Where-Object { Test-Path -LiteralPath $_ })
        Write-Host "Changed-only mode: $($filesToScan.Count) file(s)"
    }
}
else {
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Error "Scan path not found: $Path"
    }
    $filesToScan = @(Get-ChildItem -Path $Path -Recurse -Include *.ps1, *.psm1 -File | Select-Object -ExpandProperty FullName)
}

Write-Host "Scanning $($filesToScan.Count) script(s) under $Path"

$allViolations = [System.Collections.Generic.List[object]]::new()
foreach ($file in $filesToScan) {
    foreach ($v in (Get-ScriptVariableViolations -FilePath $file)) {
        $allViolations.Add($v)
    }
}

if ($allViolations.Count -gt 0) {
    $allViolations |
        Sort-Object File, Line, Name |
        ForEach-Object {
            $rel = $_.File
            if ($rel.StartsWith([string]$repoRoot, [StringComparison]::OrdinalIgnoreCase)) {
                $rel = $_.File.Substring($repoRoot.Path.Length).TrimStart('\', '/')
            }
            Write-Host ("{0}:{1}: `${2} - {3}" -f $rel, $_.Line, $_.Name, $_.Message)
        }
    Write-Error ("Test-BISFVariableCasing: {0} violation(s)" -f $allViolations.Count)
    exit 1
}

Write-Host 'Variable casing check passed.' -ForegroundColor Green
exit 0
