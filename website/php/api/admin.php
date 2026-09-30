<?php
// Hoshidub admin: /admin (rewritten to this file). Stats, licence search, manual keys, disable/enable, activations, resend, CSV export, log.
// The password lives (hashed) in the licence database, next to config.php in hoshidub-data/, never in the website folder or git.
// First sign-in: config.php 'admin_password_hash' seeds a temporary password; the first sign-in must replace it.
declare(strict_types=1);
require __DIR__ . '/lib.php';
require_once __DIR__ . '/discord-lib.php';

header('Cache-Control: no-store');
header('X-Robots-Tag: noindex, nofollow');
header("Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; img-src 'self'; font-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'");
session_name('hd_admin');
session_set_cookie_params(['lifetime' => 0, 'path' => '/', 'secure' => true, 'httponly' => true, 'samesite' => 'Strict']);
if (!is_dir(data_dir() . '/sessions')) mkdir(data_dir() . '/sessions', 0700, true);
session_save_path(data_dir() . '/sessions');
session_start();

$e = fn($s) => htmlspecialchars((string) $s, ENT_QUOTES, 'UTF-8');
$self = '/admin';

// password hash: database first; the config value only seeds it (as a temporary password that must be changed)
$pdo = db();
$auth = $pdo->query('SELECT hash, must_change FROM admin_auth WHERE id = 1')->fetch();
if (!$auth && (string) (cfg()['admin_password_hash'] ?? '') !== '') {
  $pdo->prepare('INSERT INTO admin_auth (id, hash, must_change, updated_at) VALUES (1, ?, 1, ?)')->execute([cfg()['admin_password_hash'], time()]);
  $auth = ['hash' => cfg()['admin_password_hash'], 'must_change' => 1];
}
$hash = (string) ($auth['hash'] ?? '');

