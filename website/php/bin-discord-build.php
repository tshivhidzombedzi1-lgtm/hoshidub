<?php
// One-time, run by the owner (or an agent he told to):  HOSHIDUB_CONFIG=<home>/hoshidub-data/config.php php bin-discord-build.php
// You create an EMPTY Hoshidub server in Discord and invite the bot (permissions=8); the bot then builds all of it: roles, categories,
// channels with topics and permissions, rules, welcome, FAQ and announcement posts, icon, Community features and an invite.
// Refuses to run on a server that has members. Prints no secrets.
declare(strict_types=1);
require __DIR__ . '/api/lib.php';
require __DIR__ . '/api/discord-lib.php';
if (!dc_enabled()) { fwrite(STDERR, "Set 'discord_env_file' in config.php first.\n"); exit(1); }
$cfgFile = getenv('HOSHIDUB_CONFIG') ?: data_dir() . '/config.php';
$site = rtrim((string) (cfg()['site_url'] ?? 'https://hoshidub.com'), '/');
$oldGuild = dc_guild();
$app = dc_env('DISCORD_APP_ID');
$fail = function (string $m): never { fwrite(STDERR, "$m\n"); exit(1); };

// ---- 1. the server: you create an empty one and invite the bot with Administrator; Discord does not let bots create servers ----
$gid = preg_replace("/\\D/", "", (string) ($argv[1] ?? ""));
if ($gid === "") $fail("Usage: php bin-discord-build.php <server id of a NEW, empty Hoshidub server the bot has been invited to>");
$info = dc_call("GET", "/guilds/$gid?with_counts=true");
if ($info["code"] !== 200) $fail("The bot is not in that server (HTTP " . $info["code"] . "). Invite it first with permissions=8.");
if ((int) ($info["body"]["approximate_member_count"] ?? 99) > 3 && !in_array("--force", $argv, true)) $fail("That server has members. This script wipes a server\x27s channels, so it only runs on a brand-new one.");
foreach (dc_call("GET", "/guilds/$gid/roles")["body"] as $r) if (stripos($r["name"], "hoshidub") !== false || in_array($r["name"], ["Owner", "Moderator", "Beta Tester"], true)) $fail("This server already has Hoshidub roles. Use a fresh server.");
echo "1. Building in \"" . ($info["body"]["name"] ?? "?") . "\" ($gid)\n";
$icon = is_readable(dirname(__DIR__, 2) . "/brand/icon-512.png") ? "data:image/png;base64," . base64_encode((string) file_get_contents(dirname(__DIR__, 2) . "/brand/icon-512.png")) : null;
dc_call("PATCH", "/guilds/$gid", array_filter(["name" => "Hoshidub", "icon" => $icon, "verification_level" => 1, "default_message_notifications" => 1, "explicit_content_filter" => 2]));
foreach (dc_call("GET", "/guilds/$gid/channels")["body"] as $c) dc_call("DELETE", "/channels/" . $c["id"]);   // the empty starter channels Discord adds
// ---- 2. roles (lowest first: each new role lands at the bottom) ----
$P = ['view' => 1024, 'send' => 2048, 'react' => 64, 'hist' => 65536, 'connect' => 1048576, 'speak' => 2097152];
$member = $P['view'] | $P['send'] | $P['react'] | $P['hist'] | $P['connect'] | $P['speak'] | 32768 /*attach*/ | 16384 /*embed*/ | 262144 /*ext emoji*/ | 8388608 /*voice activity*/ | 1073741824 /*app cmds*/ | 8589934592 /*threads*/;
dc_call('PATCH', "/guilds/$gid/roles/$gid", ['permissions' => (string) $member]);   // @everyone: chat like a normal member
$mk = function (string $name, int $color, string $perms, bool $hoist) use ($gid): string { $r = dc_call('POST', "/guilds/$gid/roles", ['name' => $name, 'color' => $color, 'permissions' => $perms, 'hoist' => $hoist, 'mentionable' => true]); return (string) ($r['body']['id'] ?? ''); };
$mod = (string) (8192 | 2 | 4 | 1099511627776 | 134217728 /*nicknames*/ | 16777216 /*move*/ | 4194304 /*mute*/);
$role = [
  'beta' => $mk('Beta Tester', 0x2DD4BF, (string) $member, true),
  'pro' => $mk(DC_PRO_ROLE, 0xC38BFF, (string) $member, true),
  'mod' => $mk('Moderator', 0x6BA8FF, (string) ((int) $member | (int) $mod), true),
  'team' => $mk('Hoshidub Team', 0xFF6B9D, (string) ((int) $member | (int) $mod | 16 | 268435456 | 32 | 8388608), true),
  'owner' => $mk('Owner', 0xFFD166, '8', true),
];
echo '2. Roles: ' . implode(', ', array_keys($role)) . "\n";

