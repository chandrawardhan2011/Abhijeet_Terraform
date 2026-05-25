<?php
/**
 * beneficiary lib/crypto.php
 * ICP_44 — Weak cryptography: AES-128-ECB with a hardcoded key.
 *           ECB mode means identical plaintext blocks produce identical
 *           ciphertext blocks, leaking information.
 *
 * Real fix: AES-GCM with KMS-managed key + per-record IV.
 */

// VULNERABLE: hardcoded key in source, ECB mode.
const ICP_WEAK_KEY = 'icp-2026-stable!';   // 16 bytes for AES-128

function icp_weak_encrypt(string $plaintext): string {
    return openssl_encrypt($plaintext, 'AES-128-ECB', ICP_WEAK_KEY, OPENSSL_RAW_DATA);
}

function icp_weak_decrypt(string $ciphertext): string {
    return openssl_decrypt($ciphertext, 'AES-128-ECB', ICP_WEAK_KEY, OPENSSL_RAW_DATA);
}
