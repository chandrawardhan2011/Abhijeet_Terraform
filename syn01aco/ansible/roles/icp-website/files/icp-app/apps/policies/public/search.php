<?php
/**
 * policies.icp.lab/search.php
 * ICP_11 — SQL Injection (UNION-based) on the `plan` parameter.
 * Flag is in policies.flag_note for row 7. UNION SELECT can pull it out.
 */

require_once '/var/www/icp/shared/includes/db.php';
require_once '/var/www/icp/shared/includes/audit.php';

$db   = icp_db();
$plan = $_GET['plan'] ?? '';

audit('policies.search', ['plan' => $plan]);

// VULNERABLE: string concatenation, no parameter binding.
$sql = "SELECT id, name, plan, premium FROM policies WHERE plan LIKE '%" . $plan . "%'";
$res = $db->query($sql);

echo '<!-- ICP_BACKNAV --><div style="background: #8a2818; color: #f0e8d0; padding: 8px 20px; font-family: \'Times New Roman\', Georgia, serif; font-size: 12px; letter-spacing: 0.08em; border-bottom: 2px solid #c4881e;"><a href="http://icp.lab/" style="color: #f0e8d0; text-decoration: none;">&larr; Shikra Insurance</a></div>';
echo "<h2>Policy search</h2>";
echo "<form><input name='plan' value='" . htmlspecialchars($plan) . "'><button>Search</button></form>";

if (!$res) {
    // Verbose error disclosure — supports M2.1-style enumeration too.
    echo "<p style='color:red'>SQL error: " . $db->error . "</p>";
    exit;
}

echo "<table border=1 cellpadding=4><tr><th>id</th><th>name</th><th>plan</th><th>premium</th></tr>";
while ($row = $res->fetch_assoc()) {
    echo "<tr>";
    foreach ($row as $col) {
        // No encoding — but the columns we expose here are numeric/enum.
        // The flag lands in column 4 of a UNION SELECT, which renders fine.
        echo "<td>" . $col . "</td>";
    }
    echo "</tr>";
}
echo "</table>";
