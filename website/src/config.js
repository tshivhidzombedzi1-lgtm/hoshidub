// Everything the owner fills in before launch lives here. Empty links show as "coming soon" instead of breaking.
export const site = {
  name: 'Hoshidub',
  url: 'https://hoshidub.com',
  slogan: "Don't read it. Dub it.",
  description: 'Watch anime in Japanese and hear it in English, live, with a voice for every character and Hoshi, the anime friend who watches with you.',
  version: '0.1.0',
};

export const links = {
  // latest Windows installer, hosted next to the site in public_html/downloads (see docs/HANDOFF.md)
  download: '/api/dl.php',   // counts the download, then sends /downloads/Hoshidub-Setup-0.1.0.exe
  // Stripe Payment Links for Pro (monthly $6.99, yearly $49); empty shows "coming soon"
  proMonthly: '/api/checkout.php?plan=monthly',
  proYearly: '/api/checkout.php?plan=yearly',
  // Stripe customer-portal login link (https://billing.stripe.com/p/login/...): update card, invoices, cancel. Empty hides the "My account" links.
  account: 'https://billing.stripe.com/p/login/4gM3cwgwXcH17MW3MvbAs00',
  // tip jar
  kofi: '',             // e.g. https://ko-fi.com/hoshidub
  paypal: '',           // e.g. https://paypal.me/yourname
  tipCheckout: '/api/checkout.php?plan=tip&amount=5',      // Stripe one-time "customer chooses price" Payment Link
  discord: 'https://discord.gg/5SBWbgG7Xp',
  youtube: 'https://www.youtube.com/@FTMORangeBreakoutProea',
  linkedin: 'https://www.linkedin.com/in/tshivhidzo-mbedzi-a74040233/',
  email: '',            // e.g. hello@hoshidub.com
};

export const founder = {
  name: 'Tshivhidzo (Moss) Mbedzi',
  short: 'Moss',
  title: 'Founder & Director, MCP Labs',
  place: 'Pretoria, South Africa',
};
