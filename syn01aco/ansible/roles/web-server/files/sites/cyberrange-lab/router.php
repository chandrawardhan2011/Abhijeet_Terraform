<?php

require_once 'vuln_manager.php';

class Router {

    public static function load($handler) {

        if (!VulnManager::enabled($handler)) {

            http_response_code(404);

            die("404 Not Found");
        }

        $path = __DIR__ . "/handlers/$handler.php";

        if (!file_exists($path)) {

            die("Handler missing.");
        }

        require $path;
    }
}
?>
