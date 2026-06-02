# vuln: unauthenticated_user_enum | severity: low
Write-Host "[VULN] Enabling Unauthenticated User Enumeration..."
# Allow anonymous enumeration of accounts
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RestrictAnonymous /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RestrictAnonymousSAM /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v EveryoneIncludesAnonymous /t REG_DWORD /d 1 /f
# Allow null session
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v NullSessionPipes /t REG_MULTI_SZ /d "samr`0lsarpc`0netlogon" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v NullSessionShares /t REG_MULTI_SZ /d "IPC$" /f
Write-Host "[VULN] Anonymous enumeration enabled."
Write-Host "[INFO] Attack: enum4linux -a <IP> OR rpcclient -U '' <IP>"
