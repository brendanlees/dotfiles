#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SOURCE="$ROOT/home/dot_config/sketchybar"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" CONFIG_DIR="$TMP/home/.config/sketchybar"
export XDG_CACHE_HOME="$HOME/.cache" QUOTA_TEST_DIR="$TMP"
mkdir -p "$TMP/bin" "$CONFIG_DIR/plugins" "$CONFIG_DIR/vendor/showy-quota/bin" \
    "$CONFIG_DIR/vendor/showy-quota/adapters/sketchybar/plugins" "$XDG_CACHE_HOME/showy-quota"

cp "$SOURCE/plugins/executable_quota.sh" "$CONFIG_DIR/plugins/quota.sh"
cp "$SOURCE/plugins/quota_details.py" "$CONFIG_DIR/plugins/"
cp "$SOURCE/quota.env" "$CONFIG_DIR/"
chezmoi execute-template --source "$ROOT" --override-data '{"theme":"black-metal-bathory"}' \
    <"$SOURCE/colors.sh.tmpl" >"$CONFIG_DIR/colors.sh"
chmod +x "$CONFIG_DIR/plugins/quota.sh"

cat >"$TMP/bin/sketchybar" <<'PY'
#!/usr/bin/env python3
import json, os, pathlib, re, sys
root = pathlib.Path(os.environ["QUOTA_TEST_DIR"])
args = sys.argv[1:]
with (root / "calls").open("a") as f:
    f.write(json.dumps(args) + "\n")
path = root / "bar.json"
state = json.loads(path.read_text()) if path.exists() else {"spotify": {}, "splashbar": {}, "showy_quota.trigger": {}}
if args[:2] == ["--query", "bar"]:
    print(json.dumps({"items": list(state)}))
elif args[:1] == ["--query"]:
    item = state.get(args[1])
    if item is None:
        sys.exit(1)
    print(json.dumps({"geometry": {"position": item.get("position", "right")},
                      "popup": {"drawing": item.get("popup.drawing", "off")}}))
else:
    starts = [i for i, arg in enumerate(args) if arg.startswith("--")] + [len(args)]
    for start, end in zip(starts, starts[1:]):
        command, *values = args[start:end]
        if command == "--add":
            state[values[1]] = {"position": values[2] if len(values) > 2 else "right"}
        elif command in ("--set", "--remove"):
            target = values[0]
            names = [n for n in state if re.search(target[1:-1], n)] if target.startswith("/") else [target]
            for name in names:
                if command == "--remove":
                    state.pop(name, None)
                elif name in state:
                    state[name].update(dict(v.split("=", 1) for v in values[1:] if "=" in v))
        elif command == "--reorder":
            # SketchyBar swaps only the specified slots, preserving other items.
            slots = iter(values)
            order = [next(slots) if key in values else key for key in state]
            state = {key: state[key] for key in order}
    path.write_text(json.dumps(state))
PY
cat >"$TMP/bin/aerospace" <<'SH'
#!/bin/sh
cat "$QUOTA_TEST_DIR/front"
SH
cat >"$TMP/bin/pgrep" <<'SH'
#!/bin/sh
[ "$*" = "-x CodexBar" ] && [ -e "$QUOTA_TEST_DIR/codexbar" ]
SH
cat >"$CONFIG_DIR/vendor/showy-quota/bin/showy-quota-fetch" <<'SH'
#!/bin/sh
printf 'fetch\n' >>"$QUOTA_TEST_DIR/fetches"
[ ! -e "$QUOTA_TEST_DIR/switch-away" ] || printf 'Dia\n' >"$QUOTA_TEST_DIR/front"
exit 0
SH
cat >"$CONFIG_DIR/vendor/showy-quota/bin/showy-quota-render" <<'SH'
#!/bin/sh
[ "$*" = "--emit metrics --from-cache" ] || exit 1
cat "$QUOTA_TEST_DIR/metrics.json"
SH
# The old two-writer path visibly moved Claude to y=4 before relabelling it.
cat >"$CONFIG_DIR/vendor/showy-quota/adapters/sketchybar/plugins/showy_quota.sh" <<'SH'
#!/bin/sh
touch "$QUOTA_TEST_DIR/upstream-rendered"
sketchybar --set showy_quota.claude.primary y_offset=4
SH
chmod +x "$TMP/bin/"* "$CONFIG_DIR/vendor/showy-quota/bin/"* \
    "$CONFIG_DIR/vendor/showy-quota/adapters/sketchybar/plugins/showy_quota.sh"
