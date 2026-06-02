# vuln: kerberoasting_client | severity: critical
Write-Host "[VULN] Injecting Kerberoastable SPN on Windows Client..."
Import-Module ActiveDirectory -ErrorAction SilentlyContinue
try {
    $sec = ConvertTo-SecureString "ClientSvc@123" -AsPlainText -Force
    New-ADUser -Name "svc_webclient" -SamAccountName "svc_webclient" -AccountPassword $sec -Enabled $true -PasswordNeverExpires $true -ErrorAction SilentlyContinue
    setspn -S "HTTP/windows-1.cyberstrike.mil" "svc_webclient" 2>$null
    Set-ADUser "svc_webclient" -KerberosEncryptionType RC4 -ErrorAction SilentlyContinue
    Write-Host "[+] SPN registered: HTTP/windows-1.cyberstrike.mil -> svc_webclient / ClientSvc@123"
} catch { Write-Host "[!] $($_.Exception.Message)" }
Write-Host "[VULN] Kerberoastable SPN injected on client."
Write-Host "[INFO] Attack: GetUserSPNs.py cyberstrike.mil/user:pass -outputfile hashes.txt"
