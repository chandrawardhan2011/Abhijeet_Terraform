<?php
/**
 * Front controller.
 * - If no vuln requested AND lab not yet configured → redirect to instructor
 * - If no vuln requested AND lab configured         → render Mazari page
 * - If vuln requested                               → dispatch to handler
 */

require __DIR__ . '/config.php';
init_lab();

$state = get_state();
$level = $state['level'];
$vuln  = $_REQUEST['vuln'] ?? null;

// Dispatch vuln handler requests
if ($vuln) {
    if (!in_array($vuln, VULNS, true)) {
        http_response_code(404);
        exit('Unknown vuln');
    }
    require __DIR__ . "/handlers/$vuln.php";
    $mode = is_open($level, $vuln) ? 'vuln' : 'patched';
    $fn   = "{$vuln}_{$level}_{$mode}";
    if (!function_exists($fn)) {
        http_response_code(500);
        exit("Missing handler: $fn");
    }
    echo $fn();
    exit;
}

// No vuln — check if instructor has configured the lab yet
// "Configured" means updated_at is set (instructor has hit Apply at least once)
if (empty($state['updated_at'])) {
    header('Location: instructor.php');
    exit;
}

// Lab is configured — render Mazari Tours page
include __DIR__ . '/views/lab.php';
