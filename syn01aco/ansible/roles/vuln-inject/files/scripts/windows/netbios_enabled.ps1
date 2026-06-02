# vuln: netbios_enabled | severity: medium
Write-Host "[VULN] Enabling NetBIOS and LLMNR..."
# Enable LLMNR via registry
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v EnableMulticast /t REG_DWORD /d 1 /f 2>$null
# Enable NetBIOS over TCP/IP on all adapters
$adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled }
foreach ($adapter in $adapters) {
    $adapter.SetTcpipNetbios(1) | Out-Null
}
# Disable Windows Defender Firewall for SMB to allow Responder captures
netsh advfirewall firewall add rule name="Allow SMB" protocol=TCP dir=in localport=445 action=allow 2>$null
Set-Content -Path "C:\Temp\netbios_info.txt" -Value "NetBIOS and LLMNR enabled.`nAttack: responder -I eth0 -wPv`nCaptures NTLMv2 hashes from any name resolution requests."
Write-Host "[VULN] NetBIOS/LLMNR enabled — Responder will capture NTLMv2 hashes."
