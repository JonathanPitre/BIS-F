<#
	.SYNOPSIS
		Configure Citrix VDA SSL during personalization (computer startup).
	.DESCRIPTION
		Applies Citrix VDA SSL listener settings from ADMX POL_VDASSL
		(LIC_BISF_CLI_VDASSL). Runs at computer startup on provisioned machines.
		Tested on Windows Server 2019.

		Certificate selection:
		- If a thumbprint is set (LIC_BISF_CLI_VDASSL_CertThumbprint) and that
		  certificate is not in the Local Machine store, the script fails.
		- If no thumbprint is set, the first valid Local Machine certificate whose
		  Subject Alternative Name matches the computer name is used. Wildcard
		  certificates are supported (case-insensitive).

		Auto-enrollment:
		- When certificate auto-enrollment is in use, timing gaps can occur. The
		  script waits until a valid certificate is installed or the timeout is reached.

		Skip certificate verification:
		- Expiration-date checks can be skipped when that validation is not required.

		Firewall:
		- Uses NetSecurity cmdlets (not netsh). Citrix-named rules are created only when
		  an equivalent inbound rule (display name, protocol, local port) does not exist.
		- Non-Citrix firewall rules on the SSL port are never removed.

		TLS minimum version:
		- Supports SSL 3.0 through TLS 1.3 per Citrix VDA registry values (TLS 1.3 = 5).
		- TLS 1.3 requires Windows 11 or Windows Server 2022 or later; older builds use TLS 1.2.
	.EXAMPLE
	.INPUTS
		None
	.OUTPUTS
		None
	.NOTES
		Author: Trentent Tye

		History:
		05.07.2019 TT: Script created
		16.08.2019 MS: ENH 107 - integrated into BIS-F
		05.06.2020 DS: HF 240 - SSL VDA certificate determination, auto-enrollment, skip verification
		16.06.2020 MS: HF 250 - VDA SSL wildcard support
		28.06.2020 MS: HF 253 - VDA SSL wildcard certificate matching is case-insensitive
		23.08.2026 JP: Normalize comment-based help (keywords, .LINK, move behavior into .DESCRIPTION)
		23.08.2026 JP: NetSecurity firewall cmdlets; skip existing Citrix-named rules; TLS 1.3 support
	.LINK
		https://github.com/EUCweb/BIS-F/issues/107
#>

Begin {
	$ScriptPath = $MyInvocation.MyCommand.Path
	$ScriptDir = Split-Path -Parent $ScriptPath
	$ScriptName = [System.IO.Path]::GetFileName($ScriptPath)
	if ($LIC_BISF_CLI_VDASSL -eq "YES") { $EnableMode = $true }
	if ($LIC_BISF_CLI_VDASSL -eq "NO") { $DisableMode = $true }
	[int]$SSLPort = $LIC_BISF_CLI_VDASSL_SSLPORT
	$SSLMinVersion = $LIC_BISF_CLI_VDASSL_MinVer
	$SSLCipherSuite = $LIC_BISF_CLI_VDASSL_CipherSuite
	if ($CertificateThumbPrint -ne "") { $CertificateThumbPrint = $LIC_BISF_CLI_VDASSL_CertThumbprint }
    $SkipCertVerification = $True
    $WaitForCertEnrollment = $True
    $CertEnrollmentTimeout = 180
}

