# vuln: weak_group_policy | severity: medium
Write-Host "[VULN] Weakening Group Policy settings..."
Import-Module GroupPolicy -ErrorAction SilentlyContinue
# Disable password complexity via Default Domain Policy
try {
    Set-ADDefaultDomainPasswordPolicy `
        -Identity (Get-ADDomain).DistinguishedName `
        -ComplexityEnabled $false `
        -MinPasswordLength 0 `
        -PasswordHistoryCount 0 `
        -MaxPasswordAge (New-TimeSpan -Days 0) `
        -ErrorAction SilentlyContinue
    Write-Host "[+] Password policy weakened — no complexity, no expiry"
} catch { Write-Host "[!] $($_.Exception.Message)" }
# Allow WinRM from all hosts
Enable-PSRemoting -Force -ErrorAction SilentlyContinue
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force -ErrorAction SilentlyContinue
Write-Host "[VULN] GPO weakened — no password policy, WinRM open to all."
