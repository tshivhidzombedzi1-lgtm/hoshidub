#!/bin/bash
# Thread-capped hosts (Hostinger shared): headless Chrome + the site server + shots-cdp.mjs, pinned to few CPUs.
#   bash tools/run-shots.sh <outDir> [baseUrl]   (env SIZES, PAGES); with no baseUrl it serves ./dist itself on :3000
set -u
NODE=${NODE:-/opt/alt/alt-nodejs22/root/usr/bin/node}
CHROME=${CHROME:-$HOME/.cache/chs/chrome-headless-shell-linux64/chrome-headless-shell}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-shots}; BASE=${2:-http://localhost:3000}
[ "$(ps -u "$USER" -L | wc -l)" -gt 75 ] && { echo "too many threads in use"; exit 2; }
SP=""
if [ -z "${2:-}" ]; then (cd "$HERE/.." && UV_THREADPOOL_SIZE=1 PORT=3000 exec taskset -c 0-1 "$NODE" --v8-pool-size=0 server.js >/dev/null 2>&1) & SP=$!; sleep 2; fi
"$CHROME" --no-sandbox --single-process --no-zygote --disable-gpu --disable-software-rasterizer --disable-threaded-compositing --disable-dev-shm-usage --num-raster-threads=1 --hide-scrollbars --disable-extensions --disable-background-networking --disable-breakpad --disable-component-update --no-first-run --mute-audio --disable-features=AudioServiceOutOfProcess,PaintHolding,DnsOverHttps,OptimizationHints,MediaRouter --remote-debugging-port=9222 --user-data-dir="$HOME/.cache/chs/profile" about:blank >/dev/null 2>&1 &
CP=$!
UV_THREADPOOL_SIZE=1 taskset -c 0-1 "$NODE" --v8-pool-size=0 "$HERE/shots-cdp.mjs" "$BASE" "$OUT"; RC=$?
kill $CP $SP 2>/dev/null
exit $RC
