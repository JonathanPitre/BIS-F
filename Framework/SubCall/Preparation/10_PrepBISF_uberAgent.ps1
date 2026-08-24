<#
	.SYNOPSIS
		Prepare uberAgent for Image Management
	.DESCRIPTION
	  	Delete computer specific entries
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
		26.04.2016 MZ: Script created
		09.01.2017 MS: Implemented in BIS-F, thx to Marco Zimmermann (MZ)
		12.01.2017 MS: Added IF (Test-Path $reg_Product_Key) before continue
		18.01.2017 JP: Fixed typo in product variable
		28.01.2017 MS: typo in $PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)
		03.10.2019 MS: HF 138 - didn't change the startup type to automatic

#>

Begin {
	$PSScriptFullName = $MyInvocation.MyCommand.Path
	$PSScriptRoot = Split-Path -Parent $PSScriptFullName
	$PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)

	$Product = "uberAgent"
	$ServiceName = "uberAgentSvc"
	$RegProductKey = "$HklmSoftware\vast limits\uberAgent"
}

Process {

	$Svc = Test-BISFService -ServiceName $ServiceName -ProductName $Product
	IF ($Svc) {
		Invoke-BISFService -ServiceName $ServiceName -Action Stop #-StartType automatic # -> HF 138 comment out
		Write-BISFLog -Msg Clear $Product config
		IF (Test-Path $RegProductKey) {
			& Remove-Item '$reg_Product_Key' -Recurse -Force
			Write-BISFLog -Msg "Clean $Product registry $RegProductKey deleted"
		}
	}
}

End {
	Add-BISFFinishLine
}