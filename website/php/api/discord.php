<?php
// /api/discord.php: the Hoshidub slash commands. Discord talks to the MCP Automation endpoint; that endpoint forwards every
// /hoshidub command here with the original signature headers, and this file verifies the signature again before doing anything.
//   /hoshidub buy | activate key | status | help question | faq | download | claim code
//   /hoshidub admin lookup | grant | disable | enable | stats | announce     (server admins only)
declare(strict_types=1);
require __DIR__ . '/lib.php';
require __DIR__ . '/discord-lib.php';

$body = $GLOBALS['__body'] ?? (file_get_contents('php://input') ?: '');   // __body: set only by test/harness.php
if (!dc_verify($body)) { http_response_code(401); header('Content-Type: application/json'); exit('{"error":"invalid request signature"}'); }
$i = json_decode($body, true) ?: [];
if (($i['type'] ?? 0) === 1) reply(['type' => 1]);
// ticket buttons and forms (custom_id starts with hd_)
if (in_array($i['type'] ?? 0, [3, 5], true) && str_starts_with((string) ($i['data']['custom_id'] ?? ''), 'hd_')) {
  require_once __DIR__ . '/discord-tickets.php';
  if (($i['guild_id'] ?? '') !== dc_guild()) reply(['type' => 4, 'data' => ['content' => 'Use this inside the official server.', 'flags' => 64]]);
  ticket_interaction($i);
}
if (($i['type'] ?? 0) !== 2 || ($i['data']['name'] ?? '') !== 'hoshidub') reply(['error' => 'unsupported'], 400);
if (($i['guild_id'] ?? '') !== dc_guild()) say('Use this command inside the official server.');

function say(string $t, bool $private = true): never { reply(['type' => 4, 'data' => ['content' => mb_substr($t, 0, 1900), 'flags' => $private ? 64 : 0, 'allowed_mentions' => ['parse' => []]]]); }

$user = $i['member']['user'] ?? [];
$uid = (string) ($user['id'] ?? '');
$uname = (string) ($user['global_name'] ?? $user['username'] ?? 'friend');
$isAdmin = ((int) ($i['member']['permissions'] ?? 0) & 8) === 8 || in_array($uid, (array) (cfg()['discord_admin_ids'] ?? []), true);
$site = rtrim((string) (cfg()['site_url'] ?? 'https://hoshidub.com'), '/');

// flatten: sub = 'buy' or 'admin lookup'; opts = name => value
$sub = ''; $opts = []; $node = $i['data']['options'][0] ?? null;
if ($node && ($node['type'] ?? 0) === 2) { $sub = $node['name'] . ' ' . ($node['options'][0]['name'] ?? ''); $ol = $node['options'][0]['options'] ?? []; }
elseif ($node) { $sub = $node['name']; $ol = $node['options'] ?? []; } else $ol = [];
foreach ($ol as $o) $opts[$o['name']] = $o['value'] ?? null;
if (str_starts_with($sub, 'admin ') && !$isAdmin) say('That command is for server admins only.');

$pdo = db();
$mine = function () use ($pdo, $uid): array { $q = $pdo->prepare('SELECT l.*, (SELECT COUNT(*) FROM activations a WHERE a.license_key = l.license_key) pcs FROM licenses l WHERE discord_id = ? ORDER BY created_at'); $q->execute([$uid]); return $q->fetchAll(); };

