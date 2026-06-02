<?php
$state = get_state();
$level = $state['level'];
$open  = $state['open_vulns'];
$sqli_open = in_array('sqli', $open);
$xss_open  = in_array('xss',  $open);
$idor_open = in_array('idor', $open);
$cmdi_open = in_array('cmdi', $open);
$lfi_open  = in_array('lfi',  $open);
?><!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Mazari Tours &amp; Travels — Discover the World</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,300;0,400;0,600;1,300;1,400&family=DM+Sans:wght@300;400;500&family=DM+Mono:wght@400;500&display=swap">
<link rel="stylesheet" href="/public/style.css">
</head>
<body>

<nav class="navbar">
  <div class="nav-logo">
    <span class="logo-mark">✦</span>
    <span class="logo-text">Mazari<em>Tours</em></span>
  </div>
  <ul class="nav-links">
    <li><a href="#" class="active">Destinations</a></li>
    <?php if($xss_open): ?><li><a href="#reviews">Reviews</a></li><?php endif; ?>
    <?php if($idor_open): ?><li><a href="#profile">My Account</a></li><?php endif; ?>
    <?php if($lfi_open): ?><li><a href="#guides">Travel Guides</a></li><?php endif; ?>
    <li><a href="#contact">About</a></li>
  </ul>
  <a href="#booking" class="nav-cta">Book Now</a>
</nav>

<main>

  <!-- ═══ HERO — always shown. SQLi here if open ════════════════════════════ -->
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
      <?php if($sqli_open): ?>
      <form class="hero-search" data-endpoint="sqli">
        <div class="search-field">
          <label class="search-label">Traveller Name</label>
          <input type="text" name="q" value="alice" placeholder="Search by name or booking ref" autocomplete="off">
        </div>
        <button type="submit" class="search-btn">Find My Booking</button>
      </form>
      <div class="hero-out out"></div>
      <?php else: ?>
      <div class="hero-search hero-search-inert">
        <div class="search-field">
          <label class="search-label">Traveller Name</label>
          <input type="text" placeholder="Search by name or booking ref" autocomplete="off">
        </div>
        <button type="button" class="search-btn" disabled>Find My Booking</button>
      </div>
      <?php endif; ?>
    </div>
    <div class="hero-stats">
      <div class="stat"><span class="stat-n">140+</span><span class="stat-l">Destinations</span></div>
      <div class="stat-sep"></div>
      <div class="stat"><span class="stat-n">38K</span><span class="stat-l">Happy Travellers</span></div>
      <div class="stat-sep"></div>
      <div class="stat"><span class="stat-n">97%</span><span class="stat-l">Would Return</span></div>
    </div>
  </section>

  <!-- ═══ DESTINATIONS — always shown ══════════════════════════════════════ -->
  <section class="section destinations-section">
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

  <!-- ═══ REVIEWS — only if XSS open ══════════════════════════════════════ -->
  <?php if($xss_open): ?>
  <section class="section reviews-section" id="reviews">
    <div class="section-header">
      <p class="section-kicker">Traveller Stories</p>
      <h2 class="section-title">What Our Guests Say</h2>
    </div>
    <div class="reviews-layout">
      <div class="review-featured">
        <blockquote>"Mazari turned our honeymoon into an absolute dream. Every detail was perfect — from the riad in Marrakech to the private dhow in Lakshadweep."</blockquote>
        <cite>— Priya &amp; Rohan Sharma, Mumbai</cite>
      </div>
      <div class="review-form-wrap">
        <h3>Share Your Experience</h3>
        <p class="review-sub">Travelled with us? Leave a review for fellow wanderers.</p>
        <form class="review-form" data-endpoint="xss">
          <label>Your Name
            <input type="text" name="name" value="visitor" placeholder="As it appears on your booking" autocomplete="off">
          </label>
          <button type="submit" class="btn-primary">Post Review</button>
        </form>
        <div class="review-out out"></div>
      </div>
    </div>
  </section>
  <?php endif; ?>

  <!-- ═══ PROFILE — only if IDOR open ══════════════════════════════════════ -->
  <?php if($idor_open): ?>
  <section class="section profile-section" id="profile">
    <div class="section-header">
      <p class="section-kicker">Member Portal</p>
      <h2 class="section-title">Traveller Profile</h2>
    </div>
    <div class="profile-layout">
      <div class="profile-intro">
        <p>Access your loyalty points, past bookings, and exclusive member rates. Enter your Traveller ID below to view your profile.</p>
        <p class="profile-note">Your Traveller ID was emailed to you at registration. IDs are sequential — try different numbers to explore the programme.</p>
      </div>
      <form class="profile-form" data-endpoint="idor">
        <label>Traveller ID
          <input type="text" name="id" value="1" placeholder="e.g. 1, 2, 3 …" autocomplete="off">
        </label>
        <button type="submit" class="btn-primary">View Profile</button>
      </form>
      <div class="profile-out out"></div>
    </div>
  </section>
  <?php endif; ?>

  <!-- ═══ SERVER STATUS — only if CMDi open ════════════════════════════════ -->
  <?php if($cmdi_open): ?>
  <section class="section status-section" id="status">
    <div class="section-header">
      <p class="section-kicker">Operations</p>
      <h2 class="section-title">Booking Server Status</h2>
    </div>
    <div class="status-layout">
      <p>Our infrastructure team uses this tool to check connectivity to partner booking engines. Enter an IP or hostname to run a reachability test.</p>
      <form class="status-form" data-endpoint="cmdi">
        <label>Host / IP Address
          <input type="text" name="host" value="127.0.0.1" placeholder="e.g. 8.8.8.8 or booking-api.partner.com" autocomplete="off">
        </label>
        <button type="submit" class="btn-secondary">Run Ping Check</button>
      </form>
      <div class="status-out out"></div>
    </div>
  </section>
  <?php endif; ?>

  <!-- ═══ TRAVEL GUIDES — only if LFI open ═════════════════════════════════ -->
  <?php if($lfi_open): ?>
  <section class="section guides-section" id="guides">
    <div class="section-header">
      <p class="section-kicker">Travel Library</p>
      <h2 class="section-title">Destination Guides</h2>
    </div>
    <div class="guides-layout">
      <p>Browse our curated travel guides written by our in-house experts and returning travellers.</p>
      <div class="guides-nav">
        <span class="guide-tag" onclick="loadGuide('home')">Home</span>
        <span class="guide-tag" onclick="loadGuide('about')">About Mazari</span>
        <span class="guide-tag" onclick="loadGuide('contact')">Contact</span>
      </div>
      <form class="guides-form" data-endpoint="lfi">
        <label>Guide Name
          <input type="text" name="page" value="home" placeholder="e.g. home, about, contact" autocomplete="off" id="lfi-input">
        </label>
        <button type="submit" class="btn-secondary">Load Guide</button>
      </form>
      <div class="guides-out out"></div>
    </div>
  </section>
  <?php endif; ?>

</main>

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

<script src="/public/lab.js"></script>
<script>
function loadGuide(name){ document.getElementById('lfi-input').value = name; }
</script>
</body>
</html>
