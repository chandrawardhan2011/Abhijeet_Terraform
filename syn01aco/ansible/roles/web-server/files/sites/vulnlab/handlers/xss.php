<?php
/**
 * Cross-site scripting handlers (reflected).
 *
 * Endpoint: GET /?vuln=xss&name=<input>
 * Goal:     Execute arbitrary JS in the browser session.
 */

/* -------------------------- EASY -------------------------- */
/* Direct echo, no encoding. */

function xss_easy_vuln(): string {
    $name = $_REQUEST['name'] ?? '';
    return "<div class=\"result\">Hello, $name! Welcome to the lab.</div>";
}

function xss_easy_patched(): string {
    $name = htmlspecialchars($_REQUEST['name'] ?? '', ENT_QUOTES, 'UTF-8');
    return "<div class=\"result\">Hello, $name! Welcome to the lab.</div>";
}

/* -------------------------- MEDIUM -------------------------- */
/* Strips literal <script>...</script>. Bypass with event handlers like
   <img src=x onerror=...> or <svg onload=...>. */

function xss_medium_vuln(): string {
    $name = $_REQUEST['name'] ?? '';
    $name = preg_replace('/<script\b[^>]*>.*?<\/script>/is', '', $name);
    return "<div class=\"result\">Hello, $name! Welcome to the lab.</div>";
}

function xss_medium_patched(): string {
    return xss_easy_patched();
}

/* -------------------------- HARD -------------------------- */
/* Case-insensitive blacklist on common keywords. Bypassable with nested
   reconstruction (<scrSCRIPTipt>), or HTML entities, or javascript: URIs
   in href contexts. */

function xss_hard_vuln(): string {
    $name = $_REQUEST['name'] ?? '';
    foreach (['script', 'onerror', 'onload', 'onclick', 'javascript:'] as $bad) {
        $name = str_ireplace($bad, '', $name);
    }
    return "<div class=\"result\">Hello, $name! Welcome to the lab.</div>";
}

function xss_hard_patched(): string {
    return xss_easy_patched();
}
