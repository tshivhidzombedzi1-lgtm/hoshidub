// Structured local log in %APPDATA%\Hoshidub\logs\koe.log, rotated at 2 MB. Nothing leaves the machine.
const fs = require('fs');
const path = require('path');

let file = null;

function init(dir) {
  fs.mkdirSync(dir, { recursive: true });
  file = path.join(dir, 'koe.log');
  try {
    if (fs.statSync(file).size > 2 * 1024 * 1024) fs.renameSync(file, file + '.1');
  } catch { /* no log yet */ }
}

function write(level, msg, extra) {
  const line = JSON.stringify({ t: new Date().toISOString(), level, msg, ...(extra || {}) });
  if (process.env.KOE_DEBUG) console.log(line);
  if (file) fs.appendFile(file, line + '\n', () => {});
}

module.exports = {
  init,
  info: (m, e) => write('info', m, e),
  warn: (m, e) => write('warn', m, e),
  error: (m, e) => write('error', m, e),
};
