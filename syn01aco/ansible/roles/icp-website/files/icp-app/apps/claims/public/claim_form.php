<?php
/**
 * claims.icp.lab/claim_form.php
 * ICP_23 — Local File Inclusion on `tpl` parameter.
 * Templates expected: basic, motor, health, travel, home.
 * include() is called on whatever the user supplies — absolute paths work.
 */

require_once '/var/www/icp/shared/includes/audit.php';

$tpl = $_GET['tpl'] ?? 'basic';

audit('claims.claim_form', ['tpl' => $tpl]);

echo "<h2>New claim — template: " . htmlspecialchars($tpl) . "</h2>";

$base = '/var/www/icp/templates/claims/';

// VULNERABLE: no allow-list, accepts absolute paths.
if (str_starts_with($tpl, '/')) {
    include($tpl);   // direct LFI
} else {
    include($base . $tpl . '.php');
}
?>
<!-- ICP_BACKNAV -->
<div style="background: #8a2818; color: #f0e8d0; padding: 8px 20px; font-family: 'Times New Roman', Georgia, serif; font-size: 12px; letter-spacing: 0.08em; border-bottom: 2px solid #c4881e;">
  <a href="http://icp.lab/" style="color: #f0e8d0; text-decoration: none;">&larr; Shikra Insurance</a>
</div>

<form action="/submit_claim.php" method=POST>
  <input type=hidden name=tpl value="<?= htmlspecialchars($tpl) ?>">
  <button>Submit (see ICP_24/ICP_25)</button>
</form>
