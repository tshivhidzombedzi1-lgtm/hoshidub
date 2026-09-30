<?php
// Adds the finishing touches to the Hoshidub server: welcome screen, onboarding questions, AutoMod rules, join messages.
// Run after bin-discord-build.php:  HOSHIDUB_CONFIG=<home>/hoshidub-data/config.php php bin-discord-extras.php
declare(strict_types=1);
require __DIR__ . '/api/lib.php';
require __DIR__ . '/api/discord-lib.php';
$g = dc_guild();
$chs = dc_call('GET', "/guilds/$g/channels")['body']; $roles = dc_call('GET', "/guilds/$g/roles")['body'];
$c = function (string $frag) use ($chs): ?string { foreach ($chs as $x) if (str_contains($x['name'], $frag)) return $x['id']; return null; };
$role = function (string $n) use ($roles): ?string { foreach ($roles as $x) if ($x['name'] === $n) return $x['id']; return null; };
$out = fn(string $what, array $r) => print(sprintf("%-28s %s\n", $what, $r['code'] < 300 ? 'OK' : 'FAILED HTTP ' . $r['code'] . ' ' . ($r['body']['message'] ?? '')));

// 1. Welcome screen (what new visitors see first)
$out('Welcome screen', dc_call('PATCH', "/guilds/$g/welcome-screen", ['enabled' => true, 'description' => 'Watch anime in Japanese, hear it in English, live. Welcome to the official Hoshidub community!', 'welcome_channels' => [
  ['channel_id' => $c('welcome'), 'description' => 'Start here: what Hoshidub is', 'emoji_name' => '👋'],
  ['channel_id' => $c('rules'), 'description' => 'Read the rules', 'emoji_name' => '📜'],
  ['channel_id' => $c('faq'), 'description' => 'Quick answers and bot commands', 'emoji_name' => '❓'],
  ['channel_id' => $c('general'), 'description' => 'Say hi and chat', 'emoji_name' => '💬'],
  ['channel_id' => $c('support'), 'description' => 'Need help? Ask here', 'emoji_name' => '🆘'],
]]));

// 2. Join messages: a friendly line in #general, no "boost" spam
$out('Join messages', dc_call('PATCH', "/guilds/$g", ['system_channel_id' => $c('general'), 'system_channel_flags' => 2 /* no boost messages */ | 8 /* no setup tips */]));

// 3. Onboarding: two questions that route people to the right channels / the Beta Tester role
$def = array_values(array_filter([$c('welcome'), $c('rules'), $c('announcements'), $c('faq'), $c('general'), $c('anime-talk'), $c('showcase'), $c('suggestions'), $c('support')]));
$opt = fn(string $t, string $d, string $emoji, array $ch = [], array $ro = []) => ['title' => $t, 'description' => $d, 'emoji_name' => $emoji, 'channel_ids' => $ch, 'role_ids' => $ro];
$out('Onboarding questions', dc_call('PUT', "/guilds/$g/onboarding", ['enabled' => true, 'mode' => 0, 'default_channel_ids' => $def, 'prompts' => [
  ['id' => '1', 'title' => 'What brings you to Hoshidub?', 'single_select' => false, 'required' => false, 'in_onboarding' => true, 'type' => 0, 'options' => [
    $opt('I use Hoshidub and want help', 'Show me the support channels', '🆘', array_filter([$c('support'), $c('bug-reports')])),
    $opt('I want to try it', 'Show me downloads and answers', '⬇️', array_filter([$c('faq'), $c('announcements')])),
    $opt('I want to test early builds', 'Give me the Beta Tester role', '🧪', [], array_filter([$role('Beta Tester')])),
  ]],
  ['id' => '2', 'title' => 'What do you want to do here?', 'single_select' => false, 'required' => false, 'in_onboarding' => true, 'type' => 0, 'options' => [
    $opt('Share clips and screenshots', 'Show me showcase', '🎬', array_filter([$c('showcase')])),
    $opt('Suggest ideas', 'Show me suggestions and feature requests', '💡', array_filter([$c('suggestions'), $c('feature-requests')])),
    $opt('Talk anime', 'Show me anime-talk', '🎌', array_filter([$c('anime-talk')])),
  ]],
]]));

// 4. AutoMod (blocks the message, and logs it in #mod-log)
$log = $c('mod-log'); $act = [['type' => 1], ['type' => 2, 'metadata' => ['channel_id' => $log]]];
$rules = [
  ['name' => 'Block profanity, slurs and sexual content', 'event_type' => 1, 'trigger_type' => 4, 'trigger_metadata' => ['presets' => [1, 2, 3]], 'actions' => $act, 'enabled' => true],
  ['name' => 'Block spam', 'event_type' => 1, 'trigger_type' => 3, 'actions' => $act, 'enabled' => true],
  ['name' => 'Block mention spam', 'event_type' => 1, 'trigger_type' => 5, 'trigger_metadata' => ['mention_total_limit' => 6], 'actions' => [['type' => 1], ['type' => 2, 'metadata' => ['channel_id' => $log]], ['type' => 3, 'metadata' => ['duration_seconds' => 300]]], 'enabled' => true],
  ['name' => 'Block piracy and key sharing', 'event_type' => 1, 'trigger_type' => 1, 'trigger_metadata' => ['keyword_filter' => ['*keygen*', '*cracked key*', '*crack download*', '*nulled*', '*free license key*', '*HD-?????-?????-?????-?????*'], 'regex_patterns' => ['\bHD-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}\b']], 'actions' => $act, 'enabled' => true],
];
$have = array_column(dc_call('GET', "/guilds/$g/auto-moderation/rules")['body'], 'name');
foreach ($rules as $r) { if (in_array($r['name'], $have, true)) { echo sprintf("%-28s already there\n", 'AutoMod: ' . substr($r['name'], 0, 18)); continue; } $out('AutoMod: ' . substr($r['name'], 6, 20), dc_call('POST', "/guilds/$g/auto-moderation/rules", $r)); }
