<?php
// Stripe webhook: POST /api/stripe-webhook.php
// Subscribe the endpoint to: checkout.session.completed, customer.subscription.updated, customer.subscription.deleted
// A paid subscription checkout creates a licence key and emails it; subscription changes switch the key on or off.
// One-time payments (tips) are ignored. Needs only the endpoint's signing secret, never the Stripe API key.
declare(strict_types=1);
require __DIR__ . '/lib.php';

$payload = file_get_contents('php://input') ?: '';
$secret = (string) (cfg()['stripe_webhook_secret'] ?? '');
if ($secret === '' || !stripe_signature_ok($payload, $_SERVER['HTTP_STRIPE_SIGNATURE'] ?? '', $secret)) {
  reply(['error' => 'Bad signature.'], 400);
}

function stripe_signature_ok(string $payload, string $header, string $secret, int $tolerance = 300): bool {
  $t = null;
  $sigs = [];
  foreach (explode(',', $header) as $part) {
    [$k, $v] = array_pad(explode('=', trim($part), 2), 2, '');
    if ($k === 't') $t = (int) $v;
    if ($k === 'v1') $sigs[] = $v;
  }
  if (!$t || !$sigs || abs(time() - $t) > $tolerance) return false;
  $expected = hash_hmac('sha256', $t . '.' . $payload, $secret);
  foreach ($sigs as $s) if (hash_equals($expected, $s)) return true;
  return false;
}

$event = json_decode($payload, true);
if (!is_array($event) || empty($event['id']) || empty($event['type'])) reply(['error' => 'Bad payload.'], 400);
$obj = $event['data']['object'] ?? [];

$pdo = db();
$pdo->beginTransaction();
try {
  // Stripe may deliver an event more than once: handle each id once
  $seen = $pdo->prepare('SELECT 1 FROM events WHERE id = ?');
  $seen->execute([$event['id']]);
  if ($seen->fetchColumn()) { $pdo->rollBack(); reply(['received' => true, 'duplicate' => true]); }
  $pdo->prepare('INSERT INTO events (id, created_at) VALUES (?, ?)')->execute([$event['id'], time()]);

  $mail = null;
  switch ($event['type']) {
    case 'checkout.session.completed':
      if (($obj['mode'] ?? '') !== 'subscription' || ($obj['payment_status'] ?? '') === 'unpaid') break;   // tips, unpaid
      $email = $obj['customer_details']['email'] ?? $obj['customer_email'] ?? '';
      $sub = $obj['subscription'] ?? null;
      if (!$email || !$sub) break;
      $have = $pdo->prepare('SELECT license_key FROM licenses WHERE stripe_subscription = ?');
      $have->execute([$sub]);
      if ($have->fetchColumn()) break;
      $key = create_license($email, $obj['customer'] ?? null, $sub, 'checkout ' . ($obj['id'] ?? ''));
      $mail = [$email, [$key]];
      break;

    case 'customer.subscription.updated':
    case 'customer.subscription.deleted':
      $status = $event['type'] === 'customer.subscription.deleted' ? 'expired'
        : (in_array($obj['status'] ?? '', ['active', 'trialing', 'past_due'], true) ? 'active' : 'expired');
      $pdo->prepare('UPDATE licenses SET status = ?, updated_at = ? WHERE stripe_subscription = ? AND status <> ?')
          ->execute([$status, time(), $obj['id'] ?? '', 'disabled']);          // a key you disabled by hand stays disabled
      break;
  }
  $pdo->commit();
} catch (Throwable $e) {
  if ($pdo->inTransaction()) $pdo->rollBack();
  error_log('hoshidub webhook: ' . $e->getMessage());
  reply(['error' => 'Server error.'], 500);                                 // Stripe retries later
}

if ($mail) send_keys($mail[0], $mail[1]);
reply(['received' => true]);
