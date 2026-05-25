<?php
$page_title = 'Contact &amp; Grievance';
$page_ref   = 'F.№ ICP/CONTACT/06';
$active_nav = 'contact';
include __DIR__ . '/_header.php';
?>

<h1>Contact &amp; Grievance</h1>
<p class="muted" style="font-size:13px;">
  The Bureau may be approached by post, telephone, or in person at any branch sub-office.
  Citizens with formal grievances may submit them in writing using the form provided on this
  page; written submissions are routed to the Adjudication Bureau for review.
</p>

<h2>Helpline &amp; Telephone</h2>
<table class="bureau">
  <thead>
    <tr><th>Service</th><th>Number</th><th>Hours (IST)</th></tr>
  </thead>
  <tbody>
    <tr><td>General Helpline</td><td>1800-SHIKRA (1800-744-572)</td><td>0900 – 1800, Monday – Friday</td></tr>
    <tr><td>Claim Status Enquiry</td><td>040-2345-1100</td><td>0900 – 1700, Monday – Saturday</td></tr>
    <tr><td>Grievance &amp; Adjudication</td><td>040-2345-1199</td><td>1000 – 1600, Monday – Friday</td></tr>
    <tr><td>Branch IV (Beneficiary)</td><td>040-2345-1144</td><td>0900 – 1700, Monday – Friday</td></tr>
    <tr><td>Out-of-hours emergency</td><td>1800-SHIKRA-911</td><td>24 hours, daily</td></tr>
  </tbody>
</table>

<h2>Branch Directory</h2>
<table class="bureau">
  <thead>
    <tr><th>Branch</th><th>Address</th><th>Posted Hours</th></tr>
  </thead>
  <tbody>
    <tr>
      <td>Central Directorate</td>
      <td>Bureau House, 47 Mahatma Gandhi Marg, Hyderabad – 500 001</td>
      <td>Mon – Fri 0900 – 1700</td>
    </tr>
    <tr>
      <td>Branch I — Catalogue</td>
      <td>Room 204, Co-operative Building, Bombay – 400 020</td>
      <td>Mon – Fri 1000 – 1700</td>
    </tr>
    <tr>
      <td>Branch II — Intake</td>
      <td>17 Lytton Road, Calcutta – 700 020</td>
      <td>Mon – Sat 0900 – 1300</td>
    </tr>
    <tr>
      <td>Branch III — Tracking</td>
      <td>Annexe Building, Mount Road, Madras – 600 002</td>
      <td>Mon – Fri 0930 – 1730</td>
    </tr>
    <tr>
      <td>Branch IV — Beneficiary</td>
      <td>Bureau House Annexe, Hyderabad – 500 001</td>
      <td>Mon – Fri 1000 – 1600</td>
    </tr>
    <tr>
      <td>Branch V — Adjudication (Internal)</td>
      <td>Bureau House Floor 4, Hyderabad — Authorised personnel only</td>
      <td>—</td>
    </tr>
  </tbody>
</table>

<h2>Submit a Grievance</h2>
<p>
  Citizens with a formal grievance regarding the conduct of the Bureau, the handling of a
  claim, or the behaviour of a Branch official may submit a written grievance via the form
  below. Grievances are routed to the Adjudication Bureau and acknowledged within five
  working days.
</p>
<p class="muted" style="font-size:12px;">
  Note · for grievances pertaining to a specific claim or payslip, citizens may also submit
  directly through the Defence Pay complaint system at
  <a href="http://dp.lab/complaints.php">dp.lab/complaints.php</a> (cross-Bureau). For general
  Shikra grievances, use the form below.
</p>

<form class="bureau-form" method="POST" action="http://claims.icp.lab/submit_claim.php">
  <input type="hidden" name="policy_id" value="0">

  <label>Your Name</label>
  <input name="author_name" type="text" required>

  <label>Policy Number (if applicable)</label>
  <input name="policy_number" type="text" placeholder="e.g. SHK/2024/000123">

  <label>Branch concerning the grievance</label>
  <select name="branch">
    <option value="">— select a branch —</option>
    <option value="catalogue">Branch I — Catalogue</option>
    <option value="intake">Branch II — Intake</option>
    <option value="tracking">Branch III — Tracking</option>
    <option value="beneficiary">Branch IV — Beneficiary</option>
    <option value="adjudication">Branch V — Adjudication</option>
    <option value="central">Central Directorate</option>
  </select>

  <label>Description of Grievance</label>
  <textarea name="description" required placeholder="Please describe the grievance in your own words. Be as specific as possible. Include dates, claim numbers, and the names of any officials involved."></textarea>

  <button type="submit">Submit Grievance</button>
</form>

<div class="panel" style="background:var(--parchment-dim); margin-top:32px;">
  <h3>If You Are Not Satisfied With the Outcome</h3>
  <p style="margin-bottom:0;">
    Citizens who remain dissatisfied with the Bureau's handling of a grievance may escalate
    the matter to the Bureau of Internal Affairs at the central directorate, or, in the
    final instance, to the Citizens' Ombudsman. Full escalation procedure is set out in the
    Citizens' Charter, clauses 12 through 19.
  </p>
</div>

<p class="page-ref">Page 6 of 6 · F.№ ICP/CONTACT/06 · Bureau of Internal Affairs</p>

<?php include __DIR__ . '/_footer.php'; ?>
