<?php
/**
 * claims.icp.lab/upload.php
 * ICP_21 — Unrestricted file upload.
 * Only the Content-Type header is checked. Any extension is accepted.
 * Files land in /var/www/icp/uploads/claims/ which Apache serves as PHP.
 */

require_once '/var/www/icp/shared/includes/audit.php';
require_once '/var/www/icp/shared/includes/flags.php';

$dest_dir = '/var/www/icp/uploads/claims/';
@mkdir($dest_dir, 0775, true);

if ($_SERVER['REQUEST_METHOD'] === 'POST' && !empty($_FILES['document'])) {
    $f = $_FILES['document'];
    // VULNERABLE: only checks the client-declared content type.
    $allowed_types = ['application/pdf', 'image/jpeg', 'image/png'];
    if (!in_array($f['type'], $allowed_types, true)) {
        die("Type not allowed: " . htmlspecialchars($f['type']));
    }
    // Original filename preserved — extension trusted.
    $name = basename($f['name']);
    $dest = $dest_dir . $name;
    if (move_uploaded_file($f['tmp_name'], $dest)) {
        audit('claims.upload', ['name' => $name, 'type' => $f['type']]);
        echo "<p>Uploaded. Retrieve at <a href='/uploads/claims/" . htmlspecialchars($name) . "'>";
        echo "/uploads/claims/" . htmlspecialchars($name) . "</a></p>";
        echo "<!-- ICP_21 marker: " . flag_for('ICP_21') . " -->";
    } else {
        die("Upload failed.");
    }
    exit;
}
?>
<!-- ICP_BACKNAV -->
<div style="background: #8a2818; color: #f0e8d0; padding: 8px 20px; font-family: 'Times New Roman', Georgia, serif; font-size: 12px; letter-spacing: 0.08em; border-bottom: 2px solid #c4881e;">
  <a href="http://icp.lab/" style="color: #f0e8d0; text-decoration: none;">&larr; Shikra Insurance</a>
</div>

<h2>Upload supporting document</h2>
<form method=POST enctype="multipart/form-data">
  <input type=file name=document>
  <button>Upload</button>
</form>
