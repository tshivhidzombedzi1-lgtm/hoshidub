# Hoshidub: project handoff

Read this first if you are a new session (human or AI) picking up the project. It records what exists, what works, what is left, and the rules the owner has set. Last updated 2026-09-30.

## 0. Next agent: start here

The owner has handed the rest of the launch to you. You have no memory of earlier sessions, and this file is the memory. Everything is on GitHub (private): code in https://github.com/tshivhidzombedzi1-lgtm/hoshidub, and the signed installer plus the voice engine parts in its **Release v0.1.0** (a private backup; customers can't download from a private repo, so public downloads come from the website). The owner's Apex MQL5 EA is backed up in `apex-ea/` (a separate product; leave it alone unless he asks).

### Latest (2026-09-30 13:08): final installer, engine download moved to hoshidub.com
- `dubit.runtimeBase` is now https://hoshidub.com/downloads/runtime (grey-woodpecker-803820.hostingersite.com no longer resolves from the owner's PC). Rebuilt, VMP-signed, sha256 7d86662044102b4e5363c84c76c9dcb157139d5ca82c712fb296e5e7e42f405a (115,387,932 bytes). Uploaded by the PC agent over SSH to public_html/downloads/Hoshidub-Setup-0.1.0.exe (hash checked on the server), also in release-files/ and Release v0.1.0.
- **Done 15:21 (SAST):** runtime pack v2 is live at https://hoshidub.com/downloads/runtime/: manifest.json (version 2) plus runtime.zip.001-008. All 8 pass `sha256sum -c` on the server against the manifest, the manifest loads over HTTPS, and a Range request returns 206 with no compression. Uploaded with `tools/upload-runtime.sh` (SSH key hoshidub-pc-upload; remove it from ~/.ssh/authorized_keys now that uploads are done). A fresh install's first-run download can now work end to end; still to be tested on a second PC.

### Earlier (2026-09-30 12:31): installer rebuilt with the Stripe licence server
- `dist/Hoshidub-Setup-0.1.0.exe` rebuilt from commit 1d26d56: `licenseApi` = https://hoshidub.com/api/license, "Get Pro" = /api/checkout.php?plan=monthly, VMP-signed (valid, 1387 days), includes `hoshi.yaml`. Unit tests 17/17.
- Uploaded to GitHub Release v0.1.0 (replaces the older asset) and installed on the owner's PC over the old copy (via Explorer).
- Checked: the licence API answers a script/app request with JSON (a fake key gives 404 "license_key not found"; Hostinger's browser check doesn't block it), and checkout redirects (303) to live Stripe checkout.
- **Not yet done:** the owner's activation test with his gift key (activate, deactivate, re-activate), uploading the new exe to `public_html/downloads/`, and the empty `public_html/downloads/runtime/` (manifest + 8 parts from Release v0.1.0 via FTP).

### Decisions already made (don't reopen them)
- **Payments: Stripe** (the owner has a verified Stripe account). **Not Lemon Squeezy.** Earlier docs and code mention Lemon Squeezy; see "Switch to Stripe" below.
- **Licensing: our own small licence server in PHP on the Hostinger hosting** (`website/php/`), because Stripe doesn't issue licence keys. No customer accounts or passwords on the site: customers get their key by email and manage billing in Stripe's customer portal ("My account" link).
- **Downloads are hosted on Hostinger**, next to the site: `public_html/downloads/Hoshidub-Setup-0.1.0.exe` and `public_html/downloads/runtime/` (manifest plus the 8 parts of 400 MB in `dist/runtime`, runtime pack version 2).

