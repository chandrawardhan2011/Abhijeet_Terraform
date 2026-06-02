#!/usr/bin/env python3
"""
CyberRange SYN-01 — Blue Team Linux Agent
==========================================
Runs on every Linux machine (wazuh-server-1, web-server-1, db-server-1,
ftp-server-1, linux-1). Reads /tmp/vulb.txt, checks local system state
for each injected vulnerability, and reports results to the leaderboard.

vulb.txt format : LS01:CWE-307:SSH Brute Force
                  ^--- only the first field (label) is used

Deploy           : /opt/blue-agent/blue_agent_linux.py
Service interval : 30 seconds (systemd)
"""

import os, re, socket, stat, subprocess, sys, time, uuid
from pathlib import Path

try:
    import requests
except ModuleNotFoundError:
    subprocess.check_call([sys.executable, '-m', 'pip', 'install',
                           'requests', '--break-system-packages', '-q'])
    import requests

# ── Configuration ─────────────────────────────────────────────────────────────
LEADERBOARD_URL     = 'http://10.0.40.105:8000/MAIN/BLUE/api/agent/report_batch'
VULB_TXT            = '/tmp/vulb.txt'
SCAN_INTERVAL       = 30          # seconds between scans
REQUEST_TIMEOUT     = 8

# Web-lab base URLs — only reachable when running ON web-server-1
VULNLAB_URL         = 'http://127.0.0.1:9001'
CYBERRANGE_URL      = 'http://127.0.0.1:9002'

# ── Metadata per label ─────────────────────────────────────────────────────────
META = {
    # label : (severity, category, friendly_name)
    'LS01': ('HIGH',     'system',      'SSH Brute Force'),
    'LS02': ('CRITICAL', 'system',      'Dirty COW / ASLR Disabled'),
    'LS03': ('CRITICAL', 'system',      'Sudo Privilege Escalation'),
    'LS04': ('HIGH',     'system',      'Cronjob Misconfiguration'),
    'LS05': ('CRITICAL', 'network',     'MySQL Remote Root Brute Force'),
    'LS06': ('MEDIUM',   'network',     'FTP Anonymous Login'),
    'LS07': ('MEDIUM',   'system',      'Weak File Permissions'),
    'LS08': ('CRITICAL', 'system',      'Unpatched Kernel / ASLR Disabled'),
    'LS09': ('HIGH',     'system',      'SUID Binary Misconfiguration'),
    'LS10': ('HIGH',     'network',     'NFS no_root_squash'),
    'LS11': ('HIGH',     'system',      'Plaintext Credentials in Config'),
    'LS12': ('MEDIUM',   'network',     'Unnecessary Open Ports / No Firewall'),
    'LS13': ('MEDIUM',   'system',      'Log Tampering / Audit Disabled'),
    'LS14': ('LOW',      'application', 'Insecure Service Configuration'),
    'LC01': ('CRITICAL', 'system',      'Dirty COW / ASLR Disabled'),
    'LC02': ('CRITICAL', 'system',      'World-Writable /etc/passwd'),
    'LC03': ('MEDIUM',   'system',      'World-Writable Dirs with Sensitive Data'),
    'LC04': ('HIGH',     'system',      'Writable Cron Jobs'),
    'LC05': ('MEDIUM',   'system',      'Weak User Passwords'),
    'LC06': ('HIGH',     'system',      'Unprotected SSH Private Keys'),
    'LC07': ('MEDIUM',   'network',     'No Host Firewall'),
    'LC08': ('CRITICAL', 'system',      'Kernel Hardening Disabled'),
    'LC09': ('LOW',      'system',      'Sensitive Data in Bash History'),
    'LC10': ('CRITICAL', 'system',      'LXD Group Privilege Escalation'),
    'LC11': ('HIGH',     'system',      'Exposed API Keys in Environment'),
    'LC12': ('CRITICAL', 'network',     'Netcat Backdoor Listener'),
    'LC13': ('CRITICAL', 'system',      'World Writable passwd/shadow'),
    'LC14': ('LOW',      'network',     'RPC Portmapper Exposed'),
    'LC15': ('CRITICAL', 'system',      'Dirty COW Simulation'),
    'VL01': ('HIGH',     'application', 'vulnlab SQL Injection'),
    'VL02': ('MEDIUM',   'application', 'vulnlab Reflected XSS'),
    'VL03': ('HIGH',     'application', 'vulnlab IDOR'),
    'VL04': ('CRITICAL', 'application', 'vulnlab Command Injection'),
    'VL05': ('HIGH',     'application', 'vulnlab Local File Inclusion'),
    'CR01': ('CRITICAL', 'application', 'cyberrange-lab SQLi Login Bypass'),
    'CR02': ('MEDIUM',   'application', 'cyberrange-lab Reflected XSS'),
    'CR03': ('HIGH',     'application', 'cyberrange-lab IDOR'),
    'CR04': ('HIGH',     'application', 'cyberrange-lab Local File Inclusion'),
}

