#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$ROOT/dot_config/zsh/exact_aliases.d/headroom.zsh.tmpl"
TMPDIR="${TMPDIR:-/tmp}/headroom-codex-shim-wait-test-$$"
mkdir -p "$TMPDIR/bin"
READY="$TMPDIR/ready"
FAKE_PORT=18879
SHIM_PORT=18880

# shellcheck disable=SC2329 # Invoked via trap EXIT.
cleanup() {
  if [ -n "${SHIM_PID:-}" ]; then
    pkill -P "$SHIM_PID" 2>/dev/null || true
    kill "$SHIM_PID" 2>/dev/null || true
    wait "$SHIM_PID" 2>/dev/null || true
  fi
  if [ -n "${FAKE_PID:-}" ]; then
    kill "$FAKE_PID" 2>/dev/null || true
    wait "$FAKE_PID" 2>/dev/null || true
  fi
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

python3 - "$FAKE_PORT" "$READY" <<'PY' &
import http.server, sys
port=int(sys.argv[1]); ready=sys.argv[2]
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_GET(self):
        if self.path == '/health' and open(ready).read().strip() == '1':
            self.send_response(200); self.end_headers(); self.wfile.write(b'ok'); return
        self.send_response(503); self.end_headers()
    def do_POST(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b'{}')
open(ready, 'w').write('0')
http.server.ThreadingHTTPServer(('127.0.0.1', port), Handler).serve_forever()
PY
FAKE_PID=$!
sleep 0.2

PATH="$TMPDIR/bin:$PATH" zsh -fc "
  source '$HELPER'
  HEADROOM_PORT=$FAKE_PORT HEADROOM_CODEX_SHIM_PORT=$SHIM_PORT HEADROOM_PROXY_WAIT_SECONDS=5 headroom-pi-codex-shim
" >/tmp/headroom-wait-shim.out 2>&1 &
SHIM_PID=$!

sleep 0.8
if ! kill -0 "$SHIM_PID" 2>/dev/null; then
  echo 'shim exited before proxy became healthy'
  cat /tmp/headroom-wait-shim.out
  exit 1
fi
printf '1' > "$READY"

for _ in {1..50}; do
  if curl -fsS "http://127.0.0.1:$SHIM_PORT/health" >/dev/null 2>&1; then
    echo 'shim waited for proxy and started'
    exit 0
  fi
  sleep 0.1
done

echo 'shim did not start after proxy became healthy'
cat /tmp/headroom-wait-shim.out
exit 1
