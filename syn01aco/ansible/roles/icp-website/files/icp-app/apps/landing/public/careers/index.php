<?php
$page_title = 'Careers';
$page_ref   = 'F.№ ICP/CAREERS/03';
$active_nav = 'careers';
include __DIR__ . '/_header.php';
?>

<h1>Careers at Shikra</h1>
<p class="muted" style="font-size:13px;">
  The Bureau recruits competent, methodical, and discreet professionals across actuarial,
  adjudication, and information-technology functions. Vacancies posted here are open to all
  citizens. Applications may be submitted via Form 4-G, available from any branch office.
</p>

<div class="panel">
  <h2>Why Shikra</h2>
  <p>
    The Co-operative offers permanence, defined-benefit pension, and the rare professional
    satisfaction of working for an institution whose stated objective is the welfare of its
    members. Compensation is determined by seniority and grade, and is published annually.
    Branch transfers are possible after three years of service.
  </p>
</div>

<h2>Current Vacancies</h2>

<!-- HOOK 4: Senior PHP Engineer · jQuery 1.7.x maintenance — direct ICP_14 hint -->
<div class="job">
  <div class="role-meta">REQ. №. 2026/IT-DIR/041 · Branch: IT Directorate · Grade C-7 · Hyderabad</div>
  <h3>Senior PHP Engineer</h3>
  <p>
    The IT Directorate seeks a senior engineer to join the Branch Maintenance Programme. The
    successful applicant will be responsible for the continued operation, hardening, and
    incremental modernisation of the Bureau's customer-facing web estate, comprising five
    branch sub-application stacks running on Apache 2.4 with PHP 8.x.
  </p>
  <h4>Essential responsibilities</h4>
  <ul>
    <li>Maintenance and incremental modernisation of legacy Hypertext Preprocessor codebase across the five branch sub-applications (Catalogue, Intake, Tracking, Beneficiary, Adjudication).</li>
    <li>Continued upkeep of the front-end JavaScript bundle, including the present jQuery 1.7.x dependency tree, with a view toward eventual modernisation in the 2027 work-cycle.</li>
    <li>Liaison with the Adjudication Bureau on integration matters.</li>
    <li>On-call rotation for the central MySQL cluster (one weekend in eight).</li>
  </ul>
  <h4>Essential qualifications</h4>
  <ul>
    <li>Five years' demonstrated experience with PHP 7.x or 8.x in a production setting.</li>
    <li>Working familiarity with jQuery 1.7.x and the constraints associated with its continued use.</li>
    <li>MySQL 8 administration; familiarity with prepared statements and connection pooling.</li>
    <li>Apache 2.4 configuration including virtual host management and module configuration.</li>
  </ul>
</div>

<!-- HOOK 5: MD5 password store legacy migration task — direct ICP_45 hint -->
<div class="job">
  <div class="role-meta">REQ. №. 2026/IT-DIR/042 · Branch: IT Directorate · Grade C-6 · Hyderabad</div>
  <h3>Database Engineer (Migration Track)</h3>
  <p>
    The IT Directorate has identified the legacy password storage scheme — currently MD5
    one-way hashes inherited from the 1991 Mark IV migration — as a candidate for replacement
    in the 2026/27 work-cycle. The successful applicant will be responsible for the orderly
    migration of the active user table to a modern adaptive hashing scheme without service
    interruption.
  </p>
  <h4>Essential responsibilities</h4>
  <ul>
    <li>Design and execution of a phased migration plan for the legacy MD5 password store across all five branch sub-applications.</li>
    <li>Co-ordination with the Adjudication Bureau on adjuster credential rotation.</li>
    <li>Authoring of a backwards-compatibility shim for users authenticating against the legacy hash table during transition.</li>
    <li>Production of an after-action report for submission to the Council.</li>
  </ul>
  <h4>Essential qualifications</h4>
  <ul>
    <li>Demonstrated familiarity with cryptographic hashing primitives (MD5, SHA-2, bcrypt, argon2).</li>
    <li>Five years' experience in MySQL schema migration at scale.</li>
    <li>Comfort with PHP password_hash and password_verify primitives.</li>
  </ul>
</div>

<!-- HOOK 2 (light): generic stack disclosure — Apache + PHP + MySQL -->
<div class="job">
  <div class="role-meta">REQ. №. 2026/IT-DIR/043 · Branch: IT Directorate · Grade C-5 · Hyderabad</div>
  <h3>Junior Systems Administrator</h3>
  <p>
    Responsibility for the daily operation of the Bureau's web servers (Apache 2.4 on Ubuntu
    Server LTS), application stack (PHP 8.x), and database tier (MySQL 8). Two positions
    available; entry-level qualification accepted with relevant aptitude.
  </p>
  <h4>Essential qualifications</h4>
  <ul>
    <li>Two years' experience with Linux server administration in a production setting.</li>
    <li>Familiarity with Apache virtual host configuration, PHP-FPM, and MySQL.</li>
    <li>Working familiarity with the AWStats and Wazuh monitoring tools deployed at the central directorate.</li>
  </ul>
</div>

<div class="job">
  <div class="role-meta">REQ. №. 2026/ACT/008 · Branch: Actuarial Section · Grade B-8 · Bombay</div>
  <h3>Senior Actuary, Health Cover</h3>
  <p>
    Reports to the Vice-Chair (Actuarial). Lead the quinquennial reserve calculation for the
    Family Health portfolio. Fellow of the Institute of Actuaries (or equivalent international
    qualification) required.
  </p>
</div>

<div class="job">
  <div class="role-meta">REQ. №. 2026/ADJ/017 · Branch: Adjudication Section · Grade C-4 · Hyderabad</div>
  <h3>Claim Adjudicator (Probationary)</h3>
  <p>
    Probationary appointment, twelve months. The successful applicant will join the Branch V
    intake team, processing first-tier claim review under supervision. Successful completion
    of probation leads to confirmation as Adjudicator (Grade C-5).
  </p>
</div>

<div class="panel" style="background:var(--parchment-dim); margin-top:32px;">
  <h3>How to Apply</h3>
  <p>
    Applications must be submitted on Form 4-G, accompanied by two character references and a
    sealed copy of the candidate's most recent service record. Forms may be obtained from any
    branch sub-office or downloaded from the Bureau intranet (citizens with active policies only).
  </p>
  <p style="margin-bottom:0;">
    Closing date for the present recruitment cycle: <strong>30 June 2026</strong>.
    Late applications will not be considered. Shortlisting is conducted by the IT Directorate
    in conjunction with the Bureau of Internal Affairs.
  </p>
</div>

<p class="page-ref">Page 3 of 6 · F.№ ICP/CAREERS/03 · Posted 12 March 2026</p>

<?php include __DIR__ . '/_footer.php'; ?>
