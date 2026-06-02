# vuln: domain_replication_exposed | severity: critical  
# NOTE: This is the dcsync vuln — already covered in dcsync.ps1
# This script focuses on exposing AD replication to non-DC machines
Write-Host "[VULN] Exposing Domain Replication..."
Import-Module ActiveDirectory -ErrorAction SilentlyContinue
try {
    $domain = Get-ADDomain
    $domainDN = $domain.DistinguishedName
    $userObj = Get-ADUser -Identity "repl_svc" -ErrorAction SilentlyContinue
    if (-not $userObj) {
        $sec = ConvertTo-SecureString "Repl@2024!" -AsPlainText -Force
        New-ADUser -Name "repl_svc2" -SamAccountName "repl_svc2" -AccountPassword $sec -Enabled $true -PasswordNeverExpires $true -ErrorAction SilentlyContinue
        Write-Host "[+] Created repl_svc2 / Repl@2024!"
    }
    Write-Host "[VULN] Replication account ready for DCSync attack."
} catch { Write-Host "[!] $($_.Exception.Message)" }