function page(string $title, string $body, bool $narrow = false): never {
  global $e;
  echo '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex"><title>' . $e($title) . '</title><style>
@font-face{font-family:Inter;src:url(/fonts/Inter.woff2) format("woff2");font-weight:100 900;font-display:swap}
:root{color-scheme:dark;--bg:#0c0c12;--glass:rgba(34,34,44,.55);--glass2:rgba(28,28,36,.78);--edge:rgba(255,255,255,.16);--line:rgba(255,255,255,.1);--tx:#f5f5f7;--mu:rgba(235,235,245,.66);--ac:#0a84ff;--ok:#30d158;--bad:#ff6b7a;--warn:#ffb340;--grad:linear-gradient(120deg,#ff6b9d,#c38bff 55%,#6ba8ff)}
*{box-sizing:border-box}html{min-height:100%}body{margin:0;min-height:100vh;color:var(--tx);font:15px/1.5 Inter,"Segoe UI",system-ui,sans-serif;-webkit-font-smoothing:antialiased;
background:linear-gradient(180deg,rgba(12,12,18,.42),rgba(12,12,18,.86)),url(/img/bg/fuji.webp) center 30%/cover fixed,var(--bg)}
main{max-width:1180px;margin:0 auto;padding:22px 16px 70px}main.narrow{max-width:440px;min-height:100vh;display:grid;align-content:center;padding-block:40px}
h1{font-size:24px;margin:0;letter-spacing:-.02em}h2{font-size:17px;margin:30px 0 12px;letter-spacing:-.01em}a{color:#6ba8ff;text-decoration:none}a:hover{text-decoration:underline}
.glass{background:var(--glass);border:1px solid var(--edge);border-radius:22px;backdrop-filter:blur(22px) saturate(170%);-webkit-backdrop-filter:blur(22px) saturate(170%);box-shadow:0 10px 40px rgba(0,0,0,.38)}
.top{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap;margin-bottom:20px;padding:12px 18px}.brand{display:flex;align-items:center;gap:10px}.brand img{width:30px;height:30px}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px}.card{padding:16px}.card b{display:block;font-size:28px;letter-spacing:-.03em}.card span{color:var(--mu);font-size:13px}
table{width:100%;border-collapse:collapse;display:block;overflow-x:auto;background:var(--glass);border:1px solid var(--edge);border-radius:18px;backdrop-filter:blur(22px);-webkit-backdrop-filter:blur(22px)}
th,td{padding:10px 13px;text-align:left;border-bottom:1px solid var(--line);white-space:nowrap;font-size:14px}th{color:var(--mu);font-weight:600}tr:last-child td{border-bottom:0}
code{font:13px ui-monospace,Consolas,monospace}.pill{padding:3px 10px;border-radius:99px;font-size:12px;font-weight:650}
.active{background:rgba(48,209,88,.16);color:var(--ok)}.expired{background:rgba(255,179,64,.16);color:var(--warn)}.disabled{background:rgba(255,107,122,.16);color:var(--bad)}
input,select,button{font:inherit;color:var(--tx);background:rgba(255,255,255,.08);border:1px solid var(--line);border-radius:999px;padding:9px 16px;min-height:42px}
input:focus,select:focus{outline:2px solid var(--ac);outline-offset:1px}input::placeholder{color:var(--mu)}
button{cursor:pointer;font-weight:650}button:hover{background:rgba(255,255,255,.14)}button.p{background:var(--ac);border-color:transparent;box-shadow:0 8px 24px rgba(10,132,255,.35)}button.p:hover{filter:brightness(1.1)}
button.d{color:var(--bad);border-color:rgba(255,107,122,.5)}form.inline{display:inline}.row{display:flex;gap:8px;flex-wrap:wrap;align-items:center}.ms{color:var(--mu)}
.flash{padding:11px 16px;margin-bottom:16px;border-radius:14px;background:rgba(48,209,88,.14);border:1px solid rgba(48,209,88,.5)}
.bars{display:flex;align-items:flex-end;gap:3px;height:64px;padding:12px 14px;box-sizing:content-box}.bars i{flex:1;background:var(--grad);border-radius:3px 3px 0 0;min-height:2px}
.login{padding:34px 30px;display:grid;gap:14px;justify-items:center;text-align:center}.login img{width:56px;height:56px}.login h1{font-size:26px}.login form{display:grid;gap:12px;width:100%}.login input,.login button{width:100%}
.tabs{display:flex;gap:4px;padding:6px;margin-bottom:18px;overflow-x:auto;border-radius:999px}.tabs a{padding:8px 18px;border-radius:999px;color:var(--mu);font-weight:600;white-space:nowrap}.tabs a:hover{background:rgba(255,255,255,.08);text-decoration:none}.tabs a.on{background:var(--ac);color:#fff}
.chart{padding:14px 16px}.two{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:12px;margin-top:14px}.chart .bars{padding:12px 0 0;height:80px}
.detail{padding:20px 22px}.kv{display:grid;grid-template-columns:130px 1fr;gap:12px 16px;align-items:center;margin-top:14px}.kv span{color:var(--mu)}.kv input{min-width:220px}.form{padding:14px 16px}
.btn2{display:inline-flex;align-items:center;min-height:42px;padding:0 18px;border-radius:999px;background:rgba(255,255,255,.08);border:1px solid var(--line);color:var(--tx);font-weight:650}.btn2:hover{background:rgba(255,255,255,.14);text-decoration:none}
.flash.bad{background:rgba(255,107,122,.14);border-color:rgba(255,107,122,.5)}.pill.refunded{background:rgba(255,255,255,.12);color:var(--mu)}button.d2{background:var(--bad);border-color:transparent;color:#1a0b0d}.login .btn2{justify-content:center;width:100%}
@media(max-width:640px){.kv{grid-template-columns:1fr}.top{padding:12px}}
.grad{background:var(--grad);-webkit-background-clip:text;background-clip:text;color:transparent}.err{color:var(--bad);min-height:1.4em;margin:0}
</style><main' . ($narrow ? ' class="narrow"' : '') . '>' . $body . '</main></html>';
  exit;
}
function card_page(string $title, string $lead, string $form, string $msg = ''): never {
  global $e;
  page($title, '<div class="login glass"><img src="/img/logo-mark.svg" alt=""><h1>Hoshidub <span class="grad">admin</span></h1><p class="ms" style="margin:0">' . $lead . '</p>' . $form . '<p class="err">' . $e($msg) . '</p></div>', true);
}

// ---- login ----
$ip = $_SERVER['REMOTE_ADDR'] ?? '?';
if (empty($_SESSION['ok'])) {
  $msg = '';
  if ($hash === '') card_page('Admin', 'Admin is not set up yet. Ask your developer to seed the first password.', '');
  if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    $slot = 'adminfail:' . hash('sha256', $ip) . ':' . intdiv(time(), 3600);
    $n = $pdo->prepare('SELECT COUNT(*) FROM events WHERE id LIKE ?'); $n->execute([$slot . ':%']);
    if ((int) $n->fetchColumn() >= 8) $msg = 'Too many tries. Wait an hour.';
    elseif (password_verify((string) ($_POST['password'] ?? ''), $hash)) {
      session_regenerate_id(true); $_SESSION['ok'] = 1; $_SESSION['csrf'] = bin2hex(random_bytes(16));
      admin_log('login from ' . $ip); header('Location: ' . $self, true, 303); exit;
    } else {
      $pdo->prepare('INSERT INTO events (id, created_at) VALUES (?, ?)')->execute([$slot . ':' . bin2hex(random_bytes(4)), time()]);
      usleep(600000); $msg = 'Wrong password.';
    }
  }
  card_page('Admin sign in', 'Sign in to manage licences.', '<form method="post"><input type="password" name="password" placeholder="Password" autofocus required autocomplete="current-password"><button class="p">Sign in</button></form>', $msg);
}


$csrf = $_SESSION['csrf'];

// ---- first sign-in: the temporary password must be replaced before anything else ----
if (!empty($auth['must_change'])) {
  $msg = '';
  if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST' && hash_equals($csrf, (string) ($_POST['csrf'] ?? ''))) {
    $new = (string) ($_POST['new'] ?? '');
    if (strlen($new) < 12) $msg = 'Use at least 12 characters.';
    elseif ($new !== (string) ($_POST['again'] ?? '')) $msg = 'The two passwords do not match.';
    elseif (password_verify($new, $hash)) $msg = 'Pick a different password from the temporary one.';
    else {
      $pdo->prepare('UPDATE admin_auth SET hash = ?, must_change = 0, updated_at = ? WHERE id = 1')->execute([password_hash($new, PASSWORD_DEFAULT), time()]);
      admin_log('first password created'); $_SESSION['flash'] = 'Your password is saved. Use it next time you sign in.'; header('Location: ' . $self, true, 303); exit;
    }
  }
  card_page('Create your password', 'Welcome. Create your own password to continue.',
    '<form method="post"><input type="hidden" name="csrf" value="' . $csrf . '"><input type="password" name="new" placeholder="New password (12+ characters)" required minlength="12" autofocus autocomplete="new-password"><input type="password" name="again" placeholder="Type it again" required minlength="12" autocomplete="new-password"><button class="p">Save and continue</button></form>', $msg);
}

// ---- helpers ----
$pdo = db();
$now = time();
$one = function (string $sql, array $p = []) use ($pdo): int { $q = $pdo->prepare($sql); $q->execute($p); return (int) $q->fetchColumn(); };
$all = function (string $sql, array $p = []) use ($pdo): array { $q = $pdo->prepare($sql); $q->execute($p); return $q->fetchAll(); };
$sget = fn(string $path) => stripe_api($path, [], 'GET');
$money = fn($cents, $cur = 'usd') => ($cur === 'usd' ? '$' : strtoupper((string) $cur) . ' ') . number_format(((int) $cents) / 100, 2);
$ago = function (int $t) use ($now): string { $d = $now - $t; return $d < 90 ? 'just now' : ($d < 5400 ? round($d / 60) . ' min ago' : ($d < 172800 ? round($d / 3600) . ' h ago' : date('Y-m-d', $t))); };
$series = function (string $table, string $col, int $days = 30) use ($pdo, $now): array {
  $out = array_fill(0, $days, 0);
  foreach ($pdo->query("SELECT $col c FROM $table WHERE $col > " . ($now - $days * 86400)) as $r) { $i = $days - 1 - (int) floor(($now - (int) $r['c']) / 86400); if ($i >= 0 && $i < $days) $out[$i]++; }
  return $out;
};
$bars = function (array $v, string $title) use ($e): string {
  $mx = max(1, max($v)); $s = array_sum($v);
  return '<div class="glass chart"><div class="row" style="justify-content:space-between"><b>' . $e($title) . '</b><span class="ms">' . $s . ' in 30 days</span></div><div class="bars">'
    . implode('', array_map(fn($n) => '<i title="' . $n . '" style="height:' . max(3, round($n / $mx * 100)) . '%"></i>', $v)) . '</div></div>';
};
$stat = fn(string $big, string $label, string $tone = '') => '<div class="card glass"><b' . ($tone ? ' class="' . $tone . '"' : '') . '>' . $big . '</b><span>' . $label . '</span></div>';
$table = fn(array $head, array $rows, string $empty = 'Nothing here yet.') => '<table><tr>' . implode('', array_map(fn($h) => '<th>' . $h . '</th>', $head)) . '</tr>'
  . ($rows ? implode('', $rows) : '<tr><td colspan="' . count($head) . '" class="ms">' . $e($empty) . '</td></tr>') . '</table>';
$back = $e($_SERVER['REQUEST_URI'] ?? $self);
$hid = fn(string $do, string $k = '') => '<input type="hidden" name="csrf" value="' . $csrf . '"><input type="hidden" name="do" value="' . $do . '"><input type="hidden" name="back" value="' . $back . '">' . ($k ? '<input type="hidden" name="key" value="' . $e($k) . '">' : '');
$pill = fn(string $s) => '<span class="pill ' . $e($s) . '">' . $e($s) . '</span>';

// ---- actions (POST + CSRF) ----
if (isset($_GET['logout'])) { session_destroy(); header('Location: ' . $self, true, 303); exit; }
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
  if (!hash_equals($csrf, (string) ($_POST['csrf'] ?? ''))) page('Admin', '<div class="login glass"><h1>Session expired</h1><a href="' . $self . '">Back</a></div>', true);
  $a = (string) ($_POST['do'] ?? ''); $k = strtoupper(trim((string) ($_POST['key'] ?? ''))); $flash = '';
  $confirmed = !empty($_POST['confirmed']);
  // money actions ask twice
  if (in_array($a, ['sub_cancel', 'sub_cancel_now', 'refund'], true) && !$confirmed) {
    $what = ['sub_cancel' => 'Cancel this subscription at the end of the period paid for?', 'sub_cancel_now' => 'Cancel this subscription RIGHT NOW? The key stops working immediately and nothing is refunded.', 'refund' => 'Refund ' . $money((int) ($_POST['amount'] ?? 0)) . ' to the customer? This cannot be undone.'][$a];
    $keep = ''; foreach (['key', 'sub', 'charge', 'amount', 'back'] as $f) if (isset($_POST[$f])) $keep .= '<input type="hidden" name="' . $f . '" value="' . $e($_POST[$f]) . '">';
    card_page('Please confirm', $e($what), '<form method="post"><input type="hidden" name="csrf" value="' . $csrf . '"><input type="hidden" name="do" value="' . $e($a) . '"><input type="hidden" name="confirmed" value="1">' . $keep . '<button class="p d2">Yes, do it</button></form><a class="btn2" href="' . $e($_POST['back'] ?? $self) . '">No, go back</a>');
  }
  switch ($a) {
    case 'create':
      $em = strtolower(trim((string) ($_POST['email'] ?? '')));
      if (!filter_var($em, FILTER_VALIDATE_EMAIL)) { $flash = 'That email does not look right.'; break; }
      $nk = create_license($em, null, null, trim((string) ($_POST['note'] ?? '')), in_array($_POST['plan'] ?? '', ['manual', 'comp'], true) ? $_POST['plan'] : 'manual', max(1, min(50, (int) ($_POST['limit'] ?? 2))));
      admin_log("created $nk for $em"); $flash = "Created $nk";
      if (!empty($_POST['send'])) $flash .= send_keys($em, [$nk]) ? ' and emailed it.' : ' (email failed to send).';
      break;
    case 'status':
      $st = in_array($_POST['status'] ?? '', ['active', 'disabled', 'expired'], true) ? $_POST['status'] : 'active';
      $pdo->prepare('UPDATE licenses SET status = ?, updated_at = ? WHERE license_key = ?')->execute([$st, $now, $k]); admin_log("$k -> $st"); dc_sync_key($k); $flash = "$k is now $st."; break;
    case 'limit':
      $pdo->prepare('UPDATE licenses SET activation_limit = ?, updated_at = ? WHERE license_key = ?')->execute([max(1, min(50, (int) $_POST['limit'])), $now, $k]); admin_log("$k limit " . (int) $_POST['limit']); $flash = 'Limit updated.'; break;
    case 'email':
      $em = strtolower(trim((string) ($_POST['email'] ?? '')));
      if (!filter_var($em, FILTER_VALIDATE_EMAIL)) { $flash = 'That email does not look right.'; break; }
      $pdo->prepare('UPDATE licenses SET email = ?, updated_at = ? WHERE license_key = ?')->execute([$em, $now, $k]); admin_log("$k email -> $em"); $flash = 'Email changed.'; break;
    case 'reset':
      $pdo->prepare('DELETE FROM activations WHERE license_key = ?')->execute([$k]); admin_log("$k activations reset"); $flash = 'All PCs signed out of that key.'; break;
    case 'unact':
      $pdo->prepare('DELETE FROM activations WHERE id = ? AND license_key = ?')->execute([(string) $_POST['id'], $k]); admin_log("$k one PC removed"); $flash = 'PC removed.'; break;
    case 'note':
      $pdo->prepare('UPDATE licenses SET note = ?, updated_at = ? WHERE license_key = ?')->execute([mb_substr((string) $_POST['note'], 0, 255), $now, $k]); $flash = 'Note saved.'; break;
    case 'resend':
      $l = find_license($k); $flash = $l && send_keys($l['email'], [$k]) ? 'Key emailed to ' . $l['email'] : 'Could not send.'; admin_log("$k resent"); break;
    case 'sub_cancel': case 'sub_cancel_now':
      $sub = preg_replace('/[^a-zA-Z0-9_]/', '', (string) ($_POST['sub'] ?? ''));
      $r = $a === 'sub_cancel' ? stripe_api("subscriptions/$sub", ['cancel_at_period_end' => 'true']) : stripe_api("subscriptions/$sub", [], 'DELETE');
      $flash = empty($r['id']) ? 'Stripe said no: ' . ($r['error']['message'] ?? 'unknown error') : ($a === 'sub_cancel' ? 'Will cancel at the end of the paid period.' : 'Cancelled now.');
      admin_log("$sub " . ($a === 'sub_cancel' ? 'cancel at period end' : 'cancelled now') . (empty($r['id']) ? ' FAILED' : '')); break;
    case 'refund':
      $ch = preg_replace('/[^a-zA-Z0-9_]/', '', (string) ($_POST['charge'] ?? ''));
      $r = stripe_api('refunds', ['charge' => $ch]);
      $flash = empty($r['id']) ? 'Stripe said no: ' . ($r['error']['message'] ?? 'unknown error') : 'Refunded ' . $money($r['amount']) . '.';
      admin_log("refund $ch" . (empty($r['id']) ? ' FAILED' : ' ok')); break;
    case 'testmail':
      $to = trim((string) ($_POST['to'] ?? ''));
      $flash = filter_var($to, FILTER_VALIDATE_EMAIL) ? (send_keys($to, ['HD-TEST1-TEST2-TEST3-TEST4']) ? "Test email handed to the mail server for $to (check the inbox and spam)." : 'The mail server refused it.') : 'That email does not look right.'; break;
    case 'password':
      $new = (string) ($_POST['new'] ?? ''); $cur = (string) $pdo->query('SELECT hash FROM admin_auth WHERE id = 1')->fetchColumn();
      if (!password_verify((string) ($_POST['current'] ?? ''), $cur)) { $flash = 'Current password is wrong.'; break; }
      if (strlen($new) < 12 || $new !== (string) ($_POST['again'] ?? '')) { $flash = 'New password: at least 12 characters, typed the same twice.'; break; }
      $pdo->prepare('UPDATE admin_auth SET hash = ?, must_change = 0, updated_at = ? WHERE id = 1')->execute([password_hash($new, PASSWORD_DEFAULT), $now]);
      admin_log('password changed'); $flash = 'Password changed. Use it next time you sign in.'; break;
  }
  $_SESSION['flash'] = $flash; $to = (string) ($_POST['back'] ?? '');
  header('Location: ' . ($to !== '' && $to[0] === '/' && !str_starts_with($to, '//') ? $to : $self), true, 303); exit;
}
$flash = $_SESSION['flash'] ?? ''; unset($_SESSION['flash']);

