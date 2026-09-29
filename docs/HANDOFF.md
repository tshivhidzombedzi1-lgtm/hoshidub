# Hoshidub: project handoff

Read this first if you are a new session (human or AI) picking up the project. It records what exists, what works, what is left, and the rules the owner has set. Last updated 2026-09-29.

## 0. Next agent: start here

The owner is moving the project onto his Hostinger hosting and continuing with a new agent there. You have no memory of earlier sessions, and this file is the memory. Everything below is committed in git (latest commits: the Hoshidub rename in the app, release settings in `package.json`, the "My account" link).

**What's live right now:** the website at https://grey-woodpecker-803820.hostingersite.com (Hostinger Business plan, static files in `public_html`, built from `website/` with `npm run package` → `website/release/hoshidub-website-static.zip`).

**Your job, in this order** (tick each off with the owner; one step per message, short and plain):

1. **Domain.** Help him buy `hoshidub.com` (and `hoshidub.app` if he wants) in hPanel → Domains, then connect it to the existing website and make sure SSL is on. He buys it himself. Afterwards `site.url` in `website/src/config.js` and `site` in `website/astro.config.mjs` are already `https://hoshidub.com`, so no code change is needed.
2. **Lemon Squeezy store.** Guide him through sign-up and creating the store "Hoshidub": product **Hoshidub Pro** with two variants, **$6.99/month** and **$49/year**, with **licence keys enabled** (activation limit: ask him, 2 PCs is a sensible default). Optional: a "pay what you want" tip product. He must give you:
   - the **checkout links** (monthly, yearly, and tip) → `website/src/config.js` (`proMonthly`, `proYearly`, `tipCheckout`);
   - the **product ID** and a checkout link → `package.json` `dubit.productId` and `dubit.checkoutUrl` (the app reads them through `src/main/paths.js`).
   Then run `npm run package` in `website/`, and he uploads the new static zip (extract into `public_html`, overwrite). Verify the live site with `node tools/shots.mjs <live url> <dir>`.
3. **Tip links.** If he makes Ko-fi or PayPal.me pages, put them in `config.js` (`kofi`, `paypal`), plus a business email (`email`) if he sets one up in hPanel → Emails.
4. **App download** (needs his **Windows PC**, not the server; see §7):
   - `dist/Hoshidub-Setup-0.1.0.exe` (115 MB) was built on 2026-09-29 and is VMP-signed (`python -m castlabs_evs.vmp verify-pkg dist/win-unpacked` → "Signature is valid: streaming, 1387 days left"). It is **not ready for the public yet**: `dubit.runtimeBase`, `productId` and `checkoutUrl` are still empty, so on another PC it would stall at first-run setup. It's fine for testing on the owner's PC, which already has the runtime.
   - The runtime pack (`dist/runtime/*`, 2.88 GB in two parts) and the installer must be hosted publicly. Recommended: a GitHub repo he creates, with a Release. Set `package.json` `dubit.runtimeBase` to the release download URL, add the Lemon Squeezy settings, rebuild with `npm run dist`, upload.
   - Then set `links.download` in `website/src/config.js`, run `npm run package`, and he re-uploads the website.
5. Then continue with §5 "Not done yet", items 4 onwards.

**Don't:** put the project source in `public_html` (it would be public); build accounts or a database (licensing is Lemon Squeezy, customer self-service is its "My Orders" page, linked as "My account"); start GPU work on his PC without asking.

## 1. Who and what

- **Owner:** Tshivhidzo "Moss" Mbedzi, founder and director of **MCP Labs**, Pretoria, South Africa. Public links only: LinkedIn `https://www.linkedin.com/in/tshivhidzo-mbedzi-a74040233/`, YouTube `https://www.youtube.com/@FTMORangeBreakoutProea`, Discord `https://discord.gg/5SBWbgG7Xp`. Never publish his phone, personal email or home address.
- **Product:** **Hoshidub**, "Don't read it. Dub it." A Windows desktop browser built for anime. You watch a show on a streaming service you already pay for (Crunchyroll first), press **Dub**, and every character speaks English in their own voice, live, while the soundtrack stays at full volume. **Hoshi** is a 3D anime companion who watches along, chats about the episode out loud and never spoils anything.
- **Goal:** a paid product (monthly licence). Free: 30 minutes of dubbing a day. Pro: **$6.99/month or $49/year**. Cloud (for laptops without a gaming GPU): $11.99/month, planned for 2027.
- **How to talk to the owner:** he writes short, quick, often voice-typed messages. Keep replies short and plain, one clear next step at a time. Long plans lose him. He wants premium quality, real testing, and his name and MCP Labs credited everywhere.

## 2. Hard rules (non-negotiable)

