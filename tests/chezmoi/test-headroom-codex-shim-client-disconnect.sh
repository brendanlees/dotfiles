#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SHIM="$ROOT/dot_local/bin/executable_headroom-codex-shim"
TMPDIR="${TMPDIR:-/tmp}/headroom-codex-shim-disconnect-test-$$"
mkdir -p "$TMPDIR"
SHIM_LOG="$TMPDIR/shim.err"
FAKE_PORT=18881
SHIM_PORT=18882

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

python3 - "$FAKE_PORT" <<'PY' &
import http.server
import sys
import time

port = int(sys.argv[1])

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'ok')
            return
        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        self.rfile.read(int(self.headers.get('content-length', '0')))
        self.send_response(200)
        self.send_header('content-type', 'application/octet-stream')
        self.end_headers()
        try:
            for _ in range(500):
                self.wfile.write(b'x' * 8192)
                self.wfile.flush()
                time.sleep(0.001)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass

http.server.ThreadingHTTPServer(('127.0.0.1', port), Handler).serve_forever()
PY
FAKE_PID=$!

for _ in {1..50}; do
  if curl -fsS "http://127.0.0.1:$FAKE_PORT/health" >/dev/null 2>&1; then break; fi
  sleep 0.1
done
curl -fsS "http://127.0.0.1:$FAKE_PORT/health" >/dev/null

python3 "$SHIM" "$SHIM_PORT" "http://127.0.0.1:$FAKE_PORT" 2>"$SHIM_LOG" &
SHIM_PID=$!

for _ in {1..50}; do
  if curl -fsS "http://127.0.0.1:$SHIM_PORT/health" >/dev/null 2>&1; then break; fi
  sleep 0.1
done
curl -fsS "http://127.0.0.1:$SHIM_PORT/health" >/dev/null

python3 - "$SHIM_PORT" <<'PY'
import socket
import struct
import sys

port = int(sys.argv[1])
sock = socket.create_connection(('127.0.0.1', port), timeout=5)
sock.sendall(
    b'POST /v1/codex/responses HTTP/1.1\r\n'
    b'Host: 127.0.0.1\r\n'
    b'Content-Type: application/json\r\n'
    b'Content-Length: 2\r\n'
    b'Connection: close\r\n'
    b'\r\n{}'
)
sock.recv(128)
# Force an RST so the shim sees a downstream disconnect while streaming.
sock.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii', 1, 0))
sock.close()
PY

sleep 0.5
if grep -E 'BrokenPipeError|ConnectionResetError|ConnectionAbortedError|Exception occurred during processing' "$SHIM_LOG"; then
  echo "shim logged traceback for expected client disconnect" >&2
  exit 1
fi