### State on 2026-09-30
| Piece | State |
|---|---|
| Website | Live at https://grey-woodpecker-803820.hostingersite.com (static files in `public_html`). Local changes not uploaded yet: Download button → `/downloads/Hoshidub-Setup-0.1.0.exe`, "My account" link, corrected disk requirements. |
| Installer | `dist/Hoshidub-Setup-0.1.0.exe` (115 MB, built 2026-09-30 00:28), VMP-signed ("Signature is valid: streaming, 1387 days left"), also in GitHub Release v0.1.0. Includes: the Crunchyroll fix (ad blocker switches itself off on allowed sites; with it on, the player threw "Maximum call stack size exceeded" and spun at 0:00), Hoshi's `character/hoshi.yaml` (0.1.0 builds before that left it out), and `adopt.js`. `dubit.runtimeBase` = `https://grey-woodpecker-803820.hostingersite.com/downloads/runtime`. It still uses the Lemon Squeezy licence URL. |
| Voice engine parts | `dist/runtime/` (runtime pack **version 2**, 3.13 GB, 8 × 400 MB + manifest; adds accelerate, bitsandbytes, psutil so Hoshi works; check contents with `python tools/check_runtime_pack.py`). In GitHub Release v0.1.0. **Not uploaded to Hostinger yet.** `dist/runtime-web/` is the old version 1: don't use it. |
| Licence server | `website/php/api/` written: `license.php` (activate / validate / deactivate, same JSON shape as Lemon Squeezy, so `src/main/license.js` works unchanged), `stripe-webhook.php` (signature check, creates and emails keys, switches keys off when a subscription ends), `resend.php` ("lost my key"), `lib.php`, `.htaccess`; `website/php/config.sample.php`. **Written but never run: this PC has no PHP.** Test it before going live (PHP 8.1+; `php -S` with a test config and hand-signed webhook payloads). |