SEVERITY_POINTS = {'CRITICAL': 150, 'HIGH': 100, 'MEDIUM': 75, 'LOW': 50}

# ── Low-level helpers ──────────────────────────────────────────────────────────

def run(cmd: str, timeout: int = 5) -> str:
    """Run a shell command and return combined stdout+stderr as a string."""
    try:
        return subprocess.run(
            cmd, shell=True, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            timeout=timeout
        ).stdout.strip()
    except Exception as e:
        return str(e)

def read(path: str) -> str:
    """Read a file silently, return empty string on any error."""
    try:
        return Path(path).read_text(errors='ignore')
    except Exception:
        return ''

def exists(path: str) -> bool:
    return Path(path).exists()

def file_mode(path: str):
    """Return permission bits or None if file doesn't exist."""
    try:
        return stat.S_IMODE(Path(path).stat().st_mode)
    except Exception:
        return None

def is_world_writable(path: str) -> bool:
    m = file_mode(path)
    return m is not None and bool(m & 0o002)

def has_suid(path: str) -> bool:
    try:
        return bool(Path(path).stat().st_mode & stat.S_ISUID)
    except Exception:
        return False

def port_listening(port: int) -> bool:
    out = run(
        f"ss -ltnup 2>/dev/null | grep -E ':{port}\\b' || "
        f"netstat -tulnp 2>/dev/null | grep -E ':{port}\\b'", 3
    )
    return bool(out.strip())

def service_active(name: str) -> bool:
    return 'active' in run(f'systemctl is-active {name} 2>/dev/null', 3).lower()

def sysctl(key: str) -> str:
    proc_path = '/proc/sys/' + key.replace('.', '/')
    if exists(proc_path):
        return read(proc_path).strip()
    return run(f'sysctl -n {key} 2>/dev/null', 3).strip()

def http_get(url: str, timeout: int = 4):
    """Return (status_code, body_text) — (0, error_msg) on failure."""
    try:
        r = requests.get(url, timeout=timeout, allow_redirects=True)
        return r.status_code, r.text[:3000]
    except Exception as e:
        return 0, str(e)

def http_post(url: str, data: dict, timeout: int = 4):
    try:
        r = requests.post(url, data=data, timeout=timeout, allow_redirects=True)
        return r.status_code, r.text[:3000]
    except Exception as e:
        return 0, str(e)

# ── vulb.txt parser ────────────────────────────────────────────────────────────

def read_labels(path: str = VULB_TXT) -> set:
    """
    Parse /tmp/vulb.txt.  Each line has the format:
        LS01:CWE-307:SSH Brute Force
    Extract only the first field (the PDF label).
    Lines starting with '#' and blank lines are ignored.
    """
    p = Path(path)
    if not p.exists():
        return set()
    labels = set()
    for line in p.read_text(errors='ignore').splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        label = line.split(':')[0].strip().upper()
        if label:
            labels.add(label)
    return labels

# ── Identity ───────────────────────────────────────────────────────────────────

def identity():
    """Return (team_id, team_name, hostname)."""
    hostname = socket.gethostname() or 'unknown-host'
    clean = lambda s: re.sub(r'[^a-zA-Z0-9_.-]+', '-', s).strip('-').lower() or 'unknown'
    team_id   = clean(hostname)
    team_name = hostname
    return team_id, team_name, hostname

# ── Result builder ─────────────────────────────────────────────────────────────

def make_result(label: str, vulnerable: bool, message: str,
                evidence: str = '', unknown: bool = False) -> dict:
    sev, cat, name = META.get(label, ('MEDIUM', 'system', label))
    status = 'UNKNOWN' if unknown else ('VULNERABLE' if vulnerable else 'PATCHED')
    return {
        'scenario':  label,
        'category':  cat,
        'severity':  sev,
        'difficulty': sev.lower(),
        'status':    status,
        'points':    SEVERITY_POINTS.get(sev, 75),
        'message':   message,
        'evidence':  str(evidence)[:2000],
    }

# ── Vulnerability detectors ────────────────────────────────────────────────────

