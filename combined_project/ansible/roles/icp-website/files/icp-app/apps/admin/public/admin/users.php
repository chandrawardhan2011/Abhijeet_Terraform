<?php
/**
 * admin.icp.lab/admin/users.php
 * User Management. List, add, delete personnel records.
 *
 * Note: Like the other admin pages, this enforces only require_login() and
 * NOT a role check, preserving the ICP_51 broken-access-control vulnerability.
 * A regular 'user' who navigates here can create new accounts, including
 * adjuster-role accounts — the lateral-movement teaching primitive.
 */
require_once '/var/www/icp/shared/includes/db.php';
require_once '/var/www/icp/shared/includes/audit.php';
require_once '/var/www/icp/shared/includes/auth.php';

require_login();
$db = icp_db();
$user = [
    'id'       => (int)($_SESSION['user_id'] ?? 0),
    'username' => $_SESSION['username'] ?? '',
    'role'     => $_SESSION['role'] ?? 'user',
];

$notice = null;
$notice_type = 'info';

// ---- Handle POST: add or delete ----
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';

    if ($action === 'add') {
        $username = trim($_POST['username'] ?? '');
        $password = (string)($_POST['password'] ?? '');
        $email    = trim($_POST['email'] ?? '');
        $role     = $_POST['role'] ?? 'user';

        audit('admin.users.add', ['by' => $user['username'], 'new_user' => $username, 'role' => $role]);

        if ($username === '' || $password === '') {
            $notice = 'Username and password are required.';
            $notice_type = 'error';
        } else {
            if (!in_array($role, ['user', 'adjuster'], true)) { $role = 'user'; }
            $stmt = $db->prepare("INSERT INTO users (username, password_md5, email, role) VALUES (?, MD5(?), ?, ?)");
            $stmt->bind_param('ssss', $username, $password, $email, $role);
            try {
                if ($stmt->execute()) {
                    $notice = "Account created for {$username} ({$role}).";
                    $notice_type = 'success';
                } else {
                    $notice = 'Account creation failed: ' . htmlspecialchars($stmt->error);
                    $notice_type = 'error';
                }
            } catch (mysqli_sql_exception $e) {
                $notice = 'Account creation failed: ' . htmlspecialchars($e->getMessage());
                $notice_type = 'error';
            }
        }
    }
    elseif ($action === 'delete') {
        $del_id = (int)($_POST['user_id'] ?? 0);
        audit('admin.users.delete', ['by' => $user['username'], 'user_id' => $del_id]);
        if ($del_id > 0 && $del_id !== $user['id']) {
            $stmt = $db->prepare("DELETE FROM users WHERE id=?");
            $stmt->bind_param('i', $del_id);
            if ($stmt->execute()) {
                $notice = "User #{$del_id} removed.";
                $notice_type = 'success';
            } else {
                $notice = 'Removal failed.';
                $notice_type = 'error';
            }
        } else {
            $notice = 'Cannot remove that record.';
            $notice_type = 'error';
        }
    }
}

// ---- Load roster ----
$rows = [];
$res = $db->query("SELECT id, username, email, role FROM users ORDER BY id");
if ($res) {
    while ($r = $res->fetch_assoc()) { $rows[] = $r; }
}

$sb_section = 'admin';
$sb_active  = 'users';
$sb_user    = $user;
$icp_title  = 'User Management';

require '/var/www/icp/shared/partials/dashboard_head.php';
?>

<h1>User Management</h1>
<p class="icp-folio">Personnel Accounts &middot; signed in as <?= htmlspecialchars($user['username']) ?></p>

<?php if ($notice): ?>
  <div class="icp-notice icp-notice-<?= $notice_type === 'success' ? 'success' : ($notice_type === 'error' ? 'error' : '') ?>">
    <?= htmlspecialchars($notice) ?>
  </div>
<?php endif; ?>

<div class="icp-card">
  <h2>Personnel Roster</h2>
  <table class="icp-table">
    <thead>
      <tr>
        <th>#</th>
        <th>Username</th>
        <th>Email</th>
        <th>Role</th>
        <th>Action</th>
      </tr>
    </thead>
    <tbody>
      <?php foreach ($rows as $r): ?>
      <tr>
        <td><?= (int)$r['id'] ?></td>
        <td><?= htmlspecialchars($r['username']) ?></td>
        <td><?= htmlspecialchars($r['email'] ?? '') ?></td>
        <td><?= htmlspecialchars($r['role']) ?></td>
        <td>
          <?php if ((int)$r['id'] !== $user['id']): ?>
            <form method="POST" style="display:inline; margin:0;" onsubmit="return confirm('Remove this user?');">
              <input type="hidden" name="action" value="delete">
              <input type="hidden" name="user_id" value="<?= (int)$r['id'] ?>">
              <button type="submit" class="icp-button-link">Remove</button>
            </form>
          <?php else: ?>
            <span style="font-size:11px; color:#888;">(self)</span>
          <?php endif; ?>
        </td>
      </tr>
      <?php endforeach; ?>
    </tbody>
  </table>
</div>

<div class="icp-card">
  <h2>Add Personnel Account</h2>
  <form method="POST" style="max-width:520px;">
    <input type="hidden" name="action" value="add">
    <div class="icp-form-row">
      <label>Username</label>
      <input type="text" name="username" required maxlength="64">
    </div>
    <div class="icp-form-row">
      <label>Password</label>
      <input type="password" name="password" required maxlength="60">
    </div>
    <div class="icp-form-row">
      <label>Email</label>
      <input type="email" name="email" maxlength="128">
    </div>
    <div class="icp-form-row">
      <label>Role</label>
      <select name="role">
        <option value="user">User (Beneficiary)</option>
        <option value="adjuster">Adjuster (Admin)</option>
      </select>
    </div>
    <button type="submit" class="icp-button">Create Account</button>
  </form>
</div>

<?php require '/var/www/icp/shared/partials/dashboard_foot.php'; ?>
