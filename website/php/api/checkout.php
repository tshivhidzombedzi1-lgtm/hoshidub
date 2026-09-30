<?php
// GET /api/checkout.php?plan=monthly|yearly  -> Stripe Checkout (subscription), then back to /download?paid=1
// GET /api/checkout.php?plan=tip&amount=5    -> one-time tip of $1..$500 (no licence key is made for tips)
declare(strict_types=1);
require __DIR__ . '/lib.php';

function bounce(string $why): never { header('Location: /pricing?checkout=' . $why . '#pricing', true, 303); exit; }

$plan = (string) ($_GET['plan'] ?? '');
$site = rtrim((string) (cfg()['site_url'] ?? 'https://hoshidub.com'), '/');
$logo = $site . '/img/icon-512.png';
$p = ['success_url' => $site . '/download?paid=1', 'cancel_url' => $site . '/pricing', 'allow_promotion_codes' => 'true', 'billing_address_collection' => 'auto', 'locale' => 'auto',
  'line_items[0][price_data][product_data][images][0]' => $logo];

if (isset(PLANS[$plan])) {
  $pl = PLANS[$plan];
  $p += ['mode' => 'subscription', 'metadata[plan]' => $plan, 'subscription_data[metadata][plan]' => $plan,
    'line_items[0][quantity]' => 1, 'line_items[0][price_data][currency]' => 'usd', 'line_items[0][price_data][unit_amount]' => $pl['cents'],
    'line_items[0][price_data][recurring][interval]' => $pl['interval'], 'line_items[0][price_data][product_data][name]' => $pl['name'],
    'line_items[0][price_data][product_data][description]' => 'Unlimited live English dubbing, Hoshi, and every new voice. Cancel any time.',
    'custom_text[submit][message]' => 'Your licence key is emailed to you right after you pay. Cancel any time from the link in your receipt.',
    'subscription_data[description]' => 'Hoshidub Pro'];
} elseif ($plan === 'tip') {
  $usd = max(1, min(500, (int) ($_GET['amount'] ?? 5)));
  $p += ['mode' => 'payment', 'success_url' => $site . '/tip?thanks=1', 'cancel_url' => $site . '/tip', 'line_items[0][quantity]' => 1,
    'line_items[0][price_data][currency]' => 'usd', 'line_items[0][price_data][unit_amount]' => $usd * 100,
    'line_items[0][price_data][product_data][name]' => 'Tip for Hoshidub', 'custom_text[submit][message]' => 'Thank you. Tips help Moss keep building Hoshidub.'];
  unset($p['allow_promotion_codes']);
} else bounce('bad-plan');

$s = stripe_api('checkout/sessions', $p);
if (empty($s['url'])) { error_log('hoshidub checkout: ' . json_encode($s['error'] ?? $s)); bounce('unavailable'); }
header('Location: ' . $s['url'], true, 303);
