"""Build the Dub It runtime pack: a portable Python with the engine's libraries, split into download parts.

    python tools/build_runtime.py            -> dist/runtime/manifest.json + runtime.zip.001, .002, ...

Starts from python-build-standalone (a relocatable CPython) and copies in site-packages from the dev venv, so
the libraries are exactly the ones the tests ran against. Files the engine never needs are left out.
The app downloads the parts on first run, checks each SHA-256, joins them and unzips into %LOCALAPPDATA%\\DubIt.
"""
import fnmatch
import hashlib
import json
import os
import shutil
import sys
import tarfile
import urllib.request
import zipfile
from pathlib import Path

KOE = Path(__file__).resolve().parents[1]
VENV_SITE = KOE.parent / ".venv" / "Lib" / "site-packages"
OUT = KOE / "dist" / "runtime"
STAGE = KOE / "build" / "runtime-stage"
PART_SIZE = 1_900_000_000          # under GitHub's 2 GB release-asset limit
RUNTIME_VERSION = "1"

# not needed by the engine: UI toolkits, dev tools, the old file dubber, build leftovers
SKIP_PACKAGES = ["gradio*", "gradio_client*", "pip", "pip-*", "setuptools*", "_distutils_hack", "pytest*", "_pytest",
                 "pluggy*", "iniconfig*", "demucs*", "yt_dlp*", "sklearn", "scikit_learn*", "pandas*", "matplotlib*",
                 "fastapi*", "starlette*", "uvicorn*", "pydub*", "ruff*", "huggingface_hub/templates"]
SKIP_FILES = ["distutils-precedence.pth", "*.pyc", "*.lib", "*.pdb", "*.a", "*.h", "*.hpp", "*.cuh"]
SKIP_DIRS = ["__pycache__", "tests", "test", "include", "benchmarks", "docs", "examples"]


def log(msg):
    print(f"[runtime] {msg}", flush=True)


def fetch_python():
    api = "https://api.github.com/repos/astral-sh/python-build-standalone/releases/latest"
    rel = json.load(urllib.request.urlopen(urllib.request.Request(api, headers={"User-Agent": "DubIt-build"})))
    want = f"cpython-{sys.version_info.major}.{sys.version_info.minor}.*-x86_64-pc-windows-msvc-install_only.tar.gz"
    asset = next(a for a in rel["assets"] if fnmatch.fnmatch(a["name"], want))
    dest = KOE / "build" / asset["name"]
    if not dest.exists():
        log(f"downloading {asset['name']} ({asset['size'] // 2**20} MB)")
        dest.parent.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(asset["browser_download_url"], dest)
    return dest


def skip(rel: Path):
    parts = rel.parts
    if any(fnmatch.fnmatch(parts[0], pat) for pat in SKIP_PACKAGES):
        return True
    if any(p in SKIP_DIRS for p in parts[:-1]) and parts[0] not in ("torch",):   # torch/testing is imported
        return True
    return any(fnmatch.fnmatch(parts[-1], pat) for pat in SKIP_FILES)


def stage():
    if STAGE.exists():
        shutil.rmtree(STAGE)
    with tarfile.open(fetch_python()) as t:
        t.extractall(STAGE, filter="data")               # -> STAGE/python/...
    root = STAGE / "python"
    site = root / "Lib" / "site-packages"
    log(f"copying libraries from {VENV_SITE}")
    count = size = 0
    for src in VENV_SITE.rglob("*"):
        if src.is_dir():
            continue
        rel = src.relative_to(VENV_SITE)
        if skip(rel):
            continue
        dst = site / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        count += 1
        size += src.stat().st_size
    (root / "dubit-runtime.json").write_text(json.dumps({"version": RUNTIME_VERSION}), encoding="utf-8")
    log(f"staged {count} files, {size / 2**30:.2f} GB")
    return root


def pack(root):
    OUT.mkdir(parents=True, exist_ok=True)
    zpath = OUT / "runtime.zip"
    log("compressing")
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as z:
        for f in root.rglob("*"):
            if f.is_file():
                z.write(f, f.relative_to(root))
    parts = []
    with open(zpath, "rb") as src:
        i = 1
        while True:
            chunk = src.read(PART_SIZE)
            if not chunk:
                break
            name = f"runtime.zip.{i:03d}"
            (OUT / name).write_bytes(chunk)
            parts.append({"name": name, "size": len(chunk), "sha256": hashlib.sha256(chunk).hexdigest()})
            i += 1
    zpath.unlink()
    manifest = {"version": RUNTIME_VERSION, "python": f"{sys.version_info.major}.{sys.version_info.minor}",
                "parts": parts, "total": sum(p["size"] for p in parts)}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    log(f"{len(parts)} part(s), {manifest['total'] / 2**30:.2f} GB -> {OUT}")


if __name__ == "__main__":
    pack(stage())
