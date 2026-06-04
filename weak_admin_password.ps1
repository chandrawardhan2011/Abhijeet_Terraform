# vuln: weak_admin_password | severity: high
# Creates a new local admin user with weak password instead of changing Administrator
# This preserves WinRM connectivity for Ansible while injecting the vulnerability
Write-Host "[VULN] Injecting weak admin password vulnerability..."

# Create weak local admin account — leave Administrator password untouched
net user labuser Lab@123 /add 2>$null
net user labuser /passwordreq:no 2>$null
net localgroup Administrators labuser /add 2>$null
wmic useraccount where "name='labuser'" set PasswordExpires=FALSE 2>$null

# Enable guest account with weak password
net user guest /active:yes 2>$null
net user guest guest 2>$null

# Weaken password policy
net accounts /minpwlen:0 /maxpwage:unlimited /minpwage:0 /uniquepw:0 2>$null

# Write info file
New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
@"
Weak Password Accounts:
- labuser  : Lab@123  (local admin)
- guest    : guest    (enabled)

Attack:
crackmapexec smb 10.0.20.150 -u labuser -p Lab@123
psexec.py labuser:Lab@123@10.0.20.150 cmd.exe
"@ | Out-File "C:\Temp\weak_password_info.txt" -Encoding UTF8

Write-Host "[VULN] Weak admin user created. labuser:Lab@123, guest:guest"
Write-Host "[INFO] Administrator password unchanged — Ansible connectivity preserved"