1. **Never bypass DRM, copy protection or bot checks** (Cloudflare "verify you are human" included). The app plays each service in its normal player, captures only the player's audio, and reads subtitle files the player already receives. It never records, saves or decrypts video.
2. **Never type the owner's passwords or card details** into anything, and never create accounts or make purchases for him (domains, Lemon Squeezy, GitHub, code signing, castLabs EVS). He does those; you guide him step by step.
3. **Keep his GPU free unless he says otherwise.** He uses it for other work. Don't start the app, the Python engine or Hoshi's brain without asking.
4. **Don't steal focus.** Tests open windows off-screen (`KOE_TEST_INACTIVE`); screenshots and recordings run headless.
5. **Report honestly.** Say what was tested and what wasn't.

## 3. Where things are

| Thing | Location |
|---|---|
| Project (git repo, all committed) | `C:\Users\mbedz\anime-dub\koe` (internal code name "koe"; env vars are `KOE_*`) |
| Python venv (CUDA PyTorch cu128 for the RTX 5070 Ti) | `C:\Users\mbedz\anime-dub\.venv` |
| Installed-app data and models | `%LOCALAPPDATA%\Hoshidub\` (builds before the rename used `DubIt`; `src/main/paths.js` moves it over once) |
| Live website (Hostinger Business plan, static) | https://grey-woodpecker-803820.hostingersite.com |
| Website source | `website/` (Astro) |
| Website build brief (brand, design, copy, pricing) | `docs/WEBSITE_BRIEF.md` |
| Brand kit (logo, icon, Hoshi GLB, screenshots) | `brand/` |
| Business plan | https://claude.ai/artifact/1zPV7C261C89XgmgxQWnng |

There is **no git remote yet**. The owner still needs to create a (private) GitHub repo.

## 4. How the app works

```
Electron (castLabs ECS v44.1.0+wvcus, Widevine, VMP-signed)
 ├─ glass UI window (src/ui): sidebar, address bar, Dub | Hoshi side panel, settings
 ├─ browser view (WebContentsView, session persist:koe): the streaming site
 └─ Python engine (engine/koe_engine.py) over a local WebSocket (127.0.0.1, random port + token)
