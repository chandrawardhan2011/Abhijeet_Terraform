# vuln: password_spray_target | severity: medium
Write-Host "[VULN] Injecting Password Spray Target..."
Import-Module ActiveDirectory -ErrorAction SilentlyContinue
# Create many users with same weak password pattern
$users = @("emp001","emp002","emp003","emp004","emp005","emp006","emp007","emp008","emp009","emp010")
foreach ($u in $users) {
    try {
        $sec = ConvertTo-SecureString "Welcome1!" -AsPlainText -Force
        New-ADUser -Name $u -SamAccountName $u -AccountPassword $sec -Enabled $true -PasswordNeverExpires $true -ErrorAction SilentlyContinue
        Write-Host "[+] Created: $u / Welcome1!"
    } catch { Write-Host "[!] $u : $($_.Exception.Message)" }
}
# Disable account lockout — key for spray attacks
$maxAttempts = (Get-ADDefaultDomainPasswordPolicy).LockoutThreshold
Set-ADDefaultDomainPasswordPolicy -Identity (Get-ADDomain).DistinguishedName -LockoutThreshold 0 -LockoutDuration "00:00:00" -ErrorAction SilentlyContinue
Write-Host "[VULN] 10 users with 'Welcome1!' password, lockout disabled."
Write-Host "[INFO] Spray: crackmapexec smb <IP> -u users.txt -p 'Welcome1!' --continue-on-success"
