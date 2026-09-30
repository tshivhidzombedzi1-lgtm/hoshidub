<?php
// Fake web request for CLI tests. Env: H_SCRIPT, H_METHOD, H_POST (query string), H_BODY (raw), H_SIG, H_ACTION
$_SERVER['REQUEST_METHOD'] = getenv('H_METHOD') ?: 'POST';
parse_str(getenv('H_POST') ?: '', $_POST);
if (getenv('H_ACTION')) $_GET['action'] = getenv('H_ACTION');
if (getenv('H_FSIG')) { $_SERVER['HTTP_X_HOSHIDUB_SIG'] = getenv('H_FSIG'); $_SERVER['HTTP_X_HOSHIDUB_TS'] = getenv('H_FTS'); }
if (getenv('H_DSIG')) { $_SERVER['HTTP_X_SIGNATURE_ED25519'] = getenv('H_DSIG'); $_SERVER['HTTP_X_SIGNATURE_TIMESTAMP'] = getenv('H_DTS'); }
if (getenv('H_SIG')) $_SERVER['HTTP_STRIPE_SIGNATURE'] = getenv('H_SIG');
if (getenv('H_COOKIE')) $_COOKIE['hd_admin'] = getenv('H_COOKIE');
if (getenv('H_GET')) parse_str(getenv('H_GET'), $_GET);
$_SERVER['REMOTE_ADDR'] = '127.0.0.1'; $_SERVER['HTTP_USER_AGENT'] = getenv('HTTP_USER_AGENT') ?: 'Mozilla/5.0';
$GLOBALS['__body'] = getenv('H_BODY') ?: '';
register_shutdown_function(function () { echo "\n#" . http_response_code(); });
require getenv('H_ROOT') . '/api/' . getenv('H_SCRIPT');
