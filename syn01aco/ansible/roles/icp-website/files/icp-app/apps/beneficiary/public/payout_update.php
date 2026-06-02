<?php
/**
 * beneficiary.icp.lab/payout_update.php
 * ICP_42 — IDOR (write): any policyholder can rewrite any nominee's bank
 *          details by POSTing nid + new IFSC + new account number.
 */

require_once '/var/www/icp/shared/includes/db.php';
require_once '/var/www/icp/shared/includes/audit.php';
require_once '/var/www/icp/shared/includes/auth.php';
require_once '/var/www/icp/shared/includes/flags.php';

icp_session_start();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
echo '<!-- ICP_BACKNAV --><div style="background: #8a2818; color: #f0e8d0; padding: 8px 20px; font-family: \'Times New Roman\', Georgia, serif; font-size: 12px; letter-spacing: 0.08em; border-bottom: 2px solid #c4881e;"><a href="http://icp.lab/" style="color: #f0e8d0; text-decoration: none; margin-right: 18px;">&larr; Shikra Insurance</a><span style="color: #c4881e;">|</span><a href="/dashboard.php" style="color: #f0e8d0; text-decoration: none; margin-left: 18px;">&larr; Beneficiary Office</a></div>';
    echo "<h2>Update payout instructions</h2>";
    echo "<form method=POST>";
    echo "  Nominee ID: <input name=nid value='1'><br>";
    echo "  New IFSC:   <input name=ifsc value='ATTK0001111'><br>";
    echo "  New Acct:   <input name=acct value='9999999999'><br>";
    echo "  <button>Update</button></form>";
    exit;
}

$nid  = (int)($_POST['nid'] ?? 0);
$ifsc = $_POST['ifsc']    ?? '';
$acct = $_POST['acct']    ?? '';

audit('beneficiary.payout_update', ['nid' => $nid, 'ifsc' => $ifsc]);

// Encrypt new account using the (deliberately weak) AES-ECB function.
require_once __DIR__ . '/../lib/crypto.php';
$enc = icp_weak_encrypt($acct);

$db = icp_db();
// VULNERABLE (ICP_42): no ownership check, attacker can update any nominee.
$stmt = $db->prepare('UPDATE nominees SET bank_ifsc = ?, bank_account_enc = ? WHERE id = ?');
$stmt->bind_param('ssi', $ifsc, $enc, $nid);
$stmt->execute();
$ok = $stmt->affected_rows > 0;
$stmt->close();

echo "<p>Update " . ($ok ? "succeeded" : "failed") . " for nominee #" . $nid . "</p>";
echo "<!-- ICP_42 marker: " . flag_for('ICP_42') . " -->";
