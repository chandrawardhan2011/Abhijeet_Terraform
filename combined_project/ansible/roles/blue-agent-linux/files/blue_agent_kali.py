"""
Blue Team VM Agent - Cyber Range Patch Validator

Runs every 30 seconds, checks safe/passive vulnerability conditions, and reports
PATCHED / VULNERABLE / UNKNOWN to the scoring dashboard.

Important:
- Use only inside your authorized isolated cyber range.
- Some checks are OS/service specific. Unsupported checks report UNKNOWN instead
  of crashing, so the dashboard shows an alert rather than an error.
- One binary cannot run on both Windows and Linux. Build one Windows .exe on
  Windows and one Linux binary on Linux using the included build scripts.
"""

import ctypes
import getpass
import json
import os
import platform
import re
import smtplib
import socket
import ssl
import subprocess
import sys
import time
from ftplib import FTP
from pathlib import Path
from typing import Any, Dict, List

import requests

CONFIG_PATH = Path.cwd() / "config.json"
if not CONFIG_PATH.exists():
    CONFIG_PATH = Path(__file__).with_name("config.json")

SCENARIOS = {
    "OS_OUTDATED_KERNEL": ("system_os", "high", 100),
    "LINUX_SUID_SGID_REVIEW": ("system_os", "high", 100),
    "WORLD_WRITABLE_SENSITIVE_FILES": ("system_os", "critical", 150),
    "EXCESSIVE_SUDO_NOPASSWD": ("system_os", "critical", 150),
    "MISSING_SECURITY_PATCHES": ("system_os", "high", 100),
    "WIN_UNQUOTED_SERVICE_PATHS": ("system_os", "high", 100),
    "CLEARTEXT_CREDS_IN_SCRIPTS": ("system_os", "high", 100),
    "SSH_ROOT_LOGIN_DISABLED": ("system_os", "high", 100),
    "SSH_WEAK_CIPHERS_DISABLED": ("system_os", "medium", 75),
    "CORE_DUMPS_DISABLED": ("system_os", "medium", 75),
    "WEB_SQLI_BLOCKED": ("web_api", "critical", 150),
    "WEB_XSS_FILTERED": ("web_api", "high", 100),
    "WEB_INSECURE_DESERIALIZATION_REVIEW": ("web_api", "high", 100),
    "WEB_BROKEN_ACCESS_CONTROL_BLOCKED": ("web_api", "critical", 150),
    "WEB_SSRF_BLOCKED": ("web_api", "critical", 150),
    "WEB_SECURITY_HEADERS_PRESENT": ("web_api", "medium", 75),
    "WEB_PATH_TRAVERSAL_BLOCKED": ("web_api", "critical", 150),
    "WEB_DEBUG_DISABLED": ("web_api", "high", 100),
    "WEB_API_DOCS_NOT_PUBLIC": ("web_api", "medium", 75),
    "WEB_VERBOSE_ERRORS_DISABLED": ("web_api", "medium", 75),
    "WEB_DIRECTORY_INDEXING_DISABLED": ("web_server", "high", 100),
    "SERVER_BANNER_HIDDEN": ("web_server", "low", 50),
    "DEFAULT_CREDENTIALS_CHANGED": ("web_server", "high", 100),
    "HTTP_REQUEST_SMUGGLING_REVIEW": ("web_server", "high", 100),
    "RATE_LIMITING_PRESENT": ("web_server", "medium", 75),
    "TLS_LEGACY_DISABLED": ("web_server", "high", 100),
    "APACHE_SYMLINK_FOLLOWING_DISABLED": ("web_server", "medium", 75),
    "APACHE_RISKY_MODULES_DISABLED": ("web_server", "medium", 75),
    "SLOWLORIS_PROTECTION_REVIEW": ("web_server", "medium", 75),
    "PROXY_HEADERS_VALIDATED": ("web_server", "medium", 75),
    "SMTP_OPEN_RELAY_BLOCKED": ("email", "critical", 150),
    "MAIL_SPF_DKIM_DMARC_PRESENT": ("email", "high", 100),
    "SMTP_EXPN_VRFY_DISABLED": ("email", "medium", 75),
    "SMTP_STARTTLS_REQUIRED": ("email", "high", 100),
    "SMTP_ATTACHMENT_LIMIT_PRESENT": ("email", "medium", 75),
    "FTP_ANONYMOUS_DISABLED": ("network_legacy", "high", 100),
    "TELNET_DISABLED": ("network_legacy", "high", 100),
    "FTP_BOUNCE_DISABLED": ("network_legacy", "medium", 75),
    "SMB_SIGNING_ENABLED": ("network_legacy", "high", 100),
    "SNMP_DEFAULT_COMMUNITY_DISABLED": ("network_legacy", "high", 100),
    "PASSWORD_MIN_LENGTH_STRONG": ("identity", "medium", 75),
    "ACCOUNT_LOCKOUT_ENABLED": ("identity", "high", 100),
    "PASSWORD_HISTORY_ENFORCED": ("identity", "medium", 75),
    "MFA_ENFORCED_FOR_ADMIN": ("identity", "high", 100),
    "WIN_AUTOADMINLOGON_DISABLED": ("windows_registry", "critical", 150),
    "WIN_REMOTE_REGISTRY_DISABLED": ("windows_registry", "high", 100),
    "WIN_STICKY_KEYS_CLEAN": ("windows_registry", "critical", 150),
    "WIN_LLMNR_NETBIOS_DISABLED": ("windows_registry", "medium", 75),
    "WIN_ALWAYS_INSTALL_ELEVATED_DISABLED": ("windows_registry", "critical", 150),
    "WIN_LSA_PLAINTEXT_SECRETS_DISABLED": ("windows_registry", "critical", 150),
}

