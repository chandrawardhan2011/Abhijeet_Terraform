<?php
/**
 * SQL injection handlers.
 *
 * Endpoint: GET /?vuln=sqli&q=<search>
 * Goal:     Find admin (id=3) or extract the flag from secrets table.
 */

function sqli_render(array $rows, string $debug = ''): string {
    if (!$rows) {
        return '<div class="result empty">No users found.</div>';
    }
    $out = '<div class="result"><table><thead><tr><th>id</th><th>username</th><th>email</th></tr></thead><tbody>';
    foreach ($rows as $r) {
        $out .= '<tr>';
        $out .= '<td>' . htmlspecialchars((string)($r['id'] ?? ''), ENT_QUOTES) . '</td>';
        $out .= '<td>' . htmlspecialchars((string)($r['username'] ?? ''), ENT_QUOTES) . '</td>';
        $out .= '<td>' . htmlspecialchars((string)($r['email'] ?? ''), ENT_QUOTES) . '</td>';
        $out .= '</tr>';
    }
    $out .= '</tbody></table>';
    if ($debug !== '') {
        $out .= '<pre class="debug">' . htmlspecialchars($debug) . '</pre>';
    }
    $out .= '</div>';
    return $out;
}

/* -------------------------- EASY -------------------------- */

function sqli_easy_vuln(): string {
    $q = $_REQUEST['q'] ?? '';
    $sql = "SELECT id, username, email FROM users WHERE username LIKE '%$q%'";
    try {
        $rows = get_db()->query($sql)->fetchAll(PDO::FETCH_ASSOC);
        return sqli_render($rows, $sql);
    } catch (Throwable $e) {
        return '<div class="result error">' . htmlspecialchars($e->getMessage()) . '<pre class="debug">' . htmlspecialchars($sql) . '</pre></div>';
    }
}

function sqli_easy_patched(): string {
    $q  = $_REQUEST['q'] ?? '';
    $st = get_db()->prepare("SELECT id, username, email FROM users WHERE username LIKE ?");
    $st->execute(["%$q%"]);
    return sqli_render($st->fetchAll(PDO::FETCH_ASSOC));
}

/* -------------------------- MEDIUM -------------------------- */
/* Naive blacklist filter. Bypassable with mixed case, comments, or
   alternative keywords. */

function sqli_medium_vuln(): string {
    $q = $_REQUEST['q'] ?? '';
    if (preg_match('/\b(union|select|--|or|and)\b/i', $q)) {
        return '<div class="result error">Blocked: dangerous keyword detected.</div>';
    }
    $sql = "SELECT id, username, email FROM users WHERE username LIKE '%$q%'";
    try {
        $rows = get_db()->query($sql)->fetchAll(PDO::FETCH_ASSOC);
        return sqli_render($rows);
    } catch (Throwable $e) {
        return '<div class="result error">Query failed.</div>';
    }
}

function sqli_medium_patched(): string {
    return sqli_easy_patched();
}

/* -------------------------- HARD -------------------------- */
/* Boolean-blind only. Quotes escaped but query still string-concatenated,
   so integer/boolean injection works. Errors suppressed, no rows echoed —
   only "Found" / "Not found", so it's pure blind SQLi. */

function sqli_hard_vuln(): string {
    $q   = str_replace("'", "''", $_REQUEST['q'] ?? '');
    $sql = "SELECT COUNT(*) AS c FROM users WHERE username='$q'";
    try {
        $row = get_db()->query($sql)->fetch(PDO::FETCH_ASSOC);
        $found = ($row['c'] ?? 0) > 0;
    } catch (Throwable $e) {
        $found = false;
    }
    return '<div class="result">' . ($found ? 'Found.' : 'Not found.') . '</div>';
}

function sqli_hard_patched(): string {
    $q  = $_REQUEST['q'] ?? '';
    $st = get_db()->prepare("SELECT COUNT(*) AS c FROM users WHERE username=?");
    $st->execute([$q]);
    $found = $st->fetchColumn() > 0;
    return '<div class="result">' . ($found ? 'Found.' : 'Not found.') . '</div>';
}
