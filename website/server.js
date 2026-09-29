// Production server for Node hosting: serves the built site (dist/) with compression, caching and security headers.
//   npm install && npm run build && npm start        (PORT defaults to 3000)
import compression from 'compression';
import crypto from 'node:crypto';
import fs from 'node:fs';
import express from 'express';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), 'dist');
const app = express();

// Astro inlines small page scripts. Allow exactly those (by SHA-256) instead of all inline script.
function inlineScriptHashes(dir) {
  const hashes = new Set();
  for (const f of fs.readdirSync(dir, { recursive: true })) {
    if (!String(f).endsWith('.html')) continue;
    const html = fs.readFileSync(path.join(dir, f), 'utf8');
    for (const m of html.matchAll(/<script(?![^>]*\bsrc=)(?![^>]*application\/ld\+json)[^>]*>([\s\S]*?)<\/script>/g)) {
      if (m[1].trim()) hashes.add(`'sha256-${crypto.createHash('sha256').update(m[1]).digest('base64')}'`);
    }
  }
  return [...hashes].join(' ');
}
const scriptHashes = fs.existsSync(root) ? inlineScriptHashes(root) : '';
app.disable('x-powered-by');
app.use(compression());

app.use((req, res, next) => {
  res.set({
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
    'Content-Security-Policy': [
      "default-src 'self'",
      `script-src 'self' ${scriptHashes}`,
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: blob:",
      "font-src 'self'",
      "connect-src 'self' blob: data:",
      "frame-ancestors 'none'",
      "base-uri 'self'",
      "form-action 'self'",
    ].join('; '),
  });
  next();
});

// hashed build assets never change: cache for a year; pages revalidate
app.use('/_astro', express.static(path.join(root, '_astro'), { immutable: true, maxAge: '1y' }));
app.use(express.static(root, {
  extensions: ['html'],
  setHeaders(res, file) {
    if (file.endsWith('.html')) res.set('Cache-Control', 'public, max-age=0, must-revalidate');
    else res.set('Cache-Control', 'public, max-age=604800');
  },
}));

app.use((req, res) => res.status(404).sendFile(path.join(root, '404.html')));

const port = Number(process.env.PORT) || 3000;
app.listen(port, () => console.log(`Hoshidub website on http://localhost:${port}`));
