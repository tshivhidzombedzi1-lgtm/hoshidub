<?php
// One-time, run by the owner over SSH:  php website/php/bin-stripe-setup.php  (from the folder that holds hoshidub-data)
// Creates (or reuses) the Stripe webhook endpoint for hoshidub.com and stores its signing secret in hoshidub-data/config.php.
// Uses the Stripe key from config 'stripe_env_file' / 'stripe_secret_key'. Prints no secrets.
declare(strict_types=1);
require __DIR__ . '/api/lib.php';
$c = cfg();
$acct = stripe_api('account', [], 'GET');
if (empty($acct['id'])) { fwrite(STDERR, 'Stripe key rejected: ' . ($acct['error']['message'] ?? 'unknown') . "\n"); exit(1); }
$mode = str_contains(stripe_key(), '_test_') ? 'TEST' : 'LIVE';
echo "Stripe account OK ($mode mode)\n";
$url = rtrim($c['site_url'] ?? 'https://hoshidub.com', '/') . '/api/stripe-webhook.php';
foreach (stripe_api('webhook_endpoints?limit=100', [], 'GET')['data'] ?? [] as $we) {
  if ($we['url'] === $url) { echo "Webhook already exists ({$we['id']}). Delete it in Stripe first if you need a new signing secret.\n"; exit(0); }
}
$w = stripe_api('webhook_endpoints', ['url' => $url, 'description' => 'Hoshidub licences',
  'enabled_events[0]' => 'checkout.session.completed', 'enabled_events[1]' => 'customer.subscription.updated', 'enabled_events[2]' => 'customer.subscription.deleted']);
if (empty($w['secret'])) { fwrite(STDERR, 'Could not create the webhook: ' . ($w['error']['message'] ?? 'unknown') . "\n"); exit(1); }
$file = getenv('HOSHIDUB_CONFIG') ?: data_dir() . '/config.php';
$txt = (string) file_get_contents($file);
$new = preg_replace("/'stripe_webhook_secret'\\s*=>\\s*'[^']*'/", "'stripe_webhook_secret' => '" . $w['secret'] . "'", $txt, 1, $n);
if (!$n) { fwrite(STDERR, "config.php has no 'stripe_webhook_secret' line to fill in.\n"); exit(1); }
file_put_contents($file, $new, LOCK_EX);
echo "Webhook created ({$w['id']}) -> $url; signing secret saved to config.php.\n";
