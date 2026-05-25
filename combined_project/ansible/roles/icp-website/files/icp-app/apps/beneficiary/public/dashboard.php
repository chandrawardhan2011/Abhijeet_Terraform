<?php
/**
 * beneficiary.icp.lab/dashboard.php
 * Beneficiary office dashboard. Requires login.
 */
require_once '/var/www/icp/shared/includes/db.php';
require_once '/var/www/icp/shared/includes/audit.php';
require_once '/var/www/icp/shared/includes/auth.php';

require_login();
audit('beneficiary.dashboard', ['by' => $_SESSION['username'] ?? '']);

$db = icp_db();
$user = [
    'id'       => (int)($_SESSION['user_id'] ?? 0),
    'username' => $_SESSION['username'] ?? '',
    'role'     => $_SESSION['role'] ?? 'user',
];

// Pull a couple of stats for the dashboard
$nominee_count = 0;
$claim_count = 0;

$res = $db->query("SELECT COUNT(*) AS c FROM nominees");
if ($res) { $nominee_count = (int)$res->fetch_assoc()['c']; }

$stmt = $db->prepare("SELECT COUNT(*) AS c FROM claims WHERE user_id = ?");
$stmt->bind_param('i', $user['id']);
$stmt->execute();
$res = $stmt->get_result();
if ($res) { $claim_count = (int)$res->fetch_assoc()['c']; }

$sb_section = 'beneficiary';
$sb_active  = 'dashboard';
$sb_user    = $user;
$icp_title  = 'Beneficiary Office Home';

require '/var/www/icp/shared/partials/dashboard_head.php';
?>

<h1>Beneficiary Office</h1>
<p class="icp-folio">Branch IV &middot; signed in as <?= htmlspecialchars($user['username']) ?></p>

<div class="icp-notice">
  Welcome back. Nominee records, payout schedules, and beneficiary claims are managed
  from this office. Changes to nominee bank details require a counter-signed form.
</div>

<div class="icp-card">
  <h2>Office at a Glance</h2>
  <div class="icp-card-grid">
    <div class="icp-tile" style="cursor:default;">
      <div class="icp-tile-label">Nominees</div>
      <div class="icp-tile-title"><?= $nominee_count ?> on register</div>
      <div class="icp-tile-desc">Active beneficiary records</div>
    </div>
    <div class="icp-tile" style="cursor:default;">
      <div class="icp-tile-label">Your Claims</div>
      <div class="icp-tile-title"><?= $claim_count ?> on file</div>
      <div class="icp-tile-desc">Submitted under your policyholder id</div>
    </div>
    <div class="icp-tile" style="cursor:default;">
      <div class="icp-tile-label">Bureau</div>
      <div class="icp-tile-title">Cooperative</div>
      <div class="icp-tile-desc">Established 1962 &middot; not-for-profit</div>
    </div>
  </div>
</div>

<div class="icp-card">
  <h2>Common Tasks</h2>
  <div class="icp-card-grid">
    <a class="icp-tile" href="/nominee.php?nid=1">
      <div class="icp-tile-label">Records</div>
      <div class="icp-tile-title">View Nominee</div>
      <div class="icp-tile-desc">Inspect nominee details, relation, and IFSC.</div>
    </a>
    <a class="icp-tile" href="/payout_view.php?id=1">
      <div class="icp-tile-label">Payouts</div>
      <div class="icp-tile-title">Payout Records</div>
      <div class="icp-tile-desc">Encrypted bank account ciphertext for each nominee.</div>
    </a>
    <a class="icp-tile" href="/search_nominee.php">
      <div class="icp-tile-label">Search</div>
      <div class="icp-tile-title">Nominee Search</div>
      <div class="icp-tile-desc">Look up nominees by name or relation.</div>
    </a>
    <a class="icp-tile" href="/payout_update.php">
      <div class="icp-tile-label">Updates</div>
      <div class="icp-tile-title">Update Bank Details</div>
      <div class="icp-tile-desc">Submit a change request for nominee banking.</div>
    </a>
  </div>
</div>

<?php require '/var/www/icp/shared/partials/dashboard_foot.php'; ?>