SAFE_XSS = "<script>alert('CYBERRANGE_XSS_TEST')</script>"
SAFE_SQLI = "' OR '1'='1"
SAFE_TRAVERSAL = "../../etc/passwd"



def _clean_id(value: str) -> str:
    """Make a safe, readable ID for API/DB keys."""
    value = (value or "unknown").strip()
    value = re.sub(r"\s+", "-", value)
    value = re.sub(r"[^A-Za-z0-9_.-]", "-", value)
    return value.strip("-_") or "unknown"


def auto_identity() -> tuple[str, str, str]:
    """Return (team_id, team_name, host_name) with no per-PC configuration.

    Leaderboard ranking uses team_name/team_id from the logged-in username.
    Scenario table uses host_name from the computer hostname.
    """
    try:
        username = getpass.getuser() or os.environ.get("USERNAME") or os.environ.get("USER") or "unknown-user"
    except Exception:
        username = os.environ.get("USERNAME") or os.environ.get("USER") or "unknown-user"
    try:
        hostname = socket.gethostname() or platform.node() or "unknown-host"
    except Exception:
        hostname = platform.node() or "unknown-host"

    team_name = username.strip() or "unknown-user"
    team_id = _clean_id(team_name.lower())
    host_name = hostname.strip() or "unknown-host"
    return team_id, team_name, host_name


def load_config() -> Dict[str, Any]:
    auto_team_id, auto_team_name, auto_host_name = auto_identity()
    default = {
        "leaderboard_api": "http://127.0.0.1:8000/api/agent/report_batch",
        # AUTO MODE: leave team_id/team_name/host_name blank in config.json.
        # team_id/team_name = logged-in username, host_name = computer hostname.
        "team_id": auto_team_id,
        "team_name": auto_team_name,
        "host_name": auto_host_name,
        "interval_seconds": 30,
        "require_admin": False,
        "clean_slate": False,
        "local_script_scan_paths": [],
        "web_targets": [],
        "ftp_targets": [],
        "smtp_targets": [],
        "domain": "",
        "ports_to_monitor": [23],
    }
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            user_cfg = json.load(f)
            if isinstance(user_cfg, dict):
                default.update(user_cfg)
    except Exception:
        pass

    # If old config contains empty/null values, fall back to automatic identity.
    if not str(default.get("team_id") or "").strip():
        default["team_id"] = auto_team_id
    if not str(default.get("team_name") or "").strip():
        default["team_name"] = auto_team_name
    if not str(default.get("host_name") or "").strip():
        default["host_name"] = auto_host_name

    default["team_id"] = _clean_id(str(default["team_id"]).lower())
    default["team_name"] = str(default["team_name"]).strip()
    default["host_name"] = str(default["host_name"]).strip()
    return default

def is_windows() -> bool:
    return platform.system().lower() == "windows"


def is_linux() -> bool:
    return platform.system().lower() == "linux"


def is_admin() -> bool:
    try:
        if is_windows():
            return ctypes.windll.shell32.IsUserAnAdmin() != 0
        return os.geteuid() == 0
    except Exception:
        return False


def run_cmd(cmd: str, timeout: int = 10) -> str:
    try:
        p = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return ((p.stdout or "") + "\n" + (p.stderr or "")).strip()
    except Exception as e:
        return f"COMMAND_ERROR: {e}"


def result(name: str, status: str, message: str, evidence: str = "") -> Dict[str, Any]:
    cat, sev, points = SCENARIOS[name]
    status = status.upper()
    if status not in {"PATCHED", "VULNERABLE", "UNKNOWN", "IN_PROGRESS"}:
        status = "UNKNOWN"
    if status == "UNKNOWN" and not message:
        message = "Unable to detect this check on this client/machine"
    return {"scenario": name, "category": cat, "severity": sev, "points": points, "status": status, "message": message, "evidence": (evidence or "")[:800]}


def unknown(name: str, reason: str = "Unable to detect this check on this client/machine") -> Dict[str, Any]:
    return result(name, "UNKNOWN", reason)


def safe(name: str, fn):
    try:
        return fn()
    except Exception as e:
        return unknown(name, f"Unable to detect this check on this client/machine: {e}")


def file_text(path: str) -> str:
    p = Path(path)
    return p.read_text(errors="ignore") if p.exists() else ""


def port_open(host: str, port: int, timeout=2) -> bool:
    try:
        with socket.create_connection((host, int(port)), timeout=timeout):
            return True
    except Exception:
        return False


def http_get(url: str, **kwargs):
    return requests.get(url, timeout=kwargs.pop("timeout", 6), verify=False, **kwargs)


