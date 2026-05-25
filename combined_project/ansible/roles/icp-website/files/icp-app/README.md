# ICP / Shikra Insurance — Cyber Range

Self-contained vulnerable web application for offensive and defensive web-app security training. 1962 Shikra Insurance Cooperative theme. **27 deliberate vulnerabilities** across five sub-applications, plus a public landing tier with role-aware dashboards.

## What's inside

```
icp-final.tar.gz
├── README.md                  This file
├── scripts/
│   ├── install.sh             Deploy on a fresh Ubuntu host (parametric PHP)
│   ├── smoke-test.sh          Vulnerability tests
│   └── uninstall.sh           Clean removal
├── apps/
│   ├── landing/               Public site (icp.lab + www)
│   │   ├── about/, careers/, press/, voices/, contact/
│   │   └── staff/             Staff login portal
│   ├── policies/              Sub-app I (policies.icp.lab)
│   ├── claims/                Sub-app II (claims.icp.lab)
│   ├── status/                Sub-app III (status.icp.lab)
│   ├── beneficiary/           Sub-app IV (beneficiary.icp.lab)
│   └── admin/                 Sub-app V (admin.icp.lab)
├── shared/
│   ├── includes/              db.php, audit.php, auth.php, flags.php
│   ├── partials/              Dashboard sidebar layout
│   └── assets/                shikra.css
├── apache/
│   └── icp.conf               Apache vhost (six subdomains)
└── db/
    ├── schema.sql             10 tables: users, policies, claims, etc.
    └── seed.sql               Sample data with __FLAG_ICP_xx__ placeholders
```

## Requirements

- Ubuntu 22.04, 24.04, or 26.04 (other distros untested)
- 2 GB RAM minimum, 4 GB recommended
- 10 GB disk
- Root access
- Port 80 free
- A throwaway VM. Real RCE, SQLi, command injection, file upload — do not run on a host networked to anything you care about.

## Installation

Extract and run the installer. It auto-detects PHP version (8.1 on 22.04, 8.3 on 24.04, 8.5 on 26.04).

```bash
tar xzf icp-final.tar.gz
cd icp-final
sudo bash scripts/install.sh
```

About 3 minutes on a fresh host. The installer falls back to the Ondřej PPA if no PHP 8.x is found in default repos.

## Verify

```bash
sudo bash scripts/smoke-test.sh
```

## Browser tour

1. `http://icp.lab/` — public landing. Click **Staff Login** in the bureau bar or main nav.
2. Staff Portal shows two offices. Click **Adjuster Console**.
3. Login as `admin` / `admin`. Click **Continue to dashboard →**.
4. Adjuster dashboard appears with sidebar nav. Click **User Management**.
5. Personnel roster + add/delete form.

Same flow for the Beneficiary Office:
1. From Staff Portal, click **Beneficiary Office**.
2. Login as `rajesh` / `Welcome@2026`.
3. Click **Continue to dashboard**.
4. Sidebar shows Nominee, Payout Records, Nominee Search, Update Bank, Sign out.

Demo a vulnerability — try ICP_11 SQL injection from the public side (no login needed):

```
http://policies.icp.lab/search.php?plan=x' UNION SELECT id,name,premium,flag_note FROM policies-- 
```

The flag string for ICP_11 appears at the bottom of the result table.

## Vulnerability index

