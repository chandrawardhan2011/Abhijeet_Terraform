# =============================================================================
# CyberRange SYN-01 — ADDC Master Patch Script
# Restores windows-addc (cyberstrike.mil) to clean initial state
# Run as Administrator on ADDC only
# =============================================================================

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  CyberRange ADDC — Master Patch Script" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

Import-Module ActiveDirectory -ErrorAction Stop
Import-Module GroupPolicy -ErrorAction SilentlyContinue

$errors = 0

# ── 1. PATCH — AS-REP Roasting ────────────────────────────────────────────────
Write-Host "`n[1/12] Patching AS-REP Roasting..." -ForegroundColor Yellow

foreach ($u in @("j.morrison", "t.williams", "noauth_svc")) {
    try {
        if (Get-ADUser -Filter {SamAccountName -eq $u} -ErrorAction SilentlyContinue) {
            Set-ADAccountControl -Identity $u -DoesNotRequirePreAuth $false
            Set-ADUser -Identity $u -KerberosEncryptionType AES256
            Write-Host "[+] Pre-auth re-enabled, AES256 enforced: $u" -ForegroundColor Green
        }
    } catch { Write-Host "[!] $u : $($_.Exception.Message)" -ForegroundColor Red; $errors++ }
}
# Re-enable pre-auth on Administrator
try {
    Set-ADAccountControl -Identity "Administrator" -DoesNotRequirePreAuth $false
    Write-Host "[+] Pre-auth re-enabled: Administrator" -ForegroundColor Green
} catch { Write-Host "[!] Administrator: $($_.Exception.Message)" -ForegroundColor Red; $errors++ }

Remove-Item "C:\Temp\asrep_targets.txt" -Force -ErrorAction SilentlyContinue

# ── 2. PATCH — DCSync ─────────────────────────────────────────────────────────
Write-Host "`n[2/12] Patching DCSync..." -ForegroundColor Yellow

try {
    $replSvc = Get-ADUser -Identity "repl_svc" -ErrorAction SilentlyContinue
    if ($replSvc) {
        $sid  = New-Object System.Security.Principal.SecurityIdentifier($replSvc.SID)
        $acl  = Get-Acl "AD:\DC=cyberstrike,DC=mil"
        $aces = $acl.Access | Where-Object { $_.IdentityReference -like "*repl_svc*" }
        foreach ($ace in $aces) { $acl.RemoveAccessRule($ace) | Out-Null }
        Set-Acl -Path "AD:\DC=cyberstrike,DC=mil" -AclObject $acl
        Write-Host "[+] DCSync rights removed from repl_svc" -ForegroundColor Green
        Disable-ADAccount -Identity "repl_svc"
        Write-Host "[+] repl_svc disabled" -ForegroundColor Green
    }
} catch { Write-Host "[!] DCSync patch: $($_.Exception.Message)" -ForegroundColor Red; $errors++ }

# Re-enable directory service auditing
auditpol /set /subcategory:"Directory Service Access" /success:enable /failure:enable 2>$null
auditpol /set /subcategory:"Directory Service Changes" /success:enable /failure:enable 2>$null
Write-Host "[+] Directory service auditing re-enabled" -ForegroundColor Green
Remove-Item "C:\Temp\dcsync_info.txt" -Force -ErrorAction SilentlyContinue

# ── 3. PATCH — Domain User Enumeration ───────────────────────────────────────
Write-Host "`n[3/12] Patching Domain User Enumeration..." -ForegroundColor Yellow

try {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RestrictAnonymous /t REG_DWORD /d 1 /f 2>$null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RestrictAnonymousSAM /t REG_DWORD /d 1 /f 2>$null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v EveryoneIncludesAnonymous /t REG_DWORD /d 0 /f 2>$null
    reg delete "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v NullSessionPipes /f 2>$null
    reg delete "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v NullSessionShares /f 2>$null
    Write-Host "[+] Anonymous enumeration disabled" -ForegroundColor Green
} catch { Write-Host "[!] Enum patch: $($_.Exception.Message)" -ForegroundColor Red; $errors++ }

