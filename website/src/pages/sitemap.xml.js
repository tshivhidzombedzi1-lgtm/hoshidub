// Sitemap of every indexable page (built at build time, no plugin needed). 404 and the admin are left out on purpose.
const pages = [['', 1.0], ['/pricing', 0.9], ['/download', 0.9], ['/about', 0.6], ['/support', 0.5], ['/press', 0.4], ['/tip', 0.3], ['/privacy', 0.2], ['/terms', 0.2]];

export function GET({ site }) {
  const day = new Date().toISOString().slice(0, 10);
  const urls = pages.map(([p, pr]) => `  <url><loc>${new URL(p || '/', site).href.replace(/\/$/, p ? '' : '/')}</loc><lastmod>${day}</lastmod><priority>${pr.toFixed(1)}</priority></url>`).join('\n');
  return new Response(`<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls}\n</urlset>\n`,
    { headers: { 'Content-Type': 'application/xml' } });
}
