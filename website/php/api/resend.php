<?php
// "Lost your key?" form on /support: POST email -> emails every key for that address.
// Always answers the same way, so nobody can find out which emails are customers. Limited to 3 requests per email per hour.
declare(strict_types=1);
require __DIR__ . '/lib.php';

$back = '/support?sent=1#lost-key';
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') { header('Location: /support#lost-key', true, 303); exit; }

$email = strtolower(trim((string) ($_POST['email'] ?? '')));
if (filter_var($email, FILTER_VALIDATE_EMAIL)) {
  $slot = 'resend:' . hash('sha256', $email) . ':' . intdiv(time(), 3600);
  $n = db()->prepare('SELECT COUNT(*) FROM events WHERE id LIKE ?');
  $n->execute([$slot . ':%']);
  if ((int) $n->fetchColumn() < 3) {
    db()->prepare('INSERT INTO events (id, created_at) VALUES (?, ?)')->execute([$slot . ':' . bin2hex(random_bytes(4)), time()]);
    $q = db()->prepare("SELECT license_key FROM licenses WHERE email = ? AND status = 'active' ORDER BY created_at");
    $q->execute([$email]);
    $keys = $q->fetchAll(PDO::FETCH_COLUMN);
    if ($keys) send_keys($email, $keys);
  }
}
header('Location: ' . $back, true, 303);
