<?php
/**
 * POST /api/configure.php
 * Body: {"level": "easy", "open_vulns": ["sqli", "xss"]}
 *
 * Called by the frontend selector when the user submits their choice.
 */

require __DIR__ . '/../config.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') exit;
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    exit(json_encode(['error' => 'POST only']));
}

$raw = file_get_contents('php://input');
$in  = json_decode($raw, true);
if (!is_array($in)) {
    http_response_code(400);
    exit(json_encode(['error' => 'bad json']));
}

try {
    $payload = write_state($in['level'] ?? '', $in['open_vulns'] ?? []);
    echo json_encode(['ok' => true, 'state' => $payload]);
} catch (Throwable $e) {
    http_response_code(400);
    echo json_encode(['error' => $e->getMessage()]);
}
