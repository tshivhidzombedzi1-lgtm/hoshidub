<?php
// Hoshidub licence server settings.
// Copy this file to  <home>/hoshidub-data/config.php  (the folder NEXT TO public_html, not inside it),
// so nobody can ever download it. The owner pastes the secret in himself.
return [
  // Stripe → Developers → Webhooks → endpoint https://<your domain>/api/stripe-webhook.php → "Signing secret"
  // Events: checkout.session.completed, customer.subscription.updated, customer.subscription.deleted
  'stripe_webhook_secret' => 'whsec_REPLACE_ME',

  'activation_limit' => 2,                                   // PCs per key
  'mail_from'   => 'Hoshidub <no-reply@hoshidub.com>',       // an address on your own domain
  'reply_to'    => 'Hoshidub <hello@hoshidub.com>',
  'account_url' => '',                                        // Stripe customer portal login link (billing.stripe.com/p/login/...)
  'support_url' => 'https://hoshidub.com/support',

  // Database: leave empty for a SQLite file in this folder. For MySQL (hPanel → Databases):
  // 'db_dsn' => 'mysql:host=localhost;dbname=u000000_hoshidub;charset=utf8mb4', 'db_user' => '', 'db_pass' => '',
  'db_dsn' => '',
];
