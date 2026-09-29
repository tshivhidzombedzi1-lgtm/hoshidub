# Hoshidub website — build brief

> **For the AI or developer building the website.** This file is your full brief: what to build, how it must look and feel, the words to use, and the quality bar it has to pass. Read it top to bottom before writing code. Everything you need is in this repo; ask the owner only about items marked **OWNER DECIDES**.

---

## 1. Your job

Build the public website for **Hoshidub**, a Windows desktop app that lets people watch anime and hear it in English, live, with a separate voice for every character, plus **Hoshi**, an animated 3D anime companion who watches along.

The website must:

1. Make a first-time visitor understand the product in **5 seconds** (hero + one demo).
2. Make them **want Hoshi**. She is the brand, the mascot and the reason people share it.
3. Convert: **Download (free)** is the primary action; **Get Pro** is the secondary one.
4. Look and feel like a premium product from a top studio, matching the app's **Liquid Glass** design (see §5).
5. Load fast, work on phones, meet WCAG 2.2 AA, and rank for anime-dub searches.

Domain: **hoshidub.com** (main) and **hoshidub.app** (redirects to .com). **OWNER DECIDES:** confirm both are registered before launch.

---

## 2. The product in one paragraph

Hoshidub is a browser built for anime. You open your streaming service (for example Crunchyroll, with your own account), press **Dub**, and every character speaks English in their own voice. When a show has official English subtitles, Hoshidub reads them ahead of time and voices each line **the instant it appears** (0 s delay). When there are no subtitles, it translates by ear about one second behind. Only the Japanese *voices* are lowered, so music and effects stay at full volume. It runs on the user's own PC: no account, no cloud, no recording or saving of video. **Hoshi**, a 3D anime girl, lives in the app's side panel and on its home screen: she reacts to scenes, answers questions about the episode ("who is that?", "what did I miss?") out loud, remembers the viewer, and **never spoils anything**, because she only knows the episode up to the current moment.

**Made by** Tshivhidzo (Moss) Mbedzi, founder of **MCP Labs**, Pretoria, South Africa.

---

## 3. Audience and positioning

| | |
|---|---|
| **Primary audience** | Anime fans 16–35 who watch subtitled simulcasts and would rather listen: while cooking, gaming, tired, or watching with family who can't read subtitles fast enough. |
| **Secondary** | Latin America, India and South-East Asia fans (future languages); VTuber and anime creators (affiliates). |
| **Core promise** | *Don't read it. Dub it.* Every character, every episode, in English, instantly. |
| **Why us** | Official-subtitle accuracy, a consistent voice per character, zero delay, soundtrack stays full, and Hoshi. |
| **Tone** | Warm, playful, confident. A friend who loves anime, never a corporation. Short sentences. No hype words ("revolutionary", "game-changing"). |

**Legal positioning (must follow).** Say "works with the streaming services you already pay for". **Never** use Crunchyroll's (or any service's) logo, name in headlines or ads, or footage. Mention service names only in the FAQ, factually. Footer line: *"Hoshidub is not affiliated with any streaming service. All trademarks belong to their owners."*

---

## 4. Brand

### Name and wordmark
- Always **Hoshidub**: one word, capital H. Never "HoshiDub", "Hoshi Dub" or "HOSHIDUB" in body text.
- The mascot is **Hoshi** (星, "star"). In ads and store listings lead with **Hoshidub**, not "Hoshi" alone (an unrelated AI companion app called "Hoshi" exists).
- Slogan: **Don't read it. Dub it.** Alternates: *Every character. Every episode. In English, instantly.* · *Your anime, your voice.*

### Logo
| File | Use |
|---|---|
| `brand/logo-mark.svg` | App-icon style mark: white sound-wave on a pink→violet→blue rounded square. Favicon, app tiles, social avatars. |
| `brand/logo-wave-mono.svg` | One-colour sound-wave (uses `currentColor`). Nav bar next to the wordmark, footers, dark/light surfaces. |
| `brand/icon-512.png`, `brand/icon.ico` | Raster versions. |

