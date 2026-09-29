# Hoshidub

Watch anime in Japanese, hear it in English, live, with a voice for every character and **Hoshi**, a 3D anime companion who watches along. A Windows desktop app by **MCP Labs** (created by Tshivhidzo (Moss) Mbedzi).

- **New to the project?** Start with [`docs/HANDOFF.md`](docs/HANDOFF.md): status, rules, architecture and what's left.
- **Building the website?** Read [`docs/WEBSITE_BRIEF.md`](docs/WEBSITE_BRIEF.md). It's the complete brief: brand, design system, pages, copy, pricing and the quality bar. Brand assets are in [`brand/`](brand/).
- **Working on the app?** Read on.

## What's in the app

| Area | Where |
|---|---|
| Electron main process: window, built-in browser, subtitle discovery, adaptive glass sampling, ad blocker, licence, setup | `src/main/` |
| Glass UI (HTML/CSS/JS), dub mixer, subtitle sync, Hoshi avatar and chat | `src/ui/` |
| Python engine: speech recognition, translation, voices, speaker tracking, Hoshi's brain | `engine/` |
| Hoshi's personality | `engine/character/hoshi.yaml` |
| Tests: unit, engine (pytest), end-to-end (Playwright) | `tests/`, `engine/tests/` |
| Build tools: icon, runtime pack, Hoshi model merge | `tools/` |

Key facts:
- **Electron for Content Security** (castLabs) so DRM video plays. The packaged app is **VMP-signed** with castLabs EVS in `tools/after-pack.js` (runs as electron-builder's `afterSign`). An unsigned build fails on Crunchyroll with error KAT-6005.
- The app **never records or decrypts video**. It captures the player's audio (like listening in the room) and reads subtitle files the player already receives.
- Models download on first run into `%LOCALAPPDATA%\DubIt\models` as packs (`engine/packs.py`): `core` + `voices-en` (required, ~336 MB), `ear` (Whisper large-v2, 3.1 GB, optional), `hoshi` (Qwen3-4B 4-bit + voice + small Whisper, ~3.2 GB, optional). Every file is size- and SHA-256-checked.
- The Python runtime ships as a download (`tools/build_runtime.py` builds it; `src/main/runtime.js` installs it).

## Run from source

```bash
npm install
npm start
```

Requires the Python venv at `../.venv` (CUDA PyTorch cu128, faster-whisper, kokoro, chatterbox-tts, transformers, bitsandbytes, accelerate, websockets). Set `KOE_USER_DATA` to use a different profile.

## Test

```bash
npm test
```

Runs the unit tests, the engine tests and the end-to-end UI tests (windows open off-screen). `npx playwright test fresh-pc` runs the slow fresh-PC install test; `tests/live/` holds user-driven Crunchyroll checks.

## Build the installer

```bash
npm run dist
```

Produces `dist/Hoshidub-Setup-x.y.z.exe`, VMP-signed. Rebuild the runtime pack with `python tools/build_runtime.py` and upload `dist/runtime/*` to a GitHub release, then set `"dubit.runtimeBase"` in `package.json`.

## Credits

Speech recognition: OpenAI Whisper via faster-whisper (MIT). Voices: Kokoro (Apache-2.0). Hoshi's brain: Qwen3 (Apache-2.0). Hoshi's conversation design builds on [Project Riko](https://github.com/rayenfeng/riko_project) (MIT). Ad blocking: Ghostery adblocker (MPL-2.0). Icons partly from Lucide (ISC). 3D: three.js (MIT).
