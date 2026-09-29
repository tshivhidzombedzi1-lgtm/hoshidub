"""Re-split the runtime pack into smaller download parts (easier to upload to shared hosting and to resume).

    python tools/resplit_runtime.py [part_mb] [src_dir] [out_dir]

Reads the parts listed in src_dir/manifest.json in order, streams them into parts of part_mb megabytes,
and writes out_dir/manifest.json with each new part's size and SHA-256. The joined bytes are identical.
"""
import hashlib
import json
import sys
from pathlib import Path

part_mb = int(sys.argv[1]) if len(sys.argv) > 1 else 400
src = Path(sys.argv[2] if len(sys.argv) > 2 else "dist/runtime")
out = Path(sys.argv[3] if len(sys.argv) > 3 else "dist/runtime-web")
limit = part_mb * 1_000_000

old = json.loads((src / "manifest.json").read_text())
out.mkdir(parents=True, exist_ok=True)
for f in out.glob("runtime.zip.*"):
    f.unlink()

whole = hashlib.sha256()
parts, cur, cur_hash, cur_size = [], None, None, 0


def close():
    global cur
    if cur:
        cur.close()
        parts.append({"name": cur_name, "size": cur_size, "sha256": cur_hash.hexdigest()})
        cur = None


for p in old["parts"]:
    with open(src / p["name"], "rb") as f:
        while chunk := f.read(8 << 20):
            whole.update(chunk)
            while chunk:
                if cur is None:
                    cur_name = f"runtime.zip.{len(parts) + 1:03d}"
                    cur, cur_hash, cur_size = open(out / cur_name, "wb"), hashlib.sha256(), 0
                take = chunk[: limit - cur_size]
                cur.write(take)
                cur_hash.update(take)
                cur_size += len(take)
                chunk = chunk[len(take):]
                if cur_size >= limit:
                    close()
close()

total = sum(p["size"] for p in parts)
assert total == old["total"], (total, old["total"])
manifest = {**{k: v for k, v in old.items() if k not in ("parts", "total")}, "parts": parts, "total": total}
(out / "manifest.json").write_text(json.dumps(manifest, indent=1))
print(f"{len(parts)} parts, {total:,} bytes, whole-file sha256 {whole.hexdigest()}")
