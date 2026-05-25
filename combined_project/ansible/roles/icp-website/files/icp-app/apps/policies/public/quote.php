<?php
/**
 * policies.icp.lab/quote.php
 * ICP_12 — Reflected XSS on the `age` parameter.
 * ICP_15 — Missing audit log: this endpoint deliberately does NOT call audit().
 *
 * The flag for ICP_12 is rendered into the page when the XSS fires,
 * via document.title manipulation in the payload — so the attacker
 * can capture it from the response body.
 *
 * The flag for ICP_15 is exposed only when the audit_log table has
 * NO 'policies.quote' event for the last hour — the attacker proves
 * the gap by submitting a quote, then querying audit_log via another
 * vulnerability (e.g., the SQLi on search.php) and confirming silence.
 * For lab simplicity we surface the ICP_15 flag in an HTML comment.
 */

require_once '/var/www/icp/shared/includes/flags.php';

$age  = $_GET['age']  ?? '30';
$plan = $_GET['plan'] ?? 'TERM';

// VULNERABLE: $age echoed without encoding.
$base    = 5000;
$premium = is_numeric($age) ? $base + ((int)$age * 120) : 'NaN';

// Note: NO audit() call here — this is ICP_15.
?>
<!-- ICP_BACKNAV -->
<div style="background: #8a2818; color: #f0e8d0; padding: 8px 20px; font-family: 'Times New Roman', Georgia, serif; font-size: 12px; letter-spacing: 0.08em; border-bottom: 2px solid #c4881e;">
  <a href="http://icp.lab/" style="color: #f0e8d0; text-decoration: none;">&larr; Shikra Insurance</a>
</div>

<h2>Premium quote</h2>
<p>For age <b><?= $age ?></b> on plan <b><?= htmlspecialchars($plan) ?></b>:</p>
<p>Estimated premium: <b><?= $premium ?></b></p>
<p><a href="/search.php">Back to catalogue</a></p>

<!-- ICP_15 marker: <?= flag_for('ICP_15') ?> -->
<!-- (This endpoint never writes to audit_log; the marker is here for lab capture.) -->
