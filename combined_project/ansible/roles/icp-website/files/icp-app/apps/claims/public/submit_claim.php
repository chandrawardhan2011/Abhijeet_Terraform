<?php
/**
 * claims.icp.lab/submit_claim.php
 * ICP_24 — Cross-Site Request Forgery: no anti-CSRF token, no Referer check,
 *          no SameSite on session cookie.
 * ICP_25 — Stored XSS: `description` field stored raw and rendered raw later
 *          (rendered by status.icp.lab/claim.php).
 */

require_once '/var/www/icp/shared/includes/db.php';
require_once '/var/www/icp/shared/includes/audit.php';
require_once '/var/www/icp/shared/includes/auth.php';
require_once '/var/www/icp/shared/includes/flags.php';

icp_session_start();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    die('POST only');
}

// VULNERABLE (ICP_24): no token, no referer check.
$user_id     = current_user_id() ?: 1;  // anonymous defaults to user 1 for the lab
$policy_id   = (int)($_POST['policy_id'] ?? 1);
$description = $_POST['description'] ?? '';   // VULNERABLE (ICP_25): stored raw

$db = icp_db();
$stmt = $db->prepare(
    'INSERT INTO claims (user_id, policy_id, description, status) ' .
    'VALUES (?, ?, ?, "submitted")'
);
$stmt->bind_param('iis', $user_id, $policy_id, $description);
$stmt->execute();
$new_id = $stmt->insert_id;
$stmt->close();

audit('claims.submit', ['claim_id' => $new_id, 'len' => strlen($description)]);

echo "<p>Claim #" . $new_id . " submitted.</p>";
echo "<p>View at: <a href='http://status.icp.lab/claim.php?id=" . $new_id . "'>";
echo "status.icp.lab/claim.php?id=" . $new_id . "</a></p>";
echo "<!-- ICP_24 marker: " . flag_for('ICP_24') . " -->";
echo "<!-- ICP_25 marker: " . flag_for('ICP_25') . " -->";
