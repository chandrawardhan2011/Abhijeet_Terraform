<?php
/**
 * admin.icp.lab/admin/find.php
 * ICP_54 — SQL Injection on `q`. UNION SELECT can reach information_schema
 *          unless the DB user is properly restricted (which it isn't in seed).
 */

require_once '/var/www/icp/shared/includes/db.php';
require_once '/var/www/icp/shared/includes/flags.php';

$db = icp_db();
$q  = $_GET['q'] ?? '';

// VULNERABLE: concatenated, no parameter binding.
$sql = "SELECT a.id, a.claim_id, a.state, c.description ".
       "FROM adjudications a JOIN claims c ON c.id = a.claim_id ".
       "WHERE c.description LIKE '%" . $q . "%'";
$res = $db->query($sql);

echo '<!-- ICP_BACKNAV --><div style="background: #8a2818; color: #f0e8d0; padding: 8px 20px; font-family: \'Times New Roman\', Georgia, serif; font-size: 12px; letter-spacing: 0.08em; border-bottom: 2px solid #c4881e;"><a href="http://icp.lab/" style="color: #f0e8d0; text-decoration: none; margin-right: 18px;">&larr; Shikra Insurance</a><span style="color: #c4881e;">|</span><a href="/admin/dashboard.php" style="color: #f0e8d0; text-decoration: none; margin-left: 18px;">&larr; Adjuster Console</a></div>';
echo "<h2>Adjudication search: " . htmlspecialchars($q) . "</h2>";
if (!$res) {
    echo "<p style='color:red'>SQL error: " . $db->error . "</p>";
    exit;
}

echo "<table border=1 cellpadding=4>";
echo "<tr><th>id</th><th>claim_id</th><th>state</th><th>description</th></tr>";
while ($row = $res->fetch_assoc()) {
    echo "<tr>";
    foreach ($row as $col) echo "<td>" . $col . "</td>";
    echo "</tr>";
}
echo "</table>";
echo "<!-- ICP_54 marker: " . flag_for('ICP_54') . " -->";
