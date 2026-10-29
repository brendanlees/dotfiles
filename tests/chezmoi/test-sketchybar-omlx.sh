#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SOURCE="$ROOT/home/dot_config/sketchybar"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home with spaces" CONFIG_DIR="$TMP/config" SKETCHYBAR_STUB_LOG="$TMP/calls"
mkdir -p "$TMP/bin" "$CONFIG_DIR" "$HOME/.omlx"
cp -R "$SOURCE/items" "$CONFIG_DIR/"
cp "$SOURCE/icons.sh" "$CONFIG_DIR/"
chezmoi execute-template --source "$ROOT" --override-data '{"theme":"black-metal-bathory"}' \
    <"$SOURCE/colors.sh.tmpl" >"$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/colors.sh"

# Exercise the real startup order without contacting the bar, apps or services.
cat >"$TMP/bin/sketchybar" <<'PY'
#!/usr/bin/env python3
import json, os, sys
with open(os.environ["SKETCHYBAR_STUB_LOG"], "a") as log:
    log.write(json.dumps(sys.argv[1:]) + "\n")
if sys.argv[1:] == ["--query", "bar"]:
    print('{"items":[]}')
elif sys.argv[1:] == ["--query", "omlx"]:
    print(json.dumps({"popup": {"drawing": os.environ.get("OMLX_POPUP", "off")},
                      "geometry": {"drawing": os.environ.get("OMLX_VISIBLE", "on")}}))
PY
cat >"$TMP/bin/aerospace" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$TMP/bin/"*
export PATH="$TMP/bin:$PATH"
bash "$SOURCE/executable_sketchybarrc"

python3 - "$SKETCHYBAR_STUB_LOG" "$ROOT" <<'PY'
import json, pathlib, sys, tomllib

calls = [json.loads(line) for line in pathlib.Path(sys.argv[1]).read_text().splitlines()]
items, properties, subscriptions, events = [], {}, [], []
for call in calls:
    starts = [i for i, arg in enumerate(call) if arg.startswith("--")] + [len(call)]
    for start, end in zip(starts, starts[1:]):
        command, *args = call[start:end]
        if command == "--add" and args[0] == "item" and args[2] == "right":
            items.append(args[1])
        elif command == "--set":
            properties.setdefault(args[0], {}).update(
                value.split("=", 1) for value in args[1:] if "=" in value
            )
        elif command == "--subscribe" and args[0] == "omlx":
            subscriptions.extend(args[1:])
        elif command == "--add" and args[0] == "event":
            events.append(args[1])

assert "splashbar" not in items, items
assert items.count("omlx") == 1, items
assert items.index("omlx") == items.index("showy_quota.trigger") - 1, items
assert items.index("spotify") < items.index("omlx"), items
widget = properties["omlx"]
assert widget["drawing"] == "off", "do not flash a widget on machines without oMLX"
assert widget["update_freq"] == "3" and widget["updates"] == "on", "hidden items must keep checking for startup"
assert widget["icon"] and widget["label"] == "Qwen · Checking", widget
assert widget["padding_right"] == "10", "keep a small gap beside the quota pill"
assert widget["script"].endswith('/plugins/omlx.py"'), widget
assert "colors.sh" in widget["script"], "status colours follow the active theme"
assert {"mouse.clicked", "omlx_toggle", "mouse.exited.global", "system_woke"} <= set(subscriptions)
assert "omlx_toggle" in events
config = tomllib.loads((pathlib.Path(sys.argv[2]) / "home/dot_config/aerospace/aerospace.toml").read_text())
assert config["mode"]["main"]["binding"]["alt-shift-q"] == "exec-and-forget sketchybar --trigger omlx_toggle"
assert all("omlx." + row in properties for row in ("model", "requests", "tokens", "cached", "scope"))
PY

python3 -B - "$SOURCE/plugins/executable_omlx.py" "$TMP" <<'PYTEST'
import copy
import http.server
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
from urllib.parse import parse_qs, urlsplit

plugin, root = Path(sys.argv[1]), Path(sys.argv[2])
spec = importlib.util.spec_from_file_location("omlx", plugin)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
settings = Path.home() / ".omlx/settings.json"
log = Path(os.environ["SKETCHYBAR_STUB_LOG"])
secret = "fixture-key-never-in-bar"
qwen = {"id": "Qwen3.8-27B", "is_loading": False, "active_requests": 0, "waiting_requests": 0}
activity = {"active_models": {"models": [qwen]}}
stats = {"total_prompt_tokens": 53794, "total_completion_tokens": 4610, "total_cached_tokens": 3008}
activity_code, stats_code = 200, 200
requests = []


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        global requests
        requests.append(self.path)
        assert self.headers.get("Authorization") == "Bearer " + secret
        if self.path == "/admin/api/activity":
            code, body = activity_code, activity
        else:
            parsed = urlsplit(self.path)
            assert parsed.path == "/admin/api/stats", self.path
            query = parse_qs(parsed.query)
            assert query["scope"] == ["session"] and query["model"][0].startswith("Qwen"), query
            code, body = stats_code, stats
        encoded = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, *_):
        pass


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
settings_data = {"server": {"host": "not-the-local-service.invalid", "port": server.server_port},
                 "auth": {"api_key": secret}}
settings.write_text(json.dumps(settings_data))