def check_system_os(cfg: Dict[str, Any]) -> List[Dict[str, Any]]:
    out = []

    def os_kernel():
        if is_linux():
            ev = run_cmd("apt list --upgradable 2>/dev/null | grep -Ei 'security|linux-image|kernel' | head -20")
            if "COMMAND_ERROR" in ev:
                return unknown("OS_OUTDATED_KERNEL")
            return result("OS_OUTDATED_KERNEL", "VULNERABLE" if ev else "PATCHED", "Kernel/security update review", ev)
        if is_windows():
            hotfix = run_cmd('powershell -NoProfile -Command "Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 3 | Format-Table -HideTableHeaders"')
            return result("OS_OUTDATED_KERNEL", "UNKNOWN", "Windows kernel CVE verification requires approved KB baseline; latest hotfixes collected", hotfix)
        return unknown("OS_OUTDATED_KERNEL")
    out.append(safe("OS_OUTDATED_KERNEL", os_kernel))

    def suid():
        if not is_linux():
            return unknown("LINUX_SUID_SGID_REVIEW", "Linux-only check")
        suspicious = run_cmd("find / -xdev \\( -perm -4000 -o -perm -2000 \\) -type f 2>/dev/null | head -50", 20)
        known_ok = ["/usr/bin/sudo", "/usr/bin/passwd", "/usr/bin/su", "/usr/bin/chsh", "/usr/bin/chfn", "/usr/bin/mount", "/usr/bin/umount"]
        bad = [x for x in suspicious.splitlines() if x and x not in known_ok]
        return result("LINUX_SUID_SGID_REVIEW", "VULNERABLE" if bad else "PATCHED", "Unexpected SUID/SGID files review", "\n".join(bad))
    out.append(safe("LINUX_SUID_SGID_REVIEW", suid))

    def world_write():
        if not is_linux():
            return unknown("WORLD_WRITABLE_SENSITIVE_FILES", "Linux sensitive-file permission check not applicable on Windows")
        bad = []
        for t in ["/etc/passwd", "/etc/shadow", "/etc/sudoers"]:
            p = Path(t)
            if p.exists() and bool(p.stat().st_mode & 0o002):
                bad.append(t)
        return result("WORLD_WRITABLE_SENSITIVE_FILES", "VULNERABLE" if bad else "PATCHED", "Sensitive files world-writable check", "\n".join(bad))
    out.append(safe("WORLD_WRITABLE_SENSITIVE_FILES", world_write))

    def sudo_np():
        if not is_linux():
            return unknown("EXCESSIVE_SUDO_NOPASSWD", "Linux sudoers check not applicable on Windows")
        data = file_text("/etc/sudoers")
        if Path("/etc/sudoers.d").exists():
            for d in Path("/etc/sudoers.d").glob("*"):
                if d.is_file():
                    data += "\n" + d.read_text(errors="ignore")
        bad = re.findall(r"^[^#\n].*NOPASSWD:\s*ALL", data, re.M)
        return result("EXCESSIVE_SUDO_NOPASSWD", "VULNERABLE" if bad else "PATCHED", "NOPASSWD sudo rule review", "\n".join(bad))
    out.append(safe("EXCESSIVE_SUDO_NOPASSWD", sudo_np))

    def missing_patches():
        if is_linux():
            ev = run_cmd("apt list --upgradable 2>/dev/null | head -30")
            return result("MISSING_SECURITY_PATCHES", "VULNERABLE" if ev and "Listing..." not in ev else "PATCHED", "Package update review", ev)
        if is_windows():
            q = run_cmd("powershell -NoProfile -Command \"$s=New-Object -ComObject Microsoft.Update.Session; $s.CreateUpdateSearcher().Search(\'IsInstalled=0\').Updates.Count\"", 20)
            m = re.search(r"\d+", q)
            if m:
                return result("MISSING_SECURITY_PATCHES", "VULNERABLE" if int(m.group()) > 0 else "PATCHED", "Windows Update pending count", q)
            return unknown("MISSING_SECURITY_PATCHES", "Unable to query Windows Update pending count")
        return unknown("MISSING_SECURITY_PATCHES")
    out.append(safe("MISSING_SECURITY_PATCHES", missing_patches))

    def unquoted():
        if not is_windows():
            return unknown("WIN_UNQUOTED_SERVICE_PATHS", "Windows-only check")
        ps = """powershell -NoProfile -Command "Get-CimInstance Win32_Service | Where-Object {$_.PathName -match ' ' -and $_.PathName -notmatch '^\\\"' -and $_.PathName -match '\\\\.exe'} | Select-Object -ExpandProperty Name" """
        ev = run_cmd(ps)
        return result("WIN_UNQUOTED_SERVICE_PATHS", "VULNERABLE" if ev else "PATCHED", "Windows unquoted service path review", ev)
    out.append(safe("WIN_UNQUOTED_SERVICE_PATHS", unquoted))

    def clear_creds():
        paths = cfg.get("local_script_scan_paths") or ([] if is_windows() else ["/opt", "/var/www", "/home"])
        if not paths:
            return unknown("CLEARTEXT_CREDS_IN_SCRIPTS", "No local_script_scan_paths configured")
        patterns = re.compile(r"(password\s*=|passwd\s*=|pwd\s*=|api[_-]?key\s*=|secret\s*=)", re.I)
        hits = []
        for root in paths:
            rootp = Path(root)
            if not rootp.exists():
                continue
            for ext in ("*.sh", "*.ps1", "*.py", "*.env", "*.conf"):
                for f in list(rootp.rglob(ext))[:150]:
                    try:
                        if patterns.search(f.read_text(errors="ignore")[:5000]):
                            hits.append(str(f))
                    except Exception:
                        pass
        return result("CLEARTEXT_CREDS_IN_SCRIPTS", "VULNERABLE" if hits else "PATCHED", "Hardcoded credential pattern review", "\n".join(hits[:20]))
    out.append(safe("CLEARTEXT_CREDS_IN_SCRIPTS", clear_creds))

    def ssh_root():
        if not is_linux():
            return unknown("SSH_ROOT_LOGIN_DISABLED", "Linux/OpenSSH config check not applicable")
        sshd = file_text("/etc/ssh/sshd_config")
        bad = re.search(r"^\s*PermitRootLogin\s+(yes|without-password|prohibit-password)", sshd, re.I | re.M)
        good = re.search(r"^\s*PermitRootLogin\s+no", sshd, re.I | re.M)
        return result("SSH_ROOT_LOGIN_DISABLED", "PATCHED" if good and not bad else "VULNERABLE", "PermitRootLogin should be no")
    out.append(safe("SSH_ROOT_LOGIN_DISABLED", ssh_root))

    def ssh_ciphers():
        if not is_linux():
            return unknown("SSH_WEAK_CIPHERS_DISABLED", "Linux/OpenSSH config check not applicable")
        sshd = file_text("/etc/ssh/sshd_config")
        weak = re.search(r"(3des|arcfour|rc4|cbc)", sshd, re.I)
        return result("SSH_WEAK_CIPHERS_DISABLED", "VULNERABLE" if weak else "PATCHED", "Weak SSH cipher keyword review", weak.group(0) if weak else "")
    out.append(safe("SSH_WEAK_CIPHERS_DISABLED", ssh_ciphers))

    def core_dumps():
        if is_linux():
            limits = file_text("/etc/security/limits.conf") + "\n" + run_cmd("sysctl fs.suid_dumpable")
            bad = "fs.suid_dumpable = 1" in limits or "core unlimited" in limits
            return result("CORE_DUMPS_DISABLED", "VULNERABLE" if bad else "PATCHED", "Core dump setting review", limits)
        if is_windows():
            wer = run_cmd(r'reg query "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps"', 5)
            return result("CORE_DUMPS_DISABLED", "VULNERABLE" if "DumpFolder" in wer else "PATCHED", "Windows LocalDumps registry review", wer)
        return unknown("CORE_DUMPS_DISABLED")
    out.append(safe("CORE_DUMPS_DISABLED", core_dumps))
    return out


