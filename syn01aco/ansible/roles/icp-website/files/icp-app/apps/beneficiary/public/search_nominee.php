<?php
/**
 * beneficiary.icp.lab/search_nominee.php
 * ICP_45 — SQL Injection on `q`. UNION SELECT can leak users.password_md5
 *          including the admin row (which is MD5('admin') for ICP_55).
 */

require_once '/var/www/icp/shared/includes/db.php';
require_once '/var/www/icp/shared/includes/audit.php';
require_once '/var/www/icp/shared/includes/flags.php';

$db = icp_db();
$q  = $_GET['q'] ?? '';

audit('beneficiary.search_nominee', ['q' => $q]);

// VULNERABLE: concatenated, no parameter binding.
$sql = "SELECT id, name, relation, bank_ifsc FROM nominees WHERE name LIKE '%" . $q . "%'";
$res = $db->query($sql);

echo '<!-- ICP_BACKNAV --><div style="background: #8a2818; color: #f0e8d0; padding: 8px 20px; font-family: \'Times New Roman\', Georgia, serif; font-size: 12px; letter-spacing: 0.08em; border-bottom: 2px solid #c4881e;"><a href="http://icp.lab/" style="color: #f0e8d0; text-decoration: none; margin-right: 18px;">&larr; Shikra Insurance</a><span style="color: #c4881e;">|</span><a href="/dashboard.php" style="color: #f0e8d0; text-decoration: none; margin-left: 18px;">&larr; Beneficiary Office</a></div>';
echo "<h2>Nominee search</h2>";
if (!$res) {
    echo "<p style='color:red'>SQL error: " . $db->error . "</p>";
    exit;
}

echo "<table border=1 cellpadding=4>";
echo "<tr><th>id</th><th>name</th><th>relation</th><th>ifsc</th></tr>";
while ($row = $res->fetch_assoc()) {
    echo "<tr>";
    foreach ($row as $col) echo "<td>" . $col . "</td>";
    echo "</tr>";
}
echo "</table>";
echo "<!-- ICP_45 marker: " . flag_for('ICP_45') . " -->";
