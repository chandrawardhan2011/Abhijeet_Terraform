<?php
/**
 * claims.icp.lab — landing page
 * Sub-app 2 of 5.
 *   ICP_21  upload.php           - unrestricted file upload (web shell)
 *   ICP_22  attachment.php       - path traversal on file retrieval
 *   ICP_23  claim_form.php       - LFI on tpl parameter
 *   ICP_24  submit_claim.php     - CSRF, no token
 *   ICP_25  submit_claim.php     - stored XSS in description
 */
?><!doctype html>
<html><head><title>ICP — Claims Intake</title></head><body>
<!-- ICP_BACKNAV -->
<div style="background: #8a2818; color: #f0e8d0; padding: 8px 20px; font-family: 'Times New Roman', Georgia, serif; font-size: 12px; letter-spacing: 0.08em; border-bottom: 2px solid #c4881e;">
  <a href="http://icp.lab/" style="color: #f0e8d0; text-decoration: none;">&larr; Shikra Insurance</a>
</div>

  <h1>Insurance Claims Portal — Submit a Claim</h1>
  <ul>
    <li><a href="/claim_form.php?tpl=basic">New claim — basic form</a></li>
    <li><a href="/claim_form.php?tpl=motor">New claim — motor form</a></li>
    <li><a href="/upload.php">Upload supporting documents</a></li>
    <li><a href="/attachment.php?file=sample.txt">View an attachment</a></li>
  </ul>
</body></html>