def check_ls01_lc01_lc15():
    """LS01 / LC01 / LC15 — SSH Brute Force (passwordauth yes + no lockout)."""
    cfg = read('/etc/ssh/sshd_config').lower()
    vuln = (
        ('passwordauthentication yes' in cfg and 'permitrootlogin yes' in cfg)
        or 'maxauthtries 100' in cfg
        or bool(re.search(r'maxauthtries\s+\d{2,}', cfg))
    )
    evidence = '\n'.join(
        l for l in read('/etc/ssh/sshd_config').splitlines()
        if re.search(r'passwordauth|permitroot|maxauthtries', l, re.I)
    )[:500]
    msg = 'SSH allows password auth with unlimited retry (brute-forceable)' if vuln \
          else 'SSH brute-force mitigations in place'
    return make_result('LS01', vuln, msg, evidence)

def check_ls02_lc01_lc15():
    """LS02 / LC01 / LC15 — Dirty COW / ASLR Disabled."""
    aslr = sysctl('kernel.randomize_va_space')
    suid_bash = has_suid('/tmp/vuln_suid_bash')
    marker = exists('/tmp/dirty_cow_vulnerable')
    writ = is_world_writable('/tmp/root_owned_writable')
    vuln = aslr == '0' or suid_bash or marker or writ
    evidence = (f'aslr={aslr} suid_bash={suid_bash} '
                f'marker={marker} world_writable_tmp={writ}')
    msg = 'Dirty COW artifacts present: ASLR disabled or SUID bash in /tmp' if vuln \
          else 'ASLR enabled, no Dirty COW artifacts found'
    return make_result('LS02', vuln, msg, evidence)

def check_ls03():
    """LS03 — Sudo NOPASSWD Privilege Escalation."""
    sudoers = read('/etc/sudoers')
    sudoers_d = run('grep -R "NOPASSWD" /etc/sudoers.d 2>/dev/null', 3)
    combined = (sudoers + sudoers_d).lower()
    # Vulnerable if a non-root user (student / ansible / ubuntu) has NOPASSWD
    vuln = bool(re.search(r'(student|ansible|ubuntu|user)\s.*nopasswd', combined))
    # Also check if /etc/passwd is writable (world-writable passwd means same effect)
    if not vuln:
        vuln = is_world_writable('/etc/passwd')
    evidence = '\n'.join(
        l for l in (sudoers + '\n' + sudoers_d).splitlines()
        if 'nopasswd' in l.lower()
    )[:500]
    msg = 'Unprivileged user has NOPASSWD sudo rights' if vuln \
          else 'No dangerous NOPASSWD sudo entries found'
    return make_result('LS03', vuln, msg, evidence)

def check_ls04_lc04():
    """LS04 / LC04 — Writable Cron Script."""
    c1 = is_world_writable('/opt/cleanup.sh')
    c2 = is_world_writable('/etc/cron.d/vuln_cleanup')
    vuln = c1 or c2
    evidence = (f'/opt/cleanup.sh mode={oct(file_mode("/opt/cleanup.sh") or 0)} '
                f'/etc/cron.d/vuln_cleanup mode={oct(file_mode("/etc/cron.d/vuln_cleanup") or 0)}')
    msg = 'World-writable cron script — root cron job can be hijacked' if vuln \
          else 'Cron scripts have correct permissions'
    return make_result('LS04', vuln, msg, evidence)

def check_ls05():
    """LS05 — MySQL/MariaDB Remote Root (bound to 0.0.0.0)."""
    listening = port_listening(3306)
    cfg_paths = [
        '/etc/mysql/mariadb.conf.d/50-server.cnf',
        '/etc/mysql/mysql.conf.d/mysqld.cnf',
        '/etc/my.cnf',
        '/etc/mysql/my.cnf',
    ]
    cfg = ''.join(read(p) for p in cfg_paths).lower()
    bound_all = 'bind-address' not in cfg or '0.0.0.0' in cfg or '#bind-address' in cfg
    vuln = listening and bound_all
    evidence = f'port_3306_listening={listening} bind_unrestricted={bound_all}'
    msg = 'MariaDB/MySQL exposed on all interfaces — remote root brute-force possible' if vuln \
          else 'MySQL not exposed remotely'
    return make_result('LS05', vuln, msg, evidence)

def check_ls06():
    """LS06 — FTP Anonymous Login Enabled."""
    cfg = read('/etc/vsftpd.conf').lower()
    vuln = 'anonymous_enable=yes' in cfg or 'no_anon_password=yes' in cfg
    evidence = '\n'.join(l for l in read('/etc/vsftpd.conf').splitlines()
                         if 'anon' in l.lower())[:400]
    msg = 'vsftpd allows anonymous login' if vuln else 'Anonymous FTP login disabled'
    return make_result('LS06', vuln, msg, evidence)

