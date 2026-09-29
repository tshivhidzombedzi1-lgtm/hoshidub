// Plan and licence: Free (daily dubbing allowance) or Pro (a Lemon Squeezy licence key activated on this PC).
// Uses Lemon Squeezy's public licence API, which needs no secret: activate / validate / deactivate.
const fs = require('fs');
const os = require('os');
const path = require('path');
const log = require('./log');
const paths = require('./paths');

const API = process.env.KOE_LICENSE_API || 'https://api.lemonsqueezy.com/v1/licenses';
const PRODUCT_ID = paths.productId() ? Number(paths.productId()) : null;   // package.json "dubit.productId", set once the store exists
const FREE_SECONDS = Number(process.env.KOE_FREE_SECONDS || 30 * 60);
const REVALIDATE_MS = 24 * 3600 * 1000;
const OFFLINE_GRACE_MS = 7 * 24 * 3600 * 1000;

const today = () => new Date().toISOString().slice(0, 10);

class License {
  constructor(dir) {
    this.file = path.join(dir, 'license.json');
    this.state = { key: '', instanceId: '', status: 'free', validatedAt: 0, usage: { day: today(), seconds: 0 } };
    try { this.state = { ...this.state, ...JSON.parse(fs.readFileSync(this.file, 'utf8')) }; } catch { /* first run */ }
  }

  save() {
    const tmp = this.file + '.tmp';
    fs.writeFileSync(tmp, JSON.stringify(this.state, null, 1));
    fs.renameSync(tmp, this.file);
  }

  isPro() {
    const s = this.state;
    return s.status === 'active' && !!s.key && Date.now() - s.validatedAt < OFFLINE_GRACE_MS;
  }

  usage() {
    if (this.state.usage.day !== today()) this.state.usage = { day: today(), seconds: 0 };
    return this.state.usage;
  }

  summary() {
    const pro = this.isPro();
    const used = this.usage().seconds;
    return {
      plan: pro ? 'pro' : 'free',
      key: pro ? `${this.state.key.slice(0, 4)}…${this.state.key.slice(-4)}` : '',
      freeSeconds: FREE_SECONDS,
      remaining: pro ? null : Math.max(0, FREE_SECONDS - used),
    };
  }

  // called while dubbing; returns seconds left today (null = unlimited)
  addUsage(seconds) {
    if (this.isPro()) return null;
    const u = this.usage();
    u.seconds = Math.min(FREE_SECONDS + 60, u.seconds + Math.max(0, Math.min(seconds, 30)));
    this.save();
    return Math.max(0, FREE_SECONDS - u.seconds);
  }

  async call(action, fields) {
    const res = await fetch(`${API}/${action}`, {
      method: 'POST',
      headers: { Accept: 'application/json', 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams(fields).toString(),
      signal: AbortSignal.timeout(15000),
    });
    let body = {};
    try { body = await res.json(); } catch { /* non-JSON error page */ }
    return { ok: res.ok, body };
  }

  productMatches(meta) {
    return PRODUCT_ID === null || (meta && Number(meta.product_id) === PRODUCT_ID);
  }

  async activate(key) {
    key = String(key || '').trim();
    if (!/^[A-Za-z0-9-]{16,}$/.test(key)) return { ok: false, error: 'That doesn\'t look like a licence key. Copy it from your receipt email.' };
    let r;
    try {
      r = await this.call('activate', { license_key: key, instance_name: `${os.hostname()} (Hoshidub)` });
    } catch {
      return { ok: false, error: 'Couldn\'t reach the licence server. Check your internet connection and try again.' };
    }
    const b = r.body;
    if (!b.activated || !this.productMatches(b.meta)) {
      const msg = String(b.error || '');
      const error = /limit/i.test(msg) ? 'This key is already active on the maximum number of PCs. Deactivate it on another PC first.'
        : /expired|disabled/i.test(msg) || /expired|disabled/.test(b.license_key?.status || '') ? 'This subscription has ended. Renew it to keep using Pro.'
        : !this.productMatches(b.meta) && b.activated ? 'This key is for a different product.'
        : 'That key wasn\'t recognised. Check for typos and try again.';
      log.warn('licence activation refused', { reason: msg.slice(0, 120) });
      return { ok: false, error };
    }
    this.state = { ...this.state, key, instanceId: b.instance?.id || '', status: 'active', validatedAt: Date.now() };
    this.save();
    log.info('licence activated');
    return { ok: true };
  }

  // re-check once a day; keep Pro through short outages (OFFLINE_GRACE_MS)
  async refresh(force = false) {
    const s = this.state;
    if (!s.key || (!force && Date.now() - s.validatedAt < REVALIDATE_MS)) return this.summary();
    try {
      const r = await this.call('validate', { license_key: s.key, instance_id: s.instanceId });
      const status = r.body.license_key?.status;
      if (r.body.valid && status === 'active' && this.productMatches(r.body.meta)) {
        s.status = 'active';
        s.validatedAt = Date.now();
      } else if (r.ok || r.body.valid === false) {
        s.status = status || 'invalid';            // expired, disabled, or deactivated elsewhere
        log.info('licence no longer active', { status: s.status });
      }
      this.save();
    } catch {
      log.warn('licence check failed, staying in grace period');
    }
    return this.summary();
  }

  async deactivate() {
    const s = this.state;
    if (s.key && s.instanceId) {
      try { await this.call('deactivate', { license_key: s.key, instance_id: s.instanceId }); } catch { /* offline: forget locally anyway */ }
    }
    this.state = { ...this.state, key: '', instanceId: '', status: 'free', validatedAt: 0 };
    this.save();
    return this.summary();
  }
}

module.exports = { License, FREE_SECONDS };
