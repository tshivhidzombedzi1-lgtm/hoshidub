// Uploads build outputs to a GitHub Release on this repo (a private backup of the installer and runtime pack).
//   node tools/github-release.mjs <tag> <file> [file...]
// Uses the GitHub login Git already has (Git Credential Manager); the token is never printed or stored.
// Re-running replaces assets with the same name.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const [tag, ...files] = process.argv.slice(2);
if (!tag || !files.length) { console.error('usage: node tools/github-release.mjs <tag> <file> [file...]'); process.exit(1); }

const remote = execFileSync('git', ['remote', 'get-url', 'origin'], { encoding: 'utf8' }).trim();
const [, owner, repo] = remote.match(/github\.com[/:]([^/]+)\/(.+?)(?:\.git)?$/) || [];
const cred = execFileSync('git', ['credential', 'fill'], { input: 'protocol=https\nhost=github.com\n\n', encoding: 'utf8' });
const token = (cred.match(/^password=(.*)$/m) || [])[1];
if (!token) throw new Error('No GitHub login found in Git Credential Manager.');

const api = async (url, init = {}) => {
  const res = await fetch(url.startsWith('http') ? url : `https://api.github.com${url}`, {
    ...init, headers: { Authorization: `Bearer ${token}`, Accept: 'application/vnd.github+json', 'User-Agent': 'hoshidub-release', ...(init.headers || {}) },
  });
  if (!res.ok && res.status !== 404) throw new Error(`${init.method || 'GET'} ${url} -> ${res.status} ${await res.text()}`);
  return res.status === 204 ? null : res.status === 404 ? { notFound: true } : res.json();
};

let rel = await api(`/repos/${owner}/${repo}/releases/tags/${tag}`);
if (rel.notFound) {
  rel = await api(`/repos/${owner}/${repo}/releases`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ tag_name: tag, name: `Hoshidub ${tag}`, prerelease: true,
      body: 'Private backup: signed Windows installer and the voice engine (runtime pack) parts. See docs/HANDOFF.md.' }),
  });
  console.log(`created release ${tag}`);
}

for (const file of files) {
  const name = path.basename(file);
  const old = (rel.assets || []).find((a) => a.name === name);
  if (old) await api(`/repos/${owner}/${repo}/releases/assets/${old.id}`, { method: 'DELETE' });
  const size = fs.statSync(file).size;
  const url = rel.upload_url.replace(/\{.*\}$/, `?name=${encodeURIComponent(name)}`);
  // curl streams big files steadily (Node's fetch upload stalled and GitHub answered 408). The token goes in a
  // header file that only exists during the upload, so it never shows up in a process list.
  const headers = path.join(os.tmpdir(), `gh-upload-${process.pid}.txt`);
  fs.writeFileSync(headers, `Authorization: Bearer ${token}\nContent-Type: application/octet-stream\nUser-Agent: hoshidub-release\n`, { mode: 0o600 });
  try {
    for (let attempt = 1; ; attempt++) {
      const started = Date.now();
      try {
        const out = execFileSync('curl', ['-sS', '--fail-with-body', '-X', 'POST', '-H', `@${headers}`, '--data-binary', `@${file}`, url],
          { encoding: 'utf8', maxBuffer: 16 << 20 });
        if (!JSON.parse(out).id) throw new Error(out.slice(0, 200));
        console.log(`uploaded ${name} (${(size / 1e6).toFixed(1)} MB) in ${Math.round((Date.now() - started) / 1000)} s`);
        break;
      } catch (e) {
        if (attempt >= 3) throw e;
        console.log(`retrying ${name} (attempt ${attempt} failed: ${String(e.message).slice(0, 120)})`);
        const partial = (await api(`/repos/${owner}/${repo}/releases/${rel.id}/assets`)).find?.((a) => a.name === name);
        if (partial) await api(`/repos/${owner}/${repo}/releases/assets/${partial.id}`, { method: 'DELETE' });
      }
    }
  } finally {
    fs.rmSync(headers, { force: true });
  }
}
console.log(`https://github.com/${owner}/${repo}/releases/tag/${tag}`);
