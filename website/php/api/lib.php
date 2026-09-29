<?php
// Shared helpers for the Hoshidub licence server (PHP 8.1+, SQLite by default or MySQL, through PDO).
// Config and database live in <home>/hoshidub-data/, one folder above public_html, so they can never be downloaded.
declare(strict_types=1);

const DATA_DIR_NAME = 'hoshidub-data';

function data_dir(): string {
  return dirname(__DIR__, 2) . '/' . DATA_DIR_NAME;          // public_html/api -> <home>/hoshidub-data
}

function cfg(): array {
  static $c = null;
  if ($c !== null) return $c;
  $file = getenv('HOSHIDUB_CONFIG') ?: data_dir() . '/config.php';
  if (!is_file($file)) reply(['error' => 'The licence server is not configured yet.'], 503);
  $c = require $file;
  return $c;
}

function db(): PDO {
  static $pdo = null;
  if ($pdo) return $pdo;
  $c = cfg();
  $dsn = $c['db_dsn'] ?? '';
  if ($dsn === '') {
    if (!is_dir(data_dir())) mkdir(data_dir(), 0700, true);
    $dsn = 'sqlite:' . data_dir() . '/licenses.sqlite';
  }
  $pdo = new PDO($dsn, $c['db_user'] ?? null, $c['db_pass'] ?? null,
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]);
  // plain SQL that works on both SQLite and MySQL
  $pdo->exec('CREATE TABLE IF NOT EXISTS licenses (
    license_key VARCHAR(40) PRIMARY KEY, email VARCHAR(255) NOT NULL, status VARCHAR(20) NOT NULL,
    stripe_customer VARCHAR(64), stripe_subscription VARCHAR(64), activation_limit INTEGER NOT NULL,
    note VARCHAR(255), created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)');
  $pdo->exec('CREATE TABLE IF NOT EXISTS activations (
    id VARCHAR(32) PRIMARY KEY, license_key VARCHAR(40) NOT NULL, name VARCHAR(255), created_at INTEGER NOT NULL)');
  $pdo->exec('CREATE TABLE IF NOT EXISTS events (id VARCHAR(120) PRIMARY KEY, created_at INTEGER NOT NULL)');
  return $pdo;
}

function reply(array $body, int $code = 200): never {
  http_response_code($code);
  header('Content-Type: application/json; charset=utf-8');
  header('Cache-Control: no-store');
  echo json_encode($body, JSON_UNESCAPED_SLASHES);
  exit;
}

// HD-XXXXX-XXXXX-XXXXX-XXXXX, no look-alike characters (0/O, 1/I)
function new_license_key(): string {
  $abc = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  $groups = [];
  for ($g = 0; $g < 4; $g++) {
    $s = '';
    for ($i = 0; $i < 5; $i++) $s .= $abc[random_int(0, strlen($abc) - 1)];
    $groups[] = $s;
  }
  return 'HD-' . implode('-', $groups);
}

function find_license(string $key): ?array {
  $q = db()->prepare('SELECT * FROM licenses WHERE license_key = ?');
  $q->execute([$key]);
  return $q->fetch() ?: null;
}

function activation_count(string $key): int {
  $q = db()->prepare('SELECT COUNT(*) FROM activations WHERE license_key = ?');
  $q->execute([$key]);
  return (int) $q->fetchColumn();
}

function create_license(string $email, ?string $customer, ?string $subscription, string $note = ''): string {
  $key = new_license_key();
  $now = time();
  db()->prepare('INSERT INTO licenses (license_key, email, status, stripe_customer, stripe_subscription, activation_limit, note, created_at, updated_at)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)')
      ->execute([$key, strtolower($email), 'active', $customer, $subscription, (int) (cfg()['activation_limit'] ?? 2), $note, $now, $now]);
  return $key;
}

// Plain-text email with the key(s). Uses the host's mail(); set mail_from to an address on your domain.
function send_keys(string $email, array $keys): bool {
  $c = cfg();
  $from = $c['mail_from'] ?? 'Hoshidub <no-reply@' . ($_SERVER['HTTP_HOST'] ?? 'localhost') . '>';
  $lines = array_map(fn($k) => '    ' . $k, $keys);
  $body = implode("\r\n", [
    'Thank you for getting Hoshidub Pro!',
    '',
    count($keys) > 1 ? 'Your licence keys:' : 'Your licence key:',
    '',
    ...$lines,
    '',
    'To activate: open Hoshidub, go to Settings, then Upgrade, paste the key and press Activate.',
    'You can use it on ' . (int) ($c['activation_limit'] ?? 2) . ' PCs. To move it, press Deactivate on the old PC first.',
    '',
    'Manage your subscription (card, invoices, cancel): ' . ($c['account_url'] ?? 'the link in your Stripe receipt'),
    'Help: ' . ($c['support_url'] ?? 'https://hoshidub.com/support'),
    '',
    'Hoshidub, a product of MCP Labs',
  ]);
  if (!empty($c['mail_disabled'])) return true;             // tests
  $headers = "From: $from\r\nReply-To: " . ($c['reply_to'] ?? $from) . "\r\nContent-Type: text/plain; charset=utf-8";
  return mail($email, 'Your Hoshidub Pro licence key', $body, $headers);
}
