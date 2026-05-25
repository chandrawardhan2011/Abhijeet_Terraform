# vuln: eternal_blue
# Simulates CVE-2017-0144 EternalBlue by:
# - Enabling SMBv1
# - Disabling Windows Firewall for SMB
# - Creating weak network shares
# - Disabling automatic updates

Write-Host "[VULN] Injecting EternalBlue (CVE-2017-0144) simulation..."

# Enable SMBv1 (the vulnerable protocol)
try {
    Set-SmbServerConfiguration -EnableSMB1Protocol $true -Force
    Write-Host "[+] SMBv1 enabled"
} catch {
    Write-Host "[!] SMBv1 config: $($_.Exception.Message)"
}

# Disable Windows Defender / Firewall for SMB ports
try {
    netsh advfirewall firewall add rule name="VULN_SMB_445" protocol=TCP dir=in localport=445 action=allow
    netsh advfirewall firewall add rule name="VULN_SMB_139" protocol=TCP dir=in localport=139 action=allow
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
    Write-Host "[+] Firewall disabled for SMB"
} catch {
    Write-Host "[!] Firewall: $($_.Exception.Message)"
}

# Create a world-readable SMB share with sensitive data
try {
    New-Item -ItemType Directory -Path "C:\SharedData" -Force | Out-Null
    Set-Content -Path "C:\SharedData\passwords.txt" -Value @"
=== SENSITIVE CREDENTIALS ===
Domain Admin: Administrator / Admin@123
Service Account: svc_backup / Backup2024!
Database: db_admin / DbPass123
"@
    net share SharedData=C:\SharedData /grant:Everyone,FULL 2>$null
    Write-Host "[+] Vulnerable SMB share 'SharedData' created"
} catch {
    Write-Host "[!] Share creation: $($_.Exception.Message)"
}

# Disable automatic updates
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
        -Name "NoAutoUpdate" -Value 1 -Type DWord -Force
    Stop-Service -Name wuauserv -Force
    Set-Service -Name wuauserv -StartupType Disabled
    Write-Host "[+] Auto-updates disabled"
} catch {
    Write-Host "[!] Updates: $($_.Exception.Message)"
}

Write-Host "[VULN] EternalBlue simulation complete."
Write-Host "[INFO] SMBv1 enabled, firewall disabled, weak share at \\<IP>\SharedData"
