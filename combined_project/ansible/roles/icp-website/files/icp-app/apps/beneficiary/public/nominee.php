<?php
/**
 * beneficiary.icp.lab/nominee.php
 * ICP_41 — IDOR: read any nominee record by incrementing nid.
 */

require_once '/var/www/icp/shared/includes/db.php';
require_once '/var/www/icp/shared/includes/audit.php';
require_once '/var/www/icp/shared/includes/auth.php';
require_once '/var/www/icp/shared/includes/flags.php';

icp_session_start();

$nid = (int)($_GET['nid'] ?? 0);
$db = icp_db();

audit('beneficiary.nominee_view', ['nid' => $nid]);

$stmt = $db->prepare(
    'SELECT id, policyholder_id, name, relation, bank_ifsc FROM nominees WHERE id = ?'
);
$stmt->bind_param('i', $nid);
$stmt->execute();
$row = $stmt->get_result()->fetch_assoc();

if (!$row) {
    http_response_code(404);
    die('Nominee not found.');
}

// VULNERABLE (ICP_41): no check that policyholder_id == current_user_id().
?>
<!-- ICP_BACKNAV -->
<div style="background: #8a2818; color: #f0e8d0; padding: 8px 20px; font-family: 'Times New Roman', Georgia, serif; font-size: 12px; letter-spacing: 0.08em; border-bottom: 2px solid #c4881e;">
  <a href="http://icp.lab/" style="color: #f0e8d0; text-decoration: none; margin-right: 18px;">&larr; Shikra Insurance</a>
  <span style="color: #c4881e;">|</span>
  <a href="/dashboard.php" style="color: #f0e8d0; text-decoration: none; margin-left: 18px;">&larr; Beneficiary Office</a>
</div>

<h2>Nominee #<?= (int)$row['id'] ?></h2>
<table border=1 cellpadding=4>
  <tr><th>Name</th><td><?= htmlspecialchars($row['name']) ?></td></tr>
  <tr><th>Relation</th><td><?= htmlspecialchars($row['relation']) ?></td></tr>
  <tr><th>Policyholder ID</th><td><?= (int)$row['policyholder_id'] ?></td></tr>
  <tr><th>Bank IFSC</th><td><?= htmlspecialchars($row['bank_ifsc']) ?></td></tr>
</table>
<!-- ICP_41 marker: <?= flag_for('ICP_41') ?> -->
