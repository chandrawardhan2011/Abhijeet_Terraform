<?php
/**
 * Insecure Direct Object Reference handlers.
 *
 * Endpoint: GET /?vuln=idor&id=<id>
 * Goal:     Read another user's secret (admin's, id=3, contains the flag).
 *
 * The "logged-in user" for the lab is hard-coded to id=1 (alice). The vuln
 * is that the handler returns whatever id is requested, ignoring whose
 * record it actually is.
 */

const IDOR_CURRENT_USER = 1;

function idor_render(?string $content, int $requested_id): string {
    if ($content === null) {
        return '<div class="result empty">No record at id=' . (int)$requested_id . '.</div>';
    }
    return '<div class="result"><div class="kv"><span class="k">id:</span> ' . (int)$requested_id . '</div>'
         . '<div class="kv"><span class="k">secret:</span> ' . htmlspecialchars($content, ENT_QUOTES) . '</div></div>';
}

function idor_lookup(int $id): ?string {
    $st = get_db()->prepare("SELECT content FROM secrets WHERE id=?");
    $st->execute([$id]);
    $v = $st->fetchColumn();
    return $v === false ? null : (string)$v;
}

/* -------------------------- EASY -------------------------- */
/* Raw integer id, no auth check. Increment to enumerate. */

function idor_easy_vuln(): string {
    $id = (int)($_REQUEST['id'] ?? 1);
    return idor_render(idor_lookup($id), $id);
}

function idor_easy_patched(): string {
    $id = (int)($_REQUEST['id'] ?? 1);
    $st = get_db()->prepare("SELECT content FROM secrets WHERE id=? AND owner_id=?");
    $st->execute([$id, IDOR_CURRENT_USER]);
    $v = $st->fetchColumn();
    if ($v === false) {
        return '<div class="result error">Forbidden — not your record.</div>';
    }
    return idor_render((string)$v, $id);
}

/* -------------------------- MEDIUM -------------------------- */
/* "Obfuscated" via base64. Still trivially decoded and re-encoded. */

function idor_medium_vuln(): string {
    $raw = $_REQUEST['id'] ?? base64_encode('1');
    $id  = (int)base64_decode($raw, true);
    return idor_render(idor_lookup($id), $id);
}

function idor_medium_patched(): string {
    return idor_easy_patched();
}

/* -------------------------- HARD -------------------------- */
/* Predictable token: md5("secret_salt_2024" . user_id). Server checks the
   token's existence in a tokens table but not who's requesting. The
   attacker observes their own token, infers the algorithm or finds the
   tokens table reference somewhere else, and forges another user's
   token. (For this lab we accept any token that matches the deterministic
   hash — simulates predictable-token IDOR.) */

const IDOR_HARD_SALT = 'secret_salt_2024';

function idor_hard_token(int $user_id): string {
    return substr(md5(IDOR_HARD_SALT . $user_id), 0, 16);
}

function idor_hard_vuln(): string {
    $token = $_REQUEST['id'] ?? idor_hard_token(IDOR_CURRENT_USER);
    for ($uid = 1; $uid <= 100; $uid++) {
        if (hash_equals(idor_hard_token($uid), $token)) {
            return idor_render(idor_lookup($uid), $uid);
        }
    }
    return '<div class="result error">Invalid token.</div>';
}

function idor_hard_patched(): string {
    return idor_easy_patched();
}