def check_ls07():
    """LS07 — Weak Permissions on Sensitive Files."""
    targets = ['/etc/shadow', '/etc/sudoers', '/etc/passwd', '/etc/crontab']
    bad = [p for p in targets if is_world_writable(p)]
    # Also check shadow specifically — should be 640 or 600
    shadow_mode = file_mode('/etc/shadow')
    if shadow_mode is not None and shadow_mode not in (0o640, 0o600):
        if '/etc/shadow' not in bad:
            bad.append('/etc/shadow')
    vuln = bool(bad)
    evidence = ', '.join(f'{p}:{oct(file_mode(p) or 0)}' for p in bad) or 'permissions OK'
    msg = f'Sensitive files with dangerous permissions: {", ".join(bad)}' if vuln \
          else 'Sensitive file permissions are correctly restricted'
    return make_result('LS07', vuln, msg, evidence)

def check_ls08_lc08():
    """LS08 / LC08 — Kernel Hardening Disabled (ASLR, kptr, ptrace, syncookies)."""
    keys = {
        'kernel.randomize_va_space': ('0', 'ASLR'),
        'kernel.kptr_restrict':      ('0', 'kptr_restrict'),
        'kernel.yama.ptrace_scope':  ('0', 'ptrace_scope'),
        'net.ipv4.tcp_syncookies':   ('0', 'syncookies'),
    }
    bad = []
    vals = {}
    for k, (vuln_val, label) in keys.items():
        v = sysctl(k)
        vals[label] = v
        if v == vuln_val:
            bad.append(label)
    vuln = bool(bad)
    evidence = str(vals)
    msg = f'Kernel hardening disabled: {", ".join(bad)}' if vuln \
          else 'Kernel hardening parameters look healthy'
    return make_result('LS08', vuln, msg, evidence)

def check_ls09():
    """LS09 — Malicious SUID Binaries in /tmp."""
    targets = ['/tmp/bash_suid', '/tmp/find_suid', '/tmp/python3_suid']
    bad = [p for p in targets if has_suid(p)]
    vuln = bool(bad)
    evidence = str(bad) if bad else 'No unexpected SUID binaries found in /tmp'
    msg = f'Unexpected SUID binaries found: {", ".join(bad)}' if vuln \
          else 'No SUID abuse artifacts in /tmp'
    return make_result('LS09', vuln, msg, evidence)

def check_ls10():
    """LS10 — NFS no_root_squash."""
    exports = read('/etc/exports')
    vuln = 'no_root_squash' in exports
    evidence = exports[:400] or '/etc/exports not found'
    msg = 'NFS exports use no_root_squash — remote root possible' if vuln \
          else 'NFS exports are correctly squashing root'
    return make_result('LS10', vuln, msg, evidence)

def check_ls11():
    """LS11 — Plaintext Credentials in Config/Log Files."""
    paths = [
        '/opt/app/config/database.conf',
        '/opt/app/config/app.env',
        '/var/log/app/app.log',
    ]
    found = []
    for p in paths:
        if exists(p) and re.search(r'pass(word)?|secret|token|aws_secret|api_key',
                                    read(p), re.I):
            found.append(p)
    vuln = bool(found)
    evidence = '\n'.join(
        f'{p}: {read(p)[:200]}' for p in found
    )[:600] or 'No plaintext credential files found'
    msg = f'Plaintext credentials found in: {", ".join(found)}' if vuln \
          else 'No plaintext credential artifacts found'
    return make_result('LS11', vuln, msg, evidence)

def check_ls12():
    """LS12 — Unnecessary Open Ports / Firewall Disabled."""
    ufw_out = run('ufw status 2>/dev/null', 3).lower()
    fw_off = 'inactive' in ufw_out
    iptables_accept = 'policy accept' in run('iptables -S 2>/dev/null', 3).lower()
    backdoor_open = port_listening(4444) or port_listening(8888)
    vuln = fw_off or backdoor_open
    evidence = f'ufw={ufw_out[:80]} backdoor_4444={port_listening(4444)}'
    msg = 'Firewall inactive or backdoor ports open (4444/8888)' if vuln \
          else 'Firewall active and no unexpected listener ports'
    return make_result('LS12', vuln, msg, evidence)

