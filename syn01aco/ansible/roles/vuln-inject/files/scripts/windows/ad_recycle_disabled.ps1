# vuln: ad_recycle_bin_disabled | severity: low
Write-Host "[VULN] Disabling AD Recycle Bin and auditing..."
Import-Module ActiveDirectory -ErrorAction SilentlyContinue
# Disable AD Recycle Bin (if enabled)
$domain = Get-ADDomain
try {
    Disable-ADOptionalFeature "Recycle Bin Feature" -Scope ForestOrConfigurationSet -Target $domain.Forest -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "[+] AD Recycle Bin disabled"
} catch { Write-Host "[!] $($_.Exception.Message)" }
# Disable all audit policies
auditpol /clear /y 2>$null
auditpol /set /category:* /success:disable /failure:disable 2>$null
Write-Host "[VULN] AD auditing cleared — attacks won't be logged."
