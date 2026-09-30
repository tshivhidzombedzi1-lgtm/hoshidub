#!/bin/bash
# Exercises the licence server without a web server (loopback ports are blocked on some hosts): each request is one php process.
# Signed Stripe webhooks, activate / validate / deactivate, activation limit, cancel / renew, tips ignored.
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd); T=$(mktemp -d); mkdir -p $T/public_html $T/hoshidub-data
cp -r "$HERE/api" $T/public_html/api
cat > $T/hoshidub-data/config.php <<P
<?php return ['stripe_webhook_secret'=>'whsec_test','activation_limit'=>2,'mail_disabled'=>true];
P
export H_ROOT=$T/public_html HOSHIDUB_CONFIG=$T/hoshidub-data/config.php
fail=0
ok() { if echo "$2" | grep -q -- "$3"; then echo "PASS $1"; else echo "FAIL $1 (got: $(echo $2 | cut -c1-160))"; fail=1; fi; }
hook() { local body="$1" t=$(date +%s); local sig=${2:-$(php -r 'echo hash_hmac("sha256", $argv[1].".".$argv[2], "whsec_test");' $t "$body")}; env H_SCRIPT=stripe-webhook.php H_BODY="$body" H_SIG="t=$t,v1=$sig" php "$HERE/test/harness.php" 2>&1; }
api() { env H_SCRIPT=license.php H_ACTION="$1" H_POST="license_key=${KEY:-HD-AAAAA-AAAAA-AAAAA-AAAAA}&instance_id=${2:-}&instance_name=PC${3:-}" php "$HERE/test/harness.php" 2>&1; }
E1='{"id":"evt_1","type":"checkout.session.completed","data":{"object":{"id":"cs_1","mode":"subscription","payment_status":"paid","customer":"cus_1","subscription":"sub_1","customer_details":{"email":"Buyer@Example.com"}}}}'
ok "bad signature rejected" "$(hook "$E1" deadbeef)" "Bad signature"
ok "checkout creates key" "$(hook "$E1")" '"received":true'
ok "duplicate event ignored" "$(hook "$E1")" duplicate
hook '{"id":"evt_2","type":"checkout.session.completed","data":{"object":{"mode":"payment","payment_status":"paid","customer_details":{"email":"t@e.com"}}}}' >/dev/null
KEY=$(php -r '$d=new PDO("sqlite:'$T'/hoshidub-data/licenses.sqlite");foreach($d->query("select license_key k, email e from licenses") as $r)echo $r["k"]." ".$r["e"]."\n";')
ok "one key, email lower-cased, tip made none" "$KEY" "^HD-.* buyer@example.com$"; [ "$(echo "$KEY" | wc -l)" = 1 ] || { echo "FAIL more than one key"; fail=1; }
KEY=${KEY%% *}; export KEY
r1=$(api activate "" 1); ok "activate 1" "$r1" '"activated":true'
I1=$(echo "$r1" | grep -o '"instance":{"id":"[a-f0-9]*' | grep -o '[a-f0-9]\{32\}')
ok "activate 2" "$(api activate "" 2)" '"activated":true'
ok "activate 3 blocked by limit" "$(api activate "" 3)" 'activation limit'
ok "validate active" "$(api validate $I1)" '"valid":true'
ok "validate unknown instance" "$(api validate deadbeef)" 'instance not found'
ok "deactivate" "$(api deactivate $I1)" '"deactivated":true'
ok "validate after deactivate is not valid" "$(api validate $I1)" '"valid":false'
ok "unknown key" "$(KEY=HD-AAAAA-AAAAA-AAAAA-AAAAA api validate)" 'not found'
ok "GET refused" "$(env H_SCRIPT=license.php H_METHOD=GET H_ACTION=validate php "$HERE/test/harness.php" 2>&1)" '#405'
hook '{"id":"evt_3","type":"customer.subscription.deleted","data":{"object":{"id":"sub_1","status":"canceled"}}}' >/dev/null
ok "cancelled sub switches key off" "$(api validate)" '"valid":false'
ok "expired key cannot activate" "$(api activate "" 9)" 'expired'
hook '{"id":"evt_4","type":"customer.subscription.updated","data":{"object":{"id":"sub_1","status":"active"}}}' >/dev/null
ok "renewed sub switches key on" "$(api validate)" '"valid":true'
ok "resend never reveals customers" "$(env H_SCRIPT=resend.php H_POST='email=nobody@x.com' php "$HERE/test/harness.php" 2>&1)" '#303'
# ---- admin page ----
PW='correct horse battery'; H=$(php -r 'echo password_hash($argv[1], PASSWORD_DEFAULT);' "$PW")
sed -i "s#'mail_disabled'=>true#'mail_disabled'=>true,'admin_password_hash'=>'$H'#" $HOSHIDUB_CONFIG
mkdir -p $T/hoshidub-data/sessions; printf 'ok|i:1;csrf|s:4:"tok1";' > $T/hoshidub-data/sessions/sess_testsess
adm() { env H_SCRIPT=admin.php "$@" php "$HERE/test/harness.php" 2>&1; }
ok "admin: signed out shows login" "$(adm H_METHOD=GET)" 'Sign in'
ok "admin: wrong password refused" "$(adm H_POST=password=nope)" 'Wrong password'
ok "admin: right password signs in" "$(adm H_POST="password=$PW")" '#303'
ok "admin: first sign-in forces creating a password" "$(adm H_METHOD=GET H_COOKIE=testsess)" 'Create your password'
ok "admin: too-short new password refused" "$(adm H_COOKIE=testsess H_POST='csrf=tok1&new=short&again=short')" 'at least 12'
ok "admin: mismatch refused" "$(adm H_COOKIE=testsess H_POST='csrf=tok1&new=abcdefghijklm&again=abcdefghijkln')" 'do not match'
ok "admin: reusing the temporary password refused" "$(adm H_COOKIE=testsess H_POST="csrf=tok1&new=$PW&again=$PW")" 'different password'
PW2='my-own-first-pass'
ok "admin: own password saved" "$(adm H_COOKIE=testsess H_POST="csrf=tok1&new=$PW2&again=$PW2")" '#303'
ok "admin: temporary password no longer works" "$(adm H_POST="password=$PW")" 'Wrong password'
ok "admin: own password signs in" "$(adm H_POST="password=$PW2")" '#303'
ok "admin: no CSRF token refused" "$(adm H_COOKIE=testsess H_POST='do=create&email=a@b.com')" 'Session expired'
adm H_COOKIE=testsess H_POST='csrf=tok1&do=create&email=Gift@Example.com&plan=comp&limit=3&note=friend' >/dev/null
P=$(adm H_METHOD=GET H_COOKIE=testsess)
ok "admin: dashboard lists the new key" "$P" 'gift@example.com'
ok "admin: dashboard shows stats" "$P" 'Active Pro keys'
NK=$(echo "$P" | grep -o 'HD-[A-Z0-9-]*' | sort -u | grep -v "^$KEY$" | head -1)
adm H_COOKIE=testsess H_POST="csrf=tok1&do=status&key=$NK&status=disabled" >/dev/null
ok "admin: disable key -> app sees it off" "$(KEY=$NK api validate)" '"valid":false'
adm H_COOKIE=testsess H_POST="csrf=tok1&do=status&key=$NK&status=active" >/dev/null
ok "admin: enable key -> app sees it on" "$(KEY=$NK api validate)" '"valid":true'
ok "admin: CSV export" "$(adm H_METHOD=GET H_COOKIE=testsess H_GET=csv=1)" 'gift@example.com'
ok "admin: search" "$(adm H_METHOD=GET H_COOKIE=testsess H_GET="tab=licences&q=nomatchxyz")" 'No licences match'

