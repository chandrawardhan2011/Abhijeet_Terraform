<?php
require_once __DIR__ . '/../config.php';
if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $username = $_POST['username'];
    $password = $_POST['password'];
    $query = "SELECT * FROM users WHERE username='$username' AND password='$password'";
    $result = $db->query($query);
    if ($result->fetchArray()) {
        echo '<div class="login-result login-ok">✓ Welcome back! Redirecting to your dashboard…</div>';
    } else {
        echo '<div class="login-result login-fail">Invalid credentials. Please try again.</div>';
    }
}
?>
<form method="POST" class="site-form">
  <label>Email / Username
    <input type="text" name="username" placeholder="your.name@email.com" autocomplete="off">
  </label>
  <label>Password
    <input type="password" name="password" placeholder="••••••••">
  </label>
  <button type="submit" class="btn-primary btn-full">Sign In to My Account</button>
  <p class="form-hint">Forgot your password? <a href="#">Reset here</a></p>
</form>
