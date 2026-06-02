<?php
/**
 * /var/www/icp/shared/includes/db.php
 * Shared MySQLi connection for all 5 ICP sub-apps.
 * Reads credentials from /etc/icp/icp.env (mode 0640, root:www-data).
 */

function icp_env($key, $default = null) {
    static $env = null;
    if ($env === null) {
        $env = [];
        $path = '/etc/icp/icp.env';
        if (is_readable($path)) {
            foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
                if (preg_match('/^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*)$/', $line, $m)) {
                    $env[$m[1]] = trim($m[2], "\"' \t");
                }
            }
        }
    }
    return $env[$key] ?? $default;
}

function icp_db() {
    static $conn = null;
    if ($conn === null) {
        $host = icp_env('ICP_DB_HOST', '127.0.0.1');
        $user = icp_env('ICP_DB_USER', 'icp_app');
        $pass = icp_env('ICP_DB_PASS', '');
        $name = icp_env('ICP_DB_NAME', 'icp');
        $conn = new mysqli($host, $user, $pass, $name);
        if ($conn->connect_error) {
            http_response_code(500);
            // Note: DB error displayed verbatim — this is intentional for ICP_11/33/45/54
            die('Database connection failed: ' . $conn->connect_error);
        }
        $conn->set_charset('utf8mb4');
    }
    return $conn;
}