def run(sender="routine", showing=False, visible=True):
    log.write_text("")
    env = {**os.environ, "SENDER": sender, "OMLX_POPUP": "on" if showing else "off",
           "OMLX_VISIBLE": "on" if visible else "off",
           "HTTP_PROXY": "http://invalid-proxy.invalid:1", "http_proxy": "http://invalid-proxy.invalid:1"}
    result = subprocess.run([sys.executable, "-B", str(plugin)], env=env,
                            text=True, capture_output=True, timeout=8, check=True)
    calls = [json.loads(line) for line in log.read_text().splitlines()]
    assert secret not in result.stdout + result.stderr + log.read_text()
    state = {}
    for call in calls:
        starts = [i for i, arg in enumerate(call) if arg.startswith("--")] + [len(call)]
        for start, end in zip(starts, starts[1:]):
            command, *args = call[start:end]
            if command == "--set":
                state.setdefault(args[0], {}).update(value.split("=", 1) for value in args[1:])
    return state


def label(expected, **kwargs):
    state = run(**kwargs)
    assert state["omlx"]["label"] == "Qwen · " + expected, state
    assert state["omlx"]["drawing"] == "on", state
    return state


def hidden(**kwargs):
    assert run(**kwargs) == {"omlx": {"drawing": "off", "popup.drawing": "off"}}


try:
    state = label("Idle")
    assert state["omlx"]["icon.color"] == os.environ["GREEN"]
    assert requests == ["/admin/api/activity"], "closed menus fetch activity only"

    qwen["active_requests"] = 2
    qwen["waiting_requests"] = 1
    state = label("2 active", sender="mouse.clicked")
    assert state["omlx"]["popup.drawing"] == "on"
    assert state["omlx"]["icon.color"] == os.environ["ACCENT"]
    assert state["omlx.requests"]["label"] == "Requests · 2 active · 1 queued"
    assert state["omlx.tokens"]["label"] == "Tokens · 53.8k in · 4.6k out"
    assert state["omlx.cached"]["label"] == "Cached input · 3.0k"
    assert "server restart or stats reset" in state["omlx.scope"]["label"]
    assert all("popup.drawing" not in props for props in label("2 active", showing=True).values())
    keyboard = label("2 active", sender="omlx_toggle")
    assert keyboard == state, "the shortcut opens the same populated menu as a click"

    # Close/exit never block on the service or reopen the popup.
    requests.clear()
    for sender in ("mouse.clicked", "omlx_toggle", "mouse.exited.global"):
        assert run(sender, showing=True) == {"omlx": {"popup.drawing": "off"}}
    assert requests == []

    qwen["active_requests"] = 0
    label("1 queued")
    qwen["waiting_requests"] = 0
    qwen["is_loading"] = True
    label("Loading")
    qwen["is_loading"] = False

    # Ignore unrelated engines and keep Qwen counts scoped, even with multiple models.
    activity["active_models"]["models"].append(
        {"id": "embedding-model", "is_loading": False, "active_requests": 50, "waiting_requests": 0})
    label("Idle")
    second = {**qwen, "id": "Qwen-small", "active_requests": 1}
    activity["active_models"]["models"].append(second)
    state = label("1 active", showing=True)
    assert state["omlx.tokens"]["label"] == "Tokens · 107.6k in · 9.2k out"
    activity["active_models"]["models"] = [qwen]

    # Never carry stale usage into unavailable, malformed or denied responses.
    stats_code = 503
    state = label("Idle", showing=True)
    assert state["omlx.tokens"]["label"] == "Tokens · unavailable"
    stats_code = 200
    stats["total_prompt_tokens"] = None
    assert label("Idle", showing=True)["omlx.tokens"]["label"] == "Tokens · unavailable"
    stats["total_prompt_tokens"] = 53794

    for code in (401, 403, 503, 302):
        activity_code = code
        hidden(showing=True)
    activity_code = 200
    valid = copy.deepcopy(activity)
    for invalid in (None, [], {}, {"active_models": {"models": None}}):
        activity = invalid
        hidden()
    activity = valid
    for invalid in (None, True, -1, "0"):
        activity["active_models"]["models"][0]["active_requests"] = invalid
        hidden()
    activity = {"active_models": {"models": []}}
    state = label("Standby", showing=True)
    assert state["omlx.model"]["label"] == "No Qwen model loaded"

    settings.unlink()
    requests.clear()
    hidden(showing=True)
    assert requests == [], "unconfigured machines must not contact any service"
    for sender in ("omlx_toggle", "mouse.clicked"):
        assert run(sender, visible=False) == {}, "hidden widgets must not open a menu"
    assert requests == []
    settings.write_text("{")
    hidden()
    settings.write_text(json.dumps({**settings_data, "server": {"port": "8000"}}))
    hidden()
    settings.write_text(json.dumps(settings_data))
    state = label("Standby", visible=False)
    assert "popup.drawing" not in state["omlx"], "recovery restores the pill, not the old popup"
    activity = {"active_models": {"models": [qwen]}}
    label("Idle", visible=False)
finally:
    server.shutdown()
    server.server_close()
    thread.join()

hidden(showing=True)
requests.clear()
assert run("omlx_toggle", visible=False) == {}
assert requests == []

# The client has a short timeout and does not follow redirects or use proxies.
class TimeoutConnection:
    def __init__(self, host, port, timeout):
        assert host == "127.0.0.1" and port == server.server_port
        assert 0 < timeout < 3

    def request(self, method, path, headers):
        assert method == "GET" and path == "/admin/api/activity"

    def getresponse(self):
        raise TimeoutError()

    def close(self):
        pass

module.http.client.HTTPConnection = TimeoutConnection
try:
    module.Client().get("/admin/api/activity")
except module.Unavailable as error:
    assert str(error) == "Unavailable"
else:
    raise AssertionError("timed-out data must not look idle")
PYTEST

echo 'oMLX visibility/recovery, Qwen activity, scoped session tokens, popup and local-only requests ok'
