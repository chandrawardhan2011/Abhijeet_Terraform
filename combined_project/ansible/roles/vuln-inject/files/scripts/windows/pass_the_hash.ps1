# vuln: pass_the_hash
# Configures Windows to be vulnerable to Pass-the-Hash attacks by:
# - Enabling LM/NTLMv1 authentication
# - Disabling Protected Users group enforcement
# - Storing credentials in memory (WDigest)

Write-Host "[VULN] Injecting Pass-the-Hash vulnerability..."

# Enable WDigest (stores plaintext passwords in memory)
try {
    $path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest"
    if (!(Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    Set-ItemProperty -Path $path -Name "UseLogonCredential" -Value 1 -Type DWord
    Write-Host "[+] WDigest enabled - credentials stored in memory"
} catch { Write-Host "[!] WDigest: $($_.Exception.Message)" }

# Enable LM and NTLMv1 (weak authentication)
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" `
        -Name "LmCompatibilityLevel" -Value 1 -Type DWord
    Write-Host "[+] LMCompatibilityLevel set to 1 (NTLMv1 enabled)"
} catch { Write-Host "[!] NTLM: $($_.Exception.Message)" }

# Disable SMB signing (required for PTH over SMB)
try {
    Set-SmbServerConfiguration -RequireSecuritySignature $false -Force
    Set-SmbClientConfiguration -RequireSecuritySignature $false -Force
    Write-Host "[+] SMB signing disabled"
} catch { Write-Host "[!] SMB signing: $($_.Exception.Message)" }

# Disable Windows Credential Guard
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\LSA" `
        -Name "RunAsPPL" -Value 0 -Type DWord
    Write-Host "[+] LSA protection disabled"
} catch { Write-Host "[!] LSA: $($_.Exception.Message)" }

# Create a local admin for PTH testing
try {
    net user pth_victim Passw0rd! /add
    net localgroup Administrators pth_victim /add
    Write-Host "[+] Test account created: pth_victim / Passw0rd!"
} catch { Write-Host "[!] User: $($_.Exception.Message)" }

Write-Host "[VULN] Pass-the-Hash vulnerability injected."
Write-Host "[INFO] Use mimikatz or impacket's psexec.py to exploit PTH."
