<?php // php dcsign.php <secretKeyHex(128)> <timestamp> <body>  -> hex signature
echo bin2hex(sodium_crypto_sign_detached($argv[2] . $argv[3], hex2bin($argv[1])));