ok "admin: wrong current password refused" "$(adm H_COOKIE=testsess H_POST='csrf=tok1&do=password&current=bad&new=abcdefghijklm&again=abcdefghijklm' >/dev/null; adm H_METHOD=GET H_COOKIE=testsess)" 'Current password is wrong'
adm H_COOKIE=testsess H_POST="csrf=tok1&do=password&current=$PW2&new=brand-new-pass-99&again=brand-new-pass-99" >/dev/null
ok "admin: new password works after change" "$(adm H_POST='password=brand-new-pass-99')" '#303'
ok "admin: old password stops working" "$(adm H_POST="password=$PW2")" 'Wrong password'
# every admin tab renders with no PHP warnings, and the money actions ask before acting
for tb in overview licences payments downloads activity settings; do
  out=$(env H_SCRIPT=admin.php H_METHOD=GET H_COOKIE=testsess H_GET="tab=$tb" php -d display_errors=1 -d error_reporting=E_ALL "$HERE/test/harness.php" 2>&1)
  if echo "$out" | grep -qE "Warning:|Fatal error|Notice:|Deprecated:"; then echo "FAIL admin tab $tb: $(echo "$out" | grep -E 'Warning:|Fatal error|Notice:|Deprecated:' | head -1 | cut -c1-200)"; fail=1; else echo "PASS admin tab $tb renders"; fi
