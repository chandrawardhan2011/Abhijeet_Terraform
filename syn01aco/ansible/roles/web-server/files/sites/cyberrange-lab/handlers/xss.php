<?php $q = $_GET['q'] ?? ''; ?>
<div class="search-wrap">
  <form method="GET" class="tour-search-bar">
    <input type="hidden" name="page" value="search">
    <div class="search-field-wrap">
      <label class="search-bar-label">Destination or Tour Name</label>
      <input type="text" name="q" placeholder="e.g. Rajasthan, Karakoram, Kerala…" autocomplete="off"
             value="<?= htmlspecialchars($q, ENT_QUOTES) ?>">
    </div>
    <button type="submit" class="btn-primary">Search Tours</button>
  </form>
  <?php if ($q != ''): ?>
  <div class="search-results">
    <p class="results-header">Search results for: <?= $q ?></p>
  </div>
  <?php endif; ?>
</div>