// ---- CSV export ----
if (isset($_GET['csv'])) {
  header('Content-Type: text/csv; charset=utf-8'); header('Content-Disposition: attachment; filename="hoshidub-licences-' . date('Y-m-d') . '.csv"');
  $o = fopen('php://output', 'w'); fputcsv($o, ['key', 'email', 'status', 'plan', 'limit', 'pcs', 'created', 'note', 'stripe_subscription']);
  foreach ($all('SELECT l.*, (SELECT COUNT(*) FROM activations a WHERE a.license_key = l.license_key) pcs FROM licenses l ORDER BY created_at DESC') as $r)
    fputcsv($o, [$r['license_key'], $r['email'], $r['status'], $r['plan'], $r['activation_limit'], $r['pcs'], date('Y-m-d H:i', (int) $r['created_at']), $r['note'], $r['stripe_subscription']]);
  exit;
}

// ---- views ----
$tabs = ['overview' => 'Overview', 'licences' => 'Licences', 'payments' => 'Payments', 'downloads' => 'Downloads', 'activity' => 'Activity', 'settings' => 'Settings'];
$tab = array_key_exists($_GET['tab'] ?? '', $tabs) ? $_GET['tab'] : 'overview';
$b = '<div class="top glass"><div class="brand"><img src="/img/logo-mark.svg" alt=""><h1>Hoshidub <span class="grad">admin</span></h1></div><div class="row"><a href="' . $self . '?csv=1">Export CSV</a><a href="' . $self . '?logout=1">Sign out</a></div></div>';
$b .= '<nav class="tabs glass">' . implode('', array_map(fn($t, $l) => '<a href="' . $self . '?tab=' . $t . '"' . ($t === $tab ? ' class="on"' : '') . '>' . $l . '</a>', array_keys($tabs), $tabs)) . '</nav>';
if ($flash) $b .= '<div class="flash">' . $e($flash) . '</div>';

