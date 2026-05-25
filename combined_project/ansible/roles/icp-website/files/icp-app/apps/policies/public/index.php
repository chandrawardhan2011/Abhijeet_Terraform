<?php
/**
 * policies.icp.lab — landing page
 * Sub-app 1 of 5. Vulnerabilities live in:
 *   ICP_11  search.php  - SQLi on plan parameter
 *   ICP_12  quote.php   - reflected XSS on age parameter
 *   ICP_13  /docs/      - Apache directory listing (config-side)
 *   ICP_14  /assets/js/jquery-1.7.2.min.js - outdated component
 *   ICP_15  quote.php   - missing audit log on quote endpoint
 */
?><!doctype html>
<html><head>
  <title>ICP — Policy Catalogue</title>
  <script src="/assets/js/jquery-1.7.2.min.js"></script>  <!-- ICP_14: outdated jQuery -->
</head><body>
<!-- ICP_BACKNAV -->
<div style="background: #8a2818; color: #f0e8d0; padding: 8px 20px; font-family: 'Times New Roman', Georgia, serif; font-size: 12px; letter-spacing: 0.08em; border-bottom: 2px solid #c4881e;">
  <a href="http://icp.lab/" style="color: #f0e8d0; text-decoration: none;">&larr; Shikra Insurance</a>
</div>

  <h1>Insurance Claims Portal — Policy Catalogue</h1>
  <ul>
    <li><a href="/search.php">Browse policies</a></li>
    <li><a href="/quote.php?age=30">Get a premium quote</a></li>
    <li><a href="/docs/">Plan documents</a></li>
  </ul>
</body></html>