export PATH="$TMP/bin:$PATH"
cat >"$TMP/metrics.json" <<'JSON'
[
  {"provider":"codex","windows":{"primary":null,"secondary":{"usedPercent":23,"remainingPercent":77,"windowMinutes":10080}},"error":null},
  {"provider":"claude","windows":{"primary":{"usedPercent":4,"remainingPercent":96,"windowMinutes":300},"secondary":{"usedPercent":19,"remainingPercent":81,"windowMinutes":10080}},"extraRateWindows":[{"title":"Fable only","usageKnown":true,"usedPercent":28,"remainingPercent":72,"windowMinutes":10080,"minutesUntilReset":90}],"error":null}
]
JSON
cat >"$XDG_CACHE_HOME/showy-quota/usage.json" <<'JSON'
{"schema":1,"providers":[{"provider":"codex","usage":{"loginMethod":"prolite"}},{"provider":"openrouter","usage":{"providerCost":{"balance":11.14,"currencyCode":"USD"},"details":[{"title":"Credits","rows":[{"label":"Remaining","value":"$11.14"},{"label":"Used","value":"$78.86"}]}]}}]}
JSON
cp "$XDG_CACHE_HOME/showy-quota/usage.json" "$TMP/subscribed-usage.json"
# A warm upgrade removes the former OpenRouter row and the separate Codex column.
printf '%s\n' '{"spotify":{},"splashbar":{},"showy_quota.trigger":{},"showy_quota.codex.slot":{},"showy_quota.openrouter.icon":{},"showy_quota.openrouter.balance":{},"showy_quota_bracket":{}}' >"$TMP/bar.json"
: >"$TMP/calls"
printf 'Dia\n' >"$TMP/front"

# Inactive bars neither fetch nor render; a focused terminal or the GUI app enables them.
"$CONFIG_DIR/plugins/quota.sh"
[[ ! -e "$TMP/fetches" ]]
printf 'Ghostty\n' >"$TMP/front"
"$CONFIG_DIR/plugins/quota.sh"
[[ $(wc -l <"$TMP/fetches") -eq 1 ]]
[[ ! -e "$TMP/upstream-rendered" ]]

python3 - "$TMP" <<'PYTEST'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
state = json.loads((root / "bar.json").read_text())
codex, claude = state["showy_quota.codex.primary"], state["showy_quota.claude.primary"]
assert (codex["icon"], codex["label"], codex["slider.percentage"]) == ("7d", "77% left", "77")
assert (claude["icon"], claude["label"]) == ("5h", "96% left")
weekly = state["showy_quota.claude.secondary"]
assert weekly["label"] == "81% left"
assert [claude["y_offset"], weekly["y_offset"], codex["y_offset"]] == ["11", "0", "-11"]
assert state["showy_quota.claude.icon"]["y_offset"] == "6", "Claude's icon centres on its two rows"
assert state["showy_quota.codex.icon"]["y_offset"] == codex["y_offset"]
assert state["showy_quota.codex.icon"]["width"] == "0", "provider icons share the same column"
assert (state["showy_quota.claude.icon"]["icon.font"]
        == state["showy_quota.codex.icon"]["icon.font"])
