<?php
/**
 * beneficiary.icp.lab/payout_view.php
 * ICP_44 — Weak crypto: bank_account_enc decrypted with hardcoded AES-ECB key.
 *          The ciphertext is also exposed (header line) to demonstrate ECB
 *          pattern leakage — identical accounts produce identical ciphertext.
 */

require_once '/var/www/icp/shared/includes/db.php';
require_once '/var/www/icp/shared/includes/audit.php';
require_once '/var/www/icp/shared/includes/flags.php';
require_once __DIR__ . '/../lib/crypto.php';

$db = icp_db();
audit('beneficiary.payout_view', []);

$res = $db->query('SELECT id, name, bank_ifsc, bank_account_enc FROM nominees ORDER BY id');

echo '<!-- ICP_BACKNAV --><div style="background: #8a2818; color: #f0e8d0; padding: 8px 20px; font-family: \'Times New Roman\', Georgia, serif; font-size: 12px; letter-spacing: 0.08em; border-bottom: 2px solid #c4881e;"><a href="http://icp.lab/" style="color: #f0e8d0; text-decoration: none; margin-right: 18px;">&larr; Shikra Insurance</a><span style="color: #c4881e;">|</span><a href="/dashboard.php" style="color: #f0e8d0; text-decoration: none; margin-left: 18px;">&larr; Beneficiary Office</a></div>';
echo "<h2>Payout instructions (decrypted view)</h2>";
echo "<table border=1 cellpadding=4>";
echo "<tr><th>id</th><th>name</th><th>IFSC</th><th>account (decrypted)</th><th>ciphertext (hex)</th></tr>";
while ($row = $res->fetch_assoc()) {
    $plain = icp_weak_decrypt($row['bank_account_enc']);
    echo "<tr>";
    echo "<td>" . (int)$row['id'] . "</td>";
    echo "<td>" . htmlspecialchars($row['name']) . "</td>";
    echo "<td>" . htmlspecialchars($row['bank_ifsc']) . "</td>";
    echo "<td>" . htmlspecialchars($plain) . "</td>";
    echo "<td><code>" . bin2hex($row['bank_account_enc']) . "</code></td>";
    echo "</tr>";
}
echo "</table>";
echo "<!-- ICP_44 marker: " . flag_for('ICP_44') . " -->";
echo "<!-- key length: 16 bytes; mode: ECB; key location: lib/crypto.php (search the .git or LFI to confirm) -->";