$licRow = function (array $r) use ($e, $pill, $hid, $pdo, $self): string {
  $k = $r['license_key'];
  return '<tr><td><a href="' . $self . '?tab=licences&key=' . $e($k) . '"><code>' . $e($k) . '</code></a></td><td>' . $e($r['email']) . '</td><td>' . $pill($r['status']) . '</td><td>' . $e($r['plan'] ?: 'stripe') . '</td><td>' . $r['pcs'] . '/' . $r['activation_limit'] . '</td><td>' . date('Y-m-d', (int) $r['created_at']) . '</td><td class="row">'
    . '<form method="post" class="inline">' . $hid('status', $k) . '<input type="hidden" name="status" value="' . ($r['status'] === 'active' ? 'disabled' : 'active') . '"><button class="' . ($r['status'] === 'active' ? 'd' : 'p') . '">' . ($r['status'] === 'active' ? 'Disable' : 'Enable') . '</button></form>'
    . '<form method="post" class="inline">' . $hid('resend', $k) . '<button>Email key</button></form></td></tr>';
};
$licSql = 'SELECT l.*, (SELECT COUNT(*) FROM activations a WHERE a.license_key = l.license_key) pcs FROM licenses l';

if ($tab === 'overview') {
  $by = ['active' => 0, 'expired' => 0, 'disabled' => 0];
  foreach ($all('SELECT status, COUNT(*) c FROM licenses GROUP BY status') as $r) $by[$r['status']] = (int) $r['c'];
  $mo = $one("SELECT COUNT(*) FROM licenses WHERE status='active' AND plan='monthly'"); $yr = $one("SELECT COUNT(*) FROM licenses WHERE status='active' AND plan='yearly'");
  $free = $one("SELECT COUNT(*) FROM licenses WHERE status='active' AND plan IN ('manual','comp')");
  $dl7 = $one('SELECT COUNT(*) FROM downloads WHERE at > ?', [$now - 7 * 86400]); $dlAll = $one('SELECT COUNT(*) FROM downloads');
  $pcsLive = $one("SELECT COUNT(*) FROM activations a JOIN licenses l ON l.license_key = a.license_key WHERE l.status = 'active'");
  $b .= '<div class="cards">' . $stat((string) $by['active'], 'Active Pro keys') . $stat('$' . number_format($mo * 6.99 + $yr * 49 / 12, 2), "Est. monthly revenue ($mo monthly · $yr yearly)")
    . $stat((string) $one('SELECT COUNT(*) FROM licenses WHERE created_at > ?', [$now - 7 * 86400]), 'New keys, 7 days') . $stat((string) $dl7, "Installer downloads, 7 days ($dlAll total)")
    . $stat((string) $pcsLive, 'PCs running Pro') . $stat("$by[expired] / $by[disabled]", 'Expired / disabled') . $stat((string) $free, 'Manual and gift keys') . $stat((string) $one('SELECT COUNT(*) FROM licenses'), 'Keys ever made') . '</div>';
  $b .= '<div class="two">' . $bars($series('licenses', 'created_at'), 'New keys per day') . $bars($series('downloads', 'at'), 'Installer downloads per day') . '</div>';
  $b .= '<h2>Latest keys</h2>' . $table(['Key', 'Email', 'Status', 'Plan', 'PCs', 'Made', ''], array_map($licRow, $all($licSql . ' ORDER BY created_at DESC LIMIT 8')), 'No keys yet. They appear here when someone pays.');
  $b .= '<p class="ms">Website visitors are not counted here. Revenue above is an estimate from active keys; the Payments tab shows real Stripe numbers.</p>';
}

