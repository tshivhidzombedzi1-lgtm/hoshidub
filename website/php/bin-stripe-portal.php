<?php
// One-time, run by the owner:  HOSHIDUB_CONFIG=<home>/hoshidub-data/config.php php bin-stripe-portal.php
// Turns on Stripe's customer portal (update card, invoices, cancel at period end) with a hosted login page, and prints the login link
// to use as 'account' in website/src/config.js and 'account_url' in config.php. Prints no secrets.
declare(strict_types=1);
require __DIR__ . '/api/lib.php';
$site = rtrim(cfg()['site_url'] ?? 'https://hoshidub.com', '/');
$r = stripe_api('billing_portal/configurations', [
  'business_profile[headline]' => 'Manage your Hoshidub Pro subscription',
  'business_profile[privacy_policy_url]' => $site . '/privacy',
  'business_profile[terms_of_service_url]' => $site . '/terms',
  'default_return_url' => $site . '/',
  'features[customer_update][enabled]' => 'true', 'features[customer_update][allowed_updates][0]' => 'email', 'features[customer_update][allowed_updates][1]' => 'name',
  'features[invoice_history][enabled]' => 'true',
  'features[payment_method_update][enabled]' => 'true',
  'features[subscription_cancel][enabled]' => 'true', 'features[subscription_cancel][mode]' => 'at_period_end',
  'login_page[enabled]' => 'true',
]);
if (empty($r['login_page']['url'])) { fwrite(STDERR, 'Portal setup failed: ' . ($r['error']['message'] ?? json_encode($r)) . "\n"); exit(1); }
echo "Customer portal enabled ({$r['id']}).\nLogin link: {$r['login_page']['url']}\n";
