<?php
/**
 * Shikra Insurance — shared header partial
 * Included by every landing-tier page.
 *
 * Variables expected:
 *   $page_title  string  shown in <title>
 *   $page_ref    string  bureau-style file reference shown top-right
 *   $active_nav  string  identifier of the current nav item (home, about, ...)
 */
$page_title  = $page_title  ?? 'Shikra Insurance';
$page_ref    = $page_ref    ?? 'F.№ ICP/0000/0';
$active_nav  = $active_nav  ?? '';
function _navlink($id, $href, $label, $active) {
    $cls = ($id === $active) ? ' style="background:var(--oxide);"' : '';
    echo "<li><a href=\"{$href}\"{$cls}>{$label}</a></li>";
}
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title><?= htmlspecialchars($page_title) ?> · Shikra Insurance</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="stylesheet" href="/assets/shikra.css">
</head>
<body>

<div class="bureau-bar">
  <div class="row">
    <span>Shikra Insurance Co-operative · Reg. №. SHK/1962/IND/47</span>
    <span>Helpline · 1800-SHIKRA &middot; <a href="/staff/" style="color:inherit; text-decoration:underline;">Staff Login</a></span>
  </div>
</div>

<div class="shell">

  <header class="masthead">
    <div class="crest">
      <!-- Stylised geometric shikra crest. All circles and straight lines. -->
      <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
        <circle cx="50" cy="50" r="46" fill="none" stroke="#8a2818" stroke-width="3"/>
        <circle cx="50" cy="50" r="38" fill="none" stroke="#1a1a1a" stroke-width="1"/>
        <!-- Bird body: blocky, abstracted, facing right -->
        <polygon points="30,55 50,30 70,55 65,55 50,42 35,55" fill="#8a2818"/>
        <polygon points="50,42 50,70 56,70 56,50" fill="#1a1a1a"/>
        <!-- Wing accents -->
        <polygon points="30,55 35,55 32,68 25,60" fill="#c4881e"/>
        <polygon points="70,55 65,55 68,68 75,60" fill="#c4881e"/>
        <!-- Eye -->
        <circle cx="48" cy="38" r="1.5" fill="#f0e8d0"/>
        <!-- Lower star (state symbol) -->
        <polygon points="50,80 52,84 56,84 53,87 54,91 50,89 46,91 47,87 44,84 48,84" fill="#1a1a1a"/>
      </svg>
    </div>
    <div>
      <div class="wordmark">SHIKRA <span class="pun">INSURANCE</span></div>
      <div class="tagline">For the responsible citizen · Established 1962</div>
    </div>
    <div class="reference">
      File ref.<br>
      <strong><?= htmlspecialchars($page_ref) ?></strong><br>
      Form rev. 12 · 2026
    </div>
  </header>

</div>

<nav class="primary-nav" aria-label="Primary">
  <ul>
    <?php
    _navlink('home',     '/',                    'Home',            $active_nav);
    _navlink('about',    '/about/',              'About the Bureau', $active_nav);
    _navlink('careers',  '/careers/',            'Careers',         $active_nav);
    _navlink('press',    '/press/',              'Press',           $active_nav);
    _navlink('voices',   '/voices/',             'Customer Voices', $active_nav);
    _navlink('contact',  '/contact/',            'Contact',         $active_nav);
    _navlink('staff',    '/staff/',              'Staff Login',     $active_nav);
    ?>
  </ul>
</nav>

<div class="shell">