| ID | Class | Endpoint |
|---|---|---|
| ICP_11 | SQL Injection (UNION) | `policies.icp.lab/search.php?plan=` |
| ICP_12 | Reflected XSS | `policies.icp.lab/quote.php?age=` |
| ICP_13 | Directory listing | `policies.icp.lab/docs/` |
| ICP_14 | Outdated jQuery 1.7.2 | `policies.icp.lab/assets/js/jquery-1.7.2.min.js` |
| ICP_15 | Missing audit log | `policies.icp.lab/quote.php` (no audit row) |
| ICP_21 | Unrestricted file upload | `claims.icp.lab/upload.php` |
| ICP_22 | Path traversal | `claims.icp.lab/attachment.php?file=` |
| ICP_23 | Local file inclusion | `claims.icp.lab/claim_form.php?tpl=` |
| ICP_24 | CSRF | `claims.icp.lab/submit_claim.php` |
| ICP_25 | Stored XSS | `claims.icp.lab/submit_claim.php` (description) |
| ICP_31 | IDOR (read claim) | `status.icp.lab/claim.php?id=` |
| ICP_32 | IDOR (settlement history) | `status.icp.lab/history.php?policy_id=` |
| ICP_33 | SQL Injection | `status.icp.lab/list.php?status=` |
| ICP_34 | Insecure deserialisation | `status.icp.lab/track.php` cookie `tracking_ctx` |
| ICP_35 | `.git/` exposure | `status.icp.lab/.git/config` |
| ICP_41 | IDOR (read nominee) | `beneficiary.icp.lab/nominee.php?nid=` |
| ICP_42 | IDOR (write nominee) | `beneficiary.icp.lab/payout_update.php` |
| ICP_43 | Session fixation | `beneficiary.icp.lab/login.php` |
| ICP_44 | Weak crypto (AES-ECB) | `beneficiary.icp.lab/payout_view.php` |
| ICP_45 | SQL Injection (UNION) | `beneficiary.icp.lab/search_nominee.php?q=` |
| ICP_51 | Broken access control | `admin.icp.lab/admin/index.php` |
| ICP_52 | State-skip / business logic | `admin.icp.lab/adjudicate.php` |
| ICP_53 | OS command injection | `admin.icp.lab/export_pdf.php?claim_no=` |
| ICP_54 | SQL Injection | `admin.icp.lab/admin/find.php?q=` |
| ICP_55 | Default credentials | `admin.icp.lab/admin/login.php` |
| ICP_56 | Reflected XSS | `icp.lab/press/?search=` |
| ICP_57 | Stored XSS | `icp.lab/voices/` (body) |

## Test credentials

| Username | Password | Role | Reachable from |
|---|---|---|---|
| `admin` | `admin` | adjuster (ICP_55) | `admin.icp.lab/admin/login.php` |
| `rajesh` | `Welcome@2026` | user | `beneficiary.icp.lab/login.php` |
| `priya` | `Sunset#11` | user | `beneficiary.icp.lab/login.php` |

## What's been added on top of the original ICP

This distribution includes all the UX improvements built in the BlueCart pattern:

- **Two role-aware dashboards** — beneficiary office home (user role), adjuster console home (adjuster role) — each with sidebar nav so you don't get stranded after login
- **User Management page** at `admin.icp.lab/admin/users.php` — list/add/delete personnel accounts. Deliberately enforces only `require_login()`, NOT a role check, preserving ICP_51 broken access control as a lateral-movement teaching primitive
- **Staff Login portal** at `icp.lab/staff/` — two-tile chooser linking to the beneficiary and adjuster logins
- **Login flow improvements** — both login pages now show a "Continue to dashboard →" button after successful login; users hitting the login page while already authenticated are redirected straight to the dashboard
- **Back-navigation banner** — every sub-app PHP page that renders HTML has a maroon banner at the top with `← Shikra Insurance` and `← Office Home` links

All 27 vulnerabilities are intact. The new pages preserve them — User Management uses MD5 password hashing (matching the ICP_45 SQLi target) and skips role checks (preserving ICP_51).

## Flag format

```
silence1{ICP_<NN>_<8 hex chars>}
```

The 8-hex suffix is the first 8 characters of HMAC-SHA256 over the vulnerability ID, keyed by the per-install `FLAG_HMAC_KEY` in `/etc/icp/icp.env`. Each install rotates these — the same vulnerability on a different host produces a different flag.

To rotate flags on an existing install:

```bash
sudo rm -f /etc/icp/icp.env
sudo bash scripts/install.sh
```

## Uninstall

```bash
sudo bash scripts/uninstall.sh
```

Removes `/var/www/icp`, the `icp` MySQL database and user, the Apache vhost, the secrets file, and the `/etc/hosts` entries. Does not remove apache2, mysql-server, or php-* packages.

## Notes for instructors

- The vulnerable code is real. SQL injection actually leaks the database; uploaded `.php.pdf` files actually execute; AES-ECB ciphertexts are actually decryptable by inspection. Trainees solving these are doing real work, not pattern-matching to a CTF format.
- `/admin/users.php` is a deliberately doubled-edged tool — it's an obvious "obvious admin function" but reachable by any logged-in user (preserving ICP_51). Trainees who notice this can use it for lateral movement to create their own adjuster account.
- All flags rotate per install. Distribute to instructors after deployment by reading `/etc/icp/icp.env`'s `FLAG_HMAC_KEY` and computing values, or by simply running each exploit and noting the captured flag.
- The Apache vhost is HTTP-only by design. Adding TLS would be inappropriate for a vulnerable training app — treat the network as the security boundary.
