"""List what's inside the split runtime pack without joining it on disk.

    python tools/check_runtime_pack.py [dist/runtime]
"""
import io
import json
import os
import sys
import zipfile

folder = sys.argv[1] if len(sys.argv) > 1 else "dist/runtime"
manifest = json.load(open(os.path.join(folder, "manifest.json")))


class Joined(io.RawIOBase):
    """The parts read back to back as one seekable file."""

    def __init__(self, files):
        self.files = [open(f, "rb") for f in files]
        self.sizes = [os.path.getsize(f) for f in files]
        self.total = sum(self.sizes)
        self.pos = 0

    def readable(self):
        return True

    def seekable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, off, whence=0):
        self.pos = off if whence == 0 else self.pos + off if whence == 1 else self.total + off
        return self.pos

    def readinto(self, buf):
        n = 0
        while n < len(buf) and self.pos < self.total:
            start = 0
            for f, size in zip(self.files, self.sizes):
                if self.pos < start + size:
                    f.seek(self.pos - start)
                    chunk = f.read(min(len(buf) - n, start + size - self.pos))
                    buf[n:n + len(chunk)] = chunk
                    n += len(chunk)
                    self.pos += len(chunk)
                    break
                start += size
        return n


z = zipfile.ZipFile(io.BufferedReader(Joined([os.path.join(folder, p["name"]) for p in manifest["parts"]])))
names = [n.replace(os.sep, "/").replace("\\", "/") for n in z.namelist()]
for want in ["python.exe", "accelerate/__init__.py", "bitsandbytes/__init__.py", "psutil/__init__.py",
             "transformers/__init__.py", "torch/__init__.py", "faster_whisper/__init__.py", "kokoro/__init__.py"]:
    print(f"{want:32} {'yes' if any(n.endswith(want) for n in names) else 'MISSING'}")
print(f"{len(names)} files; pack version {manifest['version']}; runtime says {z.read('dubit-runtime.json').decode()}")