done
NK2=$(php -r '$d=new PDO("sqlite:'$T'/hoshidub-data/licenses.sqlite");echo $d->query("select license_key from licenses limit 1")->fetchColumn();')
ok "admin: licence detail page" "$(adm H_METHOD=GET H_COOKIE=testsess H_GET="tab=licences&key=$NK2")" 'PCs using this key'
ok "admin: refund asks for confirmation first" "$(adm H_COOKIE=testsess H_POST='csrf=tok1&do=refund&charge=ch_x&amount=699')" 'Yes, do it'
ok "admin: cancel now asks for confirmation first" "$(adm H_COOKIE=testsess H_POST='csrf=tok1&do=sub_cancel_now&sub=sub_x')" 'RIGHT NOW'
ok "downloads are counted, bots are not" "$(env H_SCRIPT=dl.php H_METHOD=GET HTTP_USER_AGENT= php "$HERE/test/harness.php" 2>&1; cnt=$(php -r '$d=new PDO("sqlite:'$T'/hoshidub-data/licenses.sqlite");echo $d->query("select count(*) from downloads")->fetchColumn();'); echo "n=$cnt")" 'n=1'
# ---- Discord bot (signature, /hoshidub commands); no calls to Discord are made (no bot token in the test env) ----
PHP85=${PHP85:-/opt/alt/php85/usr/bin/php}   # the Discord checks need libsodium; the default CLI here has none (the web PHP does)
KP=$($PHP85 -r '$k=sodium_crypto_sign_keypair();echo bin2hex(sodium_crypto_sign_secretkey($k))," ",bin2hex(sodium_crypto_sign_publickey($k));'); SK=${KP% *}; PK=${KP#* }
printf 'DISCORD_PUBLIC_KEY=%s\nDISCORD_GUILD_ID=111111111111111111\nDISCORD_APP_ID=222222222222222222\n' "$PK" > $T/dc.env
sed -i "s#'mail_disabled'=>true#'mail_disabled'=>true,'discord_env_file'=>'$T/dc.env','discord_forward_secret'=>'fwd-test-secret'#" $HOSHIDUB_CONFIG
dcmd() { # dcmd '<json options>' [admin(1/0)]  -> runs /hoshidub as a member
  local perms=${2:-0} b ts=$(date +%s); b='{"type":2,"guild_id":"111111111111111111","application_id":"222222222222222222","token":"tok","member":{"permissions":"'$perms'","user":{"id":"333333333333333333","username":"tester"}},"data":{"name":"hoshidub","options":'"$1"'}}'
  env H_SCRIPT=discord.php H_BODY="$b" H_FTS=$ts H_FSIG=$(php -r 'echo hash_hmac("sha256", $argv[1].".".$argv[2], "fwd-test-secret");' $ts "$b") php "$HERE/test/harness.php" 2>&1; }
ok "discord: bad signature rejected" "$(env H_SCRIPT=discord.php H_BODY='{"type":1}' H_FTS=$(date +%s) H_FSIG=00 php "$HERE/test/harness.php" 2>&1)" '#401'
ok "discord: unsigned request rejected" "$(env H_SCRIPT=discord.php H_BODY='{"type":1}' php "$HERE/test/harness.php" 2>&1)" '#401'
ok "discord: Discord own Ed25519 signature also accepted (PHP with libsodium)" "$(b='{"type":1}'; ts=$(date +%s); env H_SCRIPT=discord.php H_BODY="$b" H_DTS=$ts H_DSIG=$($PHP85 "$HERE/test/dcsign.php" $SK $ts "$b") $PHP85 "$HERE/test/harness.php" 2>&1)" '"type":1'
ok "discord: /hoshidub buy has both checkout links" "$(dcmd '[{"type":1,"name":"buy"}]')" 'plan=yearly'
ok "discord: help finds the delay answer" "$(dcmd '[{"type":1,"name":"help","options":[{"name":"question","value":"why is the dub late"}]}]')" 'zero delay'
ok "discord: help says so when it does not know" "$(dcmd '[{"type":1,"name":"help","options":[{"name":"question","value":"qqqq"}]}]')" 'ready answer'
ok "discord: status before activating" "$(dcmd '[{"type":1,"name":"status"}]')" 'No licence is linked'
ok "discord: bad key refused" "$(dcmd '[{"type":1,"name":"activate","options":[{"name":"key","value":"HD-AAAAA-AAAAA-AAAAA-AAAAA"}]}]')" 'could not find'
ok "discord: real key links" "$(dcmd '[{"type":1,"name":"activate","options":[{"name":"key","value":"'$KEY'"}]}]')" 'Key linked'
ok "discord: status after activating" "$(dcmd '[{"type":1,"name":"status"}]')" "$KEY"
ok "discord: admin commands refused for normal members" "$(dcmd '[{"type":2,"name":"admin","options":[{"type":1,"name":"stats"}]}]')" 'admins only'
ok "discord: admin stats for admins" "$(dcmd '[{"type":2,"name":"admin","options":[{"type":1,"name":"stats"}]}]' 8)" 'Active keys'
ok "discord: admin lookup by email" "$(dcmd '[{"type":2,"name":"admin","options":[{"type":1,"name":"lookup","options":[{"name":"query","value":"buyer@example.com"}]}]}]' 8)" 'buyer@example.com'
ok "discord: admin grant makes a key" "$(dcmd '[{"type":2,"name":"admin","options":[{"type":1,"name":"grant","options":[{"name":"email","value":"gift@x.com"},{"name":"plan","value":"comp"}]}]}]' 8)" 'Created `HD-'
ok "discord: admin disable switches the key off for the app" "$(dcmd '[{"type":2,"name":"admin","options":[{"type":1,"name":"disable","options":[{"name":"key","value":"'$KEY'"}]}]}]' 8 >/dev/null; api validate)" '"valid":false'
# ---- ticket buttons (only the paths that never call Discord) ----
dcraw() { local b="$1" ts=$(date +%s); env H_SCRIPT=discord.php H_BODY="$b" H_FTS=$ts H_FSIG=$(php -r 'echo hash_hmac("sha256", $argv[1].".".$argv[2], "fwd-test-secret");' $ts "$b") php "$HERE/test/harness.php" 2>&1; }
BASE='"guild_id":"111111111111111111","channel_id":"999","member":{"permissions":"0","user":{"id":"444444444444444444","username":"buyer"}}'
ok "ticket: Open button shows the form" "$(dcraw '{"type":3,'"$BASE"',"data":{"custom_id":"hd_ticket_open"}}')" '"type":9'
ok "ticket: form asks what you need" "$(dcraw '{"type":3,'"$BASE"',"data":{"custom_id":"hd_ticket_open"}}')" 'What do you need help with'
ok "ticket: close on a non-ticket channel is refused" "$(dcraw '{"type":3,'"$BASE"',"data":{"custom_id":"hd_ticket_close"}}')" 'not an open ticket'
ok "ticket: unknown button is harmless" "$(dcraw '{"type":3,'"$BASE"',"data":{"custom_id":"hd_nope"}}')" 'not active'
ok "ticket: buttons from other bots are ignored (not hd_)" "$(dcraw '{"type":3,'"$BASE"',"data":{"custom_id":"other"}}')" '#400'
php -r '$d=new PDO("sqlite:'$T'/hoshidub-data/licenses.sqlite"); $d->exec("INSERT INTO tickets (id, channel_id, user_id, topic, created_at) VALUES (1, \"555\", \"444444444444444444\", \"test\", ".time().")");'
ok "ticket: second ticket blocked while one is open" "$(dcraw '{"type":3,'"$BASE"',"data":{"custom_id":"hd_ticket_open"}}')" 'already have an open ticket'
ok "ticket: someone else cannot close it" "$(dcraw '{"type":3,"guild_id":"111111111111111111","channel_id":"555","member":{"permissions":"0","user":{"id":"777777777777777777","username":"other"}},"data":{"custom_id":"hd_ticket_close"}}')" 'Only the ticket owner'
rm -rf $T; [ $fail = 0 ] && echo "all passed"; exit $fail
