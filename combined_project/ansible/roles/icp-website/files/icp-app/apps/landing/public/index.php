<?php
$page_title = 'Home';
$page_ref   = 'F.№ ICP/HOME/01';
$active_nav = 'home';
include __DIR__ . '/_header.php';
?>

<section class="hero">
  <div>
    <h1>Insurance for the<br>Responsible Citizen.</h1>
    <p class="lead">
      Shikra Insurance has, since 1962, served the working population of this nation through a
      programme of mutual provision, scientific actuarial method, and discreet correspondence.
      Every policyholder is a co-owner of the cooperative. Every claim is processed under the
      supervision of the Adjudication Bureau.
    </p>
    <p class="lead">
      Coverage extends to Term Life, Family Health, Motor Comprehensive, Travel, and Domestic
      property — administered through five branch sub-offices and one central directorate.
    </p>
    <div class="pillars">
      <span>1962</span>
      <span>Six Million Citizens Insured</span>
      <span>Five Year Review Pending</span>
    </div>
  </div>

  <div class="calc">
    <h3>Premium Estimate</h3>
    <p style="font-size:11px; letter-spacing:0.1em; text-transform:uppercase; color:var(--ink-soft); margin-bottom:8px;">
      Service № PE-04-A
    </p>
    <!--
      The calc form GETs to the policy-catalogue quote endpoint —
      which is the ICP_12 reflected-XSS sink. The calc is genuine UX,
      but the XSS is reachable via the same route.
    -->
    <form action="http://policies.icp.lab/quote.php" method="GET">
      <label>Applicant age (years)</label>
      <input name="age" type="text" value="30" required>

      <label>Plan category</label>
      <select name="plan">
        <option value="TERM">Term Life</option>
        <option value="HEALTH">Family Health</option>
        <option value="MOTOR">Motor Comprehensive</option>
        <option value="TRAVEL">Travel Annual</option>
        <option value="HOME">Domestic Property</option>
      </select>

      <button type="submit">Compute Estimate</button>
    </form>
  </div>
</section>

<div class="ticker" role="region" aria-label="Bureau notices">
  <span class="label">Notice</span>
  <div class="items">
    <span>Quarterly co-operative meeting · 14 May 2026 · Branch officers required.</span>
    <span><a href="/press/">Annual settlement bulletin published.</a></span>
    <span>Beneficiary registration drive · all five branch offices · ongoing.</span>
  </div>
</div>

<h2>Branch Sub-offices</h2>
<p class="muted" style="font-size:13px;">
  Each operational function of the Co-operative is administered by a dedicated branch sub-office.
  Citizens may approach any of the following directly.
</p>

<div class="tiles">

  <a class="tile" href="http://policies.icp.lab/">
    <div class="number">01</div>
    <h4>Policy Catalogue</h4>
    <p>Browse plan documents, request premium quotes, study coverage tables.</p>
  </a>

  <a class="tile" href="http://claims.icp.lab/">
    <div class="number">02</div>
    <h4>Claims Intake</h4>
    <p>Submit a new claim, upload supporting documents, file form 7-B.</p>
  </a>

  <a class="tile" href="http://status.icp.lab/">
    <div class="number">03</div>
    <h4>Claim Status</h4>
    <p>Track a submitted claim, view settlement history, monitor adjudication.</p>
  </a>

  <a class="tile" href="http://beneficiary.icp.lab/">
    <div class="number">04</div>
    <h4>Beneficiary Records</h4>
    <p>Manage nominee records, register payout instructions, update bank details.</p>
  </a>

  <a class="tile" href="http://admin.icp.lab/">
    <div class="number">05</div>
    <h4>Adjuster Console</h4>
    <p>Internal use · Adjudicators only · access via authorised credentials.</p>
  </a>

  <a class="tile" href="/contact/">
    <div class="number">06</div>
    <h4>Contact &amp; Grievance</h4>
    <p>Branch directory, helpline numbers, written-grievance submission form.</p>
  </a>

</div>

<div class="panel dark">
  <h2>The Co-operative Promise</h2>
  <p>
    Shikra is not a corporation. There are no shareholders. There is no quarterly profit motive.
    Every premium contributed by a citizen flows back into the mutual reserve, from which claims
    are paid and the long-term solvency of the cooperative is maintained.
  </p>
  <p style="margin-bottom:0;">
    Our actuaries answer to the Bureau Council, not to a market. Our adjudicators answer to the
    Citizens' Charter, not to a quota. <a href="/about/">Read the operating charter →</a>
  </p>
</div>

<p class="page-ref">Page 1 of 6 · F.№ ICP/HOME/01 · Approved by the IT Directorate</p>

<?php include __DIR__ . '/_footer.php'; ?>
