# vuln: rdp_brute_force | severity: high
Write-Host "[VULN] Injecting RDP Brute Force vulnerability..."
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v UserAuthentication /t REG_DWORD /d 0 /f
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
net localgroup "Remote Desktop Users" "Everyone" /add 2>$null
$policy = [adsi]"WinNT://./Account"
$policy.MaxBadPasswordsAllowed = 0
$policy.SetInfo()
Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
Write-Host "[VULN] RDP enabled with no lockout policy, NLA disabled."
