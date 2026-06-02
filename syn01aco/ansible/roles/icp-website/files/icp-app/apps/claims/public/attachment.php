<?php
/**
 * claims.icp.lab/attachment.php
 * ICP_22 — Path traversal on the `file` parameter.
 * No allow-list, no realpath check. ../../etc/passwd works.
 */

require_once '/var/www/icp/shared/includes/audit.php';

$base = '/var/www/icp/uploads/claims/';
$file = $_GET['file'] ?? '';

audit('claims.attachment', ['file' => $file]);

// VULNERABLE: direct concatenation, no canonicalisation.
$path = $base . $file;

if (!is_readable($path)) {
    http_response_code(404);
    die("Not found: " . htmlspecialchars($file));
}

header('Content-Type: text/plain');
readfile($path);