switch ($sub) {
  case 'claim':   // the bot created this server and owns it; the first person with the one-time code becomes the owner
    $hash = (string) (cfg()['discord_claim_hash'] ?? '');
    if ($hash === '') say('Nothing to claim: this server already has its owner.');
    if (!password_verify(strtoupper(trim((string) ($opts['code'] ?? ''))), $hash)) say('That claim code is not right.');
    $r = dc_call('PATCH', '/guilds/' . dc_guild(), ['owner_id' => $uid]);
    if ($r['code'] >= 300) say('Discord would not transfer the server (HTTP ' . $r['code'] . '). Make sure you joined the server first.');
    $cf = getenv('HOSHIDUB_CONFIG') ?: data_dir() . '/config.php'; $t = (string) file_get_contents($cf);
    file_put_contents($cf, preg_replace("/\n  'discord_claim_hash' => '[^']*',/", '', $t), LOCK_EX);
    $own = dc_find('role', 'Owner'); if ($own) dc_call('PUT', '/guilds/' . dc_guild() . "/members/$uid/roles/{$own['id']}");
    admin_log("discord server claimed by $uname ($uid)");
    say('👑 You now own the Hoshidub server, and you have the **Owner** role. Enjoy it!');

  case 'buy':
    say("**Hoshidub Pro**\n• Monthly $6.99: $site/api/checkout.php?plan=monthly\n• Yearly $49 (best value): $site/api/checkout.php?plan=yearly\n\nAfter you pay, your licence key is emailed to you. Then use `/hoshidub activate` here to get your Pro role.\nFree plan: 30 minutes of dubbing a day, download at $site/download");

  case 'download':
    say("Download Hoshidub for Windows 10 and 11 (free, no account): $site/download");

  case 'activate':
    $key = strtoupper(trim((string) ($opts['key'] ?? '')));
    $slot = 'dcact:' . $uid . ':' . intdiv(time(), 3600);
    $n = $pdo->prepare('SELECT COUNT(*) FROM events WHERE id LIKE ?'); $n->execute([$slot . ':%']);
    if ((int) $n->fetchColumn() >= 8) say('Too many tries this hour. Please wait a bit.');
    $pdo->prepare('INSERT INTO events (id, created_at) VALUES (?, ?)')->execute([$slot . ':' . bin2hex(random_bytes(4)), time()]);
    $l = preg_match('/^[A-Z0-9-]{16,40}$/', $key) ? find_license($key) : null;
    if (!$l) say('I could not find that licence key. Check it against your email, or use the form at ' . $site . '/support.');
    if ($l['status'] !== 'active') say("That key is {$l['status']}. Renew Pro to use it: $site/pricing");
    if (!empty($l['discord_id']) && $l['discord_id'] !== $uid) say('That key is already linked to another Discord account. Contact support if this is a mistake.');
    $pdo->prepare('UPDATE licenses SET discord_id = ?, updated_at = ? WHERE license_key = ?')->execute([$uid, time(), $key]);
    admin_log("discord $uname linked $key");
    say(dc_set_pro($uid, true) ? '✅ Key linked. You now have the **Hoshidub Pro** role. Thank you for supporting Hoshidub!' : '✅ Key linked. (The Pro role is not set up on the server yet, so an admin will add it.)');

  case 'status':
    $ls = $mine();
    if (!$ls) say("No licence is linked to your Discord account yet. Use `/hoshidub activate` with the key from your email, or get Pro: $site/pricing");
    say(implode("\n", array_map(fn($l) => "`{$l['license_key']}`: **{$l['status']}** · {$l['plan']} · {$l['pcs']}/{$l['activation_limit']} PCs", $ls)));

  case 'faq':
    say("**Ask me with `/hoshidub help question:...`**\n" . implode("\n", array_map(fn($f) => '• ' . $f[0], dc_faq())) . "\n\nMore: $site/support");

  case 'help':
    $q = strtolower(trim((string) ($opts['question'] ?? ''))); $words = array_filter(preg_split('/\W+/', $q), fn($w) => strlen($w) > 2);
    $best = null; $bs = 0;
    foreach (dc_faq() as $f) { $s = 0; $hay = strtolower($f[0] . ' ' . $f[2]); foreach ($words as $w) if (str_contains($hay, $w)) $s++; if ($s > $bs) { $bs = $s; $best = $f; } }
    if (!$best) say("I do not have a ready answer for that. Try `/hoshidub faq` for the list, ask in the support channel, or read $site/support");
    say("**{$best[0]}**\n{$best[1]}\n\nMore help: $site/support");

  case 'admin lookup':
    $q = trim((string) ($opts['query'] ?? '')); if ($q === '') say('Give an email, key or Discord user.');
    $did = preg_replace('/\D/', '', $q); $st = $pdo->prepare('SELECT l.*, (SELECT COUNT(*) FROM activations a WHERE a.license_key = l.license_key) pcs FROM licenses l WHERE license_key LIKE ? OR email LIKE ? OR (discord_id = ? AND ? <> \'\') ORDER BY created_at DESC LIMIT 8');
    $st->execute(["%$q%", "%$q%", $did, $did]); $rows = $st->fetchAll();
    say($rows ? implode("\n", array_map(fn($l) => "`{$l['license_key']}` {$l['email']} · **{$l['status']}** · {$l['plan']} · {$l['pcs']}/{$l['activation_limit']} PCs" . ($l['discord_id'] ? " · <@{$l['discord_id']}>" : ''), $rows)) : 'Nothing found.');

  case 'admin grant':
    $em = strtolower(trim((string) ($opts['email'] ?? ''))); if (!filter_var($em, FILTER_VALIDATE_EMAIL)) say('That email does not look right.');
    $plan = in_array($opts['plan'] ?? '', ['manual', 'comp'], true) ? $opts['plan'] : 'comp';
    $nk = create_license($em, null, null, "granted by $uname on Discord", $plan);
    admin_log("discord $uname granted $nk to $em"); $sent = send_keys($em, [$nk]);
    say("Created `$nk` for $em ($plan)." . ($sent ? ' Emailed to them.' : ' The email failed to send, so give them the key by hand.'));

  case 'admin disable': case 'admin enable':
    $key = strtoupper(trim((string) ($opts['key'] ?? ''))); $l = find_license($key); if (!$l) say('No such key.');
    $to = $sub === 'admin disable' ? 'disabled' : 'active';
    $pdo->prepare('UPDATE licenses SET status = ?, updated_at = ? WHERE license_key = ?')->execute([$to, time(), $key]); admin_log("discord $uname set $key $to"); dc_sync_key($key);
    say("`$key` is now **$to**.");

  case 'admin stats':
    $c = fn(string $s, array $p = []) => (function () use ($pdo, $s, $p) { $q = $pdo->prepare($s); $q->execute($p); return (int) $q->fetchColumn(); })();
    $mo = $c("SELECT COUNT(*) FROM licenses WHERE status='active' AND plan='monthly'"); $yr = $c("SELECT COUNT(*) FROM licenses WHERE status='active' AND plan='yearly'");
    say('**Hoshidub**' . "\nActive keys: " . $c("SELECT COUNT(*) FROM licenses WHERE status='active'") . " ($mo monthly, $yr yearly)\nEst. monthly revenue: $" . number_format($mo * 6.99 + $yr * 49 / 12, 2)
      . "\nNew keys (7 days): " . $c('SELECT COUNT(*) FROM licenses WHERE created_at > ?', [time() - 604800]) . "\nDownloads (7 days): " . $c('SELECT COUNT(*) FROM downloads WHERE at > ?', [time() - 604800])
      . "\nPCs activated: " . $c('SELECT COUNT(*) FROM activations') . "\nOpen tickets: " . $c('SELECT COUNT(*) FROM tickets WHERE closed_at IS NULL') . "\nFull dashboard: $site/admin");

  case 'admin announce':
    $ch = null; foreach (dc_call('GET', '/guilds/' . dc_guild() . '/channels')['body'] as $x) if (str_contains($x['name'] ?? '', 'announcements')) $ch = $x; if (!$ch) say('There is no announcements channel.');
    $m = dc_call('POST', "/channels/{$ch['id']}/messages", ['content' => mb_substr((string) ($opts['message'] ?? ''), 0, 1900), 'allowed_mentions' => ['parse' => !empty($opts['ping']) ? ['everyone'] : []]]);
    say($m['code'] < 300 ? 'Posted in <#' . $ch['id'] . '>.' : 'Discord refused the post (check the bot can write there).');

  default:
    say("Try `/hoshidub buy`, `activate`, `status`, `help`, `faq` or `download`.");
}
