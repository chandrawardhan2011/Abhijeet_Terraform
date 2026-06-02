# vuln: weak_admin_password | severity: high
Write-Host "[VULN] Setting weak Administrator password..."
net user Administrator Admin@123 2>$null
net user Administrator /passwordreq:no 2>$null
net user guest /active:yes 2>$null
net user guest guest 2>$null
$policy = [adsi]"WinNT://./Account"
$policy.PasswordHistoryLength = 0
$policy.MaxPasswordAge = 0
$policy.MinPasswordLength = 0
$policy.MinPasswordAge = 0
$policy.SetInfo()
wmic useraccount where "name='Administrator'" set PasswordExpires=FALSE
Write-Host "[VULN] Weak passwords set. Administrator:Admin@123, guest:guest"
