<?php
/**
 * GET /api/state.php
 * Returns the current state.json contents.
 */

require __DIR__ . '/../config.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

echo json_encode(get_state());
