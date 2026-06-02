# vuln: autorun_enabled | severity: medium
Write-Host "[VULN] Enabling AutoRun/AutoPlay..."
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDriveTypeAutoRun /t REG_DWORD /d 0 /f
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDriveTypeAutoRun /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\IniFileMapping\Autorun.inf" /ve /t REG_SZ /d "@SYS:DoesNotExist" /f
# Create autorun.inf in accessible location
New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
Set-Content -Path "C:\Temp\autorun.inf" -Value "[autorun]`nopen=payload.exe`naction=Run Program`nlabel=USB Drive"
Write-Host "[VULN] AutoRun enabled — USB/removable media will auto-execute."
