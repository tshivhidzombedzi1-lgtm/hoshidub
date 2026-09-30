<?php
// Ticket system for the Hoshidub Discord: a button opens a form, the form makes a private channel, a close button saves a transcript
// to #mod-log and deletes the channel. Handles component (type 3) and modal (type 5) interactions whose custom_id starts with "hd_".
declare(strict_types=1);

const TICKET_CATEGORY = '🎫 TICKETS';

function tk_role(string $name): ?string { $r = dc_find('role', $name); return $r['id'] ?? null; }
function tk_chan_like(string $frag): ?array { foreach (dc_call('GET', '/guilds/' . dc_guild() . '/channels')['body'] as $c) if (str_contains($c['name'] ?? '', $frag)) return $c; return null; }
function tk_reply(string $text, bool $private = true): never { reply(['type' => 4, 'data' => ['content' => mb_substr($text, 0, 1900), 'flags' => $private ? 64 : 0, 'allowed_mentions' => ['parse' => []]]]); }

// upload a text file to a channel (multipart)
function tk_upload(string $channelId, string $filename, string $content, string $message): void {
  $boundary = bin2hex(random_bytes(8));
  $body = "--$boundary\r\nContent-Disposition: form-data; name=\"payload_json\"\r\nContent-Type: application/json\r\n\r\n" . json_encode(['content' => $message, 'allowed_mentions' => ['parse' => []]])
    . "\r\n--$boundary\r\nContent-Disposition: form-data; name=\"files[0]\"; filename=\"$filename\"\r\nContent-Type: text/plain\r\n\r\n$content\r\n--$boundary--\r\n";
  $ch = curl_init('https://discord.com/api/v10/channels/' . $channelId . '/messages');
  curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_POST => true, CURLOPT_POSTFIELDS => $body, CURLOPT_TIMEOUT => 20,
    CURLOPT_HTTPHEADER => ['Authorization: Bot ' . dc_env('DISCORD_BOT_TOKEN'), 'Content-Type: multipart/form-data; boundary=' . $boundary]]);
  curl_exec($ch);
}

