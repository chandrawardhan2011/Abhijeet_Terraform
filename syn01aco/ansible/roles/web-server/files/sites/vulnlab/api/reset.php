<?php
/**
 * POST /api/reset.php
 * Wipes the SQLite DB and the state file. Useful between training sessions.
 */

require __DIR__ . '/../config.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    exit(json_encode(['error' => 'POST only']));
}

@unlink(DB_FILE);
@unlink(STATE_FILE);
init_lab();

echo json_encode(['ok' => true]);
