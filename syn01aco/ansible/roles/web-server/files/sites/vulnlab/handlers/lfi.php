<?php
/**
 * Local/Remote File Inclusion handlers.
 *
 * Endpoint: GET /?vuln=lfi&page=<page>
 * Goal:     Read arbitrary files on the server (/etc/passwd, the flag file,
 *           PHP source via php://filter, or include remote code via RFI).
 */

function lfi_render(string $content, string $debug = ''): string {
    $out = '<div class="result"><pre class="terminal">' . htmlspecialchars($content) . '</pre>';
    if ($debug !== '') {
        $out .= '<pre class="debug">' . htmlspecialchars($debug) . '</pre>';
    }
    return $out . '</div>';
}

const LFI_PAGES_DIR = __DIR__ . '/../pages';

/* -------------------------- EASY -------------------------- */
/* Direct file_get_contents on user input. Absolute paths, traversal,
   and (if allow_url_include is on in php.ini) remote URLs all work. */

function lfi_easy_vuln(): string {
    $page = $_REQUEST['page'] ?? 'home';
    $candidate = LFI_PAGES_DIR . "/$page.php";
    $path = file_exists($candidate) ? $candidate : $page;
    $content = @file_get_contents($path);
    if ($content === false) {
        return lfi_render("Could not read: $path");
    }
    return lfi_render($content, "loaded: $path");
}

function lfi_easy_patched(): string {
    $allowed = ['home', 'about', 'contact'];
    $page = $_REQUEST['page'] ?? 'home';
    if (!in_array($page, $allowed, true)) {
        http_response_code(404);
        return lfi_render('Page not found.');
    }
    return lfi_render(file_get_contents(LFI_PAGES_DIR . "/$page.php"));
}

/* -------------------------- MEDIUM -------------------------- */
/* Appends .php. Bypass with php://filter/convert.base64-encode/resource=...
   to leak PHP source, or with a traversal that ends with .php. */

function lfi_medium_vuln(): string {
    $page = $_REQUEST['page'] ?? 'home';
    $path = LFI_PAGES_DIR . "/$page.php";
    $content = @file_get_contents($path);
    if ($content === false) {
        $content = @file_get_contents($page . '.php');
    }
    return lfi_render($content !== false ? $content : "Could not load: $page.php");
}

function lfi_medium_patched(): string {
    return lfi_easy_patched();
}

/* -------------------------- HARD -------------------------- */
/* Strips ../ literally one time, with no replacement. Bypass:
     - ....//        -> after one strip becomes ../
     - %2e%2e%2f     -> URL-encoded traversal
     - ..././        -> nested */

function lfi_hard_vuln(): string {
    $page = $_REQUEST['page'] ?? 'home';
    $clean = str_replace('../', '', $page);
    $path  = LFI_PAGES_DIR . "/$clean";
    $content = @file_get_contents($path);
    if ($content === false) {
        return lfi_render("Could not load: $clean");
    }
    return lfi_render($content);
}

function lfi_hard_patched(): string {
    return lfi_easy_patched();
}
