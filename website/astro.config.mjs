import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://hoshidub.com',
  output: 'static',
  trailingSlash: 'never',
  build: { format: 'file', inlineStylesheets: 'auto' },
  compressHTML: true,
  vite: { build: { assetsInlineLimit: 0 } },
});
