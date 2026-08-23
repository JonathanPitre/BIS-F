<#
	.SYNOPSIS
		Prepare or personalize a software for BIS-F image management.
	.DESCRIPTION
		Shared starting point for BIS-F Preparation and Personalization scripts.

		Copy this file to:
		- Framework/SubCall/Preparation/Custom/NN_PrepBISF_{Name}.ps1  (seal / golden image)
		- Framework/SubCall/Personalization/Custom/NN_PersBISF_{Name}.ps1  (first boot)

		Scripts under Preparation/ and Personalization/ are dot-sourced by the framework
		after the BISF module is loaded. Use Write-BISFLog (do not Import-Module here).

		Preparation typically stops services and clears machine-specific state.
		Personalization typically creates host IDs and starts services.
	.EXAMPLE
		Copy to Framework/SubCall/Preparation/Custom/10_PrepBISF_SoftwareName.ps1, set $SoftwareName and
		$ServiceName, then run PrepareBaseImage.cmd script.
	.INPUTS
		None
	.OUTPUTS
		None
	.NOTES
		Author: {Author}

		History:
		dd.mm.yyyy XX: Script created
#>

Begin {
	$SoftwareName= 'Software Name'
	$ServiceName = 'Service Name'
	# Optional ADMX gate (replace {PolicySuffix} with the policy suffix):
	# $VarCLI = $LIC_BISF_CLI_{PolicySuffix}

	function Invoke-SoftwareAction {
		<#
			.SYNOPSIS
				Runs the software-specific Pre	p or Pers action.
			.DESCRIPTION
				Stops or starts the software service. Replace the body for your software.
				Prep typically stops the service; Pers typically starts it.
				Call only after Process confirms the software is installed.
			.EXAMPLE
				Invoke-SoftwareAction
				Stops the configured software service when it is installed.
			.OUTPUTS
				System.Boolean
			.NOTES
				Prep: Invoke-BISFService -Action Stop
				Pers: Invoke-BISFService -Action Start
		#>
		[CmdletBinding(SupportsShouldProcess = $true)]
		[OutputType([bool])]
		param()

		if (-not $PSCmdlet.ShouldProcess($SoftwareName, 'Run software action')) {
			return $true
		}

		# Prep: typically Invoke-BISFService -Action Stop
		# Pers: typically Invoke-BISFService -Action Start
		Invoke-BISFService -ServiceName $ServiceName -Action Stop
		return $true
	}
}

Process {
	# Optional ADMX skip (uncomment when $VarCLI is set in Begin):
	# if ($VarCLI -eq 'NO') {
	# 	Write-BISFLog -Msg "Skip $SoftwareName (ADMX)"
	# 	return
	# }

	if (Test-BISFService -ServiceName $ServiceName -SoftwareName $SoftwareName) {
		Write-BISFLog -Msg "Processing $SoftwareName" -ShowConsole -Color Cyan
		$null = Invoke-SoftwareAction
	}
	else {
		Write-BISFLog -Msg "$SoftwareName is not installed"
	}
}

End {
	Add-BISFFinishLine
}