function ticket_interaction(array $i): never {
  $type = (int) ($i['type'] ?? 0); $cid = (string) ($i['data']['custom_id'] ?? '');
  $user = $i['member']['user'] ?? []; $uid = (string) ($user['id'] ?? ''); $uname = (string) ($user['global_name'] ?? $user['username'] ?? 'member');
  $g = dc_guild(); $pdo = db();

  // 1. button "Open a ticket" -> a short form
  if ($type === 3 && $cid === 'hd_ticket_open') {
    $q = $pdo->prepare('SELECT channel_id FROM tickets WHERE user_id = ? AND closed_at IS NULL'); $q->execute([$uid]); $open = $q->fetchColumn();
    if ($open) tk_reply("You already have an open ticket: <#$open>. Please use that one, or close it first.");
    reply(['type' => 9, 'data' => ['custom_id' => 'hd_ticket_form', 'title' => 'Open a ticket', 'components' => [
      ['type' => 1, 'components' => [['type' => 4, 'custom_id' => 'topic', 'label' => 'What do you need help with?', 'style' => 1, 'min_length' => 3, 'max_length' => 100, 'required' => true, 'placeholder' => 'For example: my key will not activate']]],
      ['type' => 1, 'components' => [['type' => 4, 'custom_id' => 'details', 'label' => 'Tell us more (optional)', 'style' => 2, 'max_length' => 1000, 'required' => false, 'placeholder' => 'Windows version, graphics card, what you tried. Never paste your licence key.']]],
    ]]]);
  }

  // 2. the form is sent -> a private channel
  if ($type === 5 && $cid === 'hd_ticket_form') {
    $vals = []; foreach ($i['data']['components'] ?? [] as $row) foreach ($row['components'] ?? [] as $c) $vals[$c['custom_id']] = (string) ($c['value'] ?? '');
    $topic = trim($vals['topic'] ?? '') ?: 'Help'; $details = trim($vals['details'] ?? '');
    $q = $pdo->prepare('SELECT channel_id FROM tickets WHERE user_id = ? AND closed_at IS NULL'); $q->execute([$uid]); if ($open = $q->fetchColumn()) tk_reply("You already have an open ticket: <#$open>.");
    $cat = dc_find('channel', TICKET_CATEGORY); $team = tk_role('Hoshidub Team'); $mod = tk_role('Moderator');
    $n = (int) $pdo->query('SELECT COALESCE(MAX(id), 0) + 1 FROM tickets')->fetchColumn();
    $staff = 1024 | 2048 | 65536 | 32768 | 16384 | 8192;
    $ow = [['id' => $g, 'type' => 0, 'allow' => '0', 'deny' => '1024'], ['id' => $uid, 'type' => 1, 'allow' => (string) (1024 | 2048 | 65536 | 32768 | 16384), 'deny' => '0']];
    foreach ([$team, $mod] as $r) if ($r) $ow[] = ['id' => $r, 'type' => 0, 'allow' => (string) $staff, 'deny' => '0'];
    $c = dc_call('POST', "/guilds/$g/channels", ['name' => sprintf('ticket-%04d', $n), 'type' => 0, 'parent_id' => $cat['id'] ?? null, 'topic' => "ticket:$uid · $topic", 'permission_overwrites' => $ow]);
    if (empty($c['body']['id'])) tk_reply('I could not make your ticket channel. Please ask in the support channel instead.');
    $ch = $c['body']['id'];
    $pdo->prepare('INSERT INTO tickets (id, channel_id, user_id, topic, created_at) VALUES (?, ?, ?, ?, ?)')->execute([$n, $ch, $uid, mb_substr($topic, 0, 120), time()]);
    dc_call('POST', "/channels/$ch/messages", ['content' => "<@$uid>" . ($team ? " <@&$team>" : ''), 'allowed_mentions' => ['users' => [$uid], 'roles' => $team ? [$team] : []],
      'embeds' => [['title' => "Ticket #$n: " . mb_substr($topic, 0, 80), 'color' => 0xC38BFF, 'description' => ($details !== '' ? "**Details**\n" . mb_substr($details, 0, 1000) . "\n\n" : '') . "Thanks, $uname. The team will reply here as soon as they can.\nPlease **don't share your licence key** in this channel.\nPress the button below when you're done."]],
      'components' => [['type' => 1, 'components' => [['type' => 2, 'style' => 4, 'label' => 'Close ticket', 'emoji' => ['name' => '🔒'], 'custom_id' => 'hd_ticket_close']]]]]);
    admin_log("ticket #$n opened by $uname: $topic");
    tk_reply("🎫 Your ticket is ready: <#$ch>");
  }

  // 3. close button -> transcript to #mod-log, then the channel goes
  if ($type === 3 && $cid === 'hd_ticket_close') {
    $chId = (string) ($i['channel_id'] ?? '');
    $q = $pdo->prepare('SELECT * FROM tickets WHERE channel_id = ? AND closed_at IS NULL'); $q->execute([$chId]); $t = $q->fetch();
    if (!$t) tk_reply('This is not an open ticket.');
    $isStaff = ((int) ($i['member']['permissions'] ?? 0) & 8192) === 8192;
    if (!$isStaff && $t['user_id'] !== $uid) tk_reply('Only the ticket owner or the team can close this ticket.');
    dc_defer();
    $msgs = array_reverse(dc_call('GET', "/channels/$chId/messages?limit=100")['body']);
    $lines = ["Ticket #{$t['id']}: {$t['topic']}", 'Opened ' . date('Y-m-d H:i', (int) $t['created_at']) . ' UTC, closed by ' . $uname . ' ' . date('Y-m-d H:i') . ' UTC', str_repeat('-', 40)];
    foreach ($msgs as $m) { $text = trim((string) ($m['content'] ?? '')) ?: implode(' / ', array_filter(array_map(fn($e) => ($e['title'] ?? '') . ' ' . ($e['description'] ?? ''), $m['embeds'] ?? []))); $lines[] = date('H:i', strtotime((string) $m['timestamp'])) . ' ' . ($m['author']['global_name'] ?? $m['author']['username'] ?? '?') . ': ' . $text; }
    $pdo->prepare('UPDATE tickets SET closed_at = ? WHERE id = ?')->execute([time(), $t['id']]);
    $log = tk_chan_like('mod-log'); if ($log) tk_upload($log['id'], "ticket-{$t['id']}.txt", implode("\n", $lines), "🎫 Ticket #{$t['id']} closed by $uname (opened by <@{$t['user_id']}>)");
    admin_log("ticket #{$t['id']} closed by $uname");
    dc_call('DELETE', "/channels/$chId");
    exit;
  }
  tk_reply('That button is not active any more.');
}
