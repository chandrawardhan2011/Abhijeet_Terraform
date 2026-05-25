<?php
/**
 * beneficiary.icp.lab/login.php
 * ICP_43 — Session fixation: session_regenerate_id() is NOT called on
 *          successful authentication. An attacker can pre-set the victim's
 *          PHPSESSID cookie and then assume the authenticated session.
 */

require_once '/var/www/icp/shared/includes/db.php';
require_once '/var/www/icp/shared/includes/audit.php';
require_once '/var/www/icp/shared/includes/auth.php';
require_once '/var/www/icp/shared/includes/flags.php';

// Redirect to dashboard if already logged in
if (session_status() === PHP_SESSION_NONE) { @session_start(); }
if (!empty($_SESSION['user_id'])) {
    header('Location: /dashboard.php');
    exit;
}

icp_session_start();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo "<h2>Beneficiary login</h2>";
    echo "<form method=POST>";
    echo "  Username: <input name=u><br>";
    echo "  Password: <input name=p type=password><br>";
    echo "  <button>Login</button></form>";
    echo "<!-- ICP_43 marker: " . flag_for('ICP_43') . " -->";
    exit;
}

$u = $_POST['u'] ?? '';
$p = $_POST['p'] ?? '';

$db = icp_db();
$stmt = $db->prepare('SELECT id, role FROM users WHERE username = ? AND password_md5 = MD5(?)');
$stmt->bind_param('ss', $u, $p);
$stmt->execute();
$row = $stmt->get_result()->fetch_assoc();

if (!$row) {
    audit('beneficiary.login_fail', ['user' => $u]);
    die('Invalid credentials.');
}

// VULNERABLE (ICP_43): no session_regenerate_id() call here.
$_SESSION['user_id']  = (int)$row['id'];
$_SESSION['role']     = $row['role'];
$_SESSION['username'] = $u;

audit('beneficiary.login_ok', ['user_id' => (int)$row['id']]);
echo "<p>Welcome, " . htmlspecialchars($u) . " (session id retained: " . session_id() . ")</p>";
echo '<p style=\"margin-top:14px;\"><a href=\"/dashboard.php\" style=\"display:inline-block; padding:8px 18px; background:#8a2818; color:#f0e8d0; text-decoration:none; letter-spacing:0.08em; text-transform:uppercase; font-size:12px;\">Continue to dashboard &rarr;</a></p>';
