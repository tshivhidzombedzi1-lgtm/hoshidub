"""Downloadable model packs: what each needs, where it lives, whether it's installed, and fetching it.

Packs
  core     speech synthesis model + speaker voiceprints      (needed for anything)
  voices-<lang>  the voices for one dub language             (English first; more languages add packs)
  ear      Whisper large-v2 for translate-by-ear             (optional: only for shows without subtitles)

Files come straight from Hugging Face and are stored under MODELS/<owner>__<repo>/<file>, so the app never
depends on a shared cache. Downloads resume from a .part file after an interruption.
"""
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]          # anime-dub/ (dev layout)
MODELS = Path(os.environ.get("KOE_MODELS")
              or Path(os.environ.get("LOCALAPPDATA", Path.home())) / "DubIt" / "models")

BASE = os.environ.get("KOE_PACK_BASE", "https://huggingface.co")   # tests point this at a local server
KOKORO = "hexgrad/Kokoro-82M"
WHISPER = "Systran/faster-whisper-large-v2"
EARS = "Systran/faster-whisper-small"                 # Hoshi hears the viewer (multilingual, accent-friendly)
BRAIN = "unsloth/Qwen3-4B-Instruct-2507-bnb-4bit"     # Hoshi's brain: Apache-2.0, 4-bit, ~2.7 GB
BRAIN_FILES = ("config.json", "generation_config.json", "model.safetensors", "tokenizer.json", "tokenizer_config.json",
               "vocab.json", "merges.txt", "added_tokens.json", "special_tokens_map.json", "chat_template.jinja")

# voice ids per dub language (Kokoro names; the first letter pair encodes accent and gender)
VOICES = {
    "en": {"male": ["am_michael", "am_fenrir", "am_puck", "am_echo", "am_eric", "am_liam"],
           "female": ["af_heart", "af_bella", "af_nicole", "af_aoede", "af_kore", "af_sarah"]},
}

PACKS = {
    "core": [(KOKORO, "config.json"), (KOKORO, "kokoro-v1_0.pth"), ("ResembleAI/chatterbox", "ve.safetensors")],
    "voices-en": [(KOKORO, f"voices/{v}.pt") for g in VOICES["en"].values() for v in g],
    "ear": [(WHISPER, f) for f in ("config.json", "model.bin", "tokenizer.json", "vocabulary.txt")],
    "hoshi": [(BRAIN, f) for f in BRAIN_FILES] + [(KOKORO, "voices/af_sky.pt")]
             + [(EARS, f) for f in ("config.json", "model.bin", "tokenizer.json", "vocabulary.txt")],
}
APPROX_MB = {"core": 330, "voices-en": 6, "ear": 3090, "hoshi": 3170}


def ears_dir():
    return MODELS / EARS.replace("/", "__")


def brain_dir():
    return MODELS / BRAIN.replace("/", "__")


def local_path(repo, filename):
    return MODELS / repo.replace("/", "__") / filename


def whisper_dir():
    """Installed Whisper model folder, including the pre-pack developer location."""
    for d in (MODELS / WHISPER.replace("/", "__"), ROOT / "models" / "whisper-large-v2"):
        if (d / "model.bin").exists():
            return d
    return None


def voice_path(voice):
    return local_path(KOKORO, f"voices/{voice}.pt")


def installed(pack):
    if pack == "ear":
        return whisper_dir() is not None
    return all(local_path(r, f).exists() for r, f in PACKS[pack])


def gpu():
    try:
        import torch
        if torch.cuda.is_available():
            p = torch.cuda.get_device_properties(0)
            return {"cuda": True, "name": p.name, "vram_gb": round(p.total_memory / 2 ** 30, 1)}
    except Exception:
        pass
    return {"cuda": False, "name": None, "vram_gb": 0}


def check():
    return {"packs": {p: installed(p) for p in PACKS}, "sizes_mb": APPROX_MB, "gpu": gpu(), "models": str(MODELS)}


def emit(**msg):
    print(json.dumps(msg), flush=True)


class Busy(Exception):
    pass


