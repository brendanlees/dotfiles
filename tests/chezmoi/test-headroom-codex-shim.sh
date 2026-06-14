#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$ROOT/dot_config/zsh/exact_aliases.d/headroom.zsh.tmpl"
TMPDIR="${TMPDIR:-/tmp}/headroom-codex-shim-test-$$"
mkdir -p "$TMPDIR"
FAKE_LOG="$TMPDIR/fake-headroom.log"
FAKE_PORT=18877
SHIM_PORT=18878

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

python3 - "$FAKE_PORT" "$FAKE_LOG" <<'PY' &
import http.server, json, sys
port=int(sys.argv[1]); log=sys.argv[2]
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200); self.end_headers(); self.wfile.write(b'ok'); return
        self.send_response(404); self.end_headers()
    def do_POST(self):
        body=self.rfile.read(int(self.headers.get('content-length','0')))
        with open(log, 'w') as f:
            json.dump({'path': self.path, 'authorization': self.headers.get('authorization'), 'body': body.decode()}, f)
        if self.path != '/v1/responses':
            self.send_response(404); self.end_headers(); return
        self.send_response(200)
        self.send_header('content-type','application/json')
        self.end_headers()
        self.wfile.write(b'{"ok":true}')
http.server.ThreadingHTTPServer(('127.0.0.1', port), Handler).serve_forever()
PY
FAKE_PID=$!

for _ in {1..50}; do
  if curl -fsS "http://127.0.0.1:$FAKE_PORT/health" >/dev/null 2>&1; then break; fi
  sleep 0.1
done
curl -fsS "http://127.0.0.1:$FAKE_PORT/health" >/dev/null

zsh -fc "
  source '$HELPER'
  HEADROOM_PORT=$FAKE_PORT HEADROOM_CODEX_SHIM_PORT=$SHIM_PORT headroom-pi-codex-shim
" &
SHIM_PID=$!

for _ in {1..50}; do
  if curl -fsS "http://127.0.0.1:$SHIM_PORT/health" >/dev/null 2>&1; then break; fi
  sleep 0.1
done
curl -fsS "http://127.0.0.1:$SHIM_PORT/health" >/dev/null

response="$(curl -fsS -X POST \
  -H 'authorization: Bearer test-token' \
  -H 'content-type: application/json' \
  --data '{"model":"gpt-5.4-mini"}' \
  "http://127.0.0.1:$SHIM_PORT/v1/codex/responses")"
[ "$response" = '{"ok":true}' ]

python3 - "$FAKE_LOG" <<'PY'
import json, sys
entry=json.load(open(sys.argv[1]))
assert entry['path'] == '/v1/responses', entry
assert entry['authorization'] == 'Bearer test-token', entry
assert entry['body'] == '{"model":"gpt-5.4-mini"}', entry
PY
