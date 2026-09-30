<?php
// Hoshidub licence server settings.
// Copy this file to  <home>/hoshidub-data/config.php  (the folder NEXT TO public_html, not inside it),
// so nobody can ever download it. The owner pastes the secrets in himself; nobody else types them.
return [
  'site_url' => 'https://hoshidub.com',

  // Stripe: the secret key is read at run time from a private .env file that already holds it (the MCP Automation app's),
  // so it is never copied into the website. Or set 'stripe_secret_key' => 'sk_live_...' instead.
  'stripe_env_file' => '/home/u150848555/domains/mcpautomation.io/app/.env',
  // Filled in for you by:  php bin-stripe-setup.php   (creates the webhook in Stripe and saves its signing secret here)
  // Events: checkout.session.completed, customer.subscription.updated, customer.subscription.deleted
  'stripe_webhook_secret' => 'whsec_REPLACE_ME',

  // Admin page (https://hoshidub.com/admin). Make the hash with:  php bin-admin-password.php
  'admin_password_hash' => '',

  'activation_limit' => 2,                                   // PCs per key
  'mail_from'   => 'Hoshidub <no-reply@hoshidub.com>',       // an address on your own domain
  'reply_to'    => 'Hoshidub <hello@hoshidub.com>',
  'account_url' => 'https://billing.stripe.com/p/login/4gM3cwgwXcH17MW3MvbAs00',                                        // Stripe customer portal login link (billing.stripe.com/p/login/...)
  'support_url' => 'https://hoshidub.com/support',

  // Database: leave empty for a SQLite file in this folder. For MySQL (hPanel → Databases):
  // 'db_dsn' => 'mysql:host=localhost;dbname=u000000_hoshidub;charset=utf8mb4', 'db_user' => '', 'db_pass' => '',
  'db_dsn' => '',
];
