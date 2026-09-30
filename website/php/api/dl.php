<?php
// /api/dl.php -> counts the installer download, then sends the file. Direct links to /downloads/... keep working (the app uses them).
declare(strict_types=1);
require __DIR__ . '/lib.php';
$file = 'Hoshidub-Setup-0.1.0.exe';
$ua = $_SERVER['HTTP_USER_AGENT'] ?? '';
if (!preg_match('/bot|crawl|spider|curl|wget|preview|monitor/i', $ua)) {
  try {
    $ip = hash('sha256', ($_SERVER['REMOTE_ADDR'] ?? '') . '|hoshidub');
    $q = db()->prepare('SELECT COUNT(*) FROM downloads WHERE ip_hash = ? AND file = ? AND at > ?');   // one per visitor per 10 minutes
    $q->execute([$ip, $file, time() - 600]);
    if (!(int) $q->fetchColumn()) db()->prepare('INSERT INTO downloads (id, at, ip_hash, file) VALUES (?, ?, ?, ?)')->execute([bin2hex(random_bytes(10)), time(), $ip, $file]);
  } catch (Throwable $e) { error_log('hoshidub dl count: ' . $e->getMessage()); }   // never block a download over counting
}
header('Cache-Control: no-store');
header('Location: /downloads/' . $file, true, 302);
