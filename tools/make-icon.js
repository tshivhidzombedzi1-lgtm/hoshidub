// Renders the app icon (512 px PNG + multi-size ICO) from SVG with Electron's own renderer.
// Run: npx electron tools/make-icon.js
const { app, BrowserWindow } = require('electron');
const fs = require('fs');
const path = require('path');

const SVG = `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#ff6b9d"/><stop offset="0.55" stop-color="#c38bff"/><stop offset="1" stop-color="#6ba8ff"/>
    </linearGradient>
    <linearGradient id="shine" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#fff" stop-opacity="0.55"/><stop offset="0.5" stop-color="#fff" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <clipPath id="c"><rect x="16" y="16" width="480" height="480" rx="112"/></clipPath>
  <rect x="16" y="16" width="480" height="480" rx="112" fill="url(#g)"/>
  <ellipse cx="256" cy="40" rx="330" ry="210" fill="url(#shine)" clip-path="url(#c)"/>
  <rect x="17.5" y="17.5" width="477" height="477" rx="110.5" fill="none" stroke="#fff" stroke-opacity="0.35" stroke-width="3"/>
  <g fill="#fff"><rect x="118" y="214" width="40" height="84" rx="20"/><rect x="186" y="150" width="40" height="212" rx="20"/><rect x="254" y="110" width="40" height="292" rx="20"/><rect x="322" y="170" width="40" height="172" rx="20"/><rect x="390" y="224" width="40" height="64" rx="20" opacity="0.85"/></g>
</svg>`;

function ico(pngs) {
  // ICO container holding PNG-encoded images (supported since Vista)
  const header = Buffer.alloc(6 + 16 * pngs.length);
  header.writeUInt16LE(0, 0); header.writeUInt16LE(1, 2); header.writeUInt16LE(pngs.length, 4);
  let offset = header.length;
  pngs.forEach(({ size, data }, i) => {
    const e = 6 + 16 * i;
    header.writeUInt8(size >= 256 ? 0 : size, e); header.writeUInt8(size >= 256 ? 0 : size, e + 1);
    header.writeUInt16LE(1, e + 4); header.writeUInt16LE(32, e + 6);
    header.writeUInt32LE(data.length, e + 8); header.writeUInt32LE(offset, e + 12);
    offset += data.length;
  });
  return Buffer.concat([header, ...pngs.map((p) => p.data)]);
}

app.whenReady().then(async () => {
  const win = new BrowserWindow({ width: 512, height: 512, show: false, transparent: true, frame: false,
    webPreferences: { offscreen: true } });
  await win.loadURL('data:text/html,' + encodeURIComponent(
    `<html><head><meta charset="utf-8"></head><body style="margin:0;background:transparent">${SVG}</body></html>`));
  await new Promise((r) => setTimeout(r, 400));
  const img = await win.webContents.capturePage({ x: 0, y: 0, width: 512, height: 512 });
  const out = path.join(__dirname, '..', 'src', 'ui');
  fs.writeFileSync(path.join(out, 'icon.png'), img.toPNG());
  const sizes = [16, 24, 32, 48, 64, 128, 256];
  const pngs = sizes.map((size) => ({ size, data: img.resize({ width: size, height: size, quality: 'best' }).toPNG() }));
  fs.mkdirSync(path.join(__dirname, '..', 'build'), { recursive: true });
  fs.writeFileSync(path.join(__dirname, '..', 'build', 'icon.ico'), ico(pngs));
  console.log('icon written');
  app.quit();
});
