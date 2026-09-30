<?php
// Discord helpers for the Hoshidub bot. It runs on the existing MCP Automation bot: its interactions endpoint forwards /hoshidub commands here.
// Secrets (bot token, public key) are read at run time from the private .env named in config 'discord_env_file'; never copied.
declare(strict_types=1);

const DC_PRO_ROLE = 'Hoshidub Pro';
const DC_CATEGORY = 'HOSHIDUB';

function dc_env(string $key): string {
  static $env = null;
  if ($env === null) {
    $env = [];
    $f = cfg()['discord_env_file'] ?? '';
    if ($f && is_readable($f)) foreach (file($f, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
      if ($line[0] !== '#' && str_contains($line, '=')) { [$k, $v] = explode('=', $line, 2); $env[trim($k)] = trim($v, " \t\"'"); }
    }
  }
  return $env[$key] ?? '';
}

// which server the Hoshidub commands live in: config.php discord_guild_id (the Hoshidub server) else the MCP Automation server
function dc_guild(): string { return (string) (cfg()['discord_guild_id'] ?? '') ?: dc_env('DISCORD_GUILD_ID'); }
function dc_enabled(): bool { return dc_env('DISCORD_BOT_TOKEN') !== '' && dc_guild() !== ''; }

function dc_call(string $method, string $path, ?array $json = null): array {
  $ch = curl_init('https://discord.com/api/v10' . $path);
  curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_CUSTOMREQUEST => $method, CURLOPT_TIMEOUT => 20,
    CURLOPT_HTTPHEADER => ['Authorization: Bot ' . dc_env('DISCORD_BOT_TOKEN'), 'Content-Type: application/json', 'User-Agent: HoshidubBot (https://hoshidub.com, 1.0)']]);
  if ($json !== null) curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($json, JSON_UNESCAPED_SLASHES));
  $raw = curl_exec($ch); $code = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
  if ($code >= 400) error_log("hoshidub discord $method $path $code " . mb_substr((string) $raw, 0, 300));
  $body = json_decode((string) $raw, true);
  return ['code' => $code, 'body' => is_array($body) ? $body : []];
}

function dc_verify(string $body): bool {
  // 1) the MCP Automation endpoint (which already checked Discord's signature) forwards with an HMAC made from a shared secret in config.php
  $fs = (string) (cfg()['discord_forward_secret'] ?? ''); $fts = $_SERVER['HTTP_X_HOSHIDUB_TS'] ?? ''; $fsig = $_SERVER['HTTP_X_HOSHIDUB_SIG'] ?? '';
  if ($fsig !== '') return $fs !== '' && ctype_digit($fts) && abs(time() - (int) $fts) <= 60 && hash_equals(hash_hmac('sha256', $fts . '.' . $body, $fs), $fsig);
  // 2) or Discord's own Ed25519 signature, when this PHP has libsodium
  $pk = dc_env('DISCORD_PUBLIC_KEY'); $sig = $_SERVER['HTTP_X_SIGNATURE_ED25519'] ?? ''; $ts = $_SERVER['HTTP_X_SIGNATURE_TIMESTAMP'] ?? '';
  if ($pk === '' || $sig === '' || !ctype_digit($ts) || abs(time() - (int) $ts) > 300 || !function_exists('sodium_crypto_sign_verify_detached')) return false;
  try { $s = hex2bin($sig); $k = hex2bin($pk); return $s !== false && $k !== false && sodium_crypto_sign_verify_detached($s, $ts . $body, $k); } catch (Throwable) { return false; }
}
function dc_find(string $kind, string $name): ?array {
  $g = dc_guild();
  foreach (dc_call('GET', "/guilds/$g/" . ($kind === 'role' ? 'roles' : 'channels'))['body'] as $x) if (($x['name'] ?? '') === $name) return $x;
  return null;
}

// Give or take the Hoshidub Pro role. Quiet when Discord is not configured or the role does not exist yet.
function dc_set_pro(string $discordId, bool $on): bool {
  if (!dc_enabled() || !preg_match('/^\d{17,20}$/', $discordId)) return false;
  $role = dc_find('role', DC_PRO_ROLE);
  if (!$role) return false;
  $r = dc_call($on ? 'PUT' : 'DELETE', '/guilds/' . dc_guild() . "/members/$discordId/roles/{$role['id']}");
  return $r['code'] >= 200 && $r['code'] < 300;
}