# ── 4. PATCH — Golden Ticket (KRBTGT) ────────────────────────────────────────
Write-Host "`n[4/12] Patching Golden Ticket — resetting KRBTGT password TWICE..." -ForegroundColor Yellow

try {
    $pw1 = "Kr8tgt!N3wP@ss#2024Rand$(Get-Random -Maximum 9999)"
    Set-ADAccountPassword krbtgt -NewPassword (ConvertTo-SecureString $pw1 -AsPlainText -Force) -Reset
    Write-Host "[+] KRBTGT password reset #1" -ForegroundColor Green
    Start-Sleep -Seconds 5
    $pw2 = "Kr8tgt!N3wP@ss#2025Rand$(Get-Random -Maximum 9999)"
    Set-ADAccountPassword krbtgt -NewPassword (ConvertTo-SecureString $pw2 -AsPlainText -Force) -Reset
    Write-Host "[+] KRBTGT password reset #2 — all existing golden tickets invalidated" -ForegroundColor Green
} catch { Write-Host "[!] KRBTGT: $($_.Exception.Message)" -ForegroundColor Red; $errors++ }

# Force AD replication
repadmin /syncall /AdeP 2>$null
Write-Host "[+] AD replication forced" -ForegroundColor Green
Remove-Item "C:\Temp\golden_ticket_info.txt" -Force -ErrorAction SilentlyContinue

# ── 5. PATCH — Kerberoasting ─────────────────────────────────────────────────
Write-Host "`n[5/12] Patching Kerberoasting..." -ForegroundColor Yellow

foreach ($u in @("svc_http", "svc_mssql", "svc_backup")) {
    try {
        if (Get-ADUser -Filter {SamAccountName -eq $u} -ErrorAction SilentlyContinue) {
            # Remove SPN
            $spns = (Get-ADUser -Identity $u -Properties ServicePrincipalNames).ServicePrincipalNames
            if ($spns.Count -gt 0) {
                Set-ADUser -Identity $u -ServicePrincipalNames @{Remove = $spns}
                Write-Host "[+] SPNs removed from: $u" -ForegroundColor Green
            }
            # Enforce AES256, disable RC4
            Set-ADUser -Identity $u -KerberosEncryptionType AES256
            # Re-enable pre-auth
            Set-ADAccountControl -Identity $u -DoesNotRequirePreAuth $false
            # Set strong random password
            $newpw = "Str0ng!$(Get-Random -Maximum 999999)P@ss#$(Get-Random -Maximum 9999)"
            Set-ADAccountPassword -Identity $u -NewPassword (ConvertTo-SecureString $newpw -AsPlainText -Force) -Reset
            Write-Host "[+] Patched: $u (SPN removed, AES256, strong password)" -ForegroundColor Green
        }
    } catch { Write-Host "[!] $u : $($_.Exception.Message)" -ForegroundColor Red; $errors++ }
}
Remove-Item "C:\Temp\kerberoasting_info.txt" -Force -ErrorAction SilentlyContinue

# ── 6. PATCH — Password Spray Target ─────────────────────────────────────────
Write-Host "`n[6/12] Patching Password Spray Target..." -ForegroundColor Yellow