Process {

	if (-not $EnableMode -and -not $DisableMode) {
		Write-BISFLog -Msg "VDA SSL Options not configured." -ShowConsole -Color Yellow
		Return
	}

	function Add-SslVdaFirewallRuleIfMissing {
		param(
			[string]$DisplayName,
			[ValidateSet('TCP', 'UDP')]$Protocol,
			[int]$LocalPort,
			[string]$Service
		)

		$Existing = Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue |
			Where-Object { $_.Direction -eq 'Inbound' }
		foreach ($Rule in $Existing) {
			$PortFilter = $Rule | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue
			if ($PortFilter.Protocol -eq $Protocol -and "$($PortFilter.LocalPort)" -eq "$LocalPort") {
				Write-BISFLog -Msg "Firewall rule already exists, skipping: $DisplayName ($Protocol/$LocalPort)" -ShowConsole -Color DarkCyan -SubMsg
				return
			}
		}

		New-NetFirewallRule -DisplayName $DisplayName -Direction Inbound -Action Allow -Profile Any `
			-Protocol $Protocol -LocalPort $LocalPort -Service $Service -Enabled True | Out-Null
		Write-BISFLog -Msg "Created firewall rule: $DisplayName ($Protocol/$LocalPort)" -ShowConsole -Color DarkCyan -SubMsg
	}

	function Remove-SslVdaFirewallRulesByDisplayName {
		param([string]$DisplayName)

		$Rules = Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue
		if (-not $Rules) {
			return
		}
		foreach ($Rule in $Rules) {
			Remove-NetFirewallRule -Name $Rule.Name -ErrorAction SilentlyContinue
			Write-BISFLog -Msg "Removed firewall rule: $DisplayName" -ShowConsole -Color DarkCyan -SubMsg
		}
	}

	function Disable-SslVdaFirewallRulesByDisplayName {
		param([string]$DisplayName)

		$Rules = Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue |
			Where-Object { $_.Direction -eq 'Inbound' -and $_.Enabled -eq 'True' }
		if (-not $Rules) {
			return
		}
		foreach ($Rule in $Rules) {
			Disable-NetFirewallRule -Name $Rule.Name -ErrorAction SilentlyContinue
			Write-BISFLog -Msg "Disabled firewall rule: $DisplayName" -ShowConsole -Color DarkCyan -SubMsg
		}
	}

	function Write-SslVdaFirewallRuleSummary {
		param([string[]]$DisplayNames)

		foreach ($Name in $DisplayNames) {
			$Rules = Get-NetFirewallRule -DisplayName $Name -ErrorAction SilentlyContinue
			if (-not $Rules) {
				Write-BISFLog -Msg "Firewall rule not found: $Name" -ShowConsole -Color DarkCyan -SubMsg
				continue
			}
			foreach ($Rule in $Rules) {
				$PortFilter = $Rule | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue
				$ServiceFilter = $Rule | Get-NetFirewallServiceFilter -ErrorAction SilentlyContinue
				$Protocol = if ($PortFilter) { $PortFilter.Protocol } else { 'Any' }
				$LocalPort = if ($PortFilter) { $PortFilter.LocalPort } else { '' }
				$Service = if ($ServiceFilter) { $ServiceFilter.Service } else { '' }
				Write-BISFLog -Msg "$($Rule.DisplayName): Enabled=$($Rule.Enabled) Direction=$($Rule.Direction) Action=$($Rule.Action) Protocol=$Protocol LocalPort=$LocalPort Service=$Service" -ShowConsole -Color DarkCyan -SubMsg
			}
		}
	}

	# Registry path constants
	$IcaListenerPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\Wds\icawd'
	$IcaCipherSuite = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\Diffie-Hellman'
	$DHEnabled = 'Enabled'
	$BackDHEnabled = 'Back_Enabled'
	$EnableSslKey = 'SSLEnabled'
	$SslCertHashKey = 'SSLThumbprint'
	$SslPortKey = 'SSLPort'
	$SslMinVersionKey = 'SSLMinVersion'
	$SslCipherSuiteKey = 'SSLCipherSuite'
	$PoliciesPath = 'HKLM:\SOFTWARE\Policies\Citrix\ICAPolicies'
	$IcaListenerPortKey = 'IcaListenerPortNumber'
	$SessionReliabilityPortKey = 'SessionReliabilityPort'
	$WebsocketPortKey = 'WebSocketPort'

	# Read ICA, CGP and HTML5 ports from the registry
	try {
		$IcaPort = (Get-ItemProperty -Path $PoliciesPath -Name $IcaListenerPortKey -ErrorAction SilentlyContinue).IcaListenerPortNumber
	}
	catch {
		$IcaPort = 1494
	}

	try {
		$CgpPort = (Get-ItemProperty -Path $PoliciesPath -Name $SessionReliabilityPortKey -ErrorAction SilentlyContinue).SessionReliabilityPort
	}
	catch {
		$CgpPort = 2598
	}

	try {
		$Html5Port = (Get-ItemProperty -Path $PoliciesPath -Name $WebsocketPortKey -ErrorAction SilentlyContinue).WebSocketPort
	}
	catch {
		$Html5Port = 8008
	}

	if (!$IcaPort) {
		$IcaPort = 1494
	}
	if (!$CgpPort) {
		$CgpPort = 2598
	}
	if (!$Html5Port) {
		$Html5Port = 8008
	}

	# Determine the name of the ICA Session Manager
	if (Get-Service | Where-Object { $_.Name -eq 'porticaservice' }) {
		$Username = 'NT SERVICE\PorticaService'
		$ServiceName = 'PortIcaService'
	}
	else {
		$Username = 'NT SERVICE\TermService'
		$ServiceName = 'TermService'
	}

	Write-BISFLog -Msg "Discovered the following:" -ShowConsole -Color DarkCyan -SubMsg
	Write-BISFLog -Msg "ICA Port     : $IcaPort" -ShowConsole -Color DarkCyan -SubMsg
	Write-BISFLog -Msg "CGP Port     : $CgpPort" -ShowConsole -Color DarkCyan -SubMsg
	Write-BISFLog -Msg "HTML5 Port   : $Html5Port" -ShowConsole -Color DarkCyan -SubMsg
	Write-BISFLog -Msg "Username     : $Username" -ShowConsole -Color DarkCyan -SubMsg
	Write-BISFLog -Msg "ServiceName  : $ServiceName" -ShowConsole -Color DarkCyan -SubMsg

	if ($DisableMode) {
		# Disable Mode.  GPO was set to Disabled.
		# Replace Diffie-Hellman Enabled value to its original value
		Write-BISFLog -Msg "Disable SSL for the Citrix VDA." -ShowConsole -Color Yellow
		if (Test-Path $IcaCipherSuite) {
			$BackEnabledExists = Get-ItemProperty -Path $IcaCipherSuite -Name $BackDHEnabled -ErrorAction SilentlyContinue
			if ($null -ne $BackEnabledExists) {
				Set-ItemProperty -Path $IcaCipherSuite -Name $DHEnabled -Value $BackEnabledExists.Back_Enabled
				Remove-ItemProperty -Path $IcaCipherSuite -Name $BackDHEnabled
			}
		}

		try {
			Write-BISFLog -Msg "Resetting Firewall rules." -ShowConsole -Color DarkCyan -SubMsg
			Add-SslVdaFirewallRuleIfMissing -DisplayName 'Citrix ICA Service' -Protocol TCP -LocalPort $IcaPort -Service $ServiceName
			Add-SslVdaFirewallRuleIfMissing -DisplayName 'Citrix CGP Server Service' -Protocol TCP -LocalPort $CgpPort -Service $ServiceName
			Add-SslVdaFirewallRuleIfMissing -DisplayName 'Citrix Websocket Service' -Protocol TCP -LocalPort $Html5Port -Service $ServiceName
			Add-SslVdaFirewallRuleIfMissing -DisplayName 'Citrix ICA UDP' -Protocol UDP -LocalPort $IcaPort -Service $ServiceName
			Add-SslVdaFirewallRuleIfMissing -DisplayName 'Citrix CGP UDP' -Protocol UDP -LocalPort $CgpPort -Service $ServiceName
			Remove-SslVdaFirewallRulesByDisplayName -DisplayName 'Citrix SSL Service'
			Remove-SslVdaFirewallRulesByDisplayName -DisplayName 'Citrix DTLS Service'
		}
		catch {
			Write-BISFLog -Msg "Firewall reset failed: $($_.Exception.Message)" -Type W -ShowConsole -Color Yellow
		}

		#Turning off SSL by setting SSLEnabled key to 0
		Write-BISFLog -Msg "Disabling ICA SSL." -ShowConsole -Color DarkCyan -SubMsg
		Set-ItemProperty -Path $IcaListenerPath -name $EnableSslKey -Value 0 -Type DWord -Confirm:$false

		Write-BISFLog -Msg "SSL for VDA has been disabled." -ShowConsole -Color DarkCyan -SubMsg
	}

	if ($EnableMode) {
		#Enable Mode.  GPO was set to Enabled.
		Write-BISFLog -Msg "Enable SSL for the Citrix VDA." -ShowConsole -Color Yellow
		$RegistryKeysSet = $ACLsSet = $FirewallConfigured = $False

		#Certificates MUST be in the Local Machine > Personal store
		$Store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My", "LocalMachine")
		$Store.Open("ReadOnly")

        #Check if certificate thumbprint has been specified and select the corresponding certificate from Local Machine Certificate Store.
        if ($CertificateThumbPrint) {
	        $Cert = $Store.Certificates | Where-Object { $_.GetCertHashString() -eq $CertificateThumbPrint }
		    if (!$Cert) {
		        Write-BISFLog -Msg "No certificate found in the certificate store with thumbprint $CertificateThumbPrint."  -ShowConsole -Color DarkCyan -SubMsg
		        Write-BISFLog -Msg "Enabling SSL to VDA failed."  -ShowConsole -Color DarkCyan -SubMsg
		        $Store.Close()
		        break
		    }
        }

        # If no certificate thumbprint has been specified, check for any valid certificate within Local Machine Certificate Store (Subject Alternative Name > Computername).
        else{
            $Cert = $Store.Certificates | Where-Object { $_.DnsNameList.Unicode -like "$($env:COMPUTERNAME)*" } | Sort-Object NotAfter -Descending | Select-Object -First 1
			if (!$Cert){
				$Cert = $Store.Certificates | Where-Object { ($_.DnsNameList.Unicode -like ("*." + "$([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name)"))} | Sort-Object NotAfter -Descending | Select-Object -First 1
			}
			$CertificateThumbPrint = $Cert.GetCertHashString()

            # If no valid certificate has been found, check for auto enrollment variable
            # If auto enrollment variable is true, wait for certificate auto enrollment from Enterprise-CA (Duration is specified by CertEnrollmentTimeout value.)
            if ((!($Cert)) -and ($WaitForCertEnrollment -eq $True)) {
                Write-BISFLog -Msg "Waiting for certificate auto-enrollment ..." -ShowConsole -Color DarkCyan -SubMsg
                For ($i=0;(!($Cert)) -and ($i -le $CertEnrollmentTimeout);$i++)
                {
                    Start-Sleep -Seconds 1
                    foreach ($Certificate in $Store.Certificates) {
			            if ($Certificate.DnsNameList.Unicode -like "$($env:COMPUTERNAME)*") {
			                $CertificateThumbPrint = $Certificate.GetCertHashString()
			                $Cert = $Certificate
                        }
                    }
	            }
                if (!$Cert) {
                        Write-BISFLog -Msg "Timeout limit of $CertEnrollmentTimeout seconds has been reached." -ShowConsole -Color DarkCyan -SubMsg
		                Write-BISFLog -Msg "No valid certificate found in Local Machine Certificate Store. Please verify your enrollment and try again." -ShowConsole -Color DarkCyan -SubMsg
			            Write-BISFLog -Msg "Enabling SSL to VDA failed." -ShowConsole -Color DarkCyan -SubMsg
		                $Store.Close()
		                break
		        }
            }
            # If auto enrollment variable is false, script does instantly fail if no valid certificate is found.
            elseif((!($Cert)) -and ($WaitForCertEnrollment -ne $True)){
                    Write-BISFLog -Msg "No valid certificate found in Local Machine Certificate Store. Please install a valid certificate and try again." -ShowConsole -Color DarkCyan -SubMsg
			        Write-BISFLog -Msg "Enabling SSL to VDA failed." -ShowConsole -Color DarkCyan -SubMsg
		            $Store.Close()
		            break
            }
        }

        Write-BISFLog -Msg "Valid certificate found in Local Machine Certificate Store."  -ShowConsole -Color DarkCyan -SubMsg
		Write-BISFLog -Msg "Certificate:" -ShowConsole -Color Cyan
		foreach ($Line in $($Cert.DnsNameList)) { if ($Line) { Write-BISFLog -Msg "DNSNameList  : $Line" -ShowConsole -Color Yellow -SubMsg } }
		foreach ($Line in $($Cert | Format-List | Out-String -Stream)) { if ($Line) { Write-BISFLog -Msg "$Line" -ShowConsole -Color Yellow -SubMsg } }



        #Verify certificate
        If($SkipCertVerification -eq $True){
            Write-BISFLog -Msg "Skipping certificate expiration date validation." -ShowConsole -Color DarkCyan -SubMsg
        }
        else
        {
		    $ValidTo = [DateTime]::Parse($Cert.GetExpirationDateString())
		    if($ValidTo -lt [DateTime]::UtcNow) {
			    Write-BISFLog -Msg "Certificate has expired. Please install a valid certificate and try again." -ShowConsole -Color DarkCyan -SubMsg
			    Write-BISFLog -Msg "Enabling SSL to VDA failed." -ShowConsole -Color DarkCyan -SubMsg
			    $Store.Close()
			    break
		    }
        }

		#Check private key availability
		try {
			[System.Security.Cryptography.AsymmetricAlgorithm] $PrivateKey = $Cert.PrivateKey
			$UniqueContainer = ((($Cert).PrivateKey).CspKeyContainerInfo).UniqueKeyContainerName
		}
		catch {
			Write-BISFLog -Msg "Unable to access the Private Key of the Certificate or one of its fields." -ShowConsole -Color DarkCyan -SubMsg
			Write-BISFLog -Msg "Enabling SSL to VDA failed." -ShowConsole -Color DarkCyan -SubMsg
			$Store.Close()
			break
		}

		if(!$PrivateKey -or !$UniqueContainer) {
			Write-BISFLog -Msg "Unable to access the Private Key of the Certificate or one of its fields." -ShowConsole -Color DarkCyan -SubMsg
			Write-BISFLog -Msg "Enabling SSL to VDA failed." -ShowConsole -Color DarkCyan -SubMsg
			$Store.Close()
			break
		}

		Write-BISFLog -Msg "Setting ACL's on private key file" -ShowConsole -Color Cyan
		$PrivateKey = ((($Cert).PrivateKey).CspKeyContainerInfo).UniqueKeyContainerName
		$Dir = $env:ProgramData + '\Microsoft\Crypto\RSA\MachineKeys\'
		$KeyPath = $Dir + $PrivateKey
		icacls $KeyPath /grant `"$Username`"`:RX | Out-Null
		$Acls = icacls $KeyPath
		foreach ($Line in $Acls) { if ($Line) { Write-BISFLog -Msg "$Line" -ShowConsole -Color DarkCyan -SubMsg } }


		Write-BISFLog -Msg "ACLs set." -ShowConsole -Color DarkCyan -SubMsg
		$ACLsSet = $True

		try {
			Add-SslVdaFirewallRuleIfMissing -DisplayName 'Citrix SSL Service' -Protocol TCP -LocalPort $SSLPort -Service $ServiceName
			Add-SslVdaFirewallRuleIfMissing -DisplayName 'Citrix DTLS Service' -Protocol UDP -LocalPort $SSLPort -Service $ServiceName
			Disable-SslVdaFirewallRulesByDisplayName -DisplayName 'Citrix ICA Service'
			Disable-SslVdaFirewallRulesByDisplayName -DisplayName 'Citrix CGP Server Service'
			Disable-SslVdaFirewallRulesByDisplayName -DisplayName 'Citrix Websocket Service'
			Disable-SslVdaFirewallRulesByDisplayName -DisplayName 'Citrix ICA UDP'
			Disable-SslVdaFirewallRulesByDisplayName -DisplayName 'Citrix CGP UDP'

			Write-BISFLog -Msg "Firewall rules:" -ShowConsole -Color Cyan
			Write-SslVdaFirewallRuleSummary -DisplayNames @(
				'Citrix SSL Service',
				'Citrix DTLS Service',
				'Citrix ICA Service',
				'Citrix CGP Server Service',
				'Citrix Websocket Service',
				'Citrix ICA UDP',
				'Citrix CGP UDP'
			)
			Write-BISFLog -Msg "Firewall configured." -ShowConsole -Color DarkCyan -SubMsg
			$FirewallConfigured = $True
		}
		catch {
			Write-BISFLog -Msg "Firewall configuration failed: $($_.Exception.Message)" -Type W -ShowConsole -Color Yellow
		}

		# Create registry keys to enable SSL to the VDA
		Write-BISFLog -Msg "Setting registry keys..."  -ShowConsole -Color Cyan
		Set-ItemProperty -Path $IcaListenerPath -name $SslCertHashKey -Value $Cert.GetCertHash() -Type Binary -Confirm:$False
		$SslMinVersionValue = $null
		switch ($SSLMinVersion) {
			"SSL_3.0" { $SslMinVersionValue = 1 }
			"TLS_1.0" { $SslMinVersionValue = 2 }
			"TLS_1.1" { $SslMinVersionValue = 3 }
			"TLS_1.2" { $SslMinVersionValue = 4 }
			"TLS_1.3" { $SslMinVersionValue = 5 }
		}

		if ($SslMinVersionValue -eq 5) {
			$OsBuild = [int](Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuildNumber).CurrentBuildNumber
			if ($OsBuild -lt 20348) {
				Write-BISFLog -Msg "TLS 1.3 requires Windows 11 or Windows Server 2022 or later. Using TLS 1.2." -Type W -ShowConsole -Color Yellow
				$SslMinVersionValue = 4
			}
		}

		if ($null -ne $SslMinVersionValue) {
			Set-ItemProperty -Path $IcaListenerPath -Name $SslMinVersionKey -Value $SslMinVersionValue -Type DWord -Confirm:$False
		}

		switch($SSLCipherSuite) {
			"GOV" {
				Set-ItemProperty -Path $IcaListenerPath -name $SslCipherSuiteKey -Value 1 -Type DWord -Confirm:$False
			}
			"COM" {
				Set-ItemProperty -Path $IcaListenerPath -name $SslCipherSuiteKey -Value 2 -Type DWord -Confirm:$False
			}
			"ALL" {
				Set-ItemProperty -Path $IcaListenerPath -name $SslCipherSuiteKey -Value 3 -Type DWord -Confirm:$False
			}
		}

		Set-ItemProperty -Path $IcaListenerPath -name $SslPortKey -Value $SSLPort -Type DWord -Confirm:$False

		#Backup DH Cipher Suite and set Enabled:0 if SSL is enabled
		if (!(Test-Path $IcaCipherSuite)) {
			New-Item -Path $IcaCipherSuite -Force | Out-Null
			New-ItemProperty -Path $IcaCipherSuite -Name $DHEnabled -Value 0 -PropertyType DWORD -Force | Out-Null
			New-ItemProperty -Path $IcaCipherSuite -Name $BackDHEnabled -Value 1 -PropertyType DWORD -Force | Out-Null
		}
		else {
			$BackEnabledExists = Get-ItemProperty -Path $IcaCipherSuite -Name $BackDHEnabled -ErrorAction SilentlyContinue
			if ($null -eq $BackEnabledExists) {
				$Exists = Get-ItemProperty -Path $IcaCipherSuite -Name $DHEnabled -ErrorAction SilentlyContinue
				if ($null -ne $Exists) {
					New-ItemProperty -Path $IcaCipherSuite -Name $BackDHEnabled -Value $Exists.Enabled -PropertyType DWORD -Force | Out-Null
					Set-ItemProperty -Path $IcaCipherSuite -Name $DHEnabled -Value 0
				}
				else {
					New-ItemProperty -Path $IcaCipherSuite -Name $DHEnabled -Value 0 -PropertyType DWORD -Force | Out-Null
					New-ItemProperty -Path $IcaCipherSuite -Name $BackDHEnabled -Value 1 -PropertyType DWORD -Force | Out-Null
				}
			}
		}

		# NOTE: This must be the last thing done when enabling SSL as the Citrix Service
		#       will use this as a signal to try and start the Citrix SSL Listener!!!!
		Set-ItemProperty -Path $IcaListenerPath -name $EnableSslKey -Value 1 -Type DWord -Confirm:$False

		Write-BISFLog -Msg "Registry Key Values:" -ShowConsole -Color Cyan
		Write-BISFLog -Msg "$IcaListenerPath\$EnableSslKey : $($(Get-ItemProperty -Path $IcaListenerPath).$EnableSslKey)" -ShowConsole -Color DarkCyan -SubMsg
		Write-BISFLog -Msg "$IcaListenerPath\$SslCertHashKey : $($(Get-ItemProperty -Path $IcaListenerPath).$SslCertHashKey)" -ShowConsole -Color DarkCyan -SubMsg
		Write-BISFLog -Msg "$IcaListenerPath\$SslMinVersionKey : $($(Get-ItemProperty -Path $IcaListenerPath).$SslMinVersionKey)" -ShowConsole -Color DarkCyan -SubMsg
		Write-BISFLog -Msg "$IcaListenerPath\$SslCipherSuiteKey : $($(Get-ItemProperty -Path $IcaListenerPath).$SslCipherSuiteKey)" -ShowConsole -Color DarkCyan -SubMsg
		Write-BISFLog -Msg "$IcaListenerPath\$SslPortKey : $($(Get-ItemProperty -Path $IcaListenerPath).$SslPortKey)" -ShowConsole -Color DarkCyan -SubMsg

		Write-BISFLog -Msg "Registry keys set." -ShowConsole -Color DarkCyan -SubMsg
		$RegistryKeysSet = $True

		$Store.Close()

		if ($RegistryKeysSet -and $ACLsSet -and $FirewallConfigured) {
			Write-BISFLog -Msg "SSL for VDA enabled." -ShowConsole -Color DarkCyan -SubMsg
		}
		else {
			if (!$RegistryKeysSet) {
				Write-BISFLog -Msg "Configure registry manually or re-run the script to complete enabling SSL for VDA." -ShowConsole -Color DarkCyan -SubMsg
			}

			if (!$ACLsSet) {
				Write-BISFLog -Msg "Configure ACLs manually or re-run the script to complete enabling SSL for VDA." -ShowConsole -Color DarkCyan -SubMsg
			}

			if (!$FirewallConfigured) {
				Write-BISFLog -Msg "Configure firewall manually or re-run the script to complete enabling SSL for VDA." -ShowConsole -Color DarkCyan -SubMsg
			}
		}
	}
}


End {
	Add-BISFFinishLine
}
