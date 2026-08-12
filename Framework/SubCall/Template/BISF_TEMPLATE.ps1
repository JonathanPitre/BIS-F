<#
	.SYNOPSIS
		Prepare or personalize <Product Name> for image management
	.DESCRIPTION
		Shared starting point for BIS-F Preparation and Personalization scripts.

		Copy this file to:
		- Framework/SubCall/Preparation/Custom/NN_PrepBISF_<Name>.ps1  (seal / golden image)
		- Framework/SubCall/Personalization/Custom/NN_PersBISF_<Name>.ps1  (first boot)

		Scripts under Preparation/ and Personalization/ are dot-sourced by the framework
		after the BISF module is loaded. Use Write-BISFLog (do not Import-Module here).

		Prep typically stops services and clears machine-specific state.
		Pers typically creates host IDs and starts services.
	.EXAMPLE
	.NOTES
		Author: <Name>
		Company: EUCWeb.com

		History:
		dd.mm.yyyy XX: Script created

	.LINK
		https://eucweb.com
#>

Begin {
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)

	$Product = '<Product Name>'
	$ServiceName = '<ServiceName>'
	# Optional ADMX gate (replace <XX> with the policy suffix):
	# $VarCLI = $LIC_BISF_CLI_<XX>

	####################################################################
	####### functions #####
	####################################################################

	function Invoke-ProductAction {
		[CmdletBinding(SupportsShouldProcess = $true)]
		[OutputType([bool])]
		param()

		end {
			if (-not $PSCmdlet.ShouldProcess($Product, 'Run product action')) {
				return $true
			}

			# Prep: typically Invoke-BISFService -Action Stop
			# Pers: typically Invoke-BISFService -Action Start
			$Svc = Test-BISFService -ServiceName $ServiceName -ProductName $Product
			if ($Svc -eq $true) {
				Invoke-BISFService -ServiceName $ServiceName -Action Stop
				return $true
			}

			Write-BISFLog -Msg "Service $ServiceName not found for $Product" -Type W
			return $false
		}
	}

	####### end functions #####
}

Process {
	#### Main Program

	# Optional ADMX skip (uncomment when $VarCLI is set in Begin):
	# if (($VarCLI -eq 'NO')) {
	# 	Write-BISFLog -Msg "Skip $Product (ADMX)"
	# 	return
	# }

	$Svc = Test-BISFService -ServiceName $ServiceName -ProductName $Product
	if ($Svc -eq $true) {
		Write-BISFLog -Msg "Processing $Product" -ShowConsole -Color Cyan
		$null = Invoke-ProductAction
	}
	else {
		Write-BISFLog -Msg "Product $Product is NOT installed"
	}
}

End {
	Add-BISFFinishLine
}