```

- **Audio:** `session.setDisplayMediaRequestHandler` captures only the player frame's audio (`enableLocalEcho: false`). The UI mixes it again: the dialogue ducker (`src/ui/js/ducker.js`) lowers only the Japanese voice band in the mid channel (about -15 dB) so music and effects stay within 2 dB. Full-mix ducking was rejected by the owner ("music gets lost").
- **Two dub modes:**
  - **Subtitles mode (zero delay):** the official subtitle file is read ahead of time. On Crunchyroll the soft-sub list is in the JSON from `/playback/v3/<id>/web/.../play`, read through `webContents.debugger` (`Network.getResponseBody`; the main page's sessionId is `""` and must be sent as `undefined`). The ASS `Name` field carries character names, so each name gets one consistent voice (Cast). Lines are pre-rendered and spoken on cue.
  - **By-ear mode:** faster-whisper large-v2 translates live (about 0.7 to 1.2 s behind on GPU); SpeakerTracker plus voice pitch pick the voices.
- **Voices:** Kokoro-82M, running locally.
- **Hoshi:** `engine/buddy.py`. Brain Qwen3-4B-Instruct (4-bit, bitsandbytes), ears faster-whisper small, voice Kokoro `af_sky`. The spoiler shield blocks words that appear only in future subtitle lines. Her memory is a JSON file on the PC. Personality: `engine/character/hoshi.yaml`. Avatar: `src/ui/models/hoshi.glb` (Meshy model, merged and compressed to 5.2 MB) rendered with three.js (`src/ui/js/hoshi3d.src.js`, bundled with `npm run build:hoshi`).
- **Downloads on first run** (`engine/packs.py`, size- and SHA-256-checked, resumable): `core` plus `voices-en` (~336 MB, required), `ear` (3.1 GB, optional), `hoshi` (~3.2 GB, optional). The Python runtime itself (2.88 GB in two parts) is downloaded by `src/main/runtime.js` from `package.json` → `dubit.runtimeBase`.
- **Licence:** `src/main/license.js` uses the Lemon Squeezy public licence API (activate, validate, deactivate), with 7 days of offline grace. There is **no own account system or database**, by design: Lemon Squeezy stores the customers, emails the keys and runs subscription management.
- **Ad blocker:** Ghostery (`src/main/adblock.js`), with a per-site toggle on the toolbar shield.
- **Adaptive glass:** samples the page's colours every second and switches the UI between dark and light.

## 5. Status

### Done and verified
- Real Crunchyroll session (the owner logged in himself): 30/30 lines matched the official subtitles; zero delay with Cast.
- Glass UI, clickable toolbar (checked with a WM_NCHITTEST test), ad blocker, adaptive glass, licence flow, first-run setup, fresh-PC install test, Hoshi's chat UI and 3D avatar.
- Tests: `npm test` runs unit, engine (pytest) and end-to-end (Playwright, off-screen) suites; they pass.
- **Website live** on Hostinger: 10 pages, 3D Hoshi, a 44 s "How it works" video, strict security headers, HTTPS, clean URLs, a 404 page. Checked on the live server on desktop and phone.

### Not done yet (in order)
1. **Domain:** `hoshidub.com` and `hoshidub.app` were unregistered on 2026-09-29. The owner buys them, then connects the domain to the Hostinger site in hPanel.
2. **Lemon Squeezy store (owner):** Pro product with monthly $6.99 and yearly $49 variants, licence keys turned on. Then:
   - put the checkout links in `website/src/config.js` (`proMonthly`, `proYearly`), plus the tip links (`kofi`, `paypal`, `tipCheckout`) and a business email if he has them;
   - put the product ID and checkout link into the app: `package.json` → `dubit.productId` and `dubit.checkoutUrl` (read by `src/main/paths.js`; env vars `KOE_PRODUCT_ID` / `KOE_CHECKOUT_URL` override them for tests), then rebuild the installer.
3. **App download:**
   - Build with `npm run dist` → `dist/Hoshidub-Setup-0.1.0.exe` (about 110 MB). Users download only this; on first run the app fetches the runtime pack (from `dubit.runtimeBase`) and the models (straight from Hugging Face) itself. Building needs **Windows**, the castLabs Electron in `node_modules`, and the owner's EVS login for VMP signing (`tools/after-pack.js` runs `python -m castlabs_evs.vmp -n sign-pkg`). An unsigned build fails on Crunchyroll with error KAT-6005.
   - Host the runtime pack (`dist/runtime/*`, 2.88 GB in two parts) and the installer publicly; **GitHub Releases** is recommended (2 GB per file limit; shared hosting isn't meant for multi-gigabyte downloads). Set `dubit.runtimeBase`, rebuild, then set `links.download` in `website/src/config.js` and re-upload the website.
   - The owner's internet is slow (about 87 KB/s measured for downloads), so a 3 GB upload can take many hours. Plan it overnight.
4. **Code-signing certificate** (owner's choice), so Windows SmartScreen stops warning.
5. **Legal:** a lawyer should review `/privacy` and `/terms`; the owner decides the refund policy and how many PCs one licence covers. Replace the Mount Fuji background photo (`src/ui/img/fuji.webp`) with a licensed one. Trademark check on "Hoshidub".
6. **Hoshi real-brain test:** her brain is downloaded and verified but hasn't had a full spoken-conversation test yet (it was held back to keep the GPU free).
7. **Later features:** more languages (Spanish, Portuguese, Hindi, French), a full browser (tabs, bookmarks, history), an in-app tip button, more Hoshi animations (Idle, Wave, Cheer, Thinking; or a VRoid VRM for lip-sync), and a real screen-recorded demo video using a clip the owner has rights to.

## 6. Website

- Astro 7 static site in `website/`. `npm run dev` for local work; `npm run package` builds:
  - `release/hoshidub-website-static.zip`: **what is live.** The built site plus `.htaccess` (HTTPS, clean URLs, 404, security headers, caching, compression). Upload it to Hostinger and extract into `public_html`.
  - `release/hoshidub-website-node.zip`: the same site with `server.js` for Node hosting or a VPS.
- All owner-supplied links are in `website/src/config.js`. Empty links show "Opening soon" or fall back to the Discord beta, so nothing breaks.
- Security headers are shared by `server.js` and the `.htaccess` through `website/security.js`. Every page script is an external file (`assetsInlineLimit: 0`), so the CSP allows no inline scripts. Keep it that way.
- `node tools/shots.mjs <baseUrl> <outDir>` takes headless full-page screenshots of every page (desktop and phone) and reports console errors and sideways scrolling. Run it against the live URL after every upload.
- `node tools/video/record.mjs` re-records the "How it works" video from `tools/video/reel.html` (needs Edge and ffmpeg).

## 7. Important: what a server can and can't do

- The Hostinger hosting **only serves the website**. The app is a Windows program that runs on each viewer's own PC, and so do the voices and Hoshi.
- Building the installer, VMP signing and testing the app need **the owner's Windows PC** (castLabs Electron, his EVS login, an NVIDIA GPU). A Linux server can edit code and the website, but can't produce or test the Windows installer.
- **Never put the project source in `public_html`**: anything there can be downloaded by anyone. Keep the source in a private GitHub repo or a private folder.

## 8. Lessons already learned (don't repeat)

- Crunchyroll in Playwright hits a Cloudflare wall; live tests must be done by the owner by hand.
- WebView2 has no Widevine; stock Electron fails VMP. That's why the app uses castLabs ECS plus EVS signing. VMP signing must run in electron-builder's `afterSign` (signtool invalidates an earlier signature).
- On Windows, controls inside a window-drag region don't receive clicks: only empty elements may be drag regions.
- Git's GNU tar can't read zip files; use `C:\Windows\System32\tar.exe`.
- Two downloads writing the same file corrupted Hoshi's brain once; `packs.py` now locks files and verifies size and SHA-256.
- Chatterbox pins torch 2.6: install it with `--no-deps` to keep cu128 torch.
- Git Bash rewrites arguments that start with `/` into Windows paths; tools take page names without slashes.
