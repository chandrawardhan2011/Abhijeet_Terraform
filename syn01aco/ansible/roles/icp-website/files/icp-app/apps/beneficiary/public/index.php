<?php
/**
 * beneficiary.icp.lab — landing page
 * Sub-app 4 of 5.
 *   ICP_41  nominee.php           - IDOR: read any nominee
 *   ICP_42  payout_update.php     - IDOR: write any nominee's bank details
 *   ICP_43  login.php             - session fixation
 *   ICP_44  payout_view.php       - weak crypto (AES-ECB hardcoded key)
 *   ICP_45  search_nominee.php    - SQLi on nominee search
 */
?><!doctype html>
<html><head><title>ICP — Beneficiary Records</title></head><body>
  <h1>Insurance Claims Portal — Beneficiary Records</h1>
  <ul>
    <li><a href="/login.php">Login</a></li>
    <li><a href="/nominee.php?nid=1">View nominee by ID</a></li>
    <li><a href="/payout_view.php">View payout instructions (decrypted)</a></li>
    <li><a href="/search_nominee.php?q=Sun">Search nominees</a></li>
  </ul>
</body></html>