def check_web(cfg: Dict[str, Any]) -> List[Dict[str, Any]]:
    names = ["WEB_SQLI_BLOCKED","WEB_XSS_FILTERED","WEB_INSECURE_DESERIALIZATION_REVIEW","WEB_BROKEN_ACCESS_CONTROL_BLOCKED","WEB_SSRF_BLOCKED","WEB_SECURITY_HEADERS_PRESENT","WEB_PATH_TRAVERSAL_BLOCKED","WEB_DEBUG_DISABLED","WEB_API_DOCS_NOT_PUBLIC","WEB_VERBOSE_ERRORS_DISABLED","WEB_DIRECTORY_INDEXING_DISABLED","SERVER_BANNER_HIDDEN","DEFAULT_CREDENTIALS_CHANGED","HTTP_REQUEST_SMUGGLING_REVIEW","RATE_LIMITING_PRESENT","TLS_LEGACY_DISABLED","APACHE_SYMLINK_FOLLOWING_DISABLED","APACHE_RISKY_MODULES_DISABLED","SLOWLORIS_PROTECTION_REVIEW","PROXY_HEADERS_VALIDATED"]
    targets = cfg.get("web_targets", [])
    if not targets:
        return [unknown(x, "No web_targets configured") for x in names]
    out = []
    for t in targets:
        base = t.get("base_url", "").rstrip("/")
        if not base:
            out.extend([unknown(x, "base_url missing") for x in names])
            continue
        try:
            r = http_get(base)
            headers = r.headers
            sec = "Content-Security-Policy" in headers and (not base.startswith("https://") or "Strict-Transport-Security" in headers)
            out.append(result("WEB_SECURITY_HEADERS_PRESENT", "PATCHED" if sec else "VULNERABLE", "CSP/HSTS security header review", str(dict(headers))))
            banner = headers.get("Server", "") + " " + headers.get("X-Powered-By", "")
            out.append(result("SERVER_BANNER_HIDDEN", "VULNERABLE" if re.search(r"\d+\.\d+|apache|nginx|uvicorn|gunicorn|php|express", banner, re.I) else "PATCHED", "Server/X-Powered-By banner review", banner))
            debug = any(x in r.text.lower() for x in ["traceback", "debugger", "werkzeug", "django debug", "stack trace"])
            verbose = any(x in r.text.lower() for x in ["sql syntax", "odbc", "jdbc", "ora-", "mysql", "sqlite", "traceback"])
            out.append(result("WEB_DEBUG_DISABLED", "VULNERABLE" if debug else "PATCHED", "Debug/stack-trace marker review"))
            out.append(result("WEB_VERBOSE_ERRORS_DISABLED", "VULNERABLE" if verbose else "PATCHED", "Verbose error marker review"))
        except Exception as e:
            for sc in ["WEB_SECURITY_HEADERS_PRESENT","SERVER_BANNER_HIDDEN","WEB_DEBUG_DISABLED","WEB_VERBOSE_ERRORS_DISABLED"]:
                out.append(unknown(sc, f"Unable to reach web base URL {base}: {e}"))

        if t.get("sqli_url"):
            try:
                rr = http_get(t["sqli_url"], params={t.get("sqli_param", "q"): SAFE_SQLI})
                bad = any(x in rr.text.lower() for x in ["sql syntax", "sqlite", "mysql", "odbc", "you have an error in your sql"])
                out.append(result("WEB_SQLI_BLOCKED", "VULNERABLE" if bad else "PATCHED", "Safe SQLi error-pattern check"))
            except Exception as e:
                out.append(unknown("WEB_SQLI_BLOCKED", str(e)))
        else: out.append(unknown("WEB_SQLI_BLOCKED", "No sqli_url configured"))

        if t.get("xss_url"):
            try:
                rr = http_get(t["xss_url"], params={t.get("xss_param", "q"): SAFE_XSS})
                out.append(result("WEB_XSS_FILTERED", "VULNERABLE" if SAFE_XSS in rr.text else "PATCHED", "Safe reflected XSS payload encoding/blocking check"))
            except Exception as e:
                out.append(unknown("WEB_XSS_FILTERED", str(e)))
        else: out.append(unknown("WEB_XSS_FILTERED", "No xss_url configured"))

        scan_paths = t.get("code_scan_paths") or cfg.get("local_script_scan_paths") or []
        hits = []
        for root in scan_paths:
            rp = Path(root)
            if rp.exists():
                for f in list(rp.rglob("*.py"))[:200]:
                    try:
                        txt = f.read_text(errors="ignore")
                        if re.search(r"pickle\.loads|yaml\.load\(", txt):
                            hits.append(str(f))
                    except Exception: pass
        out.append(result("WEB_INSECURE_DESERIALIZATION_REVIEW", "VULNERABLE" if hits else ("PATCHED" if scan_paths else "UNKNOWN"), "pickle.loads/yaml.load pattern review" if scan_paths else "No code_scan_paths configured", "\n".join(hits)))

        if t.get("admin_url"):
            try:
                rr = http_get(t["admin_url"], allow_redirects=False)
                out.append(result("WEB_BROKEN_ACCESS_CONTROL_BLOCKED", "VULNERABLE" if rr.status_code == 200 else "PATCHED", "Unauthenticated admin URL access check", str(rr.status_code)))
            except Exception as e: out.append(unknown("WEB_BROKEN_ACCESS_CONTROL_BLOCKED", str(e)))
        else: out.append(unknown("WEB_BROKEN_ACCESS_CONTROL_BLOCKED", "No admin_url configured"))

        if t.get("ssrf_url"):
            try:
                rr = http_get(t["ssrf_url"], params={t.get("ssrf_param", "url"): "http://127.0.0.1:1"})
                bad = any(x in rr.text.lower() for x in ["connection refused", "localhost", "127.0.0.1"])
                out.append(result("WEB_SSRF_BLOCKED", "VULNERABLE" if bad else "PATCHED", "Safe localhost SSRF marker check"))
            except Exception as e: out.append(result("WEB_SSRF_BLOCKED", "PATCHED", f"SSRF request blocked/unreachable: {e}"))
        else: out.append(unknown("WEB_SSRF_BLOCKED", "No ssrf_url configured"))

        if t.get("traversal_url"):
            try:
                rr = http_get(t["traversal_url"], params={t.get("traversal_param", "file"): SAFE_TRAVERSAL})
                out.append(result("WEB_PATH_TRAVERSAL_BLOCKED", "VULNERABLE" if "root:x:" in rr.text or "[boot loader]" in rr.text else "PATCHED", "Safe path traversal marker check"))
            except Exception as e: out.append(unknown("WEB_PATH_TRAVERSAL_BLOCKED", str(e)))
        else: out.append(unknown("WEB_PATH_TRAVERSAL_BLOCKED", "No traversal_url configured"))

        docs_vuln, docs_ev = False, []
        for u in ["/docs", "/swagger", "/swagger-ui", "/openapi.json", "/api-docs"]:
            try:
                rr = http_get(base + u)
                if rr.status_code == 200 and any(x in rr.text.lower() for x in ["swagger", "openapi", "api"]):
                    docs_vuln = True; docs_ev.append(u)
            except Exception: pass
        out.append(result("WEB_API_DOCS_NOT_PUBLIC", "VULNERABLE" if docs_vuln else "PATCHED", "Public API documentation endpoint review", ",".join(docs_ev)))

        if t.get("dir_url"):
            try:
                rr = http_get(t["dir_url"])
                out.append(result("WEB_DIRECTORY_INDEXING_DISABLED", "VULNERABLE" if "Index of /" in rr.text else "PATCHED", "Directory index content check"))
            except Exception as e: out.append(result("WEB_DIRECTORY_INDEXING_DISABLED", "PATCHED", f"Directory URL blocked/unreachable: {e}"))
        else: out.append(unknown("WEB_DIRECTORY_INDEXING_DISABLED", "No dir_url configured"))

        if t.get("login_url"):
            try:
                rr = requests.post(t["login_url"], data={"username": t.get("default_user","admin"), "password": t.get("default_pass","admin")}, timeout=6, verify=False, allow_redirects=False)
                success = rr.status_code in (200, 302) and not re.search(r"invalid|failed|incorrect|denied", rr.text, re.I)
                out.append(result("DEFAULT_CREDENTIALS_CHANGED", "VULNERABLE" if success else "PATCHED", "Configured default credential check"))
            except Exception as e: out.append(unknown("DEFAULT_CREDENTIALS_CHANGED", str(e)))
        else: out.append(unknown("DEFAULT_CREDENTIALS_CHANGED", "No login_url configured"))

        out.append(unknown("HTTP_REQUEST_SMUGGLING_REVIEW", "Requires proxy/backend lab-specific validation; not actively tested to avoid unsafe traffic"))

        if t.get("rate_limit_url"):
            try:
                codes = [http_get(t["rate_limit_url"]).status_code for _ in range(4)]
                out.append(result("RATE_LIMITING_PRESENT", "PATCHED" if any(c in (401,403,429) for c in codes) else "VULNERABLE", "Small safe rate-limit probe", str(codes)))
            except Exception as e: out.append(unknown("RATE_LIMITING_PRESENT", str(e)))
        else: out.append(unknown("RATE_LIMITING_PRESENT", "No rate_limit_url configured"))

        out.append(unknown("TLS_LEGACY_DISABLED", "TLS 1.0/1.1 check is disabled in this portable agent; use SSL scan module if required"))

        if t.get("symlink_url"):
            try:
                rr = http_get(t["symlink_url"])
                out.append(result("APACHE_SYMLINK_FOLLOWING_DISABLED", "VULNERABLE" if "root:x:" in rr.text else "PATCHED", "Configured symlink URL content check"))
            except Exception as e: out.append(result("APACHE_SYMLINK_FOLLOWING_DISABLED", "PATCHED", f"Symlink URL blocked/unreachable: {e}"))
        else: out.append(unknown("APACHE_SYMLINK_FOLLOWING_DISABLED", "No symlink_url configured"))

        risky = []
        for u in ["/server-status", "/server-info"]:
            try:
                rr = http_get(base + u)
                if rr.status_code == 200 and any(x in rr.text.lower() for x in ["apache server status", "server settings"]):
                    risky.append(u)
            except Exception: pass
        out.append(result("APACHE_RISKY_MODULES_DISABLED", "VULNERABLE" if risky else "PATCHED", "mod_status/mod_info public endpoint review", ",".join(risky)))

        out.append(unknown("SLOWLORIS_PROTECTION_REVIEW", "Not actively tested to avoid DoS; verify Timeout/RequestReadTimeout/rate limits manually"))

        if t.get("proxy_header_url"):
            try:
                marker = "198.51.100.77"
                rr = requests.get(t["proxy_header_url"], headers={"X-Forwarded-For": marker}, timeout=6, verify=False)
                out.append(result("PROXY_HEADERS_VALIDATED", "VULNERABLE" if marker in rr.text else "PATCHED", "X-Forwarded-For reflection/trust marker check"))
            except Exception as e: out.append(unknown("PROXY_HEADERS_VALIDATED", str(e)))
        else: out.append(unknown("PROXY_HEADERS_VALIDATED", "No proxy_header_url configured"))
    return out


