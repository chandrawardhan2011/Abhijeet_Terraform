<?php
require_once __DIR__ . '/../config.php';
$id = $_GET['id'] ?? 1;
$query = "SELECT * FROM users WHERE id=$id";
$result = $db->query($query);
$user = $result->fetchArray();
?>
<div class="profile-lookup">
  <form method="GET" class="site-form site-form-inline">
    <input type="hidden" name="page" value="profile">
    <label>Traveller ID
      <input type="text" name="id" value="<?= htmlspecialchars((string)$id) ?>" placeholder="e.g. 1, 2, 3 …" autocomplete="off">
    </label>
    <button type="submit" class="btn-primary">Lookup</button>
  </form>
  <?php if ($user): ?>
  <div class="profile-card">
    <div class="profile-avatar"><?= strtoupper(substr($user['username'] ?? 'U', 0, 1)) ?></div>
    <div class="profile-details">
      <div class="profile-row"><span class="profile-key">Traveller ID</span><span class="profile-val"><?= htmlspecialchars((string)($user['id'] ?? '')) ?></span></div>
      <div class="profile-row"><span class="profile-key">Name</span><span class="profile-val"><?= htmlspecialchars($user['username'] ?? '') ?></span></div>
      <div class="profile-row"><span class="profile-key">Credential</span><span class="profile-val profile-sensitive"><?= htmlspecialchars($user['password'] ?? '') ?></span></div>
      <div class="profile-row"><span class="profile-key">Role</span><span class="profile-val"><?= htmlspecialchars($user['role'] ?? '') ?></span></div>
      <?php if (!empty($user['adhar_id'])): ?>
      <div class="profile-row"><span class="profile-key">ID Number</span><span class="profile-val profile-sensitive"><?= htmlspecialchars($user['adhar_id']) ?></span></div>
      <?php endif; ?>
    </div>
  </div>
  <?php else: ?>
  <p class="form-hint" style="margin-top:16px;">No traveller found with ID <?= (int)$id ?>.</p>
  <?php endif; ?>
</div>