Wordmark: set "Hoshidub" in **Inter 700**, letter-spacing −0.02em, next to the wave mark. Minimum clear space around the logo = the height of one wave bar.

### Colour tokens (exact values from the app, `src/ui/styles/tokens.css`)

Dark theme (default):

| Token | Value | Use |
|---|---|---|
| `--base` | `#0c0c12` | Page background base |
| `--glass-tint` | `rgba(34,34,44,0.46)` | Glass panels |
| `--glass-tint-strong` | `rgba(28,28,36,0.72)` | Cards, modals |
| `--glass-edge` | `rgba(255,255,255,0.16)` | Glass rim |
| `--glass-specular` | `rgba(255,255,255,0.55)` | Top-left rim highlight |
| `--text` | `#f5f5f7` | Primary text |
| `--text-2` | `rgba(235,235,245,0.72)` | Secondary text |
| `--accent` | `#0a84ff` | Links, primary buttons |
| `--success` | `#30d158` | Status "on" |
| `--scrim` | `rgba(12,10,22,0.52)` | Over background photos |

Light theme:

| Token | Value |
|---|---|
| `--base` | `#eef0f6` |
| `--glass-tint` | `rgba(255,255,255,0.5)` |
| `--glass-tint-strong` | `rgba(255,255,255,0.78)` |
| `--text` | `#1d1d1f` |
| `--text-2` | `rgba(29,29,31,0.74)` |
| `--accent` | `#0071e3` |
| `--scrim` | `rgba(250,247,255,0.42)` |

