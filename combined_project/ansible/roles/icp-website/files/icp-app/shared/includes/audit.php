<?php
/**
 * /var/www/icp/shared/includes/audit.php
 * Emits structured audit events to the audit_log table.
 * Wazuh tails the MySQL slow/general log; in production this would also
 * write to /var/log/icp/audit.log for direct Wazuh agent consumption.
 *
 * Note: ICP_15 deliberately does NOT call this — that vulnerability is
 * "missing audit log on quote endpoint".
 */

require_once __DIR__ . '/db.php';

function audit($event, $details = []) {
    $db = icp_db();
    $stmt = $db->prepare(
        'INSERT INTO audit_log (ts, event, source_ip, user_id, details) ' .
        'VALUES (NOW(), ?, ?, ?, ?)'
    );
    $ip      = $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
    $user_id = $_SESSION['user_id'] ?? 0;
    $json    = json_encode($details, JSON_UNESCAPED_SLASHES);
    $stmt->bind_param('ssis', $event, $ip, $user_id, $json);
    $stmt->execute();
    $stmt->close();
}
