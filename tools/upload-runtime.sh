#!/usr/bin/env bash
# Uploads the runtime pack (dist/runtime: runtime.zip.001-008, then manifest.json) to hoshidub.com over SSH.
# Each part goes up as <name>.uploading and is renamed only after its SHA-256 matches, so the site never serves
# a half-written file; manifest.json goes last, so the app never sees a manifest whose parts are missing.
#   bash tools/upload-runtime.sh            (needs the SSH key ~/.ssh/hoshidub_hostinger in authorized_keys)
set -u
KEY=~/.ssh/hoshidub_hostinger
HOST=u150848555@82.198.227.57
PORT=65002
DEST=domains/hoshidub.com/public_html/downloads/runtime
SRC="$(dirname "$0")/../dist/runtime"
SSH=(ssh -i "$KEY" -p "$PORT" -o BatchMode=yes -o ServerAliveInterval=30 "$HOST")

sha_of() { python -c "import json,sys; m=json.load(open(sys.argv[1])); print(next(p['sha256'] for p in m['parts'] if p['name']==sys.argv[2]))" "$SRC/manifest.json" "$1"; }

"${SSH[@]}" "mkdir -p $DEST"
for f in "$SRC"/runtime.zip.0*; do
  name=$(basename "$f"); want=$(sha_of "$name")
  have=$("${SSH[@]}" "sha256sum $DEST/$name 2>/dev/null | cut -d' ' -f1")
  if [ "$have" = "$want" ]; then echo "$name already on the server"; continue; fi
  for attempt in 1 2 3; do
    start=$(date +%s)
    if scp -i "$KEY" -P "$PORT" -o BatchMode=yes -o ServerAliveInterval=30 -q "$f" "$HOST:$DEST/$name.uploading"; then
      got=$("${SSH[@]}" "sha256sum $DEST/$name.uploading | cut -d' ' -f1")
      if [ "$got" = "$want" ]; then
        "${SSH[@]}" "mv -f $DEST/$name.uploading $DEST/$name"
        echo "$name uploaded and verified in $(( $(date +%s) - start )) s"; break
      fi
      echo "$name checksum mismatch, retrying"
    else
      echo "$name upload failed (attempt $attempt), retrying"
    fi
    [ "$attempt" = 3 ] && { echo "GIVING UP on $name"; exit 1; }
  done
done
scp -i "$KEY" -P "$PORT" -o BatchMode=yes -q "$SRC/manifest.json" "$HOST:$DEST/manifest.json" && echo "manifest.json uploaded (last)"
"${SSH[@]}" "ls -la $DEST"