Brand gradient (logo, Hoshi's hair, the Dub button glow): `#ff6b9d → #c38bff → #6ba8ff` (pink → violet → blue). The "live" glow is a slowly rotating conic gradient: `#ff6b9d, #ffb86b, #7cf0c5, #6ba8ff, #c38bff`. Use the gradient **sparingly**: the logo, one hero accent, and the primary CTA's hover glow. It's the brand's single bold move; keep everything around it calm.

Support **both** light and dark themes via `prefers-color-scheme`, with a manual toggle. Contrast of all text ≥ 4.5:1 on its actual background, including over glass.

### Typography
- **Inter** (variable, the file is in `src/ui/fonts/Inter.woff2`; also on Google Fonts). Fallback `"Segoe UI", system-ui, sans-serif`.
- Scale: display 56/60 → 34 px on mobile (weight 700, letter-spacing −0.035em); H2 34 px (700, −0.02em); H3 20 px (650); body 17 px / 1.55; small 13 px. Headlines use `text-wrap: balance`.
- Body line length 60–70 characters.

### Hoshi (mascot)
- **Look:** 18-year-old anime girl, long pastel pink-to-lavender hair in two high twin tails, short bangs, gold star hair clips, big violet eyes, oversized dark indigo hoodie with the white Hoshidub sound-wave on the chest, black pleated skirt, white thigh-high socks, pink-and-white sneakers.
- **Personality:** playful, quick-witted anime superfan; warm and a little teasing, never mean; real excitement, never fake; **never spoils**. Speaks in one or two short sentences.
- **Her voice on the site:** she may "say" a line in a speech bubble in the hero and in the Hoshi section. Example lines: *"Hi! I'm Hoshi. I'll watch with you, and I promise I'll never spoil a thing."* · *"Who's that guy with the sword? Ask me, I was paying attention."* · *"Oof. That one hurts."*
- **3D model:** `brand/hoshi.glb` (5.2 MB, 40k triangles, WebP textures, Mixamo skeleton). Animations inside: `Agree_Gesture` (13 s, use as talk/greet), `Walking`, `Running`. Render with **three.js** (`GLTFLoader`) or Google's `<model-viewer>` on a **transparent** background, camera slightly above eye level, soft key light plus a violet rim light (the app uses a hemisphere light `#fff4fb/#8a7bb8` + key `#ffffff` + rim `#c9a8ff`). **Lazy-load** her (only when the hero is on screen), show a static poster image first, and fall back to that image when WebGL is unavailable or `prefers-reduced-motion` is set. Never block first paint on the model.
- **Don't:** redraw her in a different style, change her outfit colours, sexualise her, show her with other franchises' characters, or put words in her mouth that spoil shows.

### Imagery
- Background mood: dawn-lit Japan (the app uses Mount Fuji at sunrise, `brand/background-fuji.webp`). **⚠️ That photo's licence is unconfirmed.** Replace it with a licensed or free-to-use image (Unsplash / own photo) of similar mood before launch. **OWNER DECIDES.**
- **Never** use streaming services' screenshots, anime key art or character art you don't own. Demo visuals must be: the app interface (screenshots in `brand/screenshots/`), Hoshi, and original or licensed footage only.

---

## 5. Design language: Liquid Glass

The app follows Apple's **Liquid Glass** (iOS 26) look. The website must feel like it came from the same studio.

**Recipe (CSS):**
```css
.glass {
  background: var(--glass-tint);
  border-radius: 26px;
  box-shadow: 0 10px 40px rgba(0,0,0,.38), 0 2px 8px rgba(0,0,0,.22);
  backdrop-filter: blur(22px) saturate(175%);
  position: relative; isolation: isolate;
}
.glass::before {            /* 1px specular rim, lit from the top-left */
  content: ""; position: absolute; inset: 0; border-radius: inherit; padding: 1px;
  background: linear-gradient(135deg, var(--glass-specular) 0%, var(--glass-edge) 22%, transparent 48%, var(--glass-edge) 78%, rgba(255,255,255,.28) 100%);
  -webkit-mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
  -webkit-mask-composite: xor; mask-composite: exclude; pointer-events: none;
}
.glass::after {             /* thickness: soft inner light */
  content: ""; position: absolute; inset: 0; border-radius: inherit; pointer-events: none;
  box-shadow: inset 0 1px 1px rgba(255,255,255,.18), inset 0 -8px 24px rgba(255,255,255,.03);
}
```
- Optional **refraction** at glass edges (Chromium): an SVG `feDisplacementMap` in `backdrop-filter`. See `src/ui/js/glass.js` for the generator. Use it only on 1–3 hero elements, and never let it hurt performance.
- Glass needs something colourful behind it: a softly blurred, colourful background (photo + a grain overlay at 7% so gradients don't band).
- Honour `prefers-reduced-transparency` (solid surfaces) and `prefers-reduced-motion` (no floating or parallax).
- Radius scale: 26 px panels, 20 px cards, 12 px controls, 999 px pills. Motion: 160 ms fast / 320 ms medium, easing `cubic-bezier(0.32, 0.72, 0, 1)`.
- Buttons: pill-shaped, 44 px minimum touch height. Primary = solid accent. Hero CTA may carry the rotating brand-gradient rim on hover.

**Reference screenshots** (match this quality): `brand/screenshots/02-home.png` (home, light), `14-hoshi-panel.png` (Hoshi and chat), `12-glass-dark-page.png` / `13-glass-light-page.png` (adaptive glass), `09-upgrade.png` (upgrade sheet), `10-setup.png` (first-run), `03-settings.png`.

Avoid the "AI-generated website" look: no purple-to-blue gradient hero on white, no emoji section icons, no centre-everything layouts, no identical rounded cards with icon-title-text repeated six times. Use asymmetric layouts, real product imagery, and Hoshi as the character who guides the page.

---

## 6. Site map and page specs

### 6.1 Home `/`
1. **Nav** (glass, sticky): wave mark + "Hoshidub" · Features · Hoshi · Pricing · FAQ · About · **Download** (primary pill).
2. **Hero:**
   - Headline: **Watch in Japanese. Hear it in English.**
   - Sub: *Hoshidub gives every character their own English voice, live, the moment they speak. Hoshi watches along.*
   - CTAs: **Download for Windows (free)** · *See it in action* (scrolls to the demo).
   - Right side: **Hoshi in 3D** on glass, with a speech bubble: *"Hi! I'm Hoshi. I'll never spoil a thing."*
   - Under the CTAs, small: *Windows 10/11 · works with the streaming you already pay for · no account needed*.
3. **Demo:** a 30–45 s video of the app (interface + original or licensed footage) showing subtitles → press Dub → English voices, the transcript filling in, and Hoshi reacting. **OWNER DECIDES:** provide the video; until then use the screenshots as a carousel.
4. **How it works (3 steps):** Open your show → Press Dub → Every character speaks English. (Numbered, because it's a real sequence.)
5. **Features:**
   - **On cue, not behind:** official subtitles voiced the instant they appear.
   - **A voice for every character:** they keep it all episode.
   - **The soundtrack stays full:** only the Japanese voices step back.
   - **Private by design:** runs on your PC, never records video.
   - **Built-in ad and tracker blocker.**
   - **Glass that follows your show:** the app turns dark or light with the scene.
6. **Meet Hoshi** (dedicated, emotional section): large Hoshi, her personality, 3 example chat bubbles (a question about the episode, a hype reaction, a "no spoilers" reply). Copy: *Your anime friend who watches with you. Ask her anything about the episode, and she answers out loud. She remembers you. She never spoils anything.*
7. **Languages** (roadmap tease): English today; Spanish, Portuguese, Hindi and French next. Include a waitlist email field. **OWNER DECIDES:** email tool.
8. **Pricing** (see §7).
9. **FAQ** (see §8).
10. **Final CTA:** *Don't read it. Dub it.* + Download.
11. **Footer:** © 2026 MCP Labs · *Hoshidub is a product of MCP Labs* · *Created by Tshivhidzo (Moss) Mbedzi* · Privacy · Terms · Support · Press kit · social links (LinkedIn `https://www.linkedin.com/in/tshivhidzo-mbedzi-a74040233/`, YouTube `https://www.youtube.com/@FTMORangeBreakoutProea`, Discord `https://discord.gg/5SBWbgG7Xp`) · the not-affiliated line from §3.

### 6.2 Pricing `/pricing`
The same table as the home section, plus a plan comparison and billing FAQ.

### 6.3 Download `/download`
- Big Download button for the latest `Hoshidub-Setup-x.y.z.exe` (hosted on GitHub Releases; link via the releases API so it always points to the newest version).
- **System requirements:** Windows 10/11 64-bit; recommended an NVIDIA RTX graphics card with 6 GB+ VRAM for fast dubbing and Hoshi; 8 GB RAM; about 4 GB of disk for the voices and engine (plus 3 GB optional for translate-by-ear, 3.2 GB optional for Hoshi); internet for the first-run download.
- What happens on first run (a 3-step visual: install → download voices → press Dub).
- A SmartScreen note until the installer is code-signed. **OWNER DECIDES:** code-signing certificate.

### 6.4 Legal: `/privacy`, `/terms`
- Privacy: no account; no analytics in the app; everything runs locally; Hoshi's memory stays on the PC; the licence check sends only the key and an instance ID to Lemon Squeezy; the website uses privacy-friendly analytics only (see §9).
- Terms: personal use with your own streaming subscriptions; no DRM circumvention; no recording or redistribution. **OWNER DECIDES:** have a lawyer review both before launch.

### 6.5 Support `/support` and Press `/press`
Support: FAQ + Discord link + contact email (**OWNER DECIDES**). Press kit: logo files, Hoshi renders, screenshots, a one-paragraph description, and the founder bio from §6.6.

### 6.6 About and founder `/about` (required)
The founder must be visible: this page, the footer credit, the press kit, and the `Organization`/`Person` structured data.

**Founder:** **Tshivhidzo (Moss) Mbedzi**, Founder & Director of **MCP Labs**, Pretoria, South Africa.
**Photo:** **OWNER DECIDES**: a friendly headshot (square, at least 800×800). Until provided, show Hoshi beside the bio instead of a placeholder silhouette.
**Links:** LinkedIn `https://www.linkedin.com/in/tshivhidzo-mbedzi-a74040233/` · YouTube `https://www.youtube.com/@FTMORangeBreakoutProea` · Discord `https://discord.gg/5SBWbgG7Xp`

**Short bio (footer, press, store listings):**
> Hoshidub is made by Tshivhidzo "Moss" Mbedzi, founder of MCP Labs in Pretoria, South Africa. Moss builds AI products that make advanced technology feel simple, from algorithmic trading systems used by traders in more than 20 countries to Hoshidub, the app that lets anyone watch anime in their own language.

**Long bio (About page):**
> Tshivhidzo "Moss" Mbedzi is a South African technology entrepreneur and the founder and director of MCP Labs, an independent AI lab in Pretoria focused on automation, AI agents and consumer AI products. He built Hoshidub because anime deserves to be watched, not read: a live dub that gives every character a voice, and a companion, Hoshi, so nobody has to watch alone.
>
> Before Hoshidub, Moss founded TSHIVHIDZO Trading Solutions and published more than 14 algorithmic trading systems on the MQL5 marketplace, used by traders across 20+ countries. He also runs The IT Guy E-Waste Solutions, providing IT support and responsible e-waste recycling in Limpopo. He holds a Higher Certificate in Information Technology from IIE Rosebank College and completed the Introduction to Information Security course at UNISA's Centre for Software Engineering. That security-first training shows in Hoshidub's design: it runs on your own PC, never records video, and keeps your data private.
>
> His mission is simple: make sophisticated technology accessible to everyone.

**About MCP Labs (one line):** *MCP Labs is an independent AI lab in Pretoria, South Africa, building automation systems and consumer AI products. Hoshidub is its first consumer app.*

**Structured data:** add `Organization` (MCP Labs, Pretoria, ZA, `sameAs` LinkedIn) and `Person` (Tshivhidzo Mbedzi, jobTitle "Founder & Director", worksFor MCP Labs, `sameAs` the links above) in JSON-LD on `/about`, and set the `SoftwareApplication` `publisher` to MCP Labs.

Don't publish personal contact details (phone, personal email or home location) beyond the links above. **OWNER DECIDES** on a public business email (for example hello@hoshidub.com).

---

## 7. Pricing (exact)

| Plan | Price | Includes |
|---|---|---|
| **Free** | $0 | 30 minutes of dubbing a day · translate-by-ear · 2 voices |
| **Pro** | **$6.99 / month** or **$49 / year** (save 40%) | Unlimited dubbing · official-subtitle mode with zero delay · a voice per character · soundtrack-safe mixing · captions · Hoshi |
| **Cloud** *(coming 2027)* | $11.99 / month | Everything in Pro, runs on any laptop without a gaming GPU, premium voices, more languages |

Checkout is **Lemon Squeezy** (merchant of record: handles global tax, emails the licence key). Pro buttons open the Lemon Squeezy checkout overlay. **OWNER DECIDES:** store URL and product/variant IDs. The app activates keys through Lemon Squeezy's public licence API, so the site doesn't need a backend for licensing.

Referral: *Give a month, get a month* (both people get a free month when a friend subscribes). Affiliates: 30% recurring for 12 months via Lemon Squeezy affiliates.

---

## 8. FAQ (use these answers)

- **Does it work with Crunchyroll?** Yes. Open it inside Hoshidub and sign in with your own account. Hoshidub uses the show's official English subtitles when available.
- **Is it legal?** Hoshidub plays the service you already pay for, in its normal player, and listens to the sound like a person in the room. It never records, saves or decrypts video.
- **How is it zero delay?** When a show has official subtitles, Hoshidub reads them ahead of time and prepares each line before it's spoken.
- **Do I need a powerful PC?** An NVIDIA RTX graphics card with 6 GB+ is recommended. A cloud version for any laptop is planned for 2027.
- **Does Hoshi spoil episodes?** No. She only knows what has already happened in the episode, and every reply is checked against what's coming.
- **Is my data sent anywhere?** No. Dubbing, Hoshi and her memory all run on your PC.
- **Which languages?** English now; Spanish, Portuguese, Hindi and French are next.
- **Can I cancel Pro?** Anytime, from the link in your receipt email.

---

## 9. Technical requirements

- **Stack:** a static-first framework (**Astro** recommended; Next.js static export is acceptable). No heavy client framework on content pages. Deploy on the server you're given behind HTTPS with HTTP/2+, Brotli and long-cache immutable assets.
- **Performance budgets (mobile, 4G):** LCP < 2.0 s, CLS < 0.05, INP < 200 ms, total JS < 150 KB before Hoshi loads. The Hoshi model (5.2 MB) and three.js load **only** after first paint and when her section is in view. Serve images as AVIF/WebP with `srcset`.
- **Accessibility:** WCAG 2.2 AA; semantic landmarks; visible focus rings; keyboard-only navigation; alt text; captions on the demo video; honour reduced motion and transparency.
- **SEO:** unique titles and descriptions per page; Open Graph and Twitter cards (Hoshi + wordmark image, 1200×630); `SoftwareApplication` structured data (name Hoshidub, operatingSystem Windows, offers from §7); sitemap.xml; robots.txt; canonical hoshidub.com. Target phrases: "anime English dub app", "live anime dub", "watch anime in English", "AI anime dub".
- **Analytics:** privacy-friendly only (Plausible or Umami). No cookie banner needed if you don't use cookies. Track: Download clicks, Get Pro clicks, demo plays, waitlist signups.
- **Forms:** waitlist and contact go to the tool the owner picks. Never expose API keys in the client.
- **Security:** CSP, HSTS, no inline scripts, dependency audit before deploy (run `npm audit`; Perplexity's `bumblebee` scanner in CI if available).

---

## 10. Quality bar (acceptance checklist)

The site ships only when every box is true:

- [ ] A first-time visitor can say what Hoshidub does within 5 seconds of the hero.
- [ ] Hoshi appears in the hero (3D where supported, poster otherwise) without delaying first paint.
- [ ] Light and dark themes both look deliberate, and glass stays readable on both.
- [ ] Lighthouse mobile: Performance ≥ 90, Accessibility 100, Best Practices ≥ 95, SEO 100.
- [ ] Works at 360 px wide with no horizontal scroll; tap targets ≥ 44 px.
- [ ] Keyboard-only walkthrough reaches every link and button in a logical order.
- [ ] No streaming-service logos, key art or footage anywhere; the not-affiliated line is in the footer.
- [ ] Every CTA works: Download → latest installer; Get Pro → Lemon Squeezy checkout; waitlist stores the email.
- [ ] Copy matches this brief's tone: short, warm, no hype words, no spoilers.
- [ ] Credits present: "A product of MCP Labs" and "Created by Tshivhidzo (Moss) Mbedzi" in the footer, plus the `/about` page with the founder bio, links and JSON-LD from §6.6.

---

## 11. Assets in this repo

| Path | What |
|---|---|
| `brand/logo-mark.svg`, `brand/logo-wave-mono.svg` | Logos |
| `brand/icon-512.png`, `brand/icon.ico` | App icon |
| `brand/hoshi.glb` | Hoshi 3D model with animations |
| `brand/background-fuji.webp` | Mood background (**replace with a licensed image**) |
| `brand/screenshots/*.png` | App interface screenshots for the site and press kit |
| `src/ui/styles/tokens.css`, `glass.css`, `app.css` | The app's real design system (source of truth for colours, glass, motion) |
| `src/ui/js/hoshi3d.src.js` | How the app renders and animates Hoshi (three.js), reusable on the site |
| `src/ui/fonts/Inter.woff2` | Font |
| `docs/` business plan summary lives in the published plan (ask the owner for the link) | |

---

## 12. Do not

- Don't invent features the app doesn't have. Label planned ones "coming soon".
- Don't promise specific dub quality ("sounds like professional voice actors"). Say "natural voices".
- Don't collect personal data beyond an email for the waitlist and support.
- Don't use dark patterns (fake countdowns, pre-ticked boxes, hidden cancellation).
- Don't use "Hoshi" alone as the brand name in page titles, ads or metadata.
