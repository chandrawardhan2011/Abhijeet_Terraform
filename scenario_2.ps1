<#
.SYNOPSIS
    TryHackMe Vulnerable Windows Lab Machine Setup Script
    Configures all necessary vulnerabilities, files, shares, and registry keys
    to match the Red Team local enumeration challenge questions.
.NOTES
    MUST BE RUN AS ADMINISTRATOR.
#>

# Ensure script runs with administrative checks
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be executed from an elevated administrative PowerShell window!"
    Exit
}

Write-Output "[*] Commencing TryHackMe Lab Machine Configuration..."

# --- 1. USER ACCOUNTS & GROUPS SETUP (E01, E03, E04, E05, E06, E20) ---
Write-Output "[*] Structuring User Accounts and Password Policies..."

# Create supportsvc account
if (-not (Get-LocalUser -Name "supportsvc" -ErrorAction SilentlyContinue)) {
    $Pass = ConvertTo-SecureString "Welcome@123" -AsPlainText -Force
    New-LocalUser -Name "supportsvc" -Password $Pass -Description "Remote maintenance account" -PasswordNeverExpires $true
}

# Create backupadmin account
if (-not (Get-LocalUser -Name "backupadmin" -ErrorAction SilentlyContinue)) {
    $Pass = ConvertTo-SecureString "BK-2026-P@ss!" -AsPlainText -Force
    New-LocalUser -Name "backupadmin" -Password $Pass -Description "Backup operator account" -PasswordNeverExpires $true
}

# Add backupadmin to Administrators group
Add-LocalGroupMember -Group "Administrators" -Member "backupadmin" -ErrorAction SilentlyContinue

# Create IIS deployment user with password in comment description
if (-not (Get-LocalUser -Name "iis_deploy" -ErrorAction SilentlyContinue)) {
    $Pass = ConvertTo-SecureString "DeploySecure2026!" -AsPlainText -Force
    New-LocalUser -Name "iis_deploy" -Password $Pass -Description "Old key: WebDeploy@123" -PasswordNeverExpires $true
}

# Set Weak Account Policies (Min Password Length = 6, Lockout Threshold = 0)
net accounts /minpwlen:6
net accounts /lockoutthreshold:0


# --- 2. REGISTRY VULNERABILITIES SETUP (E01, E02, E07, E08, E09, E10, E11, M09, M10, M11, M12) ---
Write-Output "[*] Configuring Weak Registry Paths & Policies..."

# AutoAdminLogon Configuration
$WinlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $WinlogonPath -Name "AutoAdminLogon" -Value "1" -Type String
Set-ItemProperty -Path $WinlogonPath -Name "DefaultUserName" -Value "supportsvc" -Type String
Set-ItemProperty -Path $WinlogonPath -Name "DefaultPassword" -Value "Welcome@123" -Type String

# Enable RDP via Terminal Server registry configuration
$TSPath = "HKLM:\System\CurrentControlSet\Control\Terminal Server"
Set-ItemProperty -Path $TSPath -Name "fDenyTSConnections" -Value 0 -Type DWord

# Weaken User Account Control (DisableLUA = 0)
$UACPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $UACPath -Name "EnableLUA" -Value 0 -Type DWord

# Disable PowerShell Transcription Logging
$TranscriptPath = "HKLM:\Software\Policies\Microsoft\Windows\PowerShell\Transcription"
if (-not (Test-Path $TranscriptPath)) { New-Item -Path $TranscriptPath -Force | Out-Null }
Set-ItemProperty -Path $TranscriptPath -Name "EnableTranscripting" -Value 0 -Type DWord

# Disable PowerShell Script Block Logging
$ScriptBlockPath = "HKLM:\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
if (-not (Test-Path $ScriptBlockPath)) { New-Item -Path $ScriptBlockPath -Force | Out-Null }
Set-ItemProperty -Path $ScriptBlockPath -Name "EnableScriptBlockLogging" -Value 0 -Type DWord

# Inject Current User Run Key Persistence Masquerading Artifact
$RunPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $RunPath -Name "OneDriveUpdater" -Value "C:\Users\Public\win_update_check.bat" -Type String

