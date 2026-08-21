#powershell.scriptAnalysis.settingsPath
#
# Use the PowerShell extension setting `powershell.scriptAnalysis.settingsPath`
# (configured in `.vscode/settings.json`) so this workspace uses these rules.
#
# https://github.com/PowerShell/PSScriptAnalyzer#settings-support-in-scriptanalyzer

@{
    # Omit Severity here so IDE analysis can still show Warnings/Information.
    # CI passes -Severity Error via tools/Invoke-BISFScriptAnalyzer.ps1.
    IncludeDefaultRules = $true

    ExcludeRules = @(
        # Framework shares state across prep/pers scripts via $Global:
        'PSAvoidGlobalVars'
        # Operator-facing console UX
        'PSAvoidUsingWriteHost'
        # Legacy public function names — renaming would break callers
        'PSUseSingularNouns'
        'PSUseApprovedVerbs'
        # High-noise style rules for this legacy codebase (ratchet later)
        'PSAvoidLongLines'
        'PSUseConsistentIndentation'
        'PSUseConsistentWhitespace'
        'PSAlignAssignmentStatement'
        'PSPlaceOpenBrace'
        'PSPlaceCloseBrace'
        'PSAvoidTrailingWhitespace'
        'PSAvoidUsingDoubleQuotesForConstantString'
        'PSAvoidSemicolonsAsLineTerminators'
        'PSProvideCommentHelp'
        'PSUseDeclaredVarsMoreThanAssignments'
        'PSReviewUnusedParameter'
        'PSAvoidUsingPositionalParameters'
        'PSUseCorrectCasing'
        # Framework helpers are not interactive -WhatIf cmdlets
        'PSUseShouldProcessForStateChangingFunctions'
        # Compatibility shims / script-local wrappers (ScheduledTask, Stop-Service, Clear-EventLog)
        'PSAvoidOverwritingBuiltInCmdlets'
        # Intentional $PSScriptRoot ISE/console bootstrap and $args process-argument arrays
        'PSAvoidAssignmentToAutomaticVariable'
        # ADMX-driven prep/post command strings and external-tool launch patterns
        'PSAvoidUsingInvokeExpression'
        # Pagefile / Win32_* sealing paths (incl. Set-WMIInstance) are behavior-sensitive
        'PSAvoidUsingWMICmdlet'
    )

    Rules = @{
        PSUseCompatibleSyntax = @{
            Enable = $true
            TargetVersions = @(
                '5.1'
            )
        }
    }
}
