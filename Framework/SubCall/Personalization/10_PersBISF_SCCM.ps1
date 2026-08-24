<#
    .SYNOPSIS
        Personalize SCCM Client for Image Management Software
	.Description
      	
    .EXAMPLE
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH
		
		History
      	Last Change: 26.03.2014 MS: Script created for SCCM 2012 R2
		Last Change: 14.05.2014 MS: BUG code-error certstore SMS not deleted > & Invoke-Expression 'certutil -delstore SMS "SMS"'
		Last Change: 11.08.2014 MS: remove Write-Host change to Write-Log
		Last Change: 13.08.2014 MS: remove $LogFile = Set-LogFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
		Last Change: 19.02.2015 MS: error handling
		Last Change: 01.10.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
	.Link
#>

Begin {
	$CcmPath = "C:\Windows\CCM"
	$PSScriptFullName = $MyInvocation.MyCommand.Path
	$PSScriptRoot = Split-Path -Parent $PSScriptFullName
	$PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)
	$Product = "Microsoft SCCM Agent"
	$ServiceName = "CcmExec"
}

Process 
{
    function deleteCCMData
    {
		# remove existing certificates from SMS store
        & Invoke-Expression 'certutil -delstore SMS "SMS"'
		
		# reset site key information
		& Invoke-Expression "WMIC /NAMESPACE:\\root\ccm\locationservices Path TrustedRootKey DELETE"
		
		#Delete Smscfg.ini
		Remove-Item -Path ${env:WinDir}'\SMSCFG.ini' -Force -ErrorAction SilentlyContinue 
	}


####################################################################
####### end functions #####
####################################################################

#### Main Program

	$Svc = Test-BISFService -ServiceName "$ServiceName" -ProductName "$Product"
	IF ($Svc -eq $true)
	{
		deleteCCMdata
		Invoke-BISFService -ServiceName "$ServiceName" -Action Start
	}
}

End {
	Add-BISFFinishLine
}


