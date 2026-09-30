<?php
// Adds the ticket system to the Hoshidub server: a private 🎫 TICKETS category (one channel per ticket) and an "open a ticket" panel with a button.
// Safe to run again: it reuses what exists.  HOSHIDUB_CONFIG=<home>/hoshidub-data/config.php php bin-discord-tickets.php
declare(strict_types=1);
require __DIR__ . '/api/lib.php';
require __DIR__ . '/api/discord-lib.php';
require __DIR__ . '/api/discord-tickets.php';
$g = dc_guild(); $team = tk_role('Hoshidub Team'); $mod = tk_role('Moderator'); $owner = tk_role('Owner');
$view = fn(string $id) => ['id' => $id, 'type' => 0, 'allow' => (string) (1024 | 2048 | 65536 | 8192), 'deny' => '0'];
$cat = dc_find('channel', TICKET_CATEGORY);
if (!$cat) {
  $ow = [['id' => $g, 'type' => 0, 'allow' => '0', 'deny' => '1024']]; foreach ([$team, $mod, $owner] as $r) if ($r) $ow[] = $view($r);
  $cat = dc_call('POST', "/guilds/$g/channels", ['type' => 4, 'name' => TICKET_CATEGORY, 'permission_overwrites' => $ow])['body'];
  echo "category: created\n";
} else echo "category: already there\n";
$help = null; foreach (dc_call('GET', "/guilds/$g/channels")['body'] as $c) if ($c['type'] === 4 && str_contains($c['name'], 'HELP')) $help = $c;
$panel = tk_chan_like('open-a-ticket');
if (!$panel) {
  $panel = dc_call('POST', "/guilds/$g/channels", ['type' => 0, 'name' => '🎫┃open-a-ticket', 'parent_id' => $help['id'] ?? null, 'topic' => 'Need private help? Press the button to open a ticket with the team.',
    'permission_overwrites' => [['id' => $g, 'type' => 0, 'allow' => '0', 'deny' => '2048']]])['body'];
  echo "panel channel: created\n";
} else echo "panel channel: already there\n";
$has = false; foreach (dc_call('GET', "/channels/{$panel['id']}/messages?limit=20")['body'] as $m) if (!empty($m['components'])) $has = true;
if (!$has) {
  $m = dc_call('POST', "/channels/{$panel['id']}/messages", ['embeds' => [['title' => 'Need help? Open a ticket 🎫', 'color' => 0xC38BFF,
    'description' => "Press the button, tell us what's wrong, and the team will help you in a private channel.\n\n**Before you open one:** try `/hoshidub help` or the <#" . (tk_chan_like('faq')['id'] ?? '') . "> for a quick answer.\n**Never share your licence key** in a ticket."]],
    'components' => [['type' => 1, 'components' => [['type' => 2, 'style' => 1, 'label' => 'Open a ticket', 'emoji' => ['name' => '🎫'], 'custom_id' => 'hd_ticket_open']]]]]);
  if (!empty($m['body']['id'])) dc_call('PUT', "/channels/{$panel['id']}/pins/{$m['body']['id']}");
  echo 'panel post: ' . (!empty($m['body']['id']) ? 'published and pinned' : 'FAILED ' . json_encode($m['body'])) . "\n";
} else echo "panel post: already there\n";