if ($tab === 'licences') {
  $key = strtoupper(trim((string) ($_GET['key'] ?? '')));
  $lic = $key !== '' ? find_license($key) : null;
  if ($lic) {   // ---- one licence ----
    $acts = $all('SELECT * FROM activations WHERE license_key = ? ORDER BY created_at', [$key]);
    $b .= '<p><a href="' . $self . '?tab=licences">← All licences</a></p><div class="glass detail"><div class="row" style="justify-content:space-between"><h2 style="margin:0"><code>' . $e($key) . '</code> ' . $pill($lic['status']) . '</h2><span class="ms">made ' . date('Y-m-d H:i', (int) $lic['created_at']) . '</span></div><div class="kv">'
      . '<span>Email</span><form method="post" class="row">' . $hid('email', $key) . '<input name="email" type="email" value="' . $e($lic['email']) . '"><button>Change</button></form>'
      . '<span>Plan</span><b>' . $e($lic['plan'] ?: 'stripe') . '</b>'
      . '<span>PCs allowed</span><form method="post" class="row">' . $hid('limit', $key) . '<input type="number" name="limit" value="' . (int) $lic['activation_limit'] . '" min="1" max="50" style="width:90px"><button>Save</button></form>'
      . '<span>Note</span><form method="post" class="row">' . $hid('note', $key) . '<input name="note" value="' . $e($lic['note']) . '"><button>Save</button></form></div><div class="row" style="margin-top:14px">'
      . '<form method="post" class="inline">' . $hid('status', $key) . '<input type="hidden" name="status" value="' . ($lic['status'] === 'active' ? 'disabled' : 'active') . '"><button class="' . ($lic['status'] === 'active' ? 'd' : 'p') . '">' . ($lic['status'] === 'active' ? 'Disable key' : 'Enable key') . '</button></form>'
      . '<form method="post" class="inline">' . $hid('resend', $key) . '<button>Email the key again</button></form>'
      . '<form method="post" class="inline">' . $hid('reset', $key) . '<button>Sign out all PCs</button></form></div></div>';
    $b .= '<h2>PCs using this key (' . count($acts) . '/' . (int) $lic['activation_limit'] . ')</h2>' . $table(['PC name', 'Since', ''], array_map(fn($x) => '<tr><td>' . $e($x['name']) . '</td><td>' . date('Y-m-d H:i', (int) $x['created_at']) . '</td><td><form method="post" class="inline">' . $hid('unact', $key) . '<input type="hidden" name="id" value="' . $e($x['id']) . '"><button class="d">Remove</button></form></td></tr>', $acts), 'Not activated on any PC yet.');
    if ($lic['stripe_subscription']) {
      $sub = $sget('subscriptions/' . rawurlencode($lic['stripe_subscription']));
      $b .= '<h2>Stripe subscription</h2><div class="glass detail"><div class="kv">';
      if (!empty($sub['id'])) {
        $pr = $sub['items']['data'][0]['price'] ?? [];
        $b .= '<span>Status</span><b>' . $e($sub['status']) . (!empty($sub['cancel_at_period_end']) ? ' (cancels at period end)' : '') . '</b><span>Price</span><b>' . $money($pr['unit_amount'] ?? 0, $pr['currency'] ?? 'usd') . ' / ' . $e($pr['recurring']['interval'] ?? '?') . '</b>'
          . '<span>Renews / ends</span><b>' . (isset($sub['current_period_end']) || isset($sub['items']['data'][0]['current_period_end']) ? date('Y-m-d', (int) ($sub['current_period_end'] ?? $sub['items']['data'][0]['current_period_end'])) : '?') . '</b></div><div class="row" style="margin-top:14px">'
          . '<a class="btn2" href="https://dashboard.stripe.com/subscriptions/' . $e($sub['id']) . '" target="_blank" rel="noopener">Open in Stripe</a>';
        if (in_array($sub['status'], ['active', 'trialing', 'past_due'], true)) {
          if (empty($sub['cancel_at_period_end'])) $b .= '<form method="post" class="inline">' . $hid('sub_cancel', $key) . '<input type="hidden" name="sub" value="' . $e($sub['id']) . '"><button class="d">Cancel at period end</button></form>';
          $b .= '<form method="post" class="inline">' . $hid('sub_cancel_now', $key) . '<input type="hidden" name="sub" value="' . $e($sub['id']) . '"><button class="d">Cancel now</button></form>';
        }
        $b .= '</div>';
      } else $b .= '<span>Stripe</span><b>' . $e($sub['error']['message'] ?? 'Could not load') . '</b></div>';
      $b .= '</div>';
    }
    $b .= '<h2>History</h2>' . $table(['When', 'What'], array_map(fn($x) => '<tr><td>' . date('Y-m-d H:i', (int) $x['at']) . '</td><td>' . $e($x['what']) . '</td></tr>', $all('SELECT at, what FROM admin_log WHERE what LIKE ? ORDER BY at DESC LIMIT 30', ["%$key%"])), 'No admin actions on this key.');
  } else {   // ---- list ----
    $q = trim((string) ($_GET['q'] ?? '')); $f = (string) ($_GET['status'] ?? ''); $where = []; $par = [];
    if ($q !== '') { $where[] = '(l.license_key LIKE ? OR l.email LIKE ? OR l.note LIKE ?)'; array_push($par, "%$q%", "%$q%", "%$q%"); }
    if (in_array($f, ['active', 'expired', 'disabled'], true)) { $where[] = 'l.status = ?'; $par[] = $f; }
    $rows = $all($licSql . ($where ? ' WHERE ' . implode(' AND ', $where) : '') . ' ORDER BY l.created_at DESC LIMIT 300', $par);
    $b .= '<h2>Give a key by hand</h2><form method="post" class="row glass form">' . $hid('create') . '<input type="email" name="email" placeholder="customer@email" required><select name="plan"><option value="manual">Paid another way</option><option value="comp">Free gift</option></select><input type="number" name="limit" value="2" min="1" max="50" style="width:84px" title="PCs allowed"><input name="note" placeholder="Note (optional)"><label class="ms"><input type="checkbox" name="send" value="1" checked> email it</label><button class="p">Create key</button></form>';
    $b .= '<h2>All licences (' . count($rows) . ')</h2><form method="get" class="row" style="margin-bottom:12px"><input type="hidden" name="tab" value="licences"><input name="q" value="' . $e($q) . '" placeholder="Search key, email or note"><select name="status"><option value="">Any status</option>';
    foreach (['active', 'expired', 'disabled'] as $s) $b .= '<option' . ($f === $s ? ' selected' : '') . '>' . $s . '</option>';
    $b .= '</select><button>Search</button></form>' . $table(['Key', 'Email', 'Status', 'Plan', 'PCs', 'Made', ''], array_map($licRow, $rows), 'No licences match.');
  }
}