def check_email(cfg: Dict[str, Any]) -> List[Dict[str, Any]]:
    out = []
    targets = cfg.get("smtp_targets", [])
    if not targets:
        return [unknown(x, "No smtp_targets configured") for x in ["SMTP_OPEN_RELAY_BLOCKED","MAIL_SPF_DKIM_DMARC_PRESENT","SMTP_EXPN_VRFY_DISABLED","SMTP_STARTTLS_REQUIRED","SMTP_ATTACHMENT_LIMIT_PRESENT"]]
    for t in targets:
        h, p = t.get("host", "127.0.0.1"), int(t.get("port", 25))
        try:
            s = smtplib.SMTP(h, p, timeout=6)
            s.helo("cyberrange.local"); s.mail("external@evil.test")
            code, msg = s.rcpt(t.get("external_rcpt", "victim@example.com")); s.quit()
            out.append(result("SMTP_OPEN_RELAY_BLOCKED", "VULNERABLE" if code == 250 else "PATCHED", f"External RCPT relay response code {code}", str(msg)))
        except Exception as e: out.append(result("SMTP_OPEN_RELAY_BLOCKED", "PATCHED", f"Relay test blocked/unreachable: {e}"))
        try:
            s = smtplib.SMTP(h, p, timeout=6); s.ehlo(); features = str(s.esmtp_features)
            vrfy_code, _ = s.verify(t.get("vrfy_user", "root")); expn_code, _ = s.docmd("EXPN", t.get("vrfy_user", "root")); s.quit()
            out.append(result("SMTP_STARTTLS_REQUIRED", "PATCHED" if "starttls" in features.lower() else "VULNERABLE", "SMTP STARTTLS feature review", features))
            out.append(result("SMTP_ATTACHMENT_LIMIT_PRESENT", "PATCHED" if "size" in features.lower() else "VULNERABLE", "SMTP SIZE extension review", features))
            out.append(result("SMTP_EXPN_VRFY_DISABLED", "VULNERABLE" if vrfy_code == 250 or expn_code == 250 else "PATCHED", f"VRFY={vrfy_code}, EXPN={expn_code}"))
        except Exception as e:
            out += [unknown("SMTP_STARTTLS_REQUIRED", str(e)), unknown("SMTP_ATTACHMENT_LIMIT_PRESENT", str(e)), unknown("SMTP_EXPN_VRFY_DISABLED", str(e))]
    domain = cfg.get("domain") or targets[0].get("domain", "")
    if domain:
        ev = run_cmd(f"nslookup -type=txt {domain} && nslookup -type=txt _dmarc.{domain}", 10)
        selector = cfg.get("dkim_selector") or "default"
        dkim = run_cmd(f"nslookup -type=txt {selector}._domainkey.{domain}", 10)
        has = "v=spf1" in ev.lower() and "v=dmarc1" in ev.lower() and ("v=dkim1" in dkim.lower() or "dkim" in dkim.lower())
        out.append(result("MAIL_SPF_DKIM_DMARC_PRESENT", "PATCHED" if has else "VULNERABLE", "SPF/DKIM/DMARC DNS TXT review", ev + "\n" + dkim))
    else: out.append(unknown("MAIL_SPF_DKIM_DMARC_PRESENT", "No domain configured"))
    return out


