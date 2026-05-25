<?php
/**
 * /var/www/icp/shared/includes/flags.php
 * Generates the HMAC-suffixed flag strings for each ICP instance.
 * Format: silence1{ICP_<instance>_<hmac8>}
 * The hmac8 is the first 8 hex chars of HMAC-SHA256 over the instance ID
 * keyed with FLAG_HMAC_KEY from /etc/icp/icp.env. Build-time unique.
 */

require_once __DIR__ . '/db.php';

function flag_for($instance) {
    $key = icp_env('FLAG_HMAC_KEY', 'CHANGE_ME_IN_INSTALL');
    $hmac = hash_hmac('sha256', $instance, $key);
    return 'silence1{' . $instance . '_' . substr($hmac, 0, 8) . '}';
}