assert float(claude["label.font"].rsplit(":", 1)[1]) < 10
assert claude["slider.background.height"] == "4"
assert claude["slider.background.color"] == state["showy_quota_bracket"]["background.border_color"]
assert state["showy_quota_bracket"]["background.height"] == "36"
assert not any(name.startswith("showy_quota.openrouter.") for name in state)
assert [name for name in state if name.endswith(".slot")] == ["showy_quota.claude.slot"]
order = list(state)
assert order.index("showy_quota.codex.primary") < order.index("showy_quota.claude.slot")
assert order.index("showy_quota.codex.icon") < order.index("showy_quota.claude.icon")
# Creation order is reversed on the right: robot, stats, Spotify.
assert order.index("splashbar") == order.index("showy_quota.claude.icon") + 1, order
assert order.index("spotify") < order.index("showy_quota.trigger"), order

PYTEST

# Warm refreshes publish just one final layout, without remove/recreate or a competing renderer.
: >"$TMP/calls"
printf 'Dia\n' >"$TMP/front"
touch "$TMP/codexbar"
"$CONFIG_DIR/plugins/quota.sh"
rm "$TMP/codexbar"
python3 - "$TMP/calls" <<'PYTEST'
import json, pathlib, sys
calls = [json.loads(line) for line in pathlib.Path(sys.argv[1]).read_text().splitlines()]
writes = [c for c in calls if c and c[0] != "--query"]
assert len(writes) == 1, writes
assert not any(arg in ("--add", "--remove", "--reorder") for arg in writes[0]), writes
assert "y_offset=4" not in writes[0], writes
assert "y_offset=-11" in writes[0], writes
PYTEST

# A refresh during a reload must wait for quota's anchor, or it lands ahead of the other widgets.
cp "$TMP/bar.json" "$TMP/settled-bar.json"
printf '{"calendar_time":{}}\n' >"$TMP/bar.json"
printf 'Ghostty\n' >"$TMP/front"
: >"$TMP/calls"
"$CONFIG_DIR/plugins/quota.sh"
python3 - "$TMP" <<'PYTEST'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
assert json.loads((root / "bar.json").read_text()) == {"calendar_time": {}}
calls = [json.loads(line) for line in (root / "calls").read_text().splitlines()]
assert all(call[0] == "--query" for call in calls), calls
PYTEST
mv "$TMP/settled-bar.json" "$TMP/bar.json"

# A slow fetch must not reveal the strip after focus has moved away.
printf 'Ghostty\n' >"$TMP/front"
touch "$TMP/switch-away"
"$CONFIG_DIR/plugins/quota.sh"
tail -n1 "$TMP/calls" | grep -q 'drawing=off'
rm "$TMP/switch-away"
mv "$CONFIG_DIR/vendor/showy-quota" "$TMP/vendor"
"$CONFIG_DIR/plugins/quota.sh"
mv "$TMP/vendor" "$CONFIG_DIR/vendor/showy-quota"

# Fable's separate weekly cap belongs in details, with its name and reset preserved.
printf 'Ghostty\n' >"$TMP/front"
"$CONFIG_DIR/plugins/quota.sh"
"$CONFIG_DIR/plugins/quota.sh" toggle
python3 - "$TMP/bar.json" <<'PYTEST'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
labels = [v.get("label", "") for v in state.values()]
assert any("Fable only" in label and "72% left" in label and "1h 30m" in label for label in labels), labels
assert "Credits  ·  $11.14" in labels, labels
assert state["quota_detail.mode"]["label"] == "Show used instead"
PYTEST

# Mode switches change quota fill and text; OpenRouter keeps its current balance in the menu.
"$CONFIG_DIR/plugins/quota.sh" mode
[[ $(<"$XDG_CACHE_HOME/sketchybar/quota-mode") == used ]]
"$CONFIG_DIR/plugins/quota.sh"
"$CONFIG_DIR/plugins/quota.sh" toggle
python3 - "$TMP/bar.json" <<'PYTEST'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
row = state["showy_quota.codex.primary"]
assert (row["label"], row["slider.percentage"]) == ("23%", "23")
assert "slider.percentage=23" in row["click_script"]
assert int(row["label.width"]) < 60
assert int(state["showy_quota.claude.slot"]["width"]) < 132
# A dim, full-width track makes the used portion readable against total capacity.
for name in ["codex.primary", "claude.primary", "claude.secondary"]:
    bar = state["showy_quota." + name]
    assert bar["label"] == bar["slider.percentage"] + "%"
    track = bar["slider.background.color"]
    assert track[4:] == bar["label.color"][4:], "track follows the theme's muted colour"
    assert 0 < int(track[2:4], 16) < 128, "track stays visible but dimmer than usage"
    assert int(bar["slider.width"]) == 40 and int(bar["slider.background.height"]) > 0