def check_network_legacy(cfg: Dict[str, Any]) -> List[Dict[str, Any]]:
    out = []
    if not cfg.get("ftp_targets"):
        out += [unknown("FTP_ANONYMOUS_DISABLED", "No ftp_targets configured"), unknown("FTP_BOUNCE_DISABLED", "No ftp_targets configured")]
    for t in cfg.get("ftp_targets", []):
        h = t.get("host", "127.0.0.1")
        try:
            ftp = FTP(h, timeout=6); ftp.login(); ftp.quit()
            out.append(result("FTP_ANONYMOUS_DISABLED", "VULNERABLE", f"Anonymous FTP login succeeded on {h}"))
        except Exception: out.append(result("FTP_ANONYMOUS_DISABLED", "PATCHED", f"Anonymous FTP blocked on {h}"))
        try:
            ftp = FTP(h, timeout=6); ftp.connect(h, 21, timeout=6)
            resp = ftp.sendcmd("PORT 127,0,0,1,7,138"); ftp.quit()
            out.append(result("FTP_BOUNCE_DISABLED", "VULNERABLE" if "200" in resp else "PATCHED", "FTP PORT command bounce safety check", resp))
        except Exception as e: out.append(result("FTP_BOUNCE_DISABLED", "PATCHED", f"FTP bounce PORT command blocked/unavailable: {e}"))

    host = cfg.get("local_host", "127.0.0.1")
    out.append(result("TELNET_DISABLED", "VULNERABLE" if port_open(host, 23) else "PATCHED", "Telnet port 23 local check"))

    if is_windows():
        smb = run_cmd('powershell -NoProfile -Command "Get-SmbServerConfiguration | Select EnableSecuritySignature,RequireSecuritySignature | Format-List"', 10)
        enabled = "EnableSecuritySignature : True" in smb or "RequireSecuritySignature : True" in smb
        out.append(result("SMB_SIGNING_ENABLED", "PATCHED" if enabled else "VULNERABLE", "Windows SMB signing configuration", smb))
    else:
        smbconf = file_text("/etc/samba/smb.conf")
        if smbconf:
            weak = re.search(r"server signing\s*=\s*(disabled|auto)", smbconf, re.I)
            strong = re.search(r"server signing\s*=\s*mandatory", smbconf, re.I)
            out.append(result("SMB_SIGNING_ENABLED", "PATCHED" if strong and not weak else "VULNERABLE", "Samba server signing config", smbconf[:500]))
        else: out.append(unknown("SMB_SIGNING_ENABLED", "No local SMB/Samba config found"))

    snmp_conf = "\n".join(file_text(x) for x in ["/etc/snmp/snmpd.conf", "/etc/default/snmpd"])
    if snmp_conf:
        bad = re.search(r"rocommunity\s+(public|private)|rwcommunity\s+(public|private)", snmp_conf, re.I)
        out.append(result("SNMP_DEFAULT_COMMUNITY_DISABLED", "VULNERABLE" if bad else "PATCHED", "SNMP community string config review"))
    else: out.append(unknown("SNMP_DEFAULT_COMMUNITY_DISABLED", "No local SNMP config found"))
    return out