if ($tab === 'payments') {
  $bal = $sget('balance'); $ch = $sget('charges?limit=25'); $subs = $sget('subscriptions?status=active&limit=100');
  if (empty($ch['data']) && !empty($ch['error'])) $b .= '<div class="flash bad">Stripe: ' . $e($ch['error']['message'] ?? 'could not load') . '</div>';
  $mrr = 0; $n = 0;
  foreach ($subs['data'] ?? [] as $s) { $pr = $s['items']['data'][0]['price'] ?? []; $c = (int) ($pr['unit_amount'] ?? 0); $mrr += ($pr['recurring']['interval'] ?? 'month') === 'year' ? $c / 12 : $c; $n++; }
  $avail = 0; foreach ($bal['available'] ?? [] as $x) $avail += (int) $x['amount']; $pend = 0; foreach ($bal['pending'] ?? [] as $x) $pend += (int) $x['amount'];
  $gross = 0; foreach ($ch['data'] ?? [] as $c) if (!empty($c['paid']) && $c['created'] > $now - 30 * 86400) $gross += (int) $c['amount'] - (int) $c['amount_refunded'];
  $b .= '<div class="cards">' . $stat($money($mrr), "Real monthly revenue ($n active subs)") . $stat($money($gross), 'Collected, last 30 days (latest 25 payments)') . $stat($money($avail), 'Stripe balance available') . $stat($money($pend), 'Pending payout') . '</div>';
  $rows = [];
  foreach ($ch['data'] ?? [] as $c) {
    $em = $c['billing_details']['email'] ?? $c['receipt_email'] ?? '';
    $st = !empty($c['refunded']) ? 'refunded' : ($c['status'] === 'succeeded' ? 'active' : 'disabled');
    $rows[] = '<tr><td>' . date('Y-m-d H:i', (int) $c['created']) . '</td><td>' . $e($em) . '</td><td>' . $money($c['amount'], $c['currency']) . '</td><td><span class="pill ' . $st . '">' . ($st === 'active' ? 'paid' : ($st === 'disabled' ? $e($c['status']) : 'refunded')) . '</span></td><td class="row">'
      . '<a href="https://dashboard.stripe.com/payments/' . $e($c['payment_intent'] ?? $c['id']) . '" target="_blank" rel="noopener">Stripe</a>'
      . (!empty($c['paid']) && empty($c['refunded']) ? '<form method="post" class="inline">' . $hid('refund') . '<input type="hidden" name="charge" value="' . $e($c['id']) . '"><input type="hidden" name="amount" value="' . (int) ($c['amount'] - $c['amount_refunded']) . '"><button class="d">Refund</button></form>' : '') . '</td></tr>';
  }
  $b .= '<h2>Latest payments</h2>' . $table(['When', 'Customer', 'Amount', 'Status', ''], $rows, 'No payments yet.');
  $b .= '<p class="ms">Live data from Stripe. Refunds and cancellations ask you to confirm first.</p>';
}

