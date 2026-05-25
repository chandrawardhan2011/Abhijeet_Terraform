<?php
$page_title = 'About the Bureau';
$page_ref   = 'F.№ ICP/ABOUT/02';
$active_nav = 'about';
include __DIR__ . '/_header.php';
?>

<h1>About the Bureau</h1>
<p class="muted" style="font-size:13px;">
  An institutional record of the Shikra Insurance Co-operative, prepared by the Bureau of
  Internal Affairs and approved by the Council on 04 February 2026.
</p>

<div class="panel">
<h2>A Brief Institutional History</h2>

<p>
  The Shikra Insurance Co-operative was founded in 1962 by a working group of seventeen civil
  servants drawn from the Ministry of Welfare, with the dual objective of providing accessible
  life cover to the salaried population and demonstrating that mutual provision could outperform
  the commercial insurance houses then dominant. The founding charter is preserved in the Bureau
  archive at our central directorate, and may be inspected on application.
</p>

<p>
  Through the 1970s the cooperative expanded into health, motor, and travel cover, opening branch
  sub-offices in five regional centres. The 1985 reforms brought computerisation, and in 1991
  the Bureau processed its first claim through the now-decommissioned Mark IV mainframe at our
  Hyderabad data centre.
</p>

<p>
  In 2024 the Bureau completed a comprehensive system migration, transitioning the entire claims
  pipeline to a modern web-based architecture. The migration was supervised by the Shikra IT
  Directorate. Citizens with active policies during the migration window were issued a Form 9-C
  to confirm record continuity. The full migration log is retained by the IT Directorate
  <!-- HOOK 3: the migration log link 404s, but the URL pattern points the curious at .git/ -->
  for audit purposes — interested parties may consult the
  <a href="http://status.icp.lab/.git/migration_log_2024.txt">migration log</a>
  (read-only, citizens' charter clause 7-B applies).
</p>
</div>

<h2 id="leadership">Leadership Council</h2>
<p>
  The Bureau is governed by a Council of seven, elected from among policyholders for staggered
  five-year terms. The current sitting Council (2024 – 2029):
</p>

<table class="bureau">
  <thead>
    <tr><th>Position</th><th>Holder</th><th>Term</th></tr>
  </thead>
  <tbody>
    <tr><td>Chair, Bureau Council</td><td>R. Venkatraman</td><td>2024 – 2029</td></tr>
    <tr><td>Vice-Chair (Actuarial)</td><td>Dr. P. Ananthanarayan</td><td>2024 – 2029</td></tr>
    <tr><td>Director, Adjudication Bureau</td><td>S. Mehrotra</td><td>2023 – 2028</td></tr>
    <tr><td>Director, Branch Operations</td><td>K. Lakshmi Narayan</td><td>2024 – 2029</td></tr>
    <tr><td>Director, IT Directorate</td><td>A. Joshi</td><td>2025 – 2030</td></tr>
    <tr><td>Director, Compliance &amp; Audit</td><td>M. Iqbal</td><td>2022 – 2027</td></tr>
    <tr><td>Citizens' Representative</td><td>(rotating)</td><td>annual</td></tr>
  </tbody>
</table>

<h2 id="network">Branch Network</h2>
<p>
  The Bureau operates from a central directorate and five regional branch sub-offices, each
  responsible for one operational domain. Citizens may approach any branch directly during
  posted hours; correspondence may also be addressed to the central directorate.
</p>

<table class="bureau">
  <thead>
    <tr><th>Branch</th><th>Domain</th><th>Sub-domain</th></tr>
  </thead>
  <tbody>
    <tr><td>Branch I — Catalogue Section</td><td>Policy listings, premium quotation, plan documentation</td><td>policies.icp.lab</td></tr>
    <tr><td>Branch II — Intake Section</td><td>New-claim processing, supporting-document receipt</td><td>claims.icp.lab</td></tr>
    <tr><td>Branch III — Tracking Section</td><td>Claim status, settlement history, status correspondence</td><td>status.icp.lab</td></tr>
    <tr><td>Branch IV — Beneficiary Section</td><td>Nominee registration, payout-instruction maintenance</td><td>beneficiary.icp.lab</td></tr>
    <tr><td>Branch V — Adjudication Section</td><td>(Internal) claim review, fraud queue, approval workflow</td><td>admin.icp.lab</td></tr>
  </tbody>
</table>

<h2 id="charter">Operating Charter (Excerpt)</h2>

<div class="panel" style="background:var(--parchment-dim);">
<p style="font-style:italic;">
  "The Co-operative shall in all matters discharge its duty toward the policyholder with
  diligence, transparency, and scientific actuarial rigour. No claim shall be denied without
  written explanation. No premium shall be levied without the consent of the Council. No
  individual within the Bureau shall act in a manner inconsistent with the Citizens' Charter."
</p>
<p style="font-style:italic; margin-bottom:0;">
  — Shikra Co-operative Charter, Article 1, ratified 02 October 1962.
</p>
</div>

<div class="spacer-l center">
  <span class="stamp">Approved · IT Directorate</span>
  &nbsp;&nbsp;&nbsp;
  <span class="stamp">Verified · Bureau Council</span>
</div>

<p class="page-ref">Page 2 of 6 · F.№ ICP/ABOUT/02 · Last revised 04 February 2026</p>

<?php include __DIR__ . '/_footer.php'; ?>
