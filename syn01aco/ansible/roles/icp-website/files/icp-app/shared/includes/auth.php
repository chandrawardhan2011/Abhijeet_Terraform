<?php
/**
 * /var/www/icp/shared/includes/auth.php
 * Session helpers shared across sub-apps.
 * Note: ICP_43 (session fixation in beneficiary/login.php) deliberately
 * does NOT call session_regenerate_id() on login.
 */

function icp_session_start() {
    if (session_status() === PHP_SESSION_NONE) {
        // Cookie params intentionally weak — no Secure, no SameSite.
        // HttpOnly is on so reflected/stored XSS doesn't trivially read PHPSESSID,
        // but the IDOR/IDOR-write vulns don't depend on cookie theft anyway.
        session_set_cookie_params([
            'lifetime' => 0,
            'path'     => '/',
            'httponly' => true,
        ]);
        session_start();
    }
}

function require_login() {
    icp_session_start();
    if (empty($_SESSION['user_id'])) {
        header('Location: /login.php');
        exit;
    }
}

function require_role($role) {
    require_login();
    if (($_SESSION['role'] ?? '') !== $role) {
        http_response_code(403);
        die('Forbidden — role required: ' . htmlspecialchars($role));
    }
}

function current_user_id() {
    icp_session_start();
    return (int)($_SESSION['user_id'] ?? 0);
}
