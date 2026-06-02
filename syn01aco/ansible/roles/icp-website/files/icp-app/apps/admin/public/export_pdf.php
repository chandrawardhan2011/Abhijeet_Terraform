<?php
/**
 * admin.icp.lab/export_pdf.php
 * ICP_53 — OS command injection on the `claim_no` parameter.
 *          shell_exec("convert ... C{claim_no}.txt out.pdf") — concatenated.
 *          Payload: claim_no=1;cat /etc/shadow
 */

require_once '/var/www/icp/shared/includes/audit.php';
require_once '/var/www/icp/shared/includes/flags.php';

$claim_no = $_REQUEST['claim_no'] ?? '';

audit('admin.export_pdf', ['claim_no' => $claim_no]);

if ($claim_no === '') {
    echo "<h2>Export claim as PDF</h2>";
    echo "<form method=POST>Claim number: <input name=claim_no value='C001'> ";
    echo "<button>Export</button></form>";
    exit;
}

// VULNERABLE (ICP_53): direct concatenation into a shell command.
// We use `echo` not `convert` so no extra packages are needed in the lab.
$cmd = "echo 'Exporting claim ' " . $claim_no . " 2>&1";
$out = shell_exec($cmd);

echo "<h2>Export result</h2>";
echo "<pre>" . htmlspecialchars($out) . "</pre>";
echo "<!-- ICP_53 marker: " . flag_for('ICP_53') . " -->";
