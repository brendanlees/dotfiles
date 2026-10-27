#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SOURCE="$ROOT/home/dot_config/sketchybar"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export CONFIG_DIR="$TMP/config" SKETCHYBAR_STUB_LOG="$TMP/calls"
mkdir -p "$TMP/bin" "$CONFIG_DIR"
cp -R "$SOURCE/items" "$CONFIG_DIR/"
cp "$SOURCE/icons.sh" "$CONFIG_DIR/"
chezmoi execute-template --source "$ROOT" --override-data '{"theme":"black-metal-bathory"}' \
    <"$SOURCE/colors.sh.tmpl" >"$CONFIG_DIR/colors.sh"

# Exercise the real startup order without contacting the bar, apps or services.
cat >"$TMP/bin/sketchybar" <<'PY'
#!/usr/bin/env python3
import json, os, sys
with open(os.environ["SKETCHYBAR_STUB_LOG"], "a") as log:
    log.write(json.dumps(sys.argv[1:]) + "\n")
if sys.argv[1:] == ["--query", "bar"]:
    print('{"items":[]}')
PY
cat >"$TMP/bin/aerospace" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$TMP/bin/"*
PATH="$TMP/bin:$PATH" bash "$SOURCE/executable_sketchybarrc"

python3 - "$SKETCHYBAR_STUB_LOG" <<'PY'
import json, pathlib, sys

calls = [json.loads(line) for line in pathlib.Path(sys.argv[1]).read_text().splitlines()]
items, aliases, properties = [], [], {}
for call in calls:
    starts = [i for i, arg in enumerate(call) if arg.startswith("--")] + [len(call)]
    for start, end in zip(starts, starts[1:]):
        command, *args = call[start:end]
        if command == "--add" and args[0] in ("item", "alias"):
            if args[2] == "right":
                items.append(args[1])
            if args[0] == "alias":
                aliases.append(args)
        elif command == "--rename":
            items = [args[1] if name == args[0] else name for name in items]
        elif command == "--set":
            properties.setdefault(args[0], {}).update(
                value.split("=", 1) for value in args[1:] if "=" in value
            )

assert not aliases, "macOS 27 cannot discover SplashBar through native aliases"
assert items.count("splashbar") == 1, items
# Create the robot before quota's trigger so its renderer can order the whole group.
assert items.index("splashbar") == items.index("showy_quota.trigger") - 1, items
assert items.index("spotify") < items.index("splashbar"), items
robot = properties["splashbar"]
assert robot["padding_left"] == "20" and robot["padding_right"] == "12", robot
assert robot["update_freq"] == "1" and robot["updates"] == "on", robot
assert robot["background.image.scale"] == "0.5" and robot["width"] == "32", robot
assert all(robot[key] == "off" for key in ("icon.drawing", "label.drawing", "drawing")), robot
assert robot["background.color"] == "0x00000000", robot
assert robot["script"].endswith('/plugins/splashbar.py"'), robot
assert "click_script" not in robot, "the display must not change service state"
PY



python3 -B - "$SOURCE/plugins/executable_splashbar.py" "$TMP" <<'PYTEST'
import importlib.util, json, os, pathlib, subprocess, sys, time

plugin, root = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
spec = importlib.util.spec_from_file_location("splashbar", plugin)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
home = root / "home with spaces"
cache = home / "Library/Caches/com.steadydigital.splashbar/sketchybar"
(cache / "icons").mkdir(parents=True)
state = cache / "state.json"

assert module.image_path(cache, 1000) is None, "missing app cache must hide"
for frame in module.FRAMES:
    image = cache / "icons" / (frame + ".png")
    image.touch()
    state.write_text(json.dumps({"schema": 1, "frame": frame, "updated_at": 1000}))
    assert module.image_path(cache, 1000) == image
    assert module.image_path(cache, 1005) == image
    assert module.image_path(cache, 1005.01) is None, "stalled/crashed app must not retain a live-looking face"
    assert module.image_path(cache, 999) is None, "future timestamps must not be trusted"

for invalid in [
    None, [], {},
    {"schema": 2, "frame": "awake", "updated_at": 1000},
    {"schema": 1, "frame": "../awake", "updated_at": 1000},
    {"schema": 1, "frame": [], "updated_at": 1000},
    *[{"schema": 1, "frame": "awake", "updated_at": value}
      for value in ("1000", None, True, float("nan"), float("inf"))],
]:
    state.write_text(json.dumps(invalid))
    assert module.image_path(cache, 1000) is None, invalid
state.write_text("{")
assert module.image_path(cache, 1000) is None
state.write_text(json.dumps({"schema": 1, "frame": "awake", "updated_at": 1000}))
(cache / "icons/awake.png").unlink()
assert module.image_path(cache, 1000) is None, "missing image must hide rather than show an old frame"

# Run the real entry point with the stubbed bar. Paths with spaces remain one argument.
env = {**os.environ, "HOME": str(home), "PATH": str(root / "bin") + os.pathsep + os.environ["PATH"]}
log = pathlib.Path(env["SKETCHYBAR_STUB_LOG"])
state.write_text(json.dumps({"schema": 1, "frame": "sleeping-z", "updated_at": time.time()}))
subprocess.run([sys.executable, str(plugin)], env=env, check=True)
call = json.loads(log.read_text().splitlines()[-1])
assert call == ["--set", "splashbar", "background.image=" + str(cache / "icons/sleeping-z.png"),
                "background.image.drawing=on", "drawing=on"], call
# A stopped inference service stays visible as Off; a stopped app disappears.
state.write_text(json.dumps({"schema": 1, "frame": "off", "updated_at": time.time()}))
subprocess.run([sys.executable, str(plugin)], env=env, check=True)
assert "drawing=on" in json.loads(log.read_text().splitlines()[-1])
state.unlink()
subprocess.run([sys.executable, str(plugin)], env=env, check=True)
assert json.loads(log.read_text().splitlines()[-1]) == [
    "--set", "splashbar", "drawing=off", "background.image.drawing=off"]
PYTEST

echo 'SplashBar direct frames, freshness/failure handling and startup anchor and left spacing ok'
