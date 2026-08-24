<#
	.SYNOPSIS
		Personalize Turbo.net Applications for Image Management
	.DESCRIPTION
	  	Update the turbo subscription
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

	  	History:
		22.03.2016 MS: Script created
		18.02.2020 JK: Fixed Log output spelling
#>

Begin {

	####################################################################
	# define environment
	$PSScriptFullName = $MyInvocation.MyCommand.Path
	$PSScriptRoot = Split-Path -Parent $PSScriptFullName
	$PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)

	#product specified
	$Product = "Turbo.net"
	$ProductInstPath = "$ProgramFilesx86\Spoon\Cmd\Turbo.exe"
	$Tas

}

Process {

	####################################################################
	####### functions #####
	####################################################################

	function Invoke-TurboSubscriptionUpdate {
		$VarTB = Get-Variable -Name LIC_BISF_TurboRun -ValueOnly
		Write-BISFLog -Msg "The Turbo Subscription Update will be set to the Value $($VarTB) in the registry"

		IF ($VarTB -eq "YES") {
			Write-BISFLog -Msg "Running Turbo Update Subscription Now"
			Invoke-Expression (Get-ScheduledTask -TaskPath "\turbo-net\" | Start-ScheduledTask)
			Show-BISFProgressBar -CheckProcess "Turbo" -ActivityText "Running Turbo Subscription Update"
		}
	}

	####################################################################
	####### end functions #####
	####################################################################

	#### Main Program

	IF (Test-Path ("$ProductInstPath") -PathType Leaf) {
		Write-BISFLog -Msg "Product $Product installed" -ShowConsole -Color Cyan
		Invoke-TurboSubscriptionUpdate
	}
	ELSE {
		Write-BISFLog -Msg "Product $Product not installed"
	}
}

End {
	Add-BISFFinishLine
}