assert not any(name.startswith("showy_quota.openrouter.") for name in state)
labels = [v.get("label", "") for v in state.values()]
assert any("Fable only" in label and "28% used" in label for label in labels), labels
assert "Credits  ·  $11.14" in labels, labels
assert not any("$78.86" in label for label in labels), labels
assert state["quota_detail.mode"]["label"] == "Show remaining instead"
PYTEST
"$CONFIG_DIR/plugins/quota.sh" mode
python3 - "$TMP/bar.json" <<'PYTEST'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
row = state["showy_quota.codex.primary"]
assert row["label"] == "77% left"
assert state["showy_quota.claude.slot"]["width"] == "126"
assert row["slider.background.color"] == state["showy_quota_bracket"]["background.border_color"]
PYTEST

# A free account is not a subscription, even if CodexBar still supplies free-tier quotas.
python3 - "$XDG_CACHE_HOME/showy-quota/usage.json" <<'PYTEST'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
data["providers"][0]["usage"] = {"identity": {"loginMethod": "Free"}}
path.write_text(json.dumps(data))
PYTEST
"$CONFIG_DIR/plugins/quota.sh"
python3 - "$TMP/bar.json" <<'PYTEST'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert not any(name.startswith("showy_quota.codex.") for name in state)
assert state["showy_quota.claude.primary"]["y_offset"] == "7"
assert state["showy_quota.claude.secondary"]["y_offset"] == "-7"
assert state["showy_quota.claude.icon"]["y_offset"] == "0"
assert state["showy_quota.claude.primary"]["label.font"].endswith(":10.0")
assert state["showy_quota.claude.primary"]["slider.background.height"] == "6"
assert state["showy_quota.claude.slot"]["width"] == "132"
assert state["showy_quota_bracket"]["background.height"] == "36"
PYTEST

# Resubscribing shrinks Claude again. An unused Codex quota stays visible without its app running.
cp "$TMP/subscribed-usage.json" "$XDG_CACHE_HOME/showy-quota/usage.json"
python3 - "$TMP/metrics.json" <<'PYTEST'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
data[0]["windows"]["primary"] = {"usedPercent": 0, "remainingPercent": 100, "windowMinutes": 300}
data[0]["windows"]["secondary"].update(usedPercent=0, remainingPercent=100)
path.write_text(json.dumps(data))
PYTEST
"$CONFIG_DIR/plugins/quota.sh"
"$CONFIG_DIR/plugins/quota.sh" toggle
python3 - "$TMP/bar.json" <<'PYTEST'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert state["showy_quota.codex.primary"]["label"] == "100% left"
assert state["showy_quota.codex.primary"]["icon"] == "7d", "prefer Codex's weekly quota in the bar"
assert state["showy_quota.codex.primary"]["y_offset"] == "-11"
assert "showy_quota.codex.secondary" not in state, "Codex gets one bar row, not a fourth lane"
assert state["showy_quota.claude.primary"]["slider.background.height"] == "4"
labels = [v.get("label", "") for k, v in state.items() if k.startswith("quota_detail.")]
assert any(label.startswith("5h  ·  100% left") for label in labels), labels
assert any(label.startswith("7d  ·  100% left") for label in labels), labels
assert "Credits  ·  $11.14" in labels
# A provider removal/re-addition must not move the robot back across the stats.
order = list(state)
assert order.index("splashbar") == order.index("showy_quota.claude.icon") + 1, order
PYTEST
"$CONFIG_DIR/plugins/quota.sh" toggle