// ---- 3. categories and channels ----
$deny = fn(int $bit, string $id) => ['id' => $id, 'type' => 0, 'allow' => '0', 'deny' => (string) $bit];
$allow = fn(int $bit, string $id) => ['id' => $id, 'type' => 0, 'allow' => (string) $bit, 'deny' => '0'];
$readOnly = [['id' => $gid, 'type' => 0, 'allow' => '0', 'deny' => '2048'], $allow(2048, $role['team']), $allow(2048, $role['owner'])];
$priv = fn(array $roles) => array_merge([['id' => $gid, 'type' => 0, 'allow' => '0', 'deny' => '1024']], array_map(fn($r) => ['id' => $r, 'type' => 0, 'allow' => '1024', 'deny' => '0'], $roles));
$cat = function (string $name, array $ow = []) use ($gid): string { $r = dc_call('POST', "/guilds/$gid/channels", ['type' => 4, 'name' => $name, 'permission_overwrites' => $ow]); return (string) ($r['body']['id'] ?? ''); };
$ch = function (string $name, string $topic, string $parent, array $ow = [], int $type = 0) use ($gid): string {
  $r = dc_call('POST', "/guilds/$gid/channels", ['type' => $type, 'name' => $name, 'parent_id' => $parent] + ($type === 0 ? ['topic' => $topic] : []) + ($ow ? ['permission_overwrites' => $ow] : []));
  return (string) ($r['body']['id'] ?? ''); };

$c1 = $cat('📌 START HERE');
$welcome = $ch('👋┃welcome', 'Start here: what Hoshidub is and where everything lives.', $c1, $readOnly);
$rules = $ch('📜┃rules', 'Server rules. Read them before you chat.', $c1, $readOnly);
$ann = $ch('📢┃announcements', 'Releases, news and Hoshidub updates.', $c1, $readOnly);
$faq = $ch('❓┃faq', 'Quick answers and the bot commands. Or ask /hoshidub help.', $c1, $readOnly);
$c2 = $cat('💬 COMMUNITY');
$general = $ch('💬┃general', 'Hang out. Anime, the dub, anything friendly.', $c2);
$talk = $ch('🎌┃anime-talk', 'What are you watching? Use spoiler tags (||like this||).', $c2);
$show = $ch('🎬┃showcase', 'Share clips, screenshots and your best dub moments.', $c2);
$sugg = $ch('💡┃suggestions', 'Ideas for voices, shows and features.', $c2);
$c3 = $cat('🛠 HELP');
$support = $ch('🆘┃support', 'Something not working? Ask here, or try /hoshidub help first.', $c3);
$bugs = $ch('🐞┃bug-reports', 'Found a bug? Post your Windows version, graphics card and what happened.', $c3);
$feat = $ch('✨┃feature-requests', 'Tell us what Hoshidub should do next.', $c3);
$c4 = $cat('⭐ PRO', $priv([$role['pro'], $role['team'], $role['owner']]));
$lounge = $ch('⭐┃pro-lounge', 'Pro members only. Direct line to the team.', $c4);
$early = $ch('🧪┃early-builds', 'Early builds and test versions for Pro and Beta testers.', $c4, $priv([$role['pro'], $role['beta'], $role['team'], $role['owner']]));
$c5 = $cat('🔊 VOICE');
$ch('🍿 Watch Party', '', $c5, [], 2); $ch('☕ Hangout', '', $c5, [], 2);
$c6 = $cat('🔒 TEAM', $priv([$role['team'], $role['mod'], $role['owner']]));
$ch('🔒┃team-chat', 'Team only.', $c6); $ch('📋┃mod-log', 'Moderation notes and bot logs.', $c6);
echo "3. Categories and channels built\n";

// ---- 4. posts ----
$brand = 0xC38BFF;
$post = function (string $channel, array $embed, bool $pin = true) use ($brand): void {
  $m = dc_call('POST', "/channels/$channel/messages", ['embeds' => [$embed + ['color' => $brand]]]);
  if ($pin && !empty($m['body']['id'])) dc_call('PUT', "/channels/$channel/pins/{$m['body']['id']}"); };
