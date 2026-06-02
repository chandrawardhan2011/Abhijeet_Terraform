<?php
/**
 * Shikra Insurance — shared dashboard head.
 *
 * Usage:
 *   $sb_section = 'beneficiary';   // or 'admin'
 *   $sb_active  = 'dashboard';     // item id
 *   $sb_user    = $user;           // associative array with username, role, etc.
 *   $icp_title  = 'Beneficiary Home';
 *   require '/var/www/icp/shared/partials/dashboard_head.php';
 *   // ... page content ...
 *   require '/var/www/icp/shared/partials/dashboard_foot.php';
 */

$sb_section = $sb_section ?? 'beneficiary';
$sb_active  = $sb_active  ?? '';
$sb_user    = $sb_user    ?? null;
$icp_title  = $icp_title  ?? 'Shikra Insurance';

$sections = [
    'beneficiary' => [
        'title'    => 'Beneficiary Office',
        'subtitle' => 'Branch IV',
        'items' => [
            ['id' => 'dashboard',  'label' => 'Beneficiary Home',  'href' => '/dashboard.php'],
            ['id' => 'nominee',    'label' => 'View Nominee',      'href' => '/nominee.php?nid=1'],
            ['id' => 'payout',     'label' => 'Payout Records',    'href' => '/payout_view.php?id=1'],
            ['id' => 'search',     'label' => 'Nominee Search',    'href' => '/search_nominee.php'],
            ['id' => 'logout',     'label' => 'Sign out',          'href' => '/logout.php'],
        ],
    ],
    'admin' => [
        'title'    => 'Adjuster Console',
        'subtitle' => 'Branch V',
        'items' => [
            ['id' => 'dashboard',  'label' => 'Adjuster Home',     'href' => '/admin/dashboard.php'],
            ['id' => 'find',       'label' => 'Personnel Search',  'href' => '/admin/find.php'],
            ['id' => 'adjudicate', 'label' => 'Adjudication Queue','href' => '/adjudicate.php'],
            ['id' => 'export',     'label' => 'Export Claim PDF',  'href' => '/export_pdf.php'],
            ['id' => 'users',      'label' => 'User Management',   'href' => '/admin/users.php'],
            ['id' => 'logout',     'label' => 'Sign out',          'href' => '/admin/logout.php'],
        ],
    ],
];