# Removing the provider altogether also gives Claude the full-height, two-row layout.
printf '{"schema":1,"providers":[]}\n' >"$XDG_CACHE_HOME/showy-quota/usage.json"
python3 - "$TMP/metrics.json" <<'PYTEST'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
path.write_text(json.dumps([p for p in json.loads(path.read_text()) if p["provider"] != "codex"]))
PYTEST
"$CONFIG_DIR/plugins/quota.sh"
python3 - "$TMP/bar.json" <<'PYTEST'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert not any(name.startswith("showy_quota.codex.") for name in state)
assert state["showy_quota.claude.primary"]["y_offset"] == "7"
assert state["showy_quota.claude.secondary"]["y_offset"] == "-7"
PYTEST

# An auth/network error or missing plan is unknown, not an expired subscription.
cp "$TMP/subscribed-usage.json" "$XDG_CACHE_HOME/showy-quota/usage.json"
python3 - "$XDG_CACHE_HOME/showy-quota/usage.json" <<'PYTEST'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
data["providers"][0] = {"provider": "codex", "error": {"message": "Login required"}}
path.write_text(json.dumps(data))
PYTEST
"$CONFIG_DIR/plugins/quota.sh"
python3 - "$TMP/bar.json" <<'PYTEST'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert state["showy_quota.codex.primary"]["label"] == "no data"
assert state["showy_quota.codex.primary"]["y_offset"] == "-11"
assert state["showy_quota.codex.icon"]["drawing"] == "on"
PYTEST

# Errors/unknown data never show a healthy 0%.
printf '{"schema":1,"providers":[]}\n' >"$XDG_CACHE_HOME/showy-quota/usage.json"
cat >"$TMP/metrics.json" <<'JSON'
[
  {"provider":"codex","windows":{"primary":null,"secondary":{"usedPercent":null,"remainingPercent":null,"windowMinutes":10080}},"error":null},
  {"provider":"claude","windows":{},"error":{"message":"Login required"}}
]
JSON
"$CONFIG_DIR/plugins/quota.sh"
"$CONFIG_DIR/plugins/quota.sh" toggle
python3 - "$TMP/bar.json" <<'PYTEST'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert not any(name.startswith("showy_quota.openrouter.") for name in state)
assert int(state["showy_quota.codex.primary"]["y_offset"]) < int(state["showy_quota.claude.primary"]["y_offset"])
assert state["showy_quota.codex.primary"]["label"] == "unknown"
assert state["showy_quota.claude.primary"]["label"] == "no data"
assert state["showy_quota.claude.primary"]["slider.highlight_color"] == "0x00000000"
assert any(v.get("label") == "Login required" for v in state.values())
assert not any("open -b" in v.get("click_script", "") for v in state.values())
PYTEST
"$CONFIG_DIR/plugins/quota.sh" toggle

# The theme, data boundary, and keyboard shortcut remain part of the same contract.
bash -c 'source "$CONFIG_DIR/quota.env"; [[ $SKETCHYBAR_QUOTA_MODE == remaining ]]'
PLUGIN_DIR="$CONFIG_DIR/plugins" bash "$SOURCE/items/quota.sh"
python3 - "$ROOT" "$TMP/calls" <<'PYTEST'
import json, pathlib, sys, tomllib
root = pathlib.Path(sys.argv[1])
config = tomllib.loads((root / "home/dot_config/aerospace/aerospace.toml").read_text())
assert "quota_toggle" in config["mode"]["main"]["binding"]["ctrl-alt-q"]
bar = (root / "home/dot_config/sketchybar/executable_sketchybarrc").read_text()
assert bar.index('source "$ITEM_DIR/spotify.sh"') < bar.index('source "$ITEM_DIR/quota.sh"')
calls = [json.loads(line) for line in pathlib.Path(sys.argv[2]).read_text().splitlines()]
assert any("--subscribe" in call and "front_app_switched" in call and "quota_toggle" in call for call in calls)
PYTEST
echo 'stacked quotas, subscription transitions, single-pass refresh, menu details, modes, errors and visibility ok'
