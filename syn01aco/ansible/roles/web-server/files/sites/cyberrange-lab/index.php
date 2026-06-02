<?php
require_once 'router.php';
$page = $_GET['page'] ?? 'home';
?><!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Mazari Tours &amp; Travels — Discover the World</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,300;0,400;0,600;1,300;1,400&family=DM+Sans:wght@300;400;500&family=DM+Mono:wght@400;500&display=swap">
<link rel="stylesheet" href="assets/style.css">
</head>
<body>

<nav class="navbar">
  <div class="nav-logo">
    <span class="logo-mark">✦</span>
    <span class="logo-text">Mazari<em>Tours</em></span>
  </div>
  <ul class="nav-links">
    <li><a href="?page=home"    class="<?= $page==='home'   ?'active':'' ?>">Home</a></li>
    <li><a href="?page=login"   class="<?= $page==='login'  ?'active':'' ?>">Member Login</a></li>
    <li><a href="?page=search"  class="<?= $page==='search' ?'active':'' ?>">Search</a></li>
    <li><a href="?page=profile" class="<?= $page==='profile'?'active':'' ?>">My Profile</a></li>
    <li><a href="?page=lfi"     class="<?= $page==='lfi'    ?'active':'' ?>">Travel Guides</a></li>
  </ul>
  <a href="?page=login" class="nav-cta">Sign In</a>
</nav>

<?php if ($page === 'home'): ?>
<!-- ═══ HOME / HERO ══════════════════════════════════════════════════════════ -->
<section class="hero">
  <div class="hero-bg">
    <div class="hero-orb hero-orb-1"></div>
    <div class="hero-orb hero-orb-2"></div>
    <div class="hero-grain"></div>
  </div>
  <div class="hero-content">
    <p class="hero-kicker">Est. 1987 · Crafting Journeys Since Before the Internet</p>
    <h1 class="hero-title">Where Will You<br><em>Wander</em> Next?</h1>
    <p class="hero-sub">Bespoke travel experiences across 140 destinations.<br>From the dunes of Rajasthan to the peaks of Karakoram.</p>
    <div class="hero-actions">
      <a href="?page=login" class="btn-hero-primary">Plan My Journey</a>
      <a href="?page=search" class="btn-hero-secondary">Browse Tours</a>
    </div>
  </div>
  <div class="hero-stats">
    <div class="stat"><span class="stat-n">140+</span><span class="stat-l">Destinations</span></div>
    <div class="stat-sep"></div>
    <div class="stat"><span class="stat-n">38K</span><span class="stat-l">Happy Travellers</span></div>
    <div class="stat-sep"></div>
    <div class="stat"><span class="stat-n">97%</span><span class="stat-l">Would Return</span></div>
  </div>
</section>

<section class="section">
  <div class="section-header">
    <p class="section-kicker">Curated Picks</p>
    <h2 class="section-title">Featured Destinations</h2>
  </div>
  <div class="destinations-grid">
    <div class="dest-card dest-large">
      <div class="dest-img" style="background:linear-gradient(135deg,#c2714f 0%,#8b3a1e 100%)">
        <span class="dest-region">South Asia</span>
        <div class="dest-geo">🏔</div>
      </div>
      <div class="dest-info">
        <h3>Karakoram Highway</h3>
        <p>Pakistan · 14-day expedition</p>
        <span class="dest-price">From ₹1,20,000</span>
      </div>
    </div>
    <div class="dest-card">
      <div class="dest-img" style="background:linear-gradient(135deg,#d4956a 0%,#8b5e3c 100%)">
        <div class="dest-geo">🐪</div>
      </div>
      <div class="dest-info"><h3>Rajasthan Dunes</h3><p>India · 7-day tour</p><span class="dest-price">From ₹45,000</span></div>
    </div>
    <div class="dest-card">
      <div class="dest-img" style="background:linear-gradient(135deg,#2d7d7d 0%,#1a4f4f 100%)">
        <div class="dest-geo">🌊</div>
      </div>
      <div class="dest-info"><h3>Kerala Backwaters</h3><p>India · 5-day tour</p><span class="dest-price">From ₹38,000</span></div>
    </div>
    <div class="dest-card">
      <div class="dest-img" style="background:linear-gradient(135deg,#7a6a3e 0%,#4a3e20 100%)">
        <div class="dest-geo">🏛</div>
      </div>
      <div class="dest-info"><h3>Ancient Silk Road</h3><p>Central Asia · 21-day</p><span class="dest-price">From ₹2,10,000</span></div>
    </div>
  </div>
