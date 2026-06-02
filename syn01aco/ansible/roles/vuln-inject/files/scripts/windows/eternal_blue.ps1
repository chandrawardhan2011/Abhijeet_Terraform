# vuln: eternal_blue | severity: critical
Write-Host "[VULN] Injecting EternalBlue vulnerability..."
Set-SmbServerConfiguration -EnableSMB1Protocol $true -Force
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
New-SmbShare -Name "ADMIN_SHARE" -Path "C:\Windows" -FullAccess "Everyone" -ErrorAction SilentlyContinue
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v SMB1 /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LmCompatibilityLevel /t REG_DWORD /d 0 /f
Write-Host "[VULN] SMBv1 enabled, firewall disabled, shares created."