def check_ls13():
    """LS13 — Log Tampering / Audit Disabled."""
    auth_writable   = is_world_writable('/var/log/auth.log')
    syslog_writable = is_world_writable('/var/log/syslog')
    auditd_running  = service_active('auditd')
    vuln = auth_writable or syslog_writable or not auditd_running
    evidence = (f'auth_log_writable={auth_writable} syslog_writable={syslog_writable} '
                f'auditd_active={auditd_running}')
    msg = 'Log files world-writable or auditd not running — log tampering possible' if vuln \
          else 'Audit logs are protected and auditd is running'
    return make_result('LS13', vuln, msg, evidence)

def check_ls14():
    """LS14 — Insecure Service Configuration (Apache banner / MOTD disclosure)."""
    apache_cfg = (read('/etc/apache2/apache2.conf') + ' ' +
                  read('/etc/apache2/conf-enabled/security.conf')).lower()
    motd = read('/etc/motd').lower()
    vuln = (
        'servertokens full'  in apache_cfg or
        'serversignature on' in apache_cfg or
        'options indexes'    in apache_cfg or
        'openssh_'           in motd
    )
    evidence = '\n'.join(
        l for l in (apache_cfg + '\n' + motd).splitlines()
        if re.search(r'servertokens|serversignature|options indexes|openssh_', l, re.I)
    )[:400] or 'No obvious banner disclosure'
    msg = 'Apache/service banner reveals version information' if vuln \
          else 'Service banners appear hardened'
    return make_result('LS14', vuln, msg, evidence)

def check_lc02_lc13():
    """LC02 / LC13 — World-Writable /etc/passwd or /etc/shadow."""
    p_writable = is_world_writable('/etc/passwd')
    s_writable = is_world_writable('/etc/shadow')
    vuln = p_writable or s_writable
    evidence = (f'passwd={oct(file_mode("/etc/passwd") or 0)} '
                f'shadow={oct(file_mode("/etc/shadow") or 0)}')
    msg = 'Critical auth files are world-writable — any user can modify /etc/passwd' if vuln \
          else '/etc/passwd and /etc/shadow have correct permissions'
    return make_result('LC02', vuln, msg, evidence)

def check_lc03():
    """LC03 — World-Writable Sensitive Directories."""
    targets = ['/opt/shared', '/srv/data', '/var/app']
    bad = [p for p in targets if is_world_writable(p)]
    # Also check for planted internal notes
    note_exists = exists('/opt/shared/internal_notes.txt')
    vuln = bool(bad) or note_exists
    evidence = str(bad) + (f'  internal_notes={note_exists}' if note_exists else '')
    msg = f'World-writable sensitive directories: {", ".join(bad)}' if vuln \
          else 'Sensitive directories have restricted permissions'
    return make_result('LC03', vuln, msg, evidence)

def check_lc05():
    """LC05 — Weak User Password Policy."""
    pam_cfg = read('/etc/pam.d/common-password').lower()
    no_policy = 'pam_pwquality' not in pam_cfg and 'pam_cracklib' not in pam_cfg
    # Check if weak default users were created by the injection script
    weak_users = run('getent passwd alice bob charlie david 2>/dev/null', 3)
    vuln = no_policy or bool(weak_users.strip())
    evidence = f'pam_pwquality_missing={no_policy} weak_users={bool(weak_users.strip())}'
    msg = 'No password complexity policy and/or weak test users present' if vuln \
          else 'Password policy is enforced'
    return make_result('LC05', vuln, msg, evidence)

def check_lc06():
    """LC06 — Unprotected SSH Private Keys."""
    paths = ['/home/ansible/.ssh/id_rsa', '/tmp/admin_ssh_key']
    bad = [p for p in paths if exists(p) and (file_mode(p) or 0) & 0o077]
    vuln = bool(bad)
    evidence = ', '.join(f'{p}:{oct(file_mode(p) or 0)}' for p in bad) \
               or 'No exposed private keys found'
    msg = f'Private SSH keys with loose permissions: {", ".join(bad)}' if vuln \
          else 'SSH private key permissions are secure'
    return make_result('LC06', vuln, msg, evidence)

def check_lc07():
    """LC07 — No Host Firewall."""
    ufw = run('ufw status 2>/dev/null', 3).lower()
    vuln = 'inactive' in ufw
    evidence = ufw[:200]
    msg = 'Host firewall (ufw) is inactive' if vuln \
          else 'Host firewall is active'
    return make_result('LC07', vuln, msg, evidence)

def check_lc09():
    """LC09 — Sensitive Data in Bash History."""
    paths = ['/root/.bash_history', '/home/ansible/.bash_history']
    evidence_parts = []
    vuln = False
    for p in paths:
        content = read(p)
        if re.search(r'pass|password|Admin@123|mysql|secret|abc@123', content, re.I):
            vuln = True
            evidence_parts.append(f'{p}: sensitive commands found')
    evidence = '; '.join(evidence_parts) or 'No sensitive data in shell history'
    msg = 'Passwords/secrets found in shell history files' if vuln \
          else 'Shell history files appear clean'
    return make_result('LC09', vuln, msg, evidence)