</section>

<?php elseif ($page === 'login'): ?>
<!-- ═══ MEMBER LOGIN (SQLi) ══════════════════════════════════════════════════ -->
<div class="page-wrap">
  <div class="form-card">
    <div class="form-card-header">
      <span class="logo-mark">✦</span>
      <h2>Member Login</h2>
      <p>Access your bookings, loyalty points, and exclusive member rates.</p>
    </div>
    <?php Router::load('sqli'); ?>
    <div class="form-card-footer">
      <a href="?page=home">← Back to Home</a>
      &nbsp;·&nbsp;
      <a href="?page=profile">View Profile</a>
    </div>
  </div>
</div>

<?php elseif ($page === 'search'): ?>
<!-- ═══ TOUR SEARCH (XSS) ════════════════════════════════════════════════════ -->
<div class="page-wrap page-wrap-wide">
  <div class="page-header">
    <p class="section-kicker">Search</p>
    <h1 class="section-title">Find Your Perfect Tour</h1>
  </div>
  <?php Router::load('xss'); ?>
</div>

<?php elseif ($page === 'profile'): ?>
<!-- ═══ TRAVELLER PROFILE (IDOR) ════════════════════════════════════════════ -->
<div class="page-wrap page-wrap-wide">
  <div class="page-header">
    <p class="section-kicker">Member Portal</p>
    <h1 class="section-title">Traveller Profile</h1>
    <p class="page-sub">View your membership details, loyalty tier, and past bookings.</p>
  </div>
  <?php Router::load('idor'); ?>
</div>

<?php elseif ($page === 'lfi'): ?>
<!-- ═══ TRAVEL GUIDES (LFI) ══════════════════════════════════════════════════ -->
<div class="page-wrap page-wrap-wide">
  <div class="page-header">
    <p class="section-kicker">Travel Library</p>
    <h1 class="section-title">Destination Guides</h1>
    <p class="page-sub">Expert guides curated by our travel specialists.</p>
  </div>
  <?php Router::load('lfi'); ?>
</div>

<?php else: ?>
<div class="page-wrap"><div class="form-card"><h2>Page not found</h2><p><a href="?page=home">← Back to Home</a></p></div></div>
<?php endif; ?>

<footer class="site-footer">
  <div class="footer-top">
    <div class="footer-brand">
      <span class="logo-mark">✦</span>
      <span class="logo-text">Mazari<em>Tours</em></span>
      <p class="footer-tagline">Crafting journeys since 1987.<br>140+ destinations. One promise: unforgettable.</p>
    </div>
    <div class="footer-links">
      <div class="footer-col"><h4>Destinations</h4><ul><li>South Asia</li><li>Central Asia</li><li>Middle East</li><li>East Africa</li></ul></div>
      <div class="footer-col"><h4>Company</h4><ul><li>About Us</li><li>Careers</li><li>Press</li><li>Contact</li></ul></div>
      <div class="footer-col"><h4>Support</h4><ul><li>Help Centre</li><li>Booking Policy</li><li>Insurance</li><li>Emergency</li></ul></div>
    </div>
  </div>
  <div class="footer-bottom">
    <span>© 2025 Mazari Tours &amp; Travels Pvt. Ltd. All rights reserved.</span>
    <span>CIN: U63040DL2003PTC000001 · IATA: 12-3 4567</span>
  </div>
</footer>

</body>
</html>