# SMB Hardening Deficiencies (AllowInsecureGuestAuth = 1, RestrictNullSessAccess = 0)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "AllowInsecureGuestAuth" -Value 1 -Type DWord
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "RestrictNullSessAccess" -Value 0 -Type DWord

# Multicast Resolution Enabled (LLMNR)
$DNSClientPath = "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient"
if (-not (Test-Path $DNSClientPath)) { New-Item -Path $DNSClientPath -Force | Out-Null }
Set-ItemProperty -Path $DNSClientPath -Name "EnableMulticast" -Value 1 -Type DWord

# Proxy Discovery WPAD Configuration Setup
$InternetSettingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
Set-ItemProperty -Path $InternetSettingsPath -Name "AutoConfigURL" -Value "http://wpad.local/wpad.dat" -Type String

# SNMP Community String Caching
$SNMPCommunities = "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\ValidCommunities"
if (-not (Test-Path $SNMPCommunities)) { New-Item -Path $SNMPCommunities -Force | Out-Null }
Set-ItemProperty -Path $SNMPCommunities -Name "public" -Value 4 -Type DWord


# --- 3. FILESYSTEM ARTIFACTS & FILE SHARES (E12, E14, E15, E16, E17, E19, M01, M13, M14, M15, M18, M19, M20) ---
Write-Output "[*] Planting File Artifacts, Shares, and Directories..."

# Create user Startup folder batch file
$StartupDir = "C:\Users\Public\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
if (-not (Test-Path $StartupDir)) { New-Item -Path $StartupDir -ItemType Directory -Force | Out-Null }
"@echo off`necho Checking for system software infrastructure updates...`nwhoami" | Out-File -FilePath "$StartupDir\win_update_check.bat" -Encoding ASCII
# Also keep a copy in Public for the Run key reference
"@echo off`nwhoami" | Out-File -FilePath "C:\Users\Public\win_update_check.bat" -Encoding ASCII

# Populate a mock PSReadLine History file
$HistoryDir = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine"
if (-not (Test-Path $HistoryDir)) { New-Item -Path $HistoryDir -ItemType Directory -Force | Out-Null }
"cd C:\inetpub\wwwroot`n`$web_pass = 'P@ssword-Web-2026'`nii http://localhost" | Out-File -FilePath "$HistoryDir\ConsoleHost_history.txt" -Encoding ASCII

# Create Hidden HR Note containing VPN Password
$HRDir = "C:\Users\Public\Documents"
$HRFile = "$HRDir\vpn_connection_note.txt"
"Corporate Remote Access VPN Connection Details`nGateway: vpn.intranet.local`nKey Material Access Credentials: Fortify@2026" | Out-File -FilePath $HRFile -Encoding ASCII
(Get-Item $HRFile).Attributes = 'Hidden'

# Backup Agent Config File Allocation
$BackupDir = "C:\ProgramData\BackupAgent"
if (-not (Test-Path $BackupDir)) { New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null }
" [BackupSettings]`nVersion=4.2.1`nEncryptionKey=BK-2026-KEY-778899`nTarget=10.10.10.12" | Out-File -FilePath "$BackupDir\config.ini" -Encoding ASCII

# Unquoted Service Registry Path Simulation
$ServiceRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Vendor Update Service"
if (-not (Test-Path $ServiceRegPath)) { New-Item -Path $ServiceRegPath -Force | Out-Null }
Set-ItemProperty -Path $ServiceRegPath -Name "ImagePath" -Value "C:\Program Files\Vendor Tools\Update Subfolder\updater.exe" -Type ExpandString
Set-ItemProperty -Path $ServiceRegPath -Name "DisplayName" -Value "Vendor Update Service" -Type String

# Windows Temp Cache Log Dumping
"Running automated system context enumeration profiling scripts...`ncmd.exe /c whoami & net user" | Out-File -FilePath "C:\Windows\Temp\debug_cmd_execution.log" -Encoding ASCII

# Append entry to local hosts file
$HostsFile = "C:\Windows\System32\drivers\etc\hosts"
"`n10.10.10.5       intranet.local" | Add-Content -Path $HostsFile