def check_lc10():
    """LC10 — LXD Group Privilege Escalation."""
    lxduser = run('id lxduser 2>/dev/null', 3)
    lxd_group = run('getent group lxd 2>/dev/null', 3)
    docker_group = run('getent group docker 2>/dev/null', 3)
    vuln = bool(lxduser.strip()) and (
        'lxduser' in lxd_group or
        'lxduser' in docker_group
    )
    evidence = f'lxduser_exists={bool(lxduser)} lxd_group={lxd_group[:100]}'
    msg = 'lxduser exists and is in lxd/docker group — container escape possible' if vuln \
          else 'No dangerous LXD group membership found'
    return make_result('LC10', vuln, msg, evidence)

def check_lc11():
    """LC11 — Exposed API Keys in Environment Files."""
    env_content = read('/etc/environment') + '\n' + read('/opt/.env')
    vuln = bool(re.search(
        r'AWS_SECRET|GITHUB_TOKEN|DATABASE_URL|SECRET_KEY|REDIS_URL|API_KEY',
        env_content
    ))
    evidence = '\n'.join(
        l for l in env_content.splitlines()
        if re.search(r'SECRET|TOKEN|KEY|DATABASE_URL', l, re.I)
    )[:400] or 'No secrets found in environment files'
    msg = 'API keys / secrets leaked in environment files' if vuln \
          else 'No secret keys found in environment files'
    return make_result('LC11', vuln, msg, evidence)

def check_lc12():
    """LC12 — Netcat Backdoor Listener (port 4444 or 1337)."""
    p4444 = port_listening(4444)
    p1337 = port_listening(1337)
    crontab = read('/etc/crontab')
    persist = 'nc -lvnp 4444' in crontab or 'nc -lvnp 1337' in crontab
    vuln = p4444 or p1337 or persist
    evidence = (f'port_4444={p4444} port_1337={p1337} cron_persistence={persist} '
                + run("ss -ltnp 2>/dev/null | grep -E ':(4444|1337)' || true", 3)[:200])
    msg = 'Netcat backdoor listener active on port 4444 or 1337' if vuln \
          else 'No netcat backdoor listener detected'
    return make_result('LC12', vuln, msg, evidence)

def check_lc14():
    """LC14 — RPC Portmapper Exposed."""
    rpc_active = service_active('rpcbind')
    p111 = port_listening(111)
    vuln = rpc_active or p111
    evidence = f'rpcbind_service={rpc_active} port_111={p111}'
    msg = 'RPC portmapper (rpcbind) is running — NFS enumeration/attack surface exposed' if vuln \
          else 'RPC portmapper is not running'
    return make_result('LC14', vuln, msg, evidence)

# ── Web lab checks (only work when agent runs on web-server-1) ─────────────────

def check_vl01():
    """VL01 — vulnlab SQL Injection."""
    code, txt = http_get(
        VULNLAB_URL + "/?vuln=sqli&q=%25' UNION SELECT id,username,content FROM users JOIN secrets ON 1=1--"
    )
    if code == 0:
        return make_result('VL01', False, 'vulnlab not reachable from this host', unknown=True)
    vuln = 'FLAG{' in txt or ('admin' in txt.lower() and 'secret' in txt.lower())
    msg = 'vulnlab SQLi exploitable — secrets exposed' if vuln else 'vulnlab SQLi not exploitable'
    return make_result('VL01', vuln, msg, txt[:300])

def check_vl02():
    """VL02 — vulnlab Reflected XSS."""
    payload = '<img src=x onerror=alert(1)>'
    code, txt = http_get(VULNLAB_URL + '/?vuln=xss&review=' +
                         requests.utils.quote(payload))
    if code == 0:
        return make_result('VL02', False, 'vulnlab not reachable', unknown=True)
    vuln = payload in txt
    msg = 'vulnlab XSS payload reflected in response' if vuln else 'vulnlab XSS not triggering'
    return make_result('VL02', vuln, msg, txt[:200])

def check_vl03():
    """VL03 — vulnlab IDOR."""
    code, txt = http_get(VULNLAB_URL + '/?vuln=idor&id=3')
    if code == 0:
        return make_result('VL03', False, 'vulnlab not reachable', unknown=True)
    vuln = 'admin' in txt.lower() and ('password' in txt.lower() or 's3cr3t' in txt.lower())
    msg = 'vulnlab IDOR exposes admin account details' if vuln else 'vulnlab IDOR not exploitable'
    return make_result('VL03', vuln, msg, txt[:300])