def lock(dest):
    """Only one download of a file at a time: two writers appending to one .part corrupt it."""
    path = dest.with_suffix(dest.suffix + ".lock")
    try:
        if path.exists() and time.time() - path.stat().st_mtime > 3600:
            path.unlink()                      # left behind by a crash
        fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        os.close(fd)
        return path
    except FileExistsError:
        raise Busy(f"{dest.name} is already downloading")


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 22), b""):
            h.update(block)
    return h.hexdigest()


def fetch(repo, filename, dest, on_bytes, size=0, sha256=None):
    """Download one file with resume, then check its exact size and SHA-256 before it counts as installed."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    held = lock(dest)
    try:
        _fetch(repo, filename, dest, on_bytes, size, sha256)
    finally:
        held.unlink(missing_ok=True)


def _fetch(repo, filename, dest, on_bytes, size, sha256):
    part = dest.with_suffix(dest.suffix + ".part")
    have = part.stat().st_size if part.exists() else 0
    if size and have > size:                   # longer than the real file: it's damaged, start again
        part.unlink()
        have = 0
    url = f"{BASE}/{repo}/resolve/main/{filename}"
    req = urllib.request.Request(url, headers={"User-Agent": "DubIt/0.1", **({"Range": f"bytes={have}-"} if have else {})})
    with urllib.request.urlopen(req, timeout=60) as res:
        if have and res.status != 206:        # server ignored the range: start over
            have = 0
            part.unlink(missing_ok=True)
        if have:
            on_bytes(have)
        with open(part, "ab") as out:
            while True:
                chunk = res.read(1 << 20)
                if not chunk:
                    break
                out.write(chunk)
                on_bytes(len(chunk))
    got = part.stat().st_size
    if (size and got != size) or (sha256 and sha256_of(part) != sha256):
        part.unlink()
        raise IOError(f"{filename} arrived damaged (size or checksum mismatch); it will be downloaded again")
    part.replace(dest)


def remote_meta(repo, filename):
    """Exact size and (for large files) the SHA-256 Hugging Face publishes for them."""
    class Stay(urllib.request.HTTPRedirectHandler):      # the fingerprint is on the first reply, not the CDN's
        def redirect_request(self, *a, **k):
            return None
    req = urllib.request.Request(f"{BASE}/{repo}/resolve/main/{filename}", method="HEAD",
                                 headers={"User-Agent": "DubIt/0.1"})
    try:
        headers = urllib.request.build_opener(Stay).open(req, timeout=30).headers
    except urllib.error.HTTPError as e:                  # 302 lands here, headers included
        headers = e.headers
    size = int(headers.get("X-Linked-Size") or headers.get("Content-Length") or 0)
    etag = (headers.get("X-Linked-ETag") or "").strip('"')
    return size, etag if len(etag) == 64 and all(c in "0123456789abcdef" for c in etag) else None


def setup(packs):
    """Download the given packs, reporting progress as JSON lines on stdout."""
    todo = [(p, r, f) for p in packs for r, f in PACKS[p] if not local_path(r, f).exists()]
    if "ear" in packs and whisper_dir() is not None:
        todo = [t for t in todo if t[0] != "ear"]
    meta = {}
    for p, r, f in todo:
        try:
            meta[(r, f)] = remote_meta(r, f)
        except Exception:
            meta[(r, f)] = (0, None)
    total = sum(m[0] for m in meta.values())
    done = 0
    last = 0.0
    for p, r, f in todo:
        def on_bytes(n, p=p):
            nonlocal done, last
            done += n
            if time.time() - last > 0.25:
                last = time.time()
                emit(type="progress", pack=p, done=done, total=total)
        for attempt in range(5):
            try:
                fetch(r, f, local_path(r, f), on_bytes, *meta[(r, f)])
                break
            except Exception as e:
                if attempt == 4:
                    emit(type="setup-error", pack=p, error=str(e))
                    return False
                time.sleep(2 * (attempt + 1))
    emit(type="progress", pack=packs[-1] if packs else "", done=total, total=total)
    emit(type="setup-done", packs=packs)
    return True


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--setup":
        sys.exit(0 if setup([p for p in sys.argv[2].split(",") if p in PACKS]) else 1)
    print(json.dumps(check()))