// Call after a key's status changes: keeps the linked member's role in step (Pro only while any of their keys is active).
function dc_sync_key(string $key): void {
  try {
    $l = find_license($key);
    if (!$l || empty($l['discord_id'])) return;
    $q = db()->prepare("SELECT COUNT(*) FROM licenses WHERE discord_id = ? AND status = 'active'"); $q->execute([$l['discord_id']]);
    dc_set_pro((string) $l['discord_id'], (int) $q->fetchColumn() > 0);
  } catch (Throwable $e) { error_log('hoshidub dc_sync_key: ' . $e->getMessage()); }
}

function dc_defer(): void {
  $p = json_encode(['type' => 5, 'data' => ['flags' => 64]]);
  http_response_code(200); header('Content-Type: application/json'); header('Content-Length: ' . strlen($p)); header('Connection: close'); echo $p;
  ignore_user_abort(true);
  if (function_exists('fastcgi_finish_request')) fastcgi_finish_request(); elseif (function_exists('litespeed_finish_request')) litespeed_finish_request(); else { @ob_end_flush(); @flush(); }
}

function dc_edit_reply(string $appId, string $token, string $text): void {
  $ch = curl_init('https://discord.com/api/v10/webhooks/' . rawurlencode($appId) . '/' . rawurlencode($token) . '/messages/@original');
  curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_CUSTOMREQUEST => 'PATCH', CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
    CURLOPT_POSTFIELDS => json_encode(['content' => mb_substr($text, 0, 1900)]), CURLOPT_TIMEOUT => 20]);
  curl_exec($ch);
}

// ---- help answers (same words as the website FAQ and help page) ----
function dc_faq(): array {
  return [
    ['Does it work with Crunchyroll?', 'Yes. Open it inside Hoshidub and sign in with your own account. Hoshidub uses the show’s official English subtitles when they are available.', 'crunchyroll streaming service works'],
    ['Is it legal?', 'Hoshidub plays the service you already pay for, in its normal player, and listens to the sound like a person in the room. It never records, saves or decrypts video.', 'legal drm record copy'],
    ['How is it zero delay?', 'When a show has official subtitles, Hoshidub reads them ahead of time and prepares each line before it is spoken. Turn on the show’s English subtitles in the player. Without subtitles it translates by ear, about a second behind.', 'delay late lag sync subtitles'],
    ['Do I need a powerful PC?', 'An NVIDIA RTX graphics card with 6 GB or more is recommended. A cloud version for any laptop is planned for 2027.', 'pc gpu graphics nvidia rtx requirements laptop'],
    ['Does Hoshi spoil episodes?', 'Never. She only knows what has already happened in the episode, and every reply is checked against what is coming.', 'hoshi spoil spoilers'],
    ['Is my data sent anywhere?', 'No. Dubbing, Hoshi and her memory all run on your PC. There is no account and no tracking in the app.', 'data privacy tracking account'],
    ['Which languages?', 'English now. Spanish, Portuguese, Hindi and French are next.', 'language languages spanish french hindi portuguese'],
    ['Can I cancel Pro?', 'Any time, from the customer portal link in your Stripe receipt. You keep Pro until the end of the period you paid for.', 'cancel refund subscription billing stop'],
    ['The video will not play', 'Update Hoshidub to the latest version. Streaming services need the protected-video module that ships with the official installer, so builds from other places will not play.', 'video play error kat playback black'],
    ['I pressed Dub but hear nothing', 'Make sure the episode is playing and the voices finished downloading (Settings shows the status). If the show has no speech for a while, Hoshidub waits quietly.', 'dub nothing hear sound silent audio'],
    ['A site looks broken', 'Click the shield in the toolbar to turn off the ad blocker for that site.', 'site broken blocker shield ads'],
    ['Where is my licence key?', 'We email it right after you pay. Lost it? Use the form on hoshidub.com/support and we will send it again.', 'key licence license lost email resend'],
    ['How do I move Pro to a new PC?', 'On the old PC open Settings, Upgrade, and choose Deactivate. Then paste your key on the new PC. A key works on 2 PCs.', 'move new pc deactivate transfer activate'],
  ];
}