if ($tab === 'downloads') {
  $d1 = $one('SELECT COUNT(*) FROM downloads WHERE at > ?', [$now - 86400]); $d7 = $one('SELECT COUNT(*) FROM downloads WHERE at > ?', [$now - 7 * 86400]); $d30 = $one('SELECT COUNT(*) FROM downloads WHERE at > ?', [$now - 30 * 86400]); $dall = $one('SELECT COUNT(*) FROM downloads');
  $u = $one('SELECT COUNT(DISTINCT ip_hash) FROM downloads'); $keys = $one('SELECT COUNT(*) FROM licenses');
  $b .= '<div class="cards">' . $stat((string) $d1, 'Last 24 hours') . $stat((string) $d7, 'Last 7 days') . $stat((string) $d30, 'Last 30 days') . $stat((string) $dall, 'All time') . $stat((string) $u, 'Unique visitors') . $stat($u ? round($keys / $u * 100, 1) . '%' : '–', 'Keys per unique downloader') . '</div>';
  $b .= '<div style="margin-top:14px">' . $bars($series('downloads', 'at'), 'Installer downloads per day') . '</div>';
  $b .= '<h2>Latest downloads</h2>' . $table(['When', 'File', 'Visitor'], array_map(fn($x) => '<tr><td>' . date('Y-m-d H:i', (int) $x['at']) . '</td><td>' . $e($x['file']) . '</td><td><code>' . $e(substr($x['ip_hash'], 0, 8)) . '</code></td></tr>', $all('SELECT * FROM downloads ORDER BY at DESC LIMIT 25')), 'No downloads counted yet.');
  $b .= '<p class="ms">Counted when someone uses the site\'s Download button (one per visitor per 10 minutes, bots skipped). Visitors are stored as an anonymous fingerprint, never an IP address. The voice-engine parts downloaded by the app are not counted.</p>';
}