$sect = $sections[$sb_section] ?? $sections['beneficiary'];
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title><?= htmlspecialchars($icp_title) ?> &middot; Shikra Insurance</title>
<style>
  :root {
    --oxide: #8a2818;
    --oxide-dark: #5b1a10;
    --mustard: #c4881e;
    --mustard-dark: #8a5e0a;
    --parchment: #f0e8d0;
    --parchment-dim: #d8cdaa;
    --ink: #1a1a1a;
    --ink-soft: #4a4a4a;
  }
  body { margin:0; font-family: 'Times New Roman', Georgia, serif; background: var(--parchment); color: var(--ink); }
  .icp-app { display: grid; grid-template-columns: 240px 1fr; min-height: 100vh; }

  .icp-sidebar { background: var(--oxide); color: var(--parchment); padding: 24px 0; display:flex; flex-direction:column; border-right: 3px double var(--mustard); }
  .icp-sidebar-brand { padding: 0 18px 18px; border-bottom: 1px solid rgba(240,232,208,0.18); display:flex; gap:12px; align-items:center; }
  .icp-sidebar-mark { width:38px; height:38px; border-radius:50%; background: var(--mustard); color: var(--oxide); display:grid; place-items:center; font-weight:bold; font-size:13px; letter-spacing:0.05em; }
  .icp-sidebar-title { font-size:13px; letter-spacing:0.1em; line-height:1.3; text-transform: uppercase; }
  .icp-sidebar-subtitle { font-size:10px; letter-spacing:0.18em; text-transform:uppercase; opacity:0.75; margin-top:2px; }
  .icp-sidebar-user { padding: 14px 18px; background: rgba(196,136,30,0.18); border-bottom:1px solid rgba(240,232,208,0.15); }
  .icp-sidebar-user-name { font-size:13px; font-style:italic; }
  .icp-sidebar-user-role { font-size:10px; letter-spacing:0.12em; text-transform:uppercase; opacity:0.7; margin-top:2px; }
  .icp-sidebar-nav { padding: 12px 0; flex: 1; }
  .icp-sidebar-link { display:block; padding:9px 18px; color:var(--parchment); text-decoration:none; font-size:13px; border-left:3px solid transparent; transition: background 0.15s, border-color 0.15s; }
  .icp-sidebar-link:hover { background: rgba(240,232,208,0.08); border-left-color: rgba(196,136,30,0.6); }
  .icp-sidebar-link--active { background: rgba(196,136,30,0.22); border-left-color: var(--mustard); font-weight:bold; }
  .icp-sidebar-footer { padding: 14px 18px; font-size:10px; letter-spacing:0.1em; text-align:center; opacity:0.6; border-top:1px solid rgba(240,232,208,0.12); line-height:1.6; text-transform: uppercase; }

  .icp-main { padding: 32px 40px; overflow-x: auto; }
  .icp-main h1 { font-size:22px; font-weight:normal; margin:0 0 4px; letter-spacing:0.04em; border-bottom:1px solid var(--mustard); padding-bottom:8px; text-transform: uppercase; }
  .icp-folio { font-size:11px; letter-spacing:0.08em; color:rgba(26,26,26,0.6); margin-bottom:24px; text-transform: uppercase; }
  .icp-card { background:#fdf9eb; border:1px solid rgba(26,26,26,0.18); padding:20px; margin-bottom:18px; box-shadow:1px 1px 0 rgba(26,26,26,0.05); }
  .icp-card h2 { font-size:14px; letter-spacing:0.08em; margin:0 0 12px; color:var(--oxide); border-bottom:0.5px solid var(--mustard); padding-bottom:6px; text-transform: uppercase; }
  .icp-card-grid { display:grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap:14px; }

  .icp-tile { background:#fdf9eb; border:1px solid rgba(26,26,26,0.18); padding:16px; text-decoration:none; color:var(--ink); transition: box-shadow 0.15s, transform 0.15s; display:block; }
  .icp-tile:hover { box-shadow: 2px 2px 0 var(--mustard); transform: translate(-1px, -1px); }
  .icp-tile-label { font-size:11px; letter-spacing:0.12em; text-transform:uppercase; color:var(--mustard-dark); font-weight:bold; }
  .icp-tile-title { font-size:16px; margin-top:6px; letter-spacing:0.04em; text-transform: uppercase; }
  .icp-tile-desc { font-size:12px; margin-top:8px; color:rgba(26,26,26,0.7); line-height:1.5; }

  .icp-table { width:100%; border-collapse:collapse; font-size:13px; }
  .icp-table th, .icp-table td { padding:8px 10px; border-bottom:1px solid rgba(26,26,26,0.12); text-align:left; }
  .icp-table th { font-size:11px; letter-spacing:0.1em; text-transform:uppercase; color:var(--oxide); background:rgba(196,136,30,0.08); }
  .icp-table tbody tr:hover { background: rgba(196,136,30,0.07); }

  .icp-form-row { margin-bottom:12px; }
  .icp-form-row label { display:block; font-size:11px; letter-spacing:0.08em; text-transform:uppercase; margin-bottom:4px; color:var(--oxide); }
  .icp-form-row input, .icp-form-row select { padding:8px 10px; border:1px solid var(--ink); font-family:inherit; font-size:14px; width:100%; max-width:320px; background:#fdf9eb; color:var(--ink); }

  .icp-button { padding:9px 22px; background:var(--oxide); color:var(--parchment); border:none; font-family:inherit; letter-spacing:0.1em; cursor:pointer; font-size:13px; text-transform: uppercase; }
  .icp-button:hover { background:var(--mustard-dark); }
  .icp-button-link { background:none; border:none; color:var(--oxide-dark); cursor:pointer; padding:0; text-decoration:underline; font-family:inherit; font-size:12px; }

  .icp-notice { padding:12px 16px; background:rgba(196,136,30,0.15); border-left:3px solid var(--mustard); margin-bottom:16px; font-size:13px; font-style:italic; }
  .icp-notice-success { background:rgba(45,74,43,0.12); border-left-color:#2d4a2b; }
  .icp-notice-error { background:rgba(138,40,24,0.12); border-left-color:var(--oxide); }
</style>
</head>
<body>
<div class="icp-app">
<aside class="icp-sidebar">
  <div class="icp-sidebar-brand">
    <div class="icp-sidebar-mark">SI</div>
    <div>
      <div class="icp-sidebar-title"><?= htmlspecialchars($sect['title']) ?></div>
      <div class="icp-sidebar-subtitle"><?= htmlspecialchars($sect['subtitle']) ?></div>
    </div>
  </div>

  <?php if ($sb_user): ?>
  <div class="icp-sidebar-user">
    <div class="icp-sidebar-user-name"><?= htmlspecialchars($sb_user['username'] ?? '') ?></div>
    <div class="icp-sidebar-user-role"><?= htmlspecialchars(ucfirst($sb_user['role'] ?? 'user')) ?></div>
  </div>
  <?php endif; ?>

  <nav class="icp-sidebar-nav">
    <?php foreach ($sect['items'] as $item): ?>
      <a href="<?= htmlspecialchars($item['href']) ?>"
         class="icp-sidebar-link <?= $sb_active === $item['id'] ? 'icp-sidebar-link--active' : '' ?>">
        <?= htmlspecialchars($item['label']) ?>
      </a>
    <?php endforeach; ?>
  </nav>

  <div class="icp-sidebar-footer">
    Shikra Insurance Cooperative<br>
    Established MCMLXII
  </div>
</aside>

<main class="icp-main">
