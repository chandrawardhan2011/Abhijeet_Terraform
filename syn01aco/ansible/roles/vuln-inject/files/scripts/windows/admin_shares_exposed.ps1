# vuln: admin_shares_exposed | label: AD14 | severity: medium
Write-Host "[VULN] Injecting Administrative Shares Exposed (AD14)..."

# Ensure admin shares are enabled (they may be disabled by policy)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v AutoShareServer /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v AutoShareWks /t REG_DWORD /d 1 /f

# Restart Server service to apply
Restart-Service LanmanServer -Force -ErrorAction SilentlyContinue

# Create additional exposed share
New-SmbShare -Name "NETLOGON_BACKUP" -Path "C:\Windows\SYSVOL" -FullAccess "Everyone" -ErrorAction SilentlyContinue
New-SmbShare -Name "DATA" -Path "C:\Users\Administrator\Documents" -FullAccess "Authenticated Users" -ErrorAction SilentlyContinue

# Disable share-level access control
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v NullSessionShares /t REG_MULTI_SZ /d "IPC$\0ADMIN$\0C$" /f

Set-Content -Path "C:\Temp\ad14_info.txt" -Value "AD14: Administrative Shares Exposed.`nActive shares:`n  ADMIN$ -> C:\Windows`n  C$ -> C:\`n  NETLOGON_BACKUP -> C:\Windows\SYSVOL`n  DATA -> C:\Users\Administrator\Documents`nAttack: net use \\<DC_IP>\C$ /user:Administrator Admin@123`nAttack: psexec \\<DC_IP> -u Administrator -p Admin@123 cmd"
Write-Host "[VULN] AD14: Admin shares exposed."
Write-Host "[INFO] Shares: ADMIN$, C$, NETLOGON_BACKUP, DATA"
Write-Host "[INFO] Attack: net use \\10.0.20.101\C$ /user:Administrator Admin@123"