def check_vl04():
    """VL04 — vulnlab Command Injection."""
    code, txt = http_get(VULNLAB_URL + '/?vuln=cmdi&host=127.0.0.1%3B%20id')
    if code == 0:
        return make_result('VL04', False, 'vulnlab not reachable', unknown=True)
    vuln = 'uid=' in txt or 'gid=' in txt or 'FLAG{' in txt
    msg = 'vulnlab CMDi executes OS commands' if vuln else 'vulnlab CMDi not exploitable'
    return make_result('VL04', vuln, msg, txt[:300])

def check_vl05():
    """VL05 — vulnlab LFI."""
    code, txt = http_get(VULNLAB_URL + '/?vuln=lfi&page=/var/lib/vulnlab/.flag')
    if code == 0:
        return make_result('VL05', False, 'vulnlab not reachable', unknown=True)
    vuln = 'FLAG{' in txt or 'vulnlab_filesystem' in txt
    msg = 'vulnlab LFI reads flag file from server' if vuln else 'vulnlab LFI not exploitable'
    return make_result('VL05', vuln, msg, txt[:300])

def check_cr01():
    """CR01 — cyberrange-lab SQL Injection Login Bypass."""
    code, txt = http_post(CYBERRANGE_URL + '/?page=login',
                           {'username': "' OR '1'='1'--", 'password': 'x'})
    if code == 0:
        return make_result('CR01', False, 'cyberrange-lab not reachable', unknown=True)
    vuln = 'admin' in txt.lower() or 'dashboard' in txt.lower()
    msg = 'cyberrange-lab SQLi auth bypass successful' if vuln else 'cyberrange-lab SQLi not exploitable'
    return make_result('CR01', vuln, msg, txt[:300])

def check_cr02():
    """CR02 — cyberrange-lab Reflected XSS."""
    payload = '<img src=x onerror=alert(1)>'
    code, txt = http_get(CYBERRANGE_URL + '/?page=search&q=' + requests.utils.quote(payload))
    if code == 0:
        return make_result('CR02', False, 'cyberrange-lab not reachable', unknown=True)
    vuln = payload in txt
    msg = 'cyberrange-lab XSS payload reflected' if vuln else 'cyberrange-lab XSS not triggering'
    return make_result('CR02', vuln, msg, txt[:200])

def check_cr03():
    """CR03 — cyberrange-lab IDOR."""
    code, txt = http_get(CYBERRANGE_URL + '/?page=profile&id=1')
    if code == 0:
        return make_result('CR03', False, 'cyberrange-lab not reachable', unknown=True)
    vuln = ('adhar' in txt.lower() or 'aadhar' in txt.lower() or
            'supersecretadmin' in txt.lower() or 'administrator' in txt.lower())
    msg = 'cyberrange-lab IDOR exposes sensitive profile data' if vuln \
          else 'cyberrange-lab IDOR not exploitable'
    return make_result('CR03', vuln, msg, txt[:300])

def check_cr04():
    """CR04 — cyberrange-lab LFI."""
    code, txt = http_get(CYBERRANGE_URL + '/?page=lfi&file=../config.php')
    if code == 0:
        return make_result('CR04', False, 'cyberrange-lab not reachable', unknown=True)
    vuln = 'db_pass' in txt.lower() or 'webapp123' in txt.lower() or 'root:' in txt
    msg = 'cyberrange-lab LFI reads server-side config' if vuln \
          else 'cyberrange-lab LFI not exploitable'
    return make_result('CR04', vuln, msg, txt[:300])

# ── Dispatch table ─────────────────────────────────────────────────────────────
# Maps label -> check function.  Alias labels share the same function.