$post($welcome, ['title' => 'Welcome to Hoshidub 🌸', 'description' => "**Don't read it. Dub it.**\nHoshidub is a Windows anime browser: you watch in Japanese and every character speaks English in their own voice, live, with the soundtrack at full volume. **Hoshi**, your anime watch buddy, watches along and never spoils.",
  'fields' => [
    ['name' => 'Get started', 'value' => "• Download (free): $site/download\n• Go Pro: type `/hoshidub buy`, then `/hoshidub activate` to get your **Hoshidub Pro** role", 'inline' => false],
    ['name' => 'Where to go', 'value' => "<#$rules> read the rules\n<#$faq> quick answers\n<#$general> say hi\n<#$support> need help\n<#$show> show your clips", 'inline' => false],
  ], 'footer' => ['text' => 'Hoshidub · a product of MCP Labs']]);
$post($rules, ['title' => 'Server rules 📜', 'description' =>
  "**1. Be kind.** No harassment, hate speech or slurs.\n**2. No piracy.** Don't share pirated anime, cracked keys or ways around paywalls or DRM. Hoshidub works with services you pay for.\n**3. Guard your key.** Never post your licence key. Staff will never ask for it in DMs.\n**4. Spoilers.** Use spoiler tags (`||text||`). Hoshi never spoils, and neither should you.\n**5. Right channel.** Help in support, bugs in bug-reports (add your Windows version and graphics card).\n**6. No spam.** No ads, self-promo or invite links without permission.\n**7. English in the main channels.** Other languages are welcome in threads.\n**8. Follow Discord's Terms and staff decisions.**\n\nBreaking the rules can mean a timeout, kick or ban.", 'footer' => ['text' => 'By staying here you agree to the rules.']]);
$post($faq, ['title' => 'Quick answers ❓', 'description' => "**Does it work with Crunchyroll?** Yes: open it inside Hoshidub and sign in with your own account.\n**Is it legal?** It plays the service you already pay for and never records, saves or decrypts video.\n**Do I need a strong PC?** An NVIDIA RTX card with 6 GB or more is recommended.\n**Dub is late?** Turn on the show's English subtitles in the player for zero delay.\n**Where's my key?** Emailed right after you pay. Lost it? $site/support\n**Move Pro to a new PC?** Settings → Upgrade → Deactivate on the old PC, then paste the key on the new one.",
  'fields' => [['name' => 'Bot commands', 'value' => "`/hoshidub buy` get Pro\n`/hoshidub activate` link your key and get the role\n`/hoshidub status` your licence\n`/hoshidub help` ask a question\n`/hoshidub download` the installer", 'inline' => false]]]);
$post($ann, ['title' => 'Hoshidub is live 🎉', 'description' => "The Windows app is ready to download: $site/download\nFree for 30 minutes of dubbing a day. Pro is unlimited: `/hoshidub buy`.", 'footer' => ['text' => 'Releases and news will land here.']], false);
echo "4. Welcome, rules, FAQ and announcement posts published and pinned\n";

// ---- 5. Community features, description, welcome messages ----
$upd = dc_call('PATCH', "/guilds/$gid", ['rules_channel_id' => $rules, 'public_updates_channel_id' => $ann, 'system_channel_id' => $general, 'preferred_locale' => 'en-US',
  'features' => ['COMMUNITY'], 'description' => 'Watch anime in Japanese, hear it in English, live. The official Hoshidub community: help, updates and Pro.', 'verification_level' => 1, 'explicit_content_filter' => 2, 'default_message_notifications' => 1]);
echo '5. Community features: ' . ($upd['code'] < 300 ? 'on' : 'NOT enabled (HTTP ' . $upd['code'] . ', ' . ($upd['body']['message'] ?? '?') . ')') . "\n";

// ---- 6. invite and config ----
$inv = dc_call('POST', "/channels/$welcome/invites", ['max_age' => 0, 'max_uses' => 0, 'unique' => true])['body']['code'] ?? '';
$txt = (string) file_get_contents($cfgFile);
$txt = preg_replace("/\n  'discord_(guild_id|claim_hash|invite)' => '[^']*',/", '', $txt);
$new = preg_replace("/\n\];\s*$/", "\n  'discord_guild_id' => '$gid',\n  'discord_invite' => '$inv',\n];\n", $txt, 1, $n);
if (!$n) $fail('Could not save config.php');
file_put_contents($cfgFile, $new, LOCK_EX);
echo "6. Saved the server id. Invite: https://discord.gg/$inv\n";

// ---- 7. read it all back ----
$chs = dc_call('GET', "/guilds/$gid/channels")['body']; $rl = dc_call('GET', "/guilds/$gid/roles")['body'];
echo '7. Check: ' . count(array_filter($chs, fn($c) => $c['type'] === 4)) . ' categories, ' . count(array_filter($chs, fn($c) => $c['type'] === 0)) . ' text channels, ' . count(array_filter($chs, fn($c) => $c['type'] === 2)) . ' voice channels, ' . count($rl) . " roles\n";
