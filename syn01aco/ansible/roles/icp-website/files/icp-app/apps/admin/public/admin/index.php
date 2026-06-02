<?php
/**
 * admin.icp.lab/admin/index.php
 * ICP_51 — Broken Access Control: relies on "obscure" subdomain,
 *          has no actual role check. Direct access yields admin functions.
 */

require_once '/var/www/icp/shared/includes/db.php';
require_once '/var/www/icp/shared/includes/audit.php';
require_once '/var/www/icp/shared/includes/flags.php';

// VULNERABLE (ICP_51): no require_role('adjuster') call here.
audit('admin.console_access', []);

$db = icp_db();
$res = $db->query(
    'SELECT a.id, a.claim_id, a.state, a.decision, c.user_id ' .
    'FROM adjudications a JOIN claims c ON c.id = a.claim_id ORDER BY a.id'
);
?>
<!-- ICP_BACKNAV -->
<div style="background: #8a2818; color: #f0e8d0; padding: 8px 20px; font-family: 'Times New Roman', Georgia, serif; font-size: 12px; letter-spacing: 0.08em; border-bottom: 2px solid #c4881e;">
  <a href="http://icp.lab/" style="color: #f0e8d0; text-decoration: none; margin-right: 18px;">&larr; Shikra Insurance</a>
  <span style="color: #c4881e;">|</span>
  <a href="/admin/dashboard.php" style="color: #f0e8d0; text-decoration: none; margin-left: 18px;">&larr; Adjuster Console</a>
</div>

<h2>Adjudication queue (UNAUTHENTICATED)</h2>
<table border=1 cellpadding=4>
  <tr><th>id</th><th>claim_id</th><th>state</th><th>decision</th><th>policyholder</th></tr>
<?php while ($row = $res->fetch_assoc()): ?>
  <tr>
    <td><?= (int)$row['id'] ?></td>
    <td><?= (int)$row['claim_id'] ?></td>
    <td><?= htmlspecialchars($row['state']) ?></td>
    <td><?= htmlspecialchars($row['decision']) ?></td>
    <td><?= (int)$row['user_id'] ?></td>
  </tr>
<?php endwhile; ?>
</table>
<!-- ICP_51 marker: <?= flag_for('ICP_51') ?> -->