### Your job, in this order (one step per message to the owner, short and plain)
1. **Upload the downloads.** `public_html/downloads/` gets the installer, `runtime/` (manifest.json plus runtime.zip.001 to .008) and the `.htaccess` from `website/downloads-htaccess/`. 3.2 GB in total: use FTP (hPanel → Files → FTP accounts; FileZilla), not the browser file manager. Then check that `…/downloads/runtime/manifest.json` loads and a part supports resume: `curl -I -H "Range: bytes=0-99"` should return 206, with no gzip.
2. **Upload the updated website:** `cd website && npm run package` → extract `release/hoshidub-website-static.zip` into `public_html`. Check it with `node tools/shots.mjs <url> <dir>`. Now "Download" works for Free users.
3. **Test on a second Windows PC (the owner does this):** install, first-run download, press Dub. This is the real end-to-end test of the runtime download from Hostinger.
4. **Switch to Stripe:**
   - Test and finish `website/php/` (see above). Add `api/` to the static bundle in `website/tools/package.mjs` (copy `website/php/api` → `release/static/api`).
   - The owner creates in Stripe: product "Hoshidub Pro", prices $6.99/month and $49/year, **Payment Links** for both, the **customer portal** (and its login link), and a **webhook** to `https://<domain>/api/stripe-webhook.php` (the 3 events in `config.sample.php`). He copies `config.sample.php` to `<home>/hoshidub-data/config.php` and pastes the signing secret himself. Never type his secrets.
   - App: add `dubit.licenseApi` to `package.json` (read it in `src/main/paths.js` like the other settings) and use it in `src/main/license.js` instead of the Lemon Squeezy URL. Also fix `refresh()`: when `valid` is false, set the status to `invalid` even if `license_key.status` says `active` (a key deactivated on this PC must stop Pro). Set `dubit.checkoutUrl` to the monthly Payment Link. Rebuild with `npm run dist` (Windows PC, EVS login) and upload the new installer.
   - Website: `website/src/config.js` → `proMonthly`, `proYearly` (Payment Links), `account` (portal login link; empty hides nothing yet, so make `Base.astro` hide "My account" when it's empty), `tipCheckout` (a one-time "pay what you want" Payment Link; the webhook ignores one-time payments). Change the Lemon Squeezy wording to Stripe in `Pricing.astro`, `pricing.astro` (billing FAQ), `privacy.astro`, `terms.astro` and `docs/WEBSITE_BRIEF.md`. Add a "Lost your key?" form (`id="lost-key"`, POST to `/api/resend.php`) on `/support`.
   - Tax: Stripe is not a merchant of record. Tell the owner he is responsible for VAT/sales tax, and suggest Stripe Tax.
   - An admin view is optional: the Stripe dashboard shows payments, and a small password-protected `admin.php` (list and search keys, disable, reset activations, resend) would cover licences.
5. **Solved: the first-launch "download" bug.** When an agent runs inside the **Claude desktop app (an MSIX-packaged app)**, Windows redirects everything its tools write under `%LOCALAPPDATA%` (and `%APPDATA%`) to `%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\...`. The agent's tools see those files at the normal path; programs the owner starts from Explorer don't. The runtime and models created during development were therefore invisible to the installed app, so it offered to download them. Fixed on 2026-09-29 by moving them with `anime-dub/fix-hoshidub-location.cmd`, **run through Explorer**. Rules from now on:
   - Anything the owner's installed app must see goes to real AppData via a process started by Explorer (`Start-Process explorer.exe <script>`), never written directly by agent tools.
   - Test the installed app by launching it through Explorer (a `.lnk` also works), not from agent shells, or you test a different filesystem view.
   - Since commit after 7979980 the app also fixes this itself: `src/main/adopt.js` runs at startup and moves a runtime/models found in `%LOCALAPPDATA%\DubIt` or `%LOCALAPPDATA%\Packages\*\LocalCache\Local\{Hoshidub,DubIt}` into `%LOCALAPPDATA%\Hoshidub` (only what's missing; logged as "moved existing downloads into place"; unit tests in `tests/unit/adopt.test.js`).
   - The installed app only looks for models in `%LOCALAPPDATA%\Hoshidub\models`, not the dev folder `anime-dub/models`.
   - **Fixed 2026-09-30: Hoshi in the installed app.** Runtime pack version 1 lacked accelerate, bitsandbytes and psutil, and the installer lacked `hoshi.yaml`. Both are fixed in the new builds. On the owner's PC they were patched by hand (`anime-dub/fix-hoshi-libraries.cmd`, `fix-hoshi-character.cmd`, run through Explorer). An installed app with runtime v1 doesn't update itself yet: add an update check (compare `dubit-runtime.json` with the online manifest version) before public launch.
   - **Fixed 2026-09-30: Crunchyroll spinning forever.** Cause: the Ghostery ad blocker, not DRM. Debug ports (`--inspect`, `--remote-debugging-port`) do NOT break playback; an earlier note blaming `--inspect` was wrong. The owner's copy has the blocker turned off in settings; the new build handles it automatically (`AdBlock.applyFor`).
   - **Open: "the audio is bad".** The owner compared it with YouTube's translated audio. Ask which part: robotic English voices, Japanese still audible (duck slider defaults to 25%), music pumping, or crackle/sync. Dolby Atmos isn't a fix (YouTube swaps whole voice tracks; we only get the mixed audio).
6. **Domain:** the owner buys `hoshidub.com` and connects it. Then change `dubit.runtimeBase` to `https://hoshidub.com/downloads/runtime` and rebuild, but keep the files reachable on the old address too, because installers already downloaded point there.
7. Then §5 "Not done yet", items 4 onwards.

**Don't:** put the project source in `public_html`; enter the owner's passwords, card details or API secrets anywhere; start GPU work on his PC without asking; publish a build that says "Dub It".

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
- **Licence:** `src/main/license.js` (activate, validate, deactivate; 7 days offline grace) speaks the Lemon Squeezy licence API shape. **Decision 2026-09-29: payments move to Stripe**, and keys come from our own PHP licence server (`website/php/api/`), which answers in the same shape. See §0.
- **Ad blocker:** Ghostery (`src/main/adblock.js`), with a per-site toggle on the toolbar shield.
- **Adaptive glass:** samples the page's colours every second and switches the UI between dark and light.

## 5. Status

### Done and verified
- Real Crunchyroll session (the owner logged in himself): 30/30 lines matched the official subtitles; zero delay with Cast.
- Glass UI, clickable toolbar (checked with a WM_NCHITTEST test), ad blocker, adaptive glass, licence flow, first-run setup, fresh-PC install test, Hoshi's chat UI and 3D avatar.
- Tests: `npm test` runs unit, engine (pytest) and end-to-end (Playwright, off-screen) suites; they pass.
- **Website live** on Hostinger: 10 pages, 3D Hoshi, a 44 s "How it works" video, strict security headers, HTTPS, clean URLs, a 404 page. Checked on the live server on desktop and phone.

### Not done yet (in order; §0 replaces items 1 to 3: Stripe, Hostinger downloads)
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

## Addendum 2026-09-30 (website sizing pass, run on the Hostinger server)
- The site is served from this same server (`~/domains/hoshidub.com/public_html`); "upload" = extract the zip there. Installer is already in `public_html/downloads`; `runtime/` is still empty (the 8 parts are only in the private GitHub Release, and the server has no GitHub login).
- The account is capped at ~105 threads. Builds need `ROLLDOWN_WORKER_THREADS=2 ROLLDOWN_MAX_BLOCKING_THREADS=4 TOKIO_WORKER_THREADS=2 RAYON_NUM_THREADS=2 GOMAXPROCS=1 UV_THREADPOOL_SIZE=1` and `taskset -c 0-1`. Headless Chrome could not open its debug port in that session, so `website/tools/run-shots.sh` (thread-capped screenshots) is untested; the sizing fixes (hero title `min(78px, 9.6cqi)`, wrap-safe buttons, `overflow-wrap`) were made from reading the CSS and are NOT yet checked at the 6 sizes.

### Update 2026-09-30 (later): payments, admin, SEO, Discord (all in website/php and website/src)
- Live on hoshidub.com: Stripe checkout (`/api/checkout.php`), webhook (created via `bin-stripe-setup.php`, LIVE mode), customer portal (`bin-stripe-portal.php`), admin at `/admin` (6 tabs; password stored hashed in the licence DB; first sign-in forces a new password), download counter (`/api/dl.php`), SEO (canonicals, structured data, sitemap, robots), Fuji background.
- Secrets never in git: config and DB live in `~/domains/hoshidub.com/hoshidub-data/`. The Stripe key is read at run time from the MCP Automation `.env` (`stripe_env_file`).
- Tests: `bash website/php/test/run.sh` (60+ checks). Thread-capped host tips are in the addendum above.
- Discord bot (`/hoshidub buy|activate|status|help|faq|download`, `/hoshidub admin setup|lookup|grant|disable|enable|stats|announce`): code is in `website/php/api/discord*.php` and `bin-discord-register.php`. NOT live yet: needs (1) `discord_env_file` and `discord_forward_secret` in config.php, (2) a small `hoshidub` case + `lib/hoshidub_bridge.php` in the MCP Automation app (`controllers/api.php`, backup `api.php.bak-20260930-hoshidub`), (3) `php bin-discord-register.php` (merges /hoshidub into the server's existing commands). The web PHP on hoshidub.com (8.3) has no libsodium, so the MCP endpoint forwards with a shared-secret HMAC.

### Discord (2026-09-30, final)
The Hoshidub community lives in its own server "Hoshidub" (id in config.php `discord_guild_id`, invite https://discord.gg/bs7xXRbTaW). Discord does not let bots create servers, so the owner creates an empty one, invites the bot with permissions=8, and `php website/php/bin-discord-build.php <server id>` builds roles, channels, topics, permissions, rules/welcome/FAQ/announcement posts, icon and Community features (refuses servers with members). Then `php website/php/bin-discord-register.php` registers /hoshidub there. Never build inside an existing community. Playbook skill: ~/.claude/skills/discord-server-build.
