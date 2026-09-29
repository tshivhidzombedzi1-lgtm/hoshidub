// electron-builder hook: VMP-sign the packaged app with castLabs EVS so streaming services accept it.
// Runs as electron-builder's afterSign hook: on Windows the VMP signature must come AFTER code signing
// (signtool rewrites the exe and would invalidate it), and before the installer is assembled.
const { execFileSync } = require('child_process');

exports.default = async function afterSign(context) {
  if (context.electronPlatformName !== 'win32') return;
  const dir = context.appOutDir;
  console.log(`  • VMP signing ${dir}`);
  execFileSync('python', ['-m', 'castlabs_evs.vmp', '-n', 'sign-pkg', dir], { stdio: 'inherit' });
};
