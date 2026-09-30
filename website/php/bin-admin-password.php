<?php
// php bin-admin-password.php  -> asks for a password (hidden) and prints the config.php line to paste. Nothing is stored.
echo 'New admin password: '; system('stty -echo 2>/dev/null'); $p = trim((string) fgets(STDIN)); system('stty echo 2>/dev/null'); echo "\n";
if (strlen($p) < 12) { fwrite(STDERR, "Use at least 12 characters.\n"); exit(1); }
echo "Paste into hoshidub-data/config.php, inside the array:\n  'admin_password_hash' => '" . password_hash($p, PASSWORD_DEFAULT) . "',\n";
