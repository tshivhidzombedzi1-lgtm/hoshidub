// Production server for Node hosting: serves the built site (dist/) with compression, caching and security headers.
//   npm install && npm run build && npm start        (PORT defaults to 3000)
import compression from 'compression';
import express from 'express';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { securityHeaders } from './security.js';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), 'dist');
const app = express();

// every page script is an external file (astro.config.mjs sets assetsInlineLimit: 0), so script-src 'self' is enough
app.disable('x-powered-by');
app.use(compression());
app.use((req, res, next) => { res.set(securityHeaders); next(); });

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
