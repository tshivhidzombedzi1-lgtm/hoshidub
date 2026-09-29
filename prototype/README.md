# The anime-dub folder around the app

The app lives in the repo root (the `koe` folder on the owner's PC). Its parent folder `C:\Users\mbedz\anime-dub` also holds:

| Item | What | In git? |
|---|---|---|
| `live.py`, `Live Interpreter.bat` | The first live interpreter (WASAPI loopback, Whisper, edge-tts). The engine grew out of it. | yes (here) |
| `dub.py`, `app.py` | The first file dubber (demucs, Whisper, Chatterbox) | yes (here) |
| `test/` | 35 s two-voice Japanese test clip plus subtitles, used by `engine/tests` (they look for `anime-dub/test/`) | yes, `prototype/test/` |
| `owner-pc-fixes/` | Scripts run through Explorer on 2026-09-29/30 to fix the owner's installed app (see docs/HANDOFF.md) | yes (here) |
| `.venv` | Dev Python 3.12 with CUDA PyTorch cu128 and the engine libraries (~8 GB). Rebuild: see README "Run from source". | no (rebuildable) |
| `.venv-live` | Old venv for `live.py` | no |
| `models/whisper-large-v2` | Systran/faster-whisper-large-v2 from Hugging Face (3.1 GB) | no (download) |
| `wheels/` | Cached pip wheels | no (download) |
| `vendor-riko/` | Clone of https://github.com/rayenfeng/riko_project (MIT); Hoshi's design builds on it | no (upstream) |

The installer and the runtime pack (voice engine) are in the GitHub Release `v0.1.0`.
