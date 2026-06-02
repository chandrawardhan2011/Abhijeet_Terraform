<?php
/**
 * admin.icp.lab/admin/dashboard.php
 * Adjuster Console dashboard. Requires login only — does NOT enforce
 * role check, preserving ICP_51 broken access control on /admin/.
 */
require_once '/var/www/icp/shared/includes/db.php';
require_once '/var/www/icp/shared/includes/audit.php';
require_once '/var/www/icp/shared/includes/auth.php';

require_login();
audit('admin.dashboard', ['by' => $_SESSION['username'] ?? '']);

$db = icp_db();
$user = [
    'id'       => (int)($_SESSION['user_id'] ?? 0),
    'username' => $_SESSION['username'] ?? '',
    'role'     => $_SESSION['role'] ?? 'user',
];

// Stats
$user_count = 0;
$queued_count = 0;
$total_adj = 0;

$res = $db->query("SELECT COUNT(*) AS c FROM users");
if ($res) { $user_count = (int)$res->fetch_assoc()['c']; }

$res = $db->query("SELECT COUNT(*) AS c FROM adjudications WHERE state='queued'");
if ($res) { $queued_count = (int)$res->fetch_assoc()['c']; }

$res = $db->query("SELECT COUNT(*) AS c FROM adjudications");
if ($res) { $total_adj = (int)$res->fetch_assoc()['c']; }

$sb_section = 'admin';
$sb_active  = 'dashboard';
$sb_user    = $user;
$icp_title  = 'Adjuster Console';

require '/var/www/icp/shared/partials/dashboard_head.php';
?>

<h1>Adjuster Console</h1>
<p class="icp-folio">Branch V &middot; signed in as <?= htmlspecialchars($user['username']) ?> &middot; role: <?= htmlspecialchars($user['role']) ?></p>

<div class="icp-notice">
  Adjudication queue, personnel records, and claim oversight are handled from this office.
  All actions are logged to the audit trail under By-law III of the cooperative charter.
</div>

<div class="icp-card">
  <h2>Console at a Glance</h2>
  <div class="icp-card-grid">
    <div class="icp-tile" style="cursor:default;">
      <div class="icp-tile-label">Personnel</div>
      <div class="icp-tile-title"><?= $user_count ?> on register</div>
      <div class="icp-tile-desc">Beneficiaries and adjusters combined</div>
    </div>
    <div class="icp-tile" style="cursor:default;">
      <div class="icp-tile-label">Adjudications</div>
      <div class="icp-tile-title"><?= $queued_count ?> queued</div>
      <div class="icp-tile-desc"><?= $total_adj ?> total in ledger</div>
    </div>
    <div class="icp-tile" style="cursor:default;">
      <div class="icp-tile-label">Office</div>
      <div class="icp-tile-title">Branch V &middot; Head Office</div>
      <div class="icp-tile-desc">Adjuster Console</div>
    </div>
  </div>
</div>

<div class="icp-card">
  <h2>Common Tasks</h2>
  <div class="icp-card-grid">
    <a class="icp-tile" href="/admin/find.php">
      <div class="icp-tile-label">Personnel</div>
      <div class="icp-tile-title">Personnel Search</div>
      <div class="icp-tile-desc">Search the personnel register by username or trade.</div>
    </a>
    <a class="icp-tile" href="/adjudicate.php">
      <div class="icp-tile-label">Approvals</div>
      <div class="icp-tile-title">Adjudication Queue</div>
      <div class="icp-tile-desc">Review queued claims and record a decision.</div>
    </a>
    <a class="icp-tile" href="/export_pdf.php">
      <div class="icp-tile-label">Operations</div>
      <div class="icp-tile-title">Export Claim PDF</div>
      <div class="icp-tile-desc">Generate a printable PDF of any claim file.</div>
    </a>
    <a class="icp-tile" href="/admin/users.php">
      <div class="icp-tile-label">Administration</div>
      <div class="icp-tile-title">User Management</div>
      <div class="icp-tile-desc">Add, list, and remove personnel accounts.</div>
    </a>
  </div>
</div>

<?php require '/var/www/icp/shared/partials/dashboard_foot.php'; ?>
