<?php
// Licence API used by the Hoshidub app: POST /api/license/{activate|validate|deactivate}
// Form fields and JSON replies follow the Lemon Squeezy licence API shape, so the app speaks to either.
declare(strict_types=1);
require __DIR__ . '/lib.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') reply(['error' => 'Use POST.'], 405);

$action = $_GET['action'] ?? '';
if (!in_array($action, ['activate', 'validate', 'deactivate'], true)) reply(['error' => 'Unknown action.'], 404);

$key = strtoupper(trim((string) ($_POST['license_key'] ?? '')));
$instanceId = trim((string) ($_POST['instance_id'] ?? ''));
$meta = ['product_id' => cfg()['product_id'] ?? null, 'product_name' => 'Hoshidub Pro'];

$lic = preg_match('/^[A-Z0-9-]{16,40}$/', $key) ? find_license($key) : null;
if (!$lic) reply(['activated' => false, 'valid' => false, 'deactivated' => false, 'error' => 'license_key not found.', 'meta' => $meta], 404);

$usage = activation_count($key);
$info = fn(int $n) => ['key' => $key, 'status' => $lic['status'], 'activation_limit' => (int) $lic['activation_limit'], 'activation_usage' => $n];

function instance(string $key, string $id): ?array {
  $q = db()->prepare('SELECT * FROM activations WHERE id = ? AND license_key = ?');
  $q->execute([$id, $key]);
  $row = $q->fetch();
  return $row ? ['id' => $row['id'], 'name' => $row['name'], 'created_at' => date(DATE_ATOM, (int) $row['created_at'])] : null;
}

if ($action === 'activate') {
  if ($lic['status'] !== 'active') {
    reply(['activated' => false, 'error' => "This license key is {$lic['status']}.", 'license_key' => $info($usage), 'meta' => $meta], 400);
  }
  if ($usage >= (int) $lic['activation_limit']) {
    reply(['activated' => false, 'error' => 'This license key has reached the activation limit.', 'license_key' => $info($usage), 'meta' => $meta], 400);
  }
  $id = bin2hex(random_bytes(16));
  $name = mb_substr(trim((string) ($_POST['instance_name'] ?? 'PC')), 0, 255);
  db()->prepare('INSERT INTO activations (id, license_key, name, created_at) VALUES (?, ?, ?, ?)')->execute([$id, $key, $name, time()]);
  reply(['activated' => true, 'error' => null, 'license_key' => $info($usage + 1), 'instance' => instance($key, $id), 'meta' => $meta]);
}

if ($action === 'validate') {
  $inst = $instanceId !== '' ? instance($key, $instanceId) : null;
  if ($instanceId !== '' && !$inst) {
    reply(['valid' => false, 'error' => 'license_key instance not found.', 'license_key' => $info($usage), 'meta' => $meta], 404);
  }
  reply(['valid' => $lic['status'] === 'active', 'error' => null, 'license_key' => $info($usage), 'instance' => $inst, 'meta' => $meta]);
}

// deactivate
$q = db()->prepare('DELETE FROM activations WHERE id = ? AND license_key = ?');
$q->execute([$instanceId, $key]);
$done = $q->rowCount() > 0;
reply(['deactivated' => $done, 'error' => $done ? null : 'license_key instance not found.', 'license_key' => $info(activation_count($key)), 'meta' => $meta], $done ? 200 : 404);