def check_identity(cfg: Dict[str, Any]) -> List[Dict[str, Any]]:
    out = []
    if is_windows():
        acc = run_cmd("net accounts")
        min_len = re.search(r"Minimum password length\s+(\d+)", acc, re.I)
        lockout = re.search(r"Lockout threshold\s+(.+)", acc, re.I)
        hist = re.search(r"Length of password history maintained\s+(\d+)", acc, re.I)
        out.append(result("PASSWORD_MIN_LENGTH_STRONG", "PATCHED" if min_len and int(min_len.group(1)) >= 12 else "VULNERABLE", "Windows minimum password length", acc))
        out.append(result("ACCOUNT_LOCKOUT_ENABLED", "PATCHED" if lockout and "Never" not in lockout.group(1) and "0" not in lockout.group(1).strip() else "VULNERABLE", "Windows account lockout threshold", acc))
        out.append(result("PASSWORD_HISTORY_ENFORCED", "PATCHED" if hist and int(hist.group(1)) >= 5 else "VULNERABLE", "Windows password history", acc))
    elif is_linux():
        login_defs = file_text("/etc/login.defs") + "\n" + file_text("/etc/security/pwquality.conf")
        minlen = re.search(r"minlen\s*=\s*(\d+)|PASS_MIN_LEN\s+(\d+)", login_defs, re.I)
        length = int(next(x for x in minlen.groups() if x)) if minlen else 0
        out.append(result("PASSWORD_MIN_LENGTH_STRONG", "PATCHED" if length >= 12 else "VULNERABLE", "Linux password length policy", login_defs[:800]))
        faillock = file_text("/etc/security/faillock.conf") + "\n" + file_text("/etc/pam.d/common-auth") + "\n" + file_text("/etc/pam.d/system-auth")
        out.append(result("ACCOUNT_LOCKOUT_ENABLED", "PATCHED" if re.search(r"deny\s*=\s*[1-9]|pam_faillock", faillock, re.I) else "VULNERABLE", "Linux account lockout PAM/faillock review", faillock[:800]))
        out.append(result("PASSWORD_HISTORY_ENFORCED", "PATCHED" if re.search(r"remember\s*=\s*([5-9]|\d{2,})", faillock, re.I) else "VULNERABLE", "Linux password history PAM review", faillock[:800]))
    else:
        out += [unknown("PASSWORD_MIN_LENGTH_STRONG"), unknown("ACCOUNT_LOCKOUT_ENABLED"), unknown("PASSWORD_HISTORY_ENFORCED")]
    out.append(unknown("MFA_ENFORCED_FOR_ADMIN", "MFA depends on your identity provider; configure a custom check/API if required"))
    return out