# OpenVPN Profile Username Generation
$OpenVPNDir = "C:\ProgramData\OpenVPN\config"
if (-not (Test-Path $OpenVPNDir)) { New-Item -Path $OpenVPNDir -ItemType Directory -Force | Out-Null }
"auth-user-pass`nuser=vpn.support" | Out-File -FilePath "$OpenVPNDir\creds.txt" -Encoding ASCII

# WiFi Profile Export Key Leakage
$WifiFile = "C:\Users\Public\Documents\Wi-Fi-Profile.xml"
@"
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>OfficeWifi</name>
    <MSM>
        <security>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>OfficeWifi@2026</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@ | Out-File -FilePath $WifiFile -Encoding ASCII

# Create Adapter Cache File showing NetBIOS status
"Adapter=Ethernet0`nDisableNetbiosOverTcpip=0" | Out-File -FilePath "C:\ProgramData\adapter_cache.dat" -Encoding ASCII

# Create Network Share Configuration (FinanceShare with Payroll File)
$FinanceDirPath = "C:\FinanceShareData"
if (-not (Test-Path $FinanceDirPath)) { New-Item -Path $FinanceDirPath -ItemType Directory -Force | Out-Null }
"Employee Payroll Export Master Database Backup Archive`nFile Access Decryption Phrase: Payroll@2026" | Out-File -FilePath "$FinanceDirPath\payroll_backup.txt" -Encoding ASCII
if (-not (Get-SmbShare -Name "FinanceShare" -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name "FinanceShare" -Path $FinanceDirPath -FullAccess "Everyone"
}


# --- 4. NETWORKING PARAMETERS SETUP (M16, M17) ---
Write-Output "[*] Injecting Persistent Networking Configurations..."

# Add a mock persistent route network address space mapping
route -p ADD 10.66.66.0 MASK 255.255.255.0 127.0.0.1 METRIC 1

# Add redundant loopback DNS validation address via primary interface adapters
$Adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
foreach ($Interface in $Adapters) {
    Set-DnsClientServerAddress -InterfaceIndex $Interface.InterfaceIndex -ServerAddresses ("127.0.0.1", "10.10.10.10") -ErrorAction SilentlyContinue
}


# --- 5. MOCK WEB SERVER ENVIRONMENT DATA PLANTING (M02-M07, H01-H10) ---
Write-Output "[*] Provisioning Mock Local Web Server Staging Archives..."

# Use C:\inetpub\wwwroot as the default localized staging ground for simulated web analysis challenges
$WebRoot = "C:\inetpub\wwwroot"
if (-not (Test-Path $WebRoot)) { New-Item -Path $WebRoot -ItemType Directory -Force | Out-Null }

# H01: robots.txt
"User-agent: *`nDisallow: /admin/`nDisallow: /backup/`nDisallow: /dev/`nDisallow: /old-login/" | Out-File -FilePath "$WebRoot\robots.txt" -Encoding ASCII

# H02: index.html
"<html>`n`n<h1>Internal Intranet</h1>`n</html>" | Out-File -FilePath "$WebRoot\index.html" -Encoding ASCII

# H03: /backup area database environment configuration
$WebBackup = "$WebRoot\backup"
if (-not (Test-Path $WebBackup)) { New-Item -Path $WebBackup -ItemType Directory -Force | Out-Null }
"DB_HOST=127.0.0.1`nDB_PORT=3306`nDB_USER=sa`nDB_PASS=SQL_Master_Access_2026!" | Out-File -FilePath "$WebBackup\.env" -Encoding ASCII

# H04: /old-login readme file referencing SQLi parameters
$WebOldLogin = "$WebRoot\old-login"
if (-not (Test-Path $WebOldLogin)) { New-Item -Path $WebOldLogin -ItemType Directory -Force | Out-Null }
"Legacy Authentication Endpoint Notes:`nWARNING: The parameter mapped to user index verification query strings ('id') is completely unauthenticated and susceptible to SQL Injection query concatenation." | Out-File -FilePath "$WebOldLogin\README.md" -Encoding ASCII

# H05: /dev XSS verification feedback files
$WebDev = "$WebRoot\dev"
if (-not (Test-Path $WebDev)) { New-Item -Path $WebDev -ItemType Directory -Force | Out-Null }
"Development Sandbox Notice:`nEnsure proper escaping profiles are implemented across the active search parsing variables ('q') to mitigate persistent Reflected XSS exploitation vectors." | Out-File -FilePath "$WebDev\xss_remediation.txt" -Encoding ASCII

# H06 & H07: Apache VHost file mocking
"VirtualHost Configuration Profile Tracking Context:`nServerAdmin infrastructure@intranet.local`nDocumentRoot C:\inetpub\wwwroot`nServerName intranet.local`nServerTokens Prod`nServerSignature Off`n# System Trace Output Software Engine Context: Apache/2.2.14`n<Directory 'C:\inetpub\wwwroot'>`n    Options Indexes FollowSymLinks`n    AllowOverride None`n</Directory>" | Out-File -FilePath "$WebRoot\vhost_apache.conf" -Encoding ASCII

# H08: PHP Information file creation
"<?php phpinfo(); ?>" | Out-File -FilePath "$WebRoot\phpinfo.php" -Encoding ASCII

# H09: Git Repository Tracking Metadata Disclosures
$GitDir = "$WebRoot\.git"
if (-not (Test-Path $GitDir)) { New-Item -Path $GitDir -ItemType Directory -Force | Out-Null }
"[core]`nrepositoryformatversion = 0`nfilemode = false`nbare = false`n[remote 'origin']`nurl = http://git.intranet.local/payroll/app.git" | Out-File -FilePath "$GitDir\config" -Encoding ASCII

# H10: WebDeploy Application Secret Production configurations
" {`n  'DeploymentSettings': {`n    'Environment': 'Production',`n    'JwtSigningValidationSecret': 'SuperSecretJwtKey2026',`n    'APIEndpoint': 'http://10.10.10.5:5000/v1/api'`n  }`n}" | Out-File -FilePath "$WebRoot\webdeploy_prod.json" -Encoding ASCII


# --- 6. SIMULATING EVENT LOG GENERATION FOR FORWARD LOG SEEDING (E18) ---
Write-Output "[*] Generating Simulated Audit Events into Application Logs..."

# Create Custom Application Event log source mapping and dispatch log block
New-EventLog -LogName Application -Source "BackupAgent" -ErrorAction SilentlyContinue
Write-EventLog -LogName Application -Source "BackupAgent" -EntryType Error -EventId 401 -Message "Critical Infrastructure Error Code 401: Authentication session negotiation failed. The remote service account profile 'backupadmin' supplied invalid access tokens during the processing initialization phase."

Write-Output "[+] Configuration Script Completed Successfully! The host system is ready for student enumeration modules."

<#
.SYNOPSIS
    TryHackMe Vulnerable Windows Lab Machine Setup Script - Hard Extension
    Appends files and configurations for tasks H11 through H20.
#>

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script extension must be executed from an elevated administrative window!"
    Exit
}

