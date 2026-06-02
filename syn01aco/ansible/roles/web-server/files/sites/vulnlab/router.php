<?php
/**
 * Router for the PHP built-in server (php -S).
 * Apache uses /docker/apache.conf for the same job in the Docker setup.
 *
 * Maps:
 *   /                 -> index.php (lab page)
 *   /api/configure    -> api/configure.php
 *   /api/state        -> api/state.php
 *   /api/reset        -> api/reset.php
 *   /public/*         -> served as static files
 *   everything else   -> falls through to index.php
 */

$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

if (preg_match('#^/(handlers|views|pages|config\.php|router\.php)#', $uri)) {
    http_response_code(403);
    exit('Forbidden');
}

if (preg_match('#^/api/(configure|state|reset)$#', $uri, $m)) {
    require __DIR__ . "/api/{$m[1]}.php";
    return true;
}

if (preg_match('#^/public/.+\.(css|js|png|svg)$#', $uri)) {
    return false;
}

require __DIR__ . '/index.php';
return true;
