<?php

class VulnManager {

    private static $config = null;

    public static function load() {

        if (self::$config !== null) {
            return;
        }

        $path = __DIR__ . '/config/config.json';

        if (!file_exists($path)) {
            die("Missing config.json");
        }

        self::$config = json_decode(
            file_get_contents($path),
            true
        );
    }

    public static function enabled($vuln) {

        self::load();

        if (!isset(self::$config['enabled_vulnerabilities'])) {
            return false;
        }

        return in_array(
            $vuln,
            self::$config['enabled_vulnerabilities']
        );
    }

    public static function difficulty() {

        self::load();

        return self::$config['difficulty'] ?? 'easy';
    }
}
?>
