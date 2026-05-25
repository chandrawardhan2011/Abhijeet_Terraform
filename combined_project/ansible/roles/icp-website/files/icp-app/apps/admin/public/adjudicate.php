<?php
/**
 * admin.icp.lab/adjudicate.php
 * ICP_52 — Insecure design: state machine not enforced server-side.
 *          Workflow expected: queued -> review -> decided (approve/reject).
 *          Vulnerability: action=approve is honoured directly from any state,
 *          skipping the fraud-queue review step. Fraud-flagged claims pass.
 */

require_once '/var/www/icp/shared/includes/db.php';
require_once '/var/www/icp/shared/includes/audit.php';
require_once '/var/www/icp/shared/includes/flags.php';

$db = icp_db();
$adj_id = (int)($_REQUEST['adj_id'] ?? 0);
$action = $_REQUEST['action']        ?? '';

audit('admin.adjudicate', ['adj_id' => $adj_id, 'action' => $action]);

if ($action === 'approve' || $action === 'reject') {
    // VULNERABLE (ICP_52): no state-machine guard. Skip 'review' state.
    $stmt = $db->prepare(
        'UPDATE adjudications SET state = "decided", decision = ?, decided_at = NOW() WHERE id = ?'
    );
    $stmt->bind_param('si', $action, $adj_id);
    $stmt->execute();
    echo "<p>Adjudication #" . $adj_id . " set to " . htmlspecialchars($action) . ".</p>";
    echo "<!-- ICP_52 marker: " . flag_for('ICP_52') . " -->";
    exit;
}
?>
<!-- ICP_BACKNAV -->
<div style="background: #8a2818; color: #f0e8d0; padding: 8px 20px; font-family: 'Times New Roman', Georgia, serif; font-size: 12px; letter-spacing: 0.08em; border-bottom: 2px solid #c4881e;">
  <a href="http://icp.lab/" style="color: #f0e8d0; text-decoration: none; margin-right: 18px;">&larr; Shikra Insurance</a>
  <span style="color: #c4881e;">|</span>
  <a href="/admin/dashboard.php" style="color: #f0e8d0; text-decoration: none; margin-left: 18px;">&larr; Adjuster Console</a>
</div>

<h2>Adjudicate a claim</h2>
<form method=POST>
  Adjudication ID: <input name=adj_id value="1"><br>
  <button name=action value=approve>Approve</button>
  <button name=action value=reject>Reject</button>
</form>
