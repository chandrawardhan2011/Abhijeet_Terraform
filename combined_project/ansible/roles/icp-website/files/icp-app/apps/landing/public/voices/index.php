<?php
/**
 * Customer Voices — testimonials wall
 * Hook 7 = ICP_57 — Stored XSS via the `body` field on submission.
 * The submitted body is stored RAW in the testimonials table and rendered
 * RAW back to every visitor. Persistent waterhole.
 */
$page_title = 'Customer Voices';
$page_ref   = 'F.№ ICP/VOICES/05';
$active_nav = 'voices';
include __DIR__ . '/_header.php';

require_once '/var/www/icp/shared/includes/db.php';
require_once '/var/www/icp/shared/includes/audit.php';
$db = icp_db();

$submitted = false;
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $name = $_POST['name'] ?? 'Anonymous';
    $body = $_POST['body'] ?? '';     // VULNERABLE: stored raw
    if (trim($body) !== '') {
        $stmt = $db->prepare('INSERT INTO testimonials (author_name, body, submitted_at) VALUES (?, ?, NOW())');
        $stmt->bind_param('ss', $name, $body);
        $stmt->execute();
        $stmt->close();
        audit('voices.submit', ['name' => $name, 'len' => strlen($body)]);
        $submitted = true;
    }
}

$res = $db->query('SELECT author_name, body, submitted_at FROM testimonials ORDER BY id DESC LIMIT 20');
?>

<h1>Customer Voices</h1>
<p class="muted" style="font-size:13px;">
  Testimonies submitted by policyholders, in their own words. The Bureau publishes these
  unedited, in line with the citizens' charter principle of mutual transparency. Submission
  is open to any citizen with an active policy.
</p>

<?php if ($submitted): ?>
<div class="panel" style="background:var(--bottle); color:var(--parchment); border-color:var(--bottle);">
  <p style="margin-bottom:0;">
    <strong>Thank you.</strong> Your testimony has been submitted to the wall. It will appear
    immediately, alongside the contributions of your fellow policyholders.
  </p>
</div>
<?php endif; ?>

<h2>Recent Testimonies</h2>

<?php while ($row = $res->fetch_assoc()): ?>
  <div class="voice">
    <!-- ICP_57 SINK: $row['body'] rendered raw — stored XSS reflection point -->
    <div class="quote">"<?= $row['body'] ?>"</div>
    <div class="who">
      — <?= htmlspecialchars($row['author_name']) ?>
      &nbsp;·&nbsp;
      <?= htmlspecialchars(date('d M Y', strtotime($row['submitted_at']))) ?>
    </div>
  </div>
<?php endwhile; ?>

<h2>Submit Your Testimony</h2>

<form class="bureau-form" method="POST" action="">
  <label>Your Name (or pen-name)</label>
  <input name="name" type="text" maxlength="80" placeholder="e.g. R. Subramaniam, Hyderabad">

  <label>Your Testimony</label>
  <textarea name="body" required placeholder="Tell other citizens about your experience with the Bureau."></textarea>

  <button type="submit">Submit to the Wall</button>
</form>

<div class="panel" style="background:var(--parchment-dim); margin-top:32px;">
  <h3>Editorial Policy</h3>
  <p style="margin-bottom:0;">
    The Bureau of Communications reserves the right to remove testimonies which are abusive,
    fraudulent, or in breach of the citizens' charter. Submitted testimonies remain the
    intellectual property of their author. The Bureau does not edit submissions for content,
    spelling, or grammar — testimonies appear as written.
  </p>
</div>

<p class="page-ref">Page 5 of 6 · F.№ ICP/VOICES/05 · Bureau of Communications</p>

<?php include __DIR__ . '/_footer.php'; ?>
