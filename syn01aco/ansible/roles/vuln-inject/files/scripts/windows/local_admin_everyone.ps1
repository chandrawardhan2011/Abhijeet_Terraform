# vuln: excessive_local_admin | severity: high
Write-Host "[VULN] Adding Everyone to Local Administrators..."
net localgroup Administrators "Everyone" /add 2>$null
net localgroup Administrators "Authenticated Users" /add 2>$null
net user labuser Lab@123 /add 2>$null
net localgroup Administrators labuser /add 2>$null
net user labuser /passwordreq:no 2>$null
Set-Content -Path "C:\Temp\admin_users.txt" -Value "Everyone group added to Administrators`nNew user: labuser:Lab@123"
Write-Host "[VULN] Everyone added to Administrators group."
