# vuln: unconstrained_delegation | severity: critical
Write-Host "[VULN] Enabling Unconstrained Delegation..."
Import-Module ActiveDirectory -ErrorAction SilentlyContinue
# Create a service account with unconstrained delegation
try {
    $sec = ConvertTo-SecureString "Delegate@123" -AsPlainText -Force
    New-ADUser -Name "svc_delegate" -SamAccountName "svc_delegate" -AccountPassword $sec -Enabled $true -PasswordNeverExpires $true -ErrorAction SilentlyContinue
    # Enable unconstrained delegation
    Set-ADAccountControl -Identity "svc_delegate" -TrustedForDelegation $true
    Write-Host "[+] svc_delegate created with unconstrained delegation"
} catch { Write-Host "[!] $($_.Exception.Message)" }
Set-Content -Path "C:\Temp\delegation_info.txt" -Value "Unconstrained Delegation:`nAccount: svc_delegate / Delegate@123`nWhen any user authenticates to this service, their TGT is cached.`nAttack: Get-ADComputer -Filter {TrustedForDelegation -eq `$true} | Select Name"
Write-Host "[VULN] Unconstrained delegation enabled — TGT theft possible."
