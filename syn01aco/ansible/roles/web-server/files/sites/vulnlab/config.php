<?php
/**
 * Central configuration and state management for the vulnerability lab.
 * The state file is the single source of truth for which vulns are open.
 */

define('STATE_DIR',  getenv('VULNLAB_STATE_DIR') ?: '/var/lib/vulnlab');
define('STATE_FILE', STATE_DIR . '/state.json');
define('DB_FILE',    STATE_DIR . '/lab.sqlite');
define('SEED_FILE',  __DIR__ . '/db/seed.sql');
define('FLAG_FILE',  STATE_DIR . '/.flag');

const VULNS  = ['sqli', 'xss', 'idor', 'cmdi', 'lfi'];
const LEVELS = ['easy', 'medium', 'hard'];

function default_state(): array {
    return ['level' => 'easy', 'open_vulns' => [], 'updated_at' => null];
}

/**
 * Read the current state from disk. Sanitises whatever is there —
 * we never trust the file blindly (it could be corrupted, partially
 * written, or tampered with via a successful cmdi exploit).
 */
function get_state(): array {
    if (!is_readable(STATE_FILE)) return default_state();

    $raw = @file_get_contents(STATE_FILE);
    if ($raw === false || $raw === '') return default_state();

    $data = json_decode($raw, true);
    if (!is_array($data)) return default_state();

    $level = in_array($data['level'] ?? '', LEVELS, true) ? $data['level'] : 'easy';
    $open  = array_values(array_intersect($data['open_vulns'] ?? [], VULNS));

    return [
        'level'      => $level,
        'open_vulns' => $open,
        'updated_at' => $data['updated_at'] ?? null,
    ];
}

function current_level(): string {
    return get_state()['level'];
}

function is_open(string $level, string $vuln): bool {
    $s = get_state();
    return $s['level'] === $level && in_array($vuln, $s['open_vulns'], true);
}

/**
 * Atomic write of the state file. tmp + rename guarantees readers
 * never see a partially-written JSON document.
 */
function write_state(string $level, array $open_vulns): array {
    if (!in_array($level, LEVELS, true)) {
        throw new InvalidArgumentException("Bad level: $level");
    }
    $open_vulns = array_values(array_intersect($open_vulns, VULNS));

    $payload = [
        'level'      => $level,
        'open_vulns' => $open_vulns,
        'updated_at' => gmdate('c'),
    ];

    if (!is_dir(STATE_DIR)) {
        mkdir(STATE_DIR, 0750, true);
    }

    $tmp = STATE_FILE . '.tmp.' . getmypid() . '.' . bin2hex(random_bytes(4));
    file_put_contents($tmp, json_encode($payload, JSON_PRETTY_PRINT), LOCK_EX);
    rename($tmp, STATE_FILE);

    return $payload;
}

function get_db(): PDO {
    static $pdo = null;
    if ($pdo === null) {
        $pdo = new PDO('sqlite:' . DB_FILE);
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    }
    return $pdo;
}

/**
 * First-run initialisation: create the DB from seed.sql, drop the flag file,
 * write a default state.json if none exists.
 */
function init_lab(): void {
    if (!is_dir(STATE_DIR)) {
        @mkdir(STATE_DIR, 0750, true);
    }

    if (!file_exists(DB_FILE) || filesize(DB_FILE) === 0) {
        if (file_exists(DB_FILE)) @unlink(DB_FILE);
        $db = new PDO('sqlite:' . DB_FILE);
        $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $sql = file_get_contents(SEED_FILE);
        $db->exec($sql);
    }

    if (!file_exists(FLAG_FILE)) {
        @file_put_contents(FLAG_FILE, "FLAG{vulnlab_filesystem_pwned}\n");
    }

    if (!file_exists(STATE_FILE)) {
        write_state('easy', []);
    }
}
