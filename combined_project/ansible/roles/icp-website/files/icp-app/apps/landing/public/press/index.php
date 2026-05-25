<?php
/**
 * Press / Releases page
 * Hook 6 = ICP_56 — Reflected XSS on the `search` GET parameter.
 * The search box echoes its value verbatim into the page header, no encoding.
 */
$page_title = 'Press &amp; Releases';
$page_ref   = 'F.№ ICP/PRESS/04';
$active_nav = 'press';
include __DIR__ . '/_header.php';

// Read but DO NOT encode — this is the deliberate reflected-XSS sink.
$search = $_GET['search'] ?? '';
?>

<h1>Press &amp; Releases</h1>
<p class="muted" style="font-size:13px;">
  Public bulletins issued by the Bureau of Communications, in chronological order. Citizens
  may search the bulletin archive by keyword, or filter by branch.
</p>

<div class="panel">
  <form action="" method="GET" style="display:flex; gap:12px; align-items:flex-end;">
    <div style="flex:1;">
      <label style="font-size:11px; letter-spacing:0.15em; text-transform:uppercase; display:block; margin-bottom:4px;">
        Search the bulletin archive
      </label>
      <input name="search" type="text" value="<?= htmlspecialchars($search) ?>"
             placeholder="e.g. settlement, migration, charter"
             style="width:100%; padding:10px; border:2px solid var(--ink); font-family:inherit; font-size:14px;">
    </div>
    <button type="submit"
            style="padding:12px 24px; background:var(--oxide); color:var(--parchment); border:2px solid var(--ink); font-family:inherit; font-size:13px; letter-spacing:0.18em; text-transform:uppercase; cursor:pointer;">
      Search
    </button>
  </form>

  <?php if ($search !== ''): ?>
    <!--
      ICP_56 SINK: $search is echoed without htmlspecialchars().
      The htmlspecialchars() call above is on the *form input value*, which is good UX,
      but the echo into the heading below is intentionally raw.
    -->
    <h3 style="margin-top:20px; color:var(--oxide);">
      Results for "<?= $search ?>"
    </h3>
    <p style="font-size:13px; color:var(--ink-soft);">
      Three matching bulletins found. Refine your search if too many results are returned.
    </p>
  <?php endif; ?>
</div>

<h2>Recent Bulletins</h2>

<div class="release">
  <div class="date">12 April 2026</div>
  <h4>Annual Settlement Bulletin · 2025 / 26</h4>
  <p>
    The Bureau processed 47,318 claims during the 2025/26 reporting period, of which 96.4 per
    cent were settled within the citizens' charter target of fourteen working days. Reserve
    adequacy stands at 132 per cent of the regulatory minimum. Full report available at the
    central directorate on application.
  </p>
</div>

<div class="release">
  <div class="date">28 March 2026</div>
  <h4>Premium Adjustment Notice · Family Health Plans</h4>
  <p>
    Following the quinquennial actuarial review, the Council has approved a 4.2 per cent
    average premium adjustment to the Family Health portfolio, effective 01 July 2026.
    Adjustments are tier-dependent; existing policyholders will receive individual notices.
  </p>
</div>

<div class="release">
  <div class="date">14 March 2026</div>
  <h4>Branch IV Beneficiary Drive Concludes</h4>
  <p>
    The 2025/26 beneficiary registration drive, conducted by Branch IV across all regional
    offices, has concluded with 18,492 nominee records updated and 3,107 new nominations
    registered. Citizens who have not updated their nomination in five years are reminded
    that Form 6-N may be submitted at any branch.
  </p>
</div>

<div class="release">
  <div class="date">04 February 2026</div>
  <h4>System Migration Audit Closed</h4>
  <p>
    The 2024 system migration audit, conducted by the Bureau of Internal Affairs, has been
    formally closed with no material findings. The IT Directorate has been commended for the
    orderly conduct of the migration and the retention of complete audit trails.
  </p>
</div>

<div class="release">
  <div class="date">22 January 2026</div>
  <h4>Council Election Results</h4>
  <p>
    Citizens have re-elected R. Venkatraman as Chair of the Bureau Council for a second
    five-year term, with 78 per cent of the policyholder vote. Dr. P. Ananthanarayan continues
    as Vice-Chair (Actuarial). Two new directors join the Council: A. Joshi (IT Directorate)
    and K. Lakshmi Narayan (Branch Operations).
  </p>
</div>

<div class="release">
  <div class="date">30 November 2025</div>
  <h4>Mark IV Mainframe Decommissioning Complete</h4>
  <p>
    The Mark IV mainframe at the Hyderabad data centre, in continuous operation since 1991,
    has been formally decommissioned. All historical claim records have been migrated to the
    current system; physical media has been transferred to the Bureau archive.
  </p>
</div>

<p class="page-ref">Page 4 of 6 · F.№ ICP/PRESS/04 · Bureau of Communications</p>

<?php include __DIR__ . '/_footer.php'; ?>
