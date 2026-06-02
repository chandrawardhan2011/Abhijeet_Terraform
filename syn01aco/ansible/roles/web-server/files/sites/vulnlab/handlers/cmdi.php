<?php
/**
 * Command injection handlers (ping utility).
 *
 * Endpoint: GET /?vuln=cmdi&host=<host>
 * Goal:     Execute arbitrary shell commands.
 */

function cmdi_render(string $output, string $cmd = ''): string {
    $out = '<div class="result"><pre class="terminal">' . htmlspecialchars($output) . '</pre>';
    if ($cmd !== '') {
        $out .= '<pre class="debug">$ ' . htmlspecialchars($cmd) . '</pre>';
    }
    return $out . '</div>';
}

function cmdi_run(string $cmd): string {
    $output = @shell_exec($cmd . ' 2>&1');
    return $output ?? '(no output)';
}

/* -------------------------- EASY -------------------------- */
/* Raw concatenation. ;id, $(id), `id`, |id all work. */

function cmdi_easy_vuln(): string {
    $host = $_REQUEST['host'] ?? '127.0.0.1';
    $cmd  = "ping -c 1 -W 1 $host";
    return cmdi_render(cmdi_run($cmd), $cmd);
}

function cmdi_easy_patched(): string {
    $host = $_REQUEST['host'] ?? '127.0.0.1';
    if (!filter_var($host, FILTER_VALIDATE_IP) && !preg_match('/^[a-zA-Z0-9.-]{1,253}$/', $host)) {
        return cmdi_render('Invalid host.');
    }
    $cmd = "ping -c 1 -W 1 " . escapeshellarg($host);
    return cmdi_render(cmdi_run($cmd));
}

/* -------------------------- MEDIUM -------------------------- */
/* Strips ; and &. Bypass with |id, `id`, $(id), or newline. */

function cmdi_medium_vuln(): string {
    $host = $_REQUEST['host'] ?? '127.0.0.1';
    $host = str_replace([';', '&'], '', $host);
    $cmd  = "ping -c 1 -W 1 $host";
    return cmdi_render(cmdi_run($cmd));
}

function cmdi_medium_patched(): string {
    return cmdi_easy_patched();
}

/* -------------------------- HARD -------------------------- */
/* Accepts only "IP-looking" input via unanchored regex. Bypass:
   "1.1.1.1$(id)" matches the regex but still hits the shell. Or use an
   IP-with-padding trick. */

function cmdi_hard_vuln(): string {
    $host = $_REQUEST['host'] ?? '127.0.0.1';
    if (!preg_match('/\d+\.\d+\.\d+\.\d+/', $host)) {
        return cmdi_render('Invalid format — must contain an IP.');
    }
    $cmd = "ping -c 1 -W 1 $host";
    return cmdi_render(cmdi_run($cmd));
}

function cmdi_hard_patched(): string {
    return cmdi_easy_patched();
}
