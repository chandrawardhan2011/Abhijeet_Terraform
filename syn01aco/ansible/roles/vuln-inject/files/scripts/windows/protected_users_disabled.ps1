# vuln: protected_users_disabled | label: AD13 | severity: high
Write-Host "[VULN] Injecting Protected Users Not Enforced (AD13)..."
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

# Remove high-value accounts from Protected Users group if present
$protectedGroup = Get-ADGroup "Protected Users" -ErrorAction SilentlyContinue
if ($protectedGroup) {
    $members = Get-ADGroupMember "Protected Users" -ErrorAction SilentlyContinue
    foreach ($m in $members) {
        Remove-ADGroupMember -Identity "Protected Users" -Members $m -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "[+] Removed $($m.SamAccountName) from Protected Users"
    }
}

# Ensure Administrator and krbtgt are NOT in Protected Users
foreach ($acct in @("Administrator","krbtgt")) {
    try {
        Remove-ADGroupMember -Identity "Protected Users" -Members $acct -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "[+] Ensured $acct not in Protected Users"
    } catch {}
}

# Disable Kerberos armoring (Flexible Authentication Secure Tunneling) via GPO
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Kerberos\Parameters" /v SupportedEncryptionTypes /t REG_DWORD /d 28 /f 2>$null

Set-Content -Path "C:\Temp\ad13_info.txt" -Value "AD13: Protected Users group is empty.`nHigh-value accounts (Administrator, krbtgt) are not protected.`nPass-the-Hash and Pass-the-Ticket attacks work against all accounts.`nKerberos armoring disabled."
Write-Host "[VULN] AD13: Protected Users not enforced."
Write-Host "[INFO] All domain accounts vulnerable to credential theft attacks."
Write-Host "[INFO] No account is protected from pass-the-hash or Overpass-the-Hash."
