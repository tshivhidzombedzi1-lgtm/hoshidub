// Builds the upload bundle for Node hosting: release/hoshidub-website.zip
// It holds only what the server needs: the built site (dist/), server.js and a slim package.json.
//   npm run package
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const stage = path.join(root, 'release', 'hoshidub-website');
const zip = path.join(root, 'release', 'hoshidub-website.zip');
const pkg = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));

execFileSync(process.execPath, [path.join(root, 'node_modules', 'astro', 'bin', 'astro.mjs'), 'build'], { cwd: root, stdio: 'inherit' });

fs.rmSync(path.join(root, 'release'), { recursive: true, force: true });
fs.mkdirSync(stage, { recursive: true });
fs.cpSync(path.join(root, 'dist'), path.join(stage, 'dist'), { recursive: true });
fs.copyFileSync(path.join(root, 'server.js'), path.join(stage, 'server.js'));
fs.writeFileSync(path.join(stage, 'package.json'), JSON.stringify({
  name: pkg.name, version: pkg.version, private: true, type: 'module', description: pkg.description,
  scripts: { start: 'node server.js' },
  engines: pkg.engines,
  dependencies: { compression: pkg.dependencies.compression, express: pkg.dependencies.express },
}, null, 2) + '\n');
fs.writeFileSync(path.join(stage, 'README.txt'), [
  'Hoshidub website - upload bundle',
  '',
  '1. Upload everything in this folder to your server.',
  '2. In that folder run:   npm install --omit=dev',
  '3. Start it:             npm start        (listens on $PORT, default 3000)',
  '',
  'Keep it running with your host\'s Node app manager, or pm2:',
  '   npm install -g pm2 && pm2 start server.js --name hoshidub && pm2 save',
  '',
].join('\n'));

// Windows tar (bsdtar) writes zip files; GNU tar from Git can't
const tar = process.platform === 'win32' ? path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'tar.exe') : 'zip';
if (process.platform === 'win32') execFileSync(tar, ['-a', '-cf', zip, '-C', stage, '.'], { stdio: 'inherit' });
else execFileSync('zip', ['-qr', zip, '.'], { cwd: stage, stdio: 'inherit' });
console.log(`\nUpload bundle: ${zip} (${(fs.statSync(zip).size / 1e6).toFixed(1)} MB)`);
