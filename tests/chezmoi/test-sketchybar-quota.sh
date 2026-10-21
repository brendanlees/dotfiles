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
state = json.loads(path.read_text()) if path.exists() else {"spotify": {}, "showy_quota.trigger": {}}
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
            state = {**{k: v for k, v in state.items() if k not in values},
                     **{k: state[k] for k in values if k in state}}
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
{"schema":1,"providers":[{"provider":"openrouter","usage":{"providerCost":{"balance":11.14,"currencyCode":"USD"},"details":[{"title":"Credits","rows":[{"label":"Remaining","value":"$11.14"},{"label":"Used","value":"$78.86"}]}]}}]}
JSON
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
assert codex["y_offset"] == "7"
assert (claude["icon"], claude["label"], claude["y_offset"]) == ("5h", "96% left", "7")
assert state["showy_quota.claude.secondary"]["label"] == "81% left"
balance = state["showy_quota.openrouter.balance"]
assert balance["label"] == "$11.14 left" and balance["y_offset"] == "-7"
assert "slider.percentage" not in balance, "credit balance must not become a fabricated quota"
assert state["showy_quota.openrouter.icon"]["y_offset"] == "-7"
assert state["showy_quota.openrouter.icon"]["icon"] == ":openrouter:"
assert state["showy_quota.openrouter.icon"]["icon.font"].startswith("sketchybar-app-font:")
assert "showy_quota.openrouter.slot" not in state, "OpenRouter must share Codex's column"
order = list(state)
assert order.index("showy_quota.openrouter.balance") < order.index("showy_quota.codex.slot")
assert order.index("showy_quota.openrouter.icon") < order.index("showy_quota.codex.icon")
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
assert "y_offset=7" in writes[0], writes
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
assert "Credits  ·  $11.14 left" in labels, labels
assert state["quota_detail.mode"]["label"] == "Show used instead"
PYTEST

# Mode switches change quota fill and text, but OpenRouter always shows its current balance.
"$CONFIG_DIR/plugins/quota.sh" mode
[[ $(<"$XDG_CACHE_HOME/sketchybar/quota-mode") == used ]]
"$CONFIG_DIR/plugins/quota.sh"
"$CONFIG_DIR/plugins/quota.sh" toggle
python3 - "$TMP/bar.json" <<'PYTEST'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
row = state["showy_quota.codex.primary"]
assert (row["label"], row["slider.percentage"]) == ("23% used", "23")
assert "slider.percentage=23" in row["click_script"]
assert state["showy_quota.openrouter.balance"]["label"] == "$11.14 left"
labels = [v.get("label", "") for v in state.values()]
assert any("Fable only" in label and "28% used" in label for label in labels), labels
assert "Credits  ·  $11.14 left" in labels, labels
assert not any("$78.86" in label for label in labels), labels
assert state["quota_detail.mode"]["label"] == "Show remaining instead"
PYTEST
"$CONFIG_DIR/plugins/quota.sh" mode

# Removing OpenRouter restores a centred Codex row. Errors/unknown data never show a healthy 0%.
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
assert state["showy_quota.codex.primary"]["y_offset"] == "0"
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
echo 'quota grouping, single-pass refresh, Fable details, modes, errors and visibility ok'
