# vuln: powershell_unrestricted | severity: high
Write-Host "[VULN] Setting PowerShell to Unrestricted execution policy..."
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine -Force
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell" /v EnableScripts /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell" /v ExecutionPolicy /t REG_SZ /d "Unrestricted" /f
# Disable AMSI
$AMSI = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
$Field = $AMSI.GetField('amsiInitFailed','NonPublic,Static')
$Field.SetValue($null,$true)
Write-Host "[VULN] PowerShell execution unrestricted, AMSI disabled."
