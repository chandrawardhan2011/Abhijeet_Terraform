# vuln: rdp_brute_force
# Enables RDP with no account lockout and weak credentials

Write-Host "[VULN] Injecting RDP Brute Force vulnerability..."

# Enable Remote Desktop
try {
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' `
        -Name "fDenyTSConnections" -Value 0
    Write-Host "[+] RDP enabled"
} catch { Write-Host "[!] RDP enable: $($_.Exception.Message)" }

# Disable NLA (Network Level Authentication) - makes brute force easier
try {
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' `
        -Name "UserAuthentication" -Value 0
    Write-Host "[+] NLA disabled"
} catch { Write-Host "[!] NLA: $($_.Exception.Message)" }

# Allow RDP through firewall
netsh advfirewall firewall add rule name="VULN_RDP" protocol=TCP dir=in localport=3389 action=allow

# Disable account lockout policy
net accounts /lockoutthreshold:0

# Create weak user accounts
try {
    net user hacker Password1 /add
    net localgroup Administrators hacker /add
    net user guest /active:yes
    net user guest password123
    Write-Host "[+] Weak accounts created: hacker/Password1, guest/password123"
} catch { Write-Host "[!] User creation: $($_.Exception.Message)" }

# Set weak password for Administrator
try {
    net user Administrator Admin@123
    Write-Host "[+] Administrator password set to Admin@123"
} catch { Write-Host "[!] Admin password: $($_.Exception.Message)" }

Write-Host "[VULN] RDP Brute Force vulnerability injected."
Write-Host "[INFO] RDP on port 3389, no lockout policy, weak creds: hacker/Password1"