foreach ($i in 1..10) {
    $u = "emp{0:D3}" -f $i
    try {
        if (Get-ADUser -Filter {SamAccountName -eq $u} -ErrorAction SilentlyContinue) {
            $newpw = "Str0ng!$(Get-Random -Maximum 999999)P@ss#$(Get-Random -Maximum 9999)"
            Set-ADAccountPassword -Identity $u -NewPassword (ConvertTo-SecureString $newpw -AsPlainText -Force) -Reset
            Write-Host "[+] Password reset: $u" -ForegroundColor Green
        }
    } catch { Write-Host "[!] $u : $($_.Exception.Message)" -ForegroundColor Red; $errors++ }
}
# Restore account lockout policy
try {
    Set-ADDefaultDomainPasswordPolicy -Identity (Get-ADDomain).DistinguishedName `
        -LockoutThreshold 5 `
        -LockoutDuration "00:30:00" `
        -LockoutObservationWindow "00:30:00"
    Write-Host "[+] Account lockout policy restored: threshold=5, duration=30min" -ForegroundColor Green
} catch { Write-Host "[!] Lockout policy: $($_.Exception.Message)" -ForegroundColor Red; $errors++ }

# ── 7. PATCH — Protected Users ────────────────────────────────────────────────
Write-Host "`n[7/12] Patching Protected Users..." -ForegroundColor Yellow

try {
    Add-ADGroupMember -Identity "Protected Users" -Members "Administrator" -ErrorAction SilentlyContinue
    Add-ADGroupMember -Identity "Protected Users" -Members "krbtgt" -ErrorAction SilentlyContinue
    Write-Host "[+] Administrator and krbtgt added to Protected Users" -ForegroundColor Green
} catch { Write-Host "[!] Protected Users: $($_.Exception.Message)" -ForegroundColor Red; $errors++ }

# Restore Kerberos armoring
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Kerberos\Parameters" /v SupportedEncryptionTypes /t REG_DWORD /d 2147483647 /f 2>$null
Write-Host "[+] Kerberos armoring restored" -ForegroundColor Green
Remove-Item "C:\Temp\ad13_info.txt" -Force -ErrorAction SilentlyContinue

# ── 8. PATCH — Replication Exposed ───────────────────────────────────────────
Write-Host "`n[8/12] Patching Replication Exposed..." -ForegroundColor Yellow

try {
    $repl2 = Get-ADUser -Filter {SamAccountName -eq "repl_svc2"} -ErrorAction SilentlyContinue
    if ($repl2) {
        $sid  = New-Object System.Security.Principal.SecurityIdentifier($repl2.SID)
        $acl  = Get-Acl "AD:\DC=cyberstrike,DC=mil"
        $aces = $acl.Access | Where-Object { $_.IdentityReference -like "*repl_svc2*" }
        foreach ($ace in $aces) { $acl.RemoveAccessRule($ace) | Out-Null }
        Set-Acl -Path "AD:\DC=cyberstrike,DC=mil" -AclObject $acl
        Disable-ADAccount -Identity "repl_svc2"
        Write-Host "[+] repl_svc2 DCSync rights removed and account disabled" -ForegroundColor Green
    }
} catch { Write-Host "[!] Replication patch: $($_.Exception.Message)" -ForegroundColor Red; $errors++ }

# ── 9. PATCH — Shadow Credentials ────────────────────────────────────────────
Write-Host "`n[9/12] Patching Shadow Credentials..." -ForegroundColor Yellow

try {
    $st = Get-ADUser -Filter {SamAccountName -eq "shadow_target"} -ErrorAction SilentlyContinue
    if ($st) {
        Set-ADUser shadow_target -Clear msDS-KeyCredentialLink
        $newpw = "Str0ng!$(Get-Random -Maximum 999999)Sh@d0w#$(Get-Random -Maximum 9999)"
        Set-ADAccountPassword -Identity "shadow_target" -NewPassword (ConvertTo-SecureString $newpw -AsPlainText -Force) -Reset
        Write-Host "[+] shadow_target msDS-KeyCredentialLink cleared, password reset" -ForegroundColor Green
    }
} catch { Write-Host "[!] Shadow credentials: $($_.Exception.Message)" -ForegroundColor Red; $errors++ }

# Restore Schannel
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\Schannel" /v SendTrustedIssuerList /t REG_DWORD /d 1 /f 2>$null
Write-Host "[+] Schannel restored" -ForegroundColor Green

# ── 10. PATCH — Unconstrained Delegation ─────────────────────────────────────
Write-Host "`n[10/12] Patching Unconstrained Delegation..." -ForegroundColor Yellow

try {
    if (Get-ADUser -Filter {SamAccountName -eq "svc_delegate"} -ErrorAction SilentlyContinue) {
        Set-ADAccountControl -Identity "svc_delegate" -TrustedForDelegation $false
        Disable-ADAccount -Identity "svc_delegate"
        Write-Host "[+] Unconstrained delegation removed from svc_delegate, account disabled" -ForegroundColor Green
    }
    # Mark sensitive accounts as cannot be delegated
    foreach ($acct in @("Administrator", "krbtgt")) {
        Set-ADAccountControl -Identity $acct -AccountNotDelegated $true -ErrorAction SilentlyContinue
    }
    Write-Host "[+] Administrator and krbtgt marked as cannot be delegated" -ForegroundColor Green
} catch { Write-Host "[!] Delegation patch: $($_.Exception.Message)" -ForegroundColor Red; $errors++ }

Remove-Item "C:\Temp\delegation_info.txt" -Force -ErrorAction SilentlyContinue

# ── 11. PATCH — Weak GPO / Password Policy ───────────────────────────────────
Write-Host "`n[11/12] Patching Weak GPO..." -ForegroundColor Yellow

try {
    Set-ADDefaultDomainPasswordPolicy -Identity (Get-ADDomain).DistinguishedName `
        -ComplexityEnabled $true `
        -MinPasswordLength 12 `
        -PasswordHistoryCount 24 `
        -MaxPasswordAge (New-TimeSpan -Days 90) `
        -MinPasswordAge (New-TimeSpan -Days 1)
    Write-Host "[+] Password policy restored: complexity=on, minlen=12, history=24, expiry=90d" -ForegroundColor Green
} catch { Write-Host "[!] Password policy: $($_.Exception.Message)" -ForegroundColor Red; $errors++ }

# Restrict WinRM TrustedHosts
try {
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "10.0.40.23" -Force -ErrorAction SilentlyContinue
    Write-Host "[+] WinRM TrustedHosts restricted to management IP" -ForegroundColor Green
} catch {}

# ── 12. PATCH — AD Auditing + Recycle Bin ────────────────────────────────────
Write-Host "`n[12/12] Restoring AD Auditing..." -ForegroundColor Yellow

try {
    auditpol /set /category:* /success:enable /failure:enable 2>$null
    auditpol /set /subcategory:"Directory Service Access" /success:enable /failure:enable 2>$null
    auditpol /set /subcategory:"Directory Service Changes" /success:enable /failure:enable 2>$null
    auditpol /set /subcategory:"Account Logon" /success:enable /failure:enable 2>$null
    auditpol /set /subcategory:"Logon" /success:enable /failure:enable 2>$null
    Write-Host "[+] Full auditing restored" -ForegroundColor Green
} catch { Write-Host "[!] Audit policy: $($_.Exception.Message)" -ForegroundColor Red; $errors++ }

# Re-enable AD Recycle Bin
try {
    Enable-ADOptionalFeature "Recycle Bin Feature" -Scope ForestOrConfigurationSet `
        -Target (Get-ADDomain).Forest -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "[+] AD Recycle Bin re-enabled" -ForegroundColor Green
} catch { Write-Host "[!] Recycle Bin: $($_.Exception.Message)" -ForegroundColor Red }

# ── Clean up all temp info files ─────────────────────────────────────────────
Remove-Item "C:\Temp\*_info.txt" -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Temp\*_targets.txt" -Force -ErrorAction SilentlyContinue

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "  ADDC Patch Complete" -ForegroundColor Cyan
if ($errors -eq 0) {
    Write-Host "  All 12 patches applied successfully" -ForegroundColor Green
} else {
    Write-Host "  Completed with $errors error(s) — review output above" -ForegroundColor Yellow
}
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "`nNOTE: KRBTGT double-reset invalidates ALL Kerberos tickets domain-wide." -ForegroundColor Yellow
Write-Host "      Users will need to re-authenticate. Plan for brief service disruption." -ForegroundColor Yellow
