# vuln: applocker_disabled | severity: medium
Write-Host "[VULN] Disabling AppLocker and Application Control..."
# Clear all AppLocker policies
Set-AppLockerPolicy -XmlPolicy "<AppLockerPolicy Version='1'></AppLockerPolicy>" -ErrorAction SilentlyContinue
# Disable Software Restriction Policies
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers" /v DefaultLevel /t REG_DWORD /d 262144 /f 2>$null
# Disable Windows Defender Application Control
reg add "HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy" /v VerifiedAndReputablePolicyState /t REG_DWORD /d 0 /f 2>$null
# Set AppLocker service to disabled
Set-Service -Name AppIDSvc -StartupType Disabled -ErrorAction SilentlyContinue
Stop-Service -Name AppIDSvc -Force -ErrorAction SilentlyContinue
Set-Content -Path "C:\Temp\applocker_info.txt" -Value "AppLocker disabled.`nAny unsigned executable can run freely.`nDrop malware in C:\Temp\ and execute directly."
Write-Host "[VULN] AppLocker disabled — any binary can execute without restriction."