CHECKS = {
    'LS01': check_ls01_lc01_lc15,
    'LS02': check_ls02_lc01_lc15,
    'LS03': check_ls03,
    'LS04': check_ls04_lc04,
    'LS05': check_ls05,
    'LS06': check_ls06,
    'LS07': check_ls07,
    'LS08': check_ls08_lc08,
    'LS09': check_ls09,
    'LS10': check_ls10,
    'LS11': check_ls11,
    'LS12': check_ls12,
    'LS13': check_ls13,
    'LS14': check_ls14,
    # LC aliases ─────────────────────────────────────
    'LC01': check_ls02_lc01_lc15,   # alias: dirty_cow
    'LC02': check_lc02_lc13,
    'LC03': check_lc03,
    'LC04': check_ls04_lc04,        # alias: cronjob
    'LC05': check_lc05,
    'LC06': check_lc06,
    'LC07': check_lc07,
    'LC08': check_ls08_lc08,        # alias: kernel hardening
    'LC09': check_lc09,
    'LC10': check_lc10,
    'LC11': check_lc11,
    'LC12': check_lc12,
    'LC13': check_lc02_lc13,        # alias: passwd/shadow writable
    'LC14': check_lc14,
    'LC15': check_ls02_lc01_lc15,   # alias: dirty_cow
    # Web lab checks ─────────────────────────────────
    'VL01': check_vl01,
    'VL02': check_vl02,
    'VL03': check_vl03,
    'VL04': check_vl04,
    'VL05': check_vl05,
    'CR01': check_cr01,
    'CR02': check_cr02,
    'CR03': check_cr03,
    'CR04': check_cr04,
}

# ── Fix result labels — aliases write the correct label, not the function's ───

def run_check(label: str) -> dict:
    """Run the check for a given label.  Fix scenario field to match actual label."""
    fn = CHECKS.get(label)
    if fn is None:
        sev, cat, name = META.get(label, ('MEDIUM', 'system', label))
        return make_result(label, False,
                           f'No detector implemented for {label}',
                           unknown=True)
    result = fn()
    result['scenario'] = label   # ensure the label matches what's in vulb.txt
    # Look up the correct metadata for this specific label
    if label in META:
        sev, cat, name = META[label]
        result['severity']   = sev
        result['category']   = cat
        result['difficulty'] = sev.lower()
        result['points']     = SEVERITY_POINTS.get(sev, 75)
    return result

# ── Scan and report ────────────────────────────────────────────────────────────

def scan_once():
    labels = read_labels(VULB_TXT)
    if not labels:
        print(f'[{time.strftime("%H:%M:%S")}] vulb.txt empty or not found — reporting zero score',
              flush=True)
        # Still report so machine appears on leaderboard with 0 score
        team_id, team_name, hostname = identity()
        payload = {
            'team_id':            team_id,
            'team_name':          team_name,
            'host':               hostname,
            'host_name':          hostname,
            'cycle_id':           str(uuid.uuid4()),
            'replace_host_state': True,
            'items':              [],
        }
        try:
            r = requests.post(LEADERBOARD_URL, json=payload, timeout=REQUEST_TIMEOUT)
            print(f'[{time.strftime("%H:%M:%S")}] {hostname} — registered with 0 score → {r.status_code}',
                  flush=True)
        except Exception as e:
            print(f'[{time.strftime("%H:%M:%S")}] Report failed: {e}', flush=True)
        return

    items = []
    for label in sorted(labels):
        try:
            items.append(run_check(label))
        except Exception as e:
            sev, cat, _ = META.get(label, ('MEDIUM', 'system', label))
            items.append(make_result(label, False, f'Detector error: {e}', unknown=True))

    team_id, team_name, hostname = identity()
    payload = {
        'team_id':            team_id,
        'team_name':          team_name,
        'host':               hostname,
        'host_name':          hostname,
        'cycle_id':           str(uuid.uuid4()),
        'replace_host_state': True,
        'items':              items,
    }

    vuln_count    = sum(1 for i in items if i['status'] == 'VULNERABLE')
    patched_count = sum(1 for i in items if i['status'] == 'PATCHED')
    unknown_count = sum(1 for i in items if i['status'] == 'UNKNOWN')

    try:
        r = requests.post(LEADERBOARD_URL, json=payload, timeout=REQUEST_TIMEOUT)
        print(
            f'[{time.strftime("%H:%M:%S")}] {hostname} — '
            f'{len(items)} checks '
            f'(VULN:{vuln_count} PATCHED:{patched_count} UNKNOWN:{unknown_count}) '
            f'→ {r.status_code}',
            flush=True
        )
    except Exception as e:
        print(f'[{time.strftime("%H:%M:%S")}] Report failed: {e}', flush=True)

# ── Entry point ────────────────────────────────────────────────────────────────

def main():
    _, _, hostname = identity()
    print(f'[INIT] Blue Agent (Linux) started on {hostname}', flush=True)
    print(f'[INIT] vulb.txt: {VULB_TXT}', flush=True)
    print(f'[INIT] Leaderboard: {LEADERBOARD_URL}', flush=True)
    print(f'[INIT] Scan interval: {SCAN_INTERVAL}s', flush=True)

    while True:
        scan_once()
        time.sleep(SCAN_INTERVAL)

if __name__ == '__main__':
    main()