Write-Output "[*] Injecting Additional Hard TryHackMe Challenges (H11-H20)..."
$WebRoot = "C:\inetpub\wwwroot"
if (-not (Test-Path $WebRoot)) { New-Item -Path $WebRoot -ItemType Directory -Force | Out-Null }

# Ensure Subdirectories exist
$WebBackup = "$WebRoot\backup"
$WebDev = "$WebRoot\dev"
$WebAdmin = "$WebRoot\admin"
foreach ($Dir in ($WebBackup, $WebDev, $WebAdmin)) {
    if (-not (Test-Path $Dir)) { New-Item -Path $Dir -ItemType Directory -Force | Out-Null }
}

# H11: File Viewer endpoint note mapping LFI
"File Viewer Engine Utility:`nEndpoint: /view.php?page=`nNote: Current path restriction checks are not enforced. Input validation must be implemented to block relative paths like: ../../../../Windows/System32/drivers/etc/hosts" | Out-File -FilePath "$WebRoot\view_notes.txt" -Encoding ASCII

# H12: Insecure Deserialization Simulation Script
"<?php // session.php.bak`n// TODO: Transition from insecure serialized cookies to server-side tokens.`n// Example administrative serialized payload: Tzo0OiJVc2VyIjoyOntzOjQ6Im5hbWUiO3M6NToiYWRtaW4iO3M6NToiaXNBZG0iO2I6MTt9`n`$user_session = unserialize(base64_decode(`$_COOKIE['session'])); ?>" | Out-File -FilePath "$WebDev\session.php.bak" -Encoding ASCII

