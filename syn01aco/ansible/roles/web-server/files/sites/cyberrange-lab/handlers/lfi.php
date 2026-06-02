<?php $page = $_GET['file'] ?? 'home.php'; ?>
<div class="guides-wrap">
  <div class="guides-nav">
    <a href="?page=lfi&file=home.php" class="guide-tag">Overview</a>
    <a href="?page=lfi&file=about.php" class="guide-tag">About Us</a>
  </div>
  <form method="GET" class="site-form site-form-inline">
    <input type="hidden" name="page" value="lfi">
    <label>Guide File
      <input type="text" name="file" value="<?= htmlspecialchars($page) ?>" placeholder="e.g. home.php, about.php" autocomplete="off">
    </label>
    <button type="submit" class="btn-secondary-dark">Load Guide</button>
  </form>
  <div class="guide-content">
    <?php include "pages/" . $page; ?>
  </div>
</div>