if ($tab === 'activity') {
  $ev = [];
  foreach ($all('SELECT at, type, email, detail FROM stripe_log ORDER BY at DESC LIMIT 60') as $x) $ev[] = [(int) $x['at'], 'Stripe · ' . $x['type'], trim($x['email'] . ' ' . $x['detail'])];
  foreach ($all('SELECT at, what FROM admin_log ORDER BY at DESC LIMIT 60') as $x) $ev[] = [(int) $x['at'], 'Admin', $x['what']];
  foreach ($all('SELECT created_at, license_key, email, plan FROM licenses ORDER BY created_at DESC LIMIT 30') as $x) $ev[] = [(int) $x['created_at'], 'New key', $x['email'] . ' · ' . $x['plan'] . ' · ' . $x['license_key']];
  usort($ev, fn($a, $b) => $b[0] <=> $a[0]);
  $b .= '<h2>Everything that happened</h2>' . $table(['When', 'Type', 'Details'], array_map(fn($x) => '<tr><td title="' . date('Y-m-d H:i:s', $x[0]) . '">' . $e($ago($x[0])) . '</td><td>' . $e($x[1]) . '</td><td>' . $e($x[2]) . '</td></tr>', array_slice($ev, 0, 100)), 'Nothing yet.');
}

if ($tab === 'settings') {
  $acct = $sget('account'); $hooks = $sget('webhook_endpoints?limit=100'); $mine = null;
  foreach ($hooks['data'] ?? [] as $h) if (str_ends_with($h['url'], '/api/stripe-webhook.php')) $mine = $h;
  $last = $one("SELECT MAX(created_at) FROM events WHERE id LIKE 'evt_%'");
  $yes = fn($ok, $t, $bad = '') => '<tr><td>' . ($ok ? '<span class="pill active">OK</span>' : '<span class="pill disabled">Fix</span>') . '</td><td>' . $e($t) . '</td><td class="ms">' . $e($ok ? '' : $bad) . '</td></tr>';
  $rows = [
    $yes(strlen((string) (cfg()['stripe_webhook_secret'] ?? '')) > 20, 'Webhook signing secret is saved', 'Run bin-stripe-setup.php'),
    $yes(stripe_key() !== '' && !empty($acct['id']), 'Stripe key works' . (!empty($acct['id']) ? ' (' . (str_contains(stripe_key(), '_test_') ? 'TEST' : 'LIVE') . ' mode)' : ''), 'Key missing or rejected: ' . ($acct['error']['message'] ?? '')),
    $yes((bool) $mine && ($mine['status'] ?? '') === 'enabled', 'Stripe is set to send payments to this site', 'No enabled webhook for /api/stripe-webhook.php in Stripe'),
    $yes($last > $now - 30 * 86400 || $last === 0, $last ? 'Last Stripe message received ' . $ago($last) : 'No Stripe message received yet (normal before the first sale)', 'Nothing received in 30 days'),
    $yes(!empty(cfg()['account_url']), 'Customer portal link is set', 'Set account_url in config.php'),
    $yes(is_writable(data_dir()), 'Database folder is writable', 'Check permissions on hoshidub-data'),
    $yes(function_exists('mail'), 'Email sending is available (test below)', 'mail() is disabled'),
    $yes(dc_enabled(), 'Discord bot is connected (/hoshidub commands)', 'Set discord_env_file in config.php'),
  ];
  $b .= '<h2>Health check</h2>' . $table(['', 'Check', 'Problem'], $rows);
  $b .= '<h2>Send a test key email</h2><form method="post" class="row glass form">' . $hid('testmail') . '<input type="email" name="to" placeholder="your@email" required><button class="p">Send test</button><span class="ms">Sends a sample key email through the same path customers use.</span></form>';
  $b .= '<h2>Shortcuts</h2><div class="row"><a class="btn2" href="https://dashboard.stripe.com/payments" target="_blank" rel="noopener">Stripe payments</a><a class="btn2" href="https://dashboard.stripe.com/subscriptions" target="_blank" rel="noopener">Stripe subscriptions</a><a class="btn2" href="https://dashboard.stripe.com/settings/branding" target="_blank" rel="noopener">Stripe checkout branding</a><a class="btn2" href="' . $e(cfg()['account_url'] ?? '#') . '" target="_blank" rel="noopener">Customer portal login</a></div>';
  $b .= '<h2>Change admin password</h2><form method="post" class="row glass form">' . $hid('password') . '<input type="password" name="current" placeholder="Current password" required autocomplete="current-password"><input type="password" name="new" placeholder="New (12+ characters)" required minlength="12" autocomplete="new-password"><input type="password" name="again" placeholder="New again" required minlength="12" autocomplete="new-password"><button class="p">Change</button></form>';
}
page('Hoshidub admin · ' . $tabs[$tab], $b);