# H13: Command Injection Utility Simulation
"<?php // admin/ping.php`n// Quick diagnostic interface for administrators`n`$target = `$_REQUEST['ip'];`n// Vulnerable execution context string: system('ping -c 1 ' . `$target);`n// Exploitation proof: Input '127.0.0.1 && whoami' will echo host context strings.`n?>" | Out-File -FilePath "$WebAdmin\ping.php" -Encoding ASCII

# H14: SSRF Mock Metric Endpoint Configuration
"Server Internal Performance Tracker Dashboard`nContext: Private Only`nStatus: Authenticated Bypass Approved`nMetric_Data_Flag: 1`nActive System Trace: API Route /v1/api is healthy" | Out-File -FilePath "$WebRoot\webdeploy_prod.json" -Append -Encoding ASCII
# Placing an explicit metric folder map to act as the targets endpoint
$MetricsDir = "$WebRoot\metrics"
if (-not (Test-Path $MetricsDir)) { New-Item -Path $MetricsDir -ItemType Directory -Force | Out-Null }
"Internal System Performance Reporting Registry Workspace Status: OK. Admin Interface Enabled." | Out-File -FilePath "$MetricsDir\index.html" -Encoding ASCII

# H15: Hardcoded Salt File
"// hash_helpers.js - Global User Credential Hashing Arrays`nconst CRITICAL_SALT = 'S3cr3tS@lt_2026!';`nfunction generateSecureHash(password) { return md5(password + CRITICAL_SALT); }" | Out-File -FilePath "$WebDev\hash_helpers.js" -Encoding ASCII

# H16: SSTI Framework Notes
"Template Compiler Audit Tracking log:`nWarning: The feedback registration engine executes expression formatting modules directly.`nSubmitting standard math payloads like {{7*7}} returns evaluation data values client side (49)." | Out-File -FilePath "$WebDev\ssti_audit.log" -Encoding ASCII

# H17: IDOR / BOLA Invoice Store Creation
$InvoiceDir = "$WebRoot\invoices"
if (-not (Test-Path $InvoiceDir)) { New-Item -Path $InvoiceDir -ItemType Directory -Force | Out-Null }
"Invoice Account Number: 55421`nCustomer Code: 01`nTotal Due: `$450.00`nStatus: Settled" | Out-File -FilePath "$InvoiceDir\invoice_1098.txt" -Encoding ASCII
"Invoice Account Number: 11002`nCustomer Code: ADMIN_ROOT`nTotal Due: `$0.00`nStatus: Overdue`nVerification Token: FLAG{BOLA_EXPOSED_9922}" | Out-File -FilePath "$InvoiceDir\invoice_1099.txt" -Encoding ASCII

# H18: Mass Assignment Schema Log
" {`n  'UserAccountRegistrationSchema': {`n    'username': 'string',`n    'email': 'string',`n    'password_hash': 'string',`n    'isAdmin': 'boolean (Default: false) WARNING: Keep context safe from post requests'`n  }`n}" | Out-File -FilePath "$WebDev\schema.json" -Encoding ASCII

# H19: Cross-Origin Header Update in Mock VHost Configuration
"`n# CORS Security Policy Configurations`nHeader set Access-Control-Allow-Origin: *`nHeader set Access-Control-Allow-Methods 'GET, POST, OPTIONS'" | Add-Content -Path "$WebRoot\vhost_apache.conf"

# H20: XXE Configuration Manifest Template
@"
<config>
    <user>guest_developer</user>
    <permissions>read-only</permissions>
</config>
"@ | Out-File -FilePath "$WebBackup\template.xml" -Encoding ASCII

Write-Output "[+] Additional hard challenges configured successfully!"