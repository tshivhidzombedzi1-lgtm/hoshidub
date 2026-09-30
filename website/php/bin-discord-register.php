<?php
// One-time, run by the owner:  HOSHIDUB_CONFIG=<home>/hoshidub-data/config.php php bin-discord-register.php
// Adds (or updates) the /hoshidub command on the server WITHOUT touching the existing MCP Automation commands:
// it reads the server's current commands, swaps in /hoshidub, and writes the whole list back. Prints no secrets.
declare(strict_types=1);
require __DIR__ . '/api/lib.php';
require __DIR__ . '/api/discord-lib.php';
if (!dc_enabled()) { fwrite(STDERR, "Set 'discord_env_file' in config.php (the .env with DISCORD_BOT_TOKEN and DISCORD_GUILD_ID).\n"); exit(1); }
$app = dc_env('DISCORD_APP_ID'); $g = dc_guild();
$S = 1; $G = 2; $STR = 3; $BOOL = 5;
$opt = fn(int $t, string $n, string $d, bool $req = false, array $extra = []) => ['type' => $t, 'name' => $n, 'description' => $d, 'required' => $req] + $extra;
$hoshidub = ['name' => 'hoshidub', 'description' => 'Hoshidub: get Pro, activate your key, get help', 'options' => [
  ['type' => $S, 'name' => 'buy', 'description' => 'How to get Hoshidub Pro'],
  ['type' => $S, 'name' => 'activate', 'description' => 'Link your licence key to your Discord account and get the Pro role', 'options' => [$opt($STR, 'key', 'Your key, like HD-XXXXX-XXXXX-XXXXX-XXXXX', true, ['max_length' => 40])]],
  ['type' => $S, 'name' => 'status', 'description' => 'Show your linked licence'],
  ['type' => $S, 'name' => 'help', 'description' => 'Ask a question about Hoshidub', 'options' => [$opt($STR, 'question', 'What do you need help with?', true, ['max_length' => 200])]],
  ['type' => $S, 'name' => 'faq', 'description' => 'List common questions'],
  ['type' => $S, 'name' => 'download', 'description' => 'Get the Windows installer'],
  ['type' => $S, 'name' => 'claim', 'description' => 'Claim ownership of this server (one-time code)', 'options' => [$opt($STR, 'code', 'The claim code', true, ['max_length' => 20])]],
  ['type' => $G, 'name' => 'admin', 'description' => 'Server admin tools', 'options' => [
    ['type' => $S, 'name' => 'lookup', 'description' => 'Find a key by email, key or Discord user', 'options' => [$opt($STR, 'query', 'Email, key or user id', true)]],
    ['type' => $S, 'name' => 'grant', 'description' => 'Create a key and email it', 'options' => [$opt($STR, 'email', 'Customer email', true), $opt($STR, 'plan', 'comp (gift) or manual (paid another way)', false, ['choices' => [['name' => 'Free gift', 'value' => 'comp'], ['name' => 'Paid another way', 'value' => 'manual']]])]],
    ['type' => $S, 'name' => 'disable', 'description' => 'Switch a key off', 'options' => [$opt($STR, 'key', 'Licence key', true)]],
    ['type' => $S, 'name' => 'enable', 'description' => 'Switch a key back on', 'options' => [$opt($STR, 'key', 'Licence key', true)]],
    ['type' => $S, 'name' => 'stats', 'description' => 'Keys, revenue, downloads'],
    ['type' => $S, 'name' => 'announce', 'description' => 'Post to the Hoshidub announcements channel', 'options' => [$opt($STR, 'message', 'The announcement', true, ['max_length' => 1800]), $opt($BOOL, 'ping', 'Ping @everyone?')]],
  ]],
]];
$cur = dc_call('GET', "/applications/$app/guilds/$g/commands");
if ($cur['code'] !== 200) { fwrite(STDERR, "Could not read current commands (HTTP {$cur['code']}).\n"); exit(1); }
$keep = array_values(array_filter($cur['body'], fn($c) => $c['name'] !== 'hoshidub'));
$keep = array_map(fn($c) => array_intersect_key($c, array_flip(['name', 'description', 'options', 'default_member_permissions', 'type'])), $keep);
if (in_array('--dry', $argv, true)) { echo 'Would keep ' . count($keep) . ' existing commands and set /hoshidub.' . "\n"; exit(0); }
$r = dc_call('PUT', "/applications/$app/guilds/$g/commands", array_merge($keep, [$hoshidub]));
if ($r['code'] !== 200) { fwrite(STDERR, "Registration failed (HTTP {$r['code']}): " . json_encode($r['body']) . "\n"); exit(1); }
echo 'Registered /hoshidub next to ' . count($keep) . " existing commands.\n";
