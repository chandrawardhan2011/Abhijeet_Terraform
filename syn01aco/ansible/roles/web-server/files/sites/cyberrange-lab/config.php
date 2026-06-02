<?php
// Connect to MariaDB on db-server — populated by Ansible before this runs
$db_host = '10.0.20.30';
$db_name = 'cyber_range';
$db_user = 'webapp';
$db_pass = 'webapp123';

try {
    $pdo = new PDO("mysql:host=$db_host;dbname=$db_name;charset=utf8", $db_user, $db_pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    ]);
    // Legacy $db object — handlers use $db->query() which is SQLite3 API.
    // Wrap PDO in a thin shim so existing handlers work without changes.
    $db = new class($pdo) {
        public function __construct(private PDO $pdo) {}
        public function query(string $sql): object {
            $stmt = $this->pdo->query($sql);
            return new class($stmt) {
                public function __construct(private PDOStatement $s) {}
                public function fetchArray(int $mode = SQLITE3_ASSOC): array|false {
                    $row = $this->s->fetch(PDO::FETCH_ASSOC);
                    return $row === false ? false : $row;
                }
            };
        }
        public function escapeString(string $s): string {
            return addslashes($s);
        }
    };
} catch (Exception $e) {
    die("Database connection failed: " . $e->getMessage());
}
?>
