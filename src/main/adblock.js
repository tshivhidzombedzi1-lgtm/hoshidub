// Ad and tracker blocking for the built-in browser (Ghostery's open-source engine, MPL-2.0).
// Uses the prebuilt ads + tracking lists, cached on disk so blocking works from the first page after a restart.
// Per-site "off" is an exception rule (@@||site^$document), which lifts both network and cosmetic blocking.
const fs = require('fs');
const path = require('path');
const EventEmitter = require('events');
const log = require('./log');

const DEFAULT_ALLOW = ['crunchyroll.com'];   // Premium has no ads, and its player must never be put at risk

const siteOf = (url) => { try { return new URL(url).hostname.replace(/^www\./, ''); } catch { return ''; } };
const exception = (site) => `@@||${site}^$document`;

class AdBlock extends EventEmitter {
  constructor({ session, store, dir }) {
    super();
    this.session = session;
    this.store = store;
    this.cache = path.join(dir, 'adblock-engine.bin');
    this.blocker = null;
    this.blocked = new Map();      // webContents id -> count for the page it is showing
  }

  enabled() { return this.store.get('adblock') !== false; }

  allowList() {
    const saved = this.store.get('adblockAllow');
    return Array.isArray(saved) ? saved : DEFAULT_ALLOW;
  }

  async start() {
    if (process.env.KOE_ADBLOCK === 'off') return;
    try {
      const { ElectronBlocker } = require('@ghostery/adblocker-electron');
      this.blocker = await ElectronBlocker.fromPrebuiltAdsAndTracking(fetch, {
        path: this.cache,
        read: fs.promises.readFile,
        write: fs.promises.writeFile,
      });
      this.blocker.updateFromDiff({ added: this.allowList().map(exception) });
      const count = (req) => {
        const id = req.tabId;
        this.blocked.set(id, (this.blocked.get(id) || 0) + 1);
        this.emit('count', id, this.blocked.get(id));
      };
      this.blocker.on('request-blocked', count);
      this.blocker.on('request-redirected', count);
      if (this.enabled()) this.blocker.enableBlockingInSession(this.session);
      log.info('ad blocker ready', { allow: this.allowList() });
    } catch (e) {
      log.warn('ad blocker unavailable', { err: e.message });
    }
  }

  resetCount(webContentsId) { this.blocked.set(webContentsId, 0); }

  isAllowed(url) {
    const site = siteOf(url);
    return !!site && this.allowList().some((s) => site === s || site.endsWith(`.${s}`));
  }

  // The @@$document exception alone isn't enough: the blocker still injects its scriptlets into every frame
  // (Crunchyroll's player then threw "Maximum call stack size exceeded" and never started) and blocked some
  // of the player's requests. So on an allowed site the blocker is switched off for the whole session, and
  // switched back on when the browser leaves it. Called when a main-frame navigation starts.
  applyFor(url) {
    if (!this.blocker || !this.enabled()) return;
    const active = this.blocker.isBlockingEnabled(this.session);
    const want = !this.isAllowed(url);
    if (want && !active) this.blocker.enableBlockingInSession(this.session);
    if (!want && active) this.blocker.disableBlockingInSession(this.session);
  }

  state(url, webContentsId) {
    const site = siteOf(url);
    return {
      available: !!this.blocker,
      enabled: this.enabled(),
      site,
      allowed: this.isAllowed(url),
      blocked: this.blocked.get(webContentsId) || 0,
    };
  }

  setEnabled(on) {
    this.store.set('adblock', !!on);
    if (!this.blocker) return;
    const active = this.blocker.isBlockingEnabled(this.session);
    if (on && !active) this.blocker.enableBlockingInSession(this.session);
    if (!on && active) this.blocker.disableBlockingInSession(this.session);
  }

  toggleSite(url) {
    const site = siteOf(url);
    if (!site) return;
    const list = this.allowList();
    const allowed = list.includes(site);
    const next = allowed ? list.filter((s) => s !== site) : [...list, site];
    this.store.set('adblockAllow', next);
    if (this.blocker) {
      this.blocker.updateFromDiff(allowed ? { removed: [exception(site)] } : { added: [exception(site)] });
    }
    this.applyFor(url);
  }
}

module.exports = { AdBlock, siteOf };
