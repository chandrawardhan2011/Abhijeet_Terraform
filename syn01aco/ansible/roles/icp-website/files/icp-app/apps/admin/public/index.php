<?php
/**
 * admin.icp.lab — landing page (Adjuster Console)
 * Sub-app 5 of 5.
 *   ICP_51  /admin/index.php       - broken access control (no role check)
 *   ICP_52  adjudicate.php         - state-skip business logic
 *   ICP_53  export_pdf.php         - OS command injection on claim_no
 *   ICP_54  /admin/find.php        - SQLi on q parameter
 *   ICP_55  /admin/login.php       - default credentials admin/admin
 */
?><!doctype html>
<html><head><title>ICP — Adjuster Console</title></head><body>
  <h1>ICP — Adjuster Console</h1>
  <ul>
    <li><a href="/admin/index.php">Adjuster console (no auth needed!)</a></li>
    <li><a href="/admin/find.php?q=fraud">Search adjudications</a></li>
    <li><a href="/admin/login.php">Login</a></li>
    <li><a href="/adjudicate.php">Adjudicate a claim</a></li>
    <li><a href="/export_pdf.php">Export claim as PDF</a></li>
  </ul>
</body></html>
