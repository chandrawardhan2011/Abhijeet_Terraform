<?php
/**
 * admin.icp.lab/admin/login.php
 * ICP_55 — Default credentials: the admin/admin pair from seed data.
 *          (Compare ICP_45 — same row, but reached via SQLi.)
 */

require_once '/var/www/icp/shared/includes/db.php';
require_once '/var/www/icp/shared/includes/audit.php';
require_once '/var/www/icp/shared/includes/auth.php';
require_once '/var/www/icp/shared/includes/flags.php';

// Redirect to dashboard if already logged in
if (session_status() === PHP_SESSION_NONE) { @session_start(); }
if (!empty($_SESSION['user_id'])) {
    header('Location: /admin/dashboard.php');
    exit;
}

icp_session_start();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo "<h2>Adjuster login</h2>";
    echo "<form method=POST>";
    echo "  Username: <input name=u><br>";
    echo "  Password: <input name=p type=password><br>";
    echo "  <button>Login</button></form>";
    exit;
}

$u = $_POST['u'] ?? '';
$p = $_POST['p'] ?? '';

$db = icp_db();
$stmt = $db->prepare(
    'SELECT id, role FROM users WHERE username = ? AND password_md5 = MD5(?) AND role = "adjuster"'
);
$stmt->bind_param('ss', $u, $p);
$stmt->execute();
$row = $stmt->get_result()->fetch_assoc();

if (!$row) {
    audit('admin.login_fail', ['user' => $u]);
    die('Invalid credentials.');
}

$_SESSION['user_id']  = (int)$row['id'];
$_SESSION['role']     = 'adjuster';
$_SESSION['username'] = $u;

audit('admin.login_ok', ['user_id' => (int)$row['id']]);

echo "<p>Welcome, adjuster " . htmlspecialchars($u) . "</p>";
echo '<p style="margin-top:14px;"><a href="/admin/dashboard.php" style="display:inline-block; padding:8px 18px; background:#8a2818; color:#f0e8d0; text-decoration:none; letter-spacing:0.08em; text-transform:uppercase; font-size:12px;">Continue to dashboard &rarr;</a></p>';
// Reveal the flag only on successful adjuster login.
echo "<!-- ICP_55 marker: " . flag_for('ICP_55') . " -->";