def check_windows_registry(cfg: Dict[str, Any]) -> List[Dict[str, Any]]:
    names = ["WIN_AUTOADMINLOGON_DISABLED","WIN_REMOTE_REGISTRY_DISABLED","WIN_STICKY_KEYS_CLEAN","WIN_LLMNR_NETBIOS_DISABLED","WIN_ALWAYS_INSTALL_ELEVATED_DISABLED","WIN_LSA_PLAINTEXT_SECRETS_DISABLED"]
    if not is_windows():
        return [unknown(x, "Windows-only check") for x in names]
    out = []
    auto = run_cmd(r'reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"')
    out.append(result("WIN_AUTOADMINLOGON_DISABLED", "VULNERABLE" if ("AutoAdminLogon" in auto and re.search(r"AutoAdminLogon\s+REG_\w+\s+1", auto)) else "PATCHED", "AutoAdminLogon registry review", auto))
    rr = run_cmd("sc query RemoteRegistry")
    out.append(result("WIN_REMOTE_REGISTRY_DISABLED", "VULNERABLE" if "RUNNING" in rr else "PATCHED", "Remote Registry service state", rr))
    sethc = Path(os.environ.get("WINDIR", "C:\\Windows")) / "System32" / "sethc.exe"
    cmd = Path(os.environ.get("WINDIR", "C:\\Windows")) / "System32" / "cmd.exe"
    try:
        out.append(result("WIN_STICKY_KEYS_CLEAN", "VULNERABLE" if sethc.exists() and cmd.exists() and sethc.stat().st_size == cmd.stat().st_size else "PATCHED", "sethc.exe/cmd.exe size comparison"))
    except Exception as e: out.append(unknown("WIN_STICKY_KEYS_CLEAN", str(e)))
    llmnr = run_cmd(r'reg query "HKLM\Software\Policies\Microsoft\Windows NT\DNSClient" /v EnableMulticast')
    nb = run_cmd("wmic nicconfig get TcpipNetbiosOptions")
    out.append(result("WIN_LLMNR_NETBIOS_DISABLED", "PATCHED" if ("0x0" in llmnr and re.search(r"\b2\b", nb)) else "VULNERABLE", "LLMNR/NetBIOS setting review", llmnr + "\n" + nb))
    aiu1 = run_cmd(r'reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer" /v AlwaysInstallElevated')
    aiu2 = run_cmd(r'reg query "HKCU\SOFTWARE\Policies\Microsoft\Windows\Installer" /v AlwaysInstallElevated')
    out.append(result("WIN_ALWAYS_INSTALL_ELEVATED_DISABLED", "VULNERABLE" if "0x1" in aiu1 and "0x1" in aiu2 else "PATCHED", "AlwaysInstallElevated registry review", aiu1 + "\n" + aiu2))
    wdigest = run_cmd(r'reg query "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" /v UseLogonCredential')
    out.append(result("WIN_LSA_PLAINTEXT_SECRETS_DISABLED", "VULNERABLE" if "0x1" in wdigest else "PATCHED", "WDigest UseLogonCredential review", wdigest))
    return out


def _batch_url(cfg: Dict[str, Any]) -> str:
    """Return the clean-slate batch endpoint even if old config still points to /report."""
    url = (cfg.get("leaderboard_api") or "http://127.0.0.1:8000/api/agent/report_batch").rstrip("/")
    if url.endswith("/report"):
        return url + "_batch"
    if url.endswith("/api/agent"):
        return url + "/report_batch"
    return url


def send_batch_report(cfg: Dict[str, Any], items: List[Dict[str, Any]]) -> None:
    """Send one clean-slate heartbeat containing all 25-30 checks.

    The backend overwrites the previous live status/log rows for this team/host
    before inserting these items. This prevents table/log accumulation.
    """
    now = int(time.time())
    payload = {
        "team_id": cfg.get("team_id") or auto_identity()[0],
        "team_name": cfg.get("team_name") or auto_identity()[1],
        "host": cfg.get("host_name") or auto_identity()[2],
        "host_name": cfg.get("host_name") or auto_identity()[2],
        "cycle_id": f"{cfg.get('team_id') or auto_identity()[0]}-{cfg.get('host_name') or auto_identity()[2]}-{now}",
        "clean_slate": True,
        "items": items,
    }
    try:
        r = requests.post(_batch_url(cfg), json=payload, timeout=12)
        r.raise_for_status()
        print(f"SENT CLEAN SLATE {payload['team_id']} {payload['host']} ITEMS={len(items)}")
    except Exception as e:
        print(f"BATCH REPORT FAILED: {e}")


def send_report(cfg: Dict[str, Any], item: Dict[str, Any]) -> None:
    """Backward-compatible single-check sender. Prefer send_batch_report."""
    send_batch_report(cfg, [item])


def run_once(cfg: Dict[str, Any]) -> None:
    checks = []
    if cfg.get("require_admin") and not is_admin():
        checks.append(result("OS_OUTDATED_KERNEL", "UNKNOWN", "Agent is not running as administrator/root; some local checks may be unavailable"))

    for group in [check_system_os, check_web, check_email, check_network_legacy, check_identity, check_windows_registry]:
        try:
            checks.extend(group(cfg))
        except Exception as e:
            checks.append(result("OS_OUTDATED_KERNEL", "UNKNOWN", f"Agent check group failed safely: {e}"))

    # One request per 30-second cycle. This is the clean-slate heartbeat.
    send_batch_report(cfg, checks)


if __name__ == "__main__":
    cfg = load_config()
    print(f"Blue Agent started for {cfg.get('team_name', cfg.get('team_id'))} / {cfg.get('host_name')} -> {cfg.get('leaderboard_api')}")
    while True:
        run_once(cfg)
        time.sleep(int(cfg.get("interval_seconds", 30)))
