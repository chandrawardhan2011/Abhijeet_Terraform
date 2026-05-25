<?php
$page_title = 'Staff Login';
$page_ref   = 'F.№ ICP/STAFF/01';
$active_nav = 'staff';
include __DIR__ . '/../_header.php';
?>
<div class="shell">
  <h2 style="margin-top: 24px; letter-spacing: 0.06em; text-transform: uppercase;">Staff Login Portal</h2>
  <p style="font-style: italic; color: var(--ink-soft); margin-bottom: 28px;">
    Personnel of the Cooperative are directed to their appropriate office below.
    All access is logged under By-law III of the cooperative charter.
  </p>

  <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 18px; margin-bottom: 32px;">

    <a href="http://beneficiary.icp.lab/login.php" style="display:block; padding:24px; background:#fdf9eb; border:1px solid var(--mustard); text-decoration:none; color:var(--ink);">
      <div style="font-size:11px; letter-spacing:0.12em; text-transform:uppercase; color:var(--mustard-dark);">Branch IV</div>
      <div style="font-size:18px; letter-spacing:0.05em; margin-top:6px; text-transform: uppercase;">Beneficiary Office</div>
      <div style="font-size:13px; color:var(--ink-soft); margin-top:10px;">Nominee records, payouts, and beneficiary claims.</div>
    </a>

    <a href="http://admin.icp.lab/admin/login.php" style="display:block; padding:24px; background:#fdf9eb; border:1px solid var(--mustard); text-decoration:none; color:var(--ink);">
      <div style="font-size:11px; letter-spacing:0.12em; text-transform:uppercase; color:var(--mustard-dark);">Branch V</div>
      <div style="font-size:18px; letter-spacing:0.05em; margin-top:6px; text-transform: uppercase;">Adjuster Console</div>
      <div style="font-size:13px; color:var(--ink-soft); margin-top:10px;">Adjudication queue, personnel, and claim oversight.</div>
    </a>

  </div>

  <p style="font-size:12px; color:var(--ink-soft); font-style:italic; margin-top:32px;">
    Public-facing services — policy search, claim submission, claim status —
    do not require login and may be accessed directly from the main navigation.
  </p>
</div>
<?php include __DIR__ . '/../_footer.php'; ?>
