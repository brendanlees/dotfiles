#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
python3 - "$repo_root" <<'PY'
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import tomllib
import zipfile

sys.dont_write_bytecode = True
root = Path(sys.argv[1])
config = root / "home/dot_config/vicinae"
def without_vault(temp):
    fake_bin = temp / "bin"
    fake_bin.mkdir()
    bw = fake_bin / "bw"
    bw.write_text("#!/bin/sh\necho 'Bitwarden must not run during render/apply' >&2\nexit 99\n")
    bw.chmod(0o700)
    return {**os.environ, "PATH": str(fake_bin) + os.pathsep + os.environ["PATH"]}

def render(template, home, data=None, *, parse=json.loads):
    with tempfile.TemporaryDirectory() as temporary:
        temp = Path(temporary)
        (temp / "config.toml").write_text("[data]\n")
        result = subprocess.run([
            "chezmoi", "execute-template", "--source", str(root),
            "--config", str(temp / "config.toml"),
            "--persistent-state", str(temp / "state.boltdb"),
            "--override-data", json.dumps({"chezmoi": {"homeDir": home}, **(data or {})}),
        ], input=template.read_text() if isinstance(template, Path) else template,
           check=True, capture_output=True, text=True, env=without_vault(temp))
        return parse(result.stdout)

profile = render(config / "profile.json.tmpl", "/Users/alice")
definitions = render(root / "home/.chezmoitemplates/vicinae-shortcuts.json.tmpl", "/Users/alice")
inventory = json.loads((config / "extensions.json").read_text())
names = {item["name"] for item in inventory}
assert len(names) == len(inventory)
assert all(set(item) == {"name", "author"} for item in inventory)
# Provider IDs use the bundle's manifest author, not its directory or Store publisher.
# These organization-owned extensions have different authors, verified against
# registered Vicinae providers and Reclaim's public package.json (not installed).
manifest_authors = {
    "apple-reminders": "thomaslombart",
    "browser-bookmarks": "thomaslombart",
    "devutils": "vietanhlehuu",
    "github": "thomaslombart",
    "google-workspace": "thomaslombart",
    "reclaim-ai": "lightbody",
    "tailscale": "samlinville",
}
expected_extension_ids = {
    f"@{manifest_authors.get(item['name'], item['author'])}/store.raycast.{item['name']}"
    for item in inventory
}
actual_extension_ids = {key for key in profile["providers"] if "store.raycast." in key}
assert actual_extension_ids == expected_extension_ids, (
    "profile must target full runtime provider IDs, including the manifest author"
)
assert set(profile) == {
    "$schema", "global_shortcuts", "launcher_window", "providers", "font", "theme", "telemetry",
}
# The current GUI choice is Command+Space (Qt calls Command "control" on macOS).
assert profile["global_shortcuts"] == {"toggle": "control+SPACE"}
assert profile["telemetry"]["system_info"] is False
assert profile["theme"] == {
    "dark": {"name": "chezmoi"},
    "light": {"name": "chezmoi"},
}, "both system appearances must follow the active dark dotfiles palette"

themes = render("{{ .themes | toJson }}", "/Users/alice")
theme_template = root / "home/dot_local/share/vicinae/themes/chezmoi.toml.tmpl"

def check_theme(theme, name, palette):
    assert theme["meta"]["name"] == f"Chezmoi · {name}"
    assert theme["meta"]["variant"] == "dark"
    assert theme["meta"]["inherits"] == "vicinae-dark"
    colors = theme["colors"]
    assert colors["core"] == {
        "background": palette["bg"], "foreground": palette["fg"],
        "secondary_background": palette["surface"], "border": palette["border"],
        "accent": palette["accent"], "accent_foreground": palette["bg"],
    }
    # Cover semantic meaning and readable selected text, not just valid hex values.
    for key, token in {"muted": "muted", "placeholder": "comment",
                       "danger": "error", "success": "success"}.items():
        assert colors["text"][key] == palette[token]
    assert colors["text"]["selection"] == {
        "background": palette["accent"], "foreground": palette["bg"],
    }
    assert colors["list"]["item"]["selection"] == {
        "background": palette["surface_alt"], "foreground": palette["fg"],
        "secondary_background": palette["surface_alt"], "secondary_foreground": palette["muted"],
    }
    for key, token in {"blue": "primary", "green": "success", "red": "error",
                       "yellow": "warn", "cyan": "info", "orange": "orange",
                       "magenta": "secondary", "purple": "secondary"}.items():
        assert colors["accents"][key] == palette[token]
    assert colors["input"] == {
        "border": palette["border"], "border_focus": palette["accent"],
        "border_error": palette["error"],
    }

    # Component overrides must not retain hardcoded Vicinae default colors.
    def check_colors(table):
        for value in table.values():
            if isinstance(value, dict):
                check_colors(value)
            else:
                assert value in palette.values(), value
    check_colors(colors)

for name, theme in themes.items():
    rendered = render(theme_template, "/Users/alice", {"theme": name}, parse=tomllib.loads)
    check_theme(rendered, name, theme["palette"])

# Distinct sentinel colors prove token routing even where real palettes share values.
palette = {key: f"#{index:06x}" for index, key in enumerate(themes["moonfly"]["palette"], 1)}
rendered = render(theme_template, "/Users/alice", {
    "theme": "fixture", "themes": {"fixture": {"palette": palette}},
}, parse=tomllib.loads)
check_theme(rendered, "fixture", palette)

assert [p.name for p in config.glob("*settings.json*")] == ["create_private_settings.json"]
assert json.loads((config / "create_private_settings.json").read_text()) == {
    "imports": ["./profile.json"],
}
# Only reviewed preference fields belong in the public profile. New preferences
# require review, rather than copying every field from writable settings.
allowed_preferences = {
    "@ThatNerd/store.raycast.timers": "closeWindowOnTimerStart copyOnSwStop customTimerFormBypass newTimerInputOrder ringContinuously selectedSound showMenuBarIconWhen showTitleInMenuBar volumeSetting",
    "@VladCuciureanu/store.raycast.toothpick": "bluetoothBackend fuzzyRatio",
    "@chkpwd/store.raycast.ente-auth": "deleteExport primaryAction",
    "@destiner/store.raycast.iconify": "customColor iconColor iconNameFormat primaryAction",
    "@dziad/store.raycast.appcleaner": "uninstaller_app",
    "@hugomarfani/store.raycast.pick-your-wallpaper": "wallpaperFolder",
    "@k8scat/store.raycast.dockerhub": "socketPath",
    "@marcjulian/store.raycast.obsidian": "configFileName",
    "@natterstefan/store.raycast.readwise": "pageSize",
    "@rolandleth/store.raycast.kill-process": "clearSearchBarAfterKill closeWindowAfterKill goToRootAfterKill refreshDuration shouldPrioritizeAppsWhenFiltering shouldSearchInPaths shouldSearchInPid shouldShowPID shouldShowPath skipConfirmation",
    "@tholanda/store.raycast.script-commands": "folderPath",
    "@thomaslombart/store.raycast.github": "includeTeamReviewRequests isOpenInBrowser repositoryCloneProtocol repositoryFilterMode vscodeBuild",
    "@tonka3000/store.raycast.homeassistant": "camerarefreshinterval ignorecerts showEntityId usePing",
    "@vimtor/store.raycast.video-downloader": "autoLoadUrlFromClipboard autoLoadUrlFromSelectedText cookiesFromBrowser downloadPath enableBrowserExtensionSupport fastRemux forceIpv4",
    "@yangxy/store.raycast.date-format-converter": "formatWithMillis formatWithTimezone isoDate isoDateTime isoFormat localizedFullDateTime localizedLongDateTime localizedSecondsTime localizedShortDate localizedShortDateTime localizedTime naturalLanguageDateFormat unixMillis unixTimestamp utcIsoFormat",
    "@yuercl/store.raycast.imessage-2fa": "defaultSource emailSource enableVerificationLinks enabledSources ignoreRead lookBackAmount lookBackUnit",
    "snippets": "enabled undo",
    "scripts": "customDirs",
}
shortcuts = [profile["global_shortcuts"]["toggle"]]
for provider, data in profile["providers"].items():
    assert set(data) <= {"entrypoints", "preferences", "enabled"}
    assert set(data.get("preferences", {})) <= set(allowed_preferences.get(provider, "").split())
    if "enabled" in data:
        assert isinstance(data["enabled"], bool)
    for item in data.get("entrypoints", {}).values():
        assert set(item) <= {"alias", "shortcut", "enabled"}
        if "enabled" in item:
            assert isinstance(item["enabled"], bool)
        if "alias" in item:
            assert isinstance(item["alias"], str) and item["alias"].strip()
        if "shortcut" in item:
            assert item["shortcut"] and not any(c.isspace() for c in item["shortcut"])
            if item.get("enabled", True) and data.get("enabled", True):
                shortcuts.append(item["shortcut"])
assert len(shortcuts) == len(set(shortcuts)), "active global shortcuts must not collide"
providers = profile["providers"]
# On macOS Qt's control is Command; super is physical Control.
assert providers["applications"]["entrypoints"]["com.apple.finder"]["shortcut"] == "control+alt+F"
assert providers["applications"]["entrypoints"]["io.robbie.HomeAssistant"]["shortcut"] == "super+alt+H"
assert providers["snippets"]["entrypoints"]["manage"]["enabled"] is False
assert providers["core"]["entrypoints"]["search-emojis"]["shortcut"] == "super+alt+SPACE"
assert providers["files"]["entrypoints"]["search"]["enabled"] is True
assert "shortcut" not in providers["applications"]["entrypoints"]["md.obsidian"]
assert providers["scripts"]["entrypoints"]["obsidian-daily.sh"] == {
    "enabled": True, "shortcut": "alt+N",
}

# Alt+N opens the ov herdr session on its notes tab and starts nvim only from an
# idle shell. An attached client keeps its own view while a new client opens on
# the session's focused tab, so the script replaces any attached window.
fake_tool = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path

tool, args = Path(sys.argv[0]).name, sys.argv[1:]
state_file = Path(os.environ["FAKE_STATE"])
state = json.loads(state_file.read_text())
target = args[:2] if tool == "herdr" and args[:1] in (["--machine"], ["--session"]) else []
args = args[len(target):]
with open(os.environ["FAKE_LOG"], "a") as log:
    log.write(json.dumps([tool, *args]) + "\n")
if tool == "pkill":
    sys.exit(1)  # no attached client to replace
if tool == "osascript":
    assert 'tell application "Ghostty"' in sys.stdin.read()
    state["running"] = True  # attaching starts a stopped session
elif args == ["machine", "list", "--json"]:
    print(json.dumps([{"label": label} for label in state["machines"]]))
elif args == ["session", "list", "--json"]:
    print(json.dumps({"sessions": [{"name": name} for name in state["sessions"]]}))
else:
    assert target == state["target"], target
    if not state["running"]:
        sys.exit("server_not_running")
    result = {}
    if args[:2] == ["tab", "list"]:
        result = {"tabs": state["tabs"]}
    elif args[:2] == ["pane", "list"]:
        result = {"panes": state["panes"]}
    elif args[:2] == ["pane", "process-info"]:
        result = {"process_info": {"shell_pid": 10, "foreground_process_group_id": 20 if state["busy"] else 10}}
    elif args[:2] == ["workspace", "create"]:
        state["tabs"].append({"tab_id": "w9:t1", "label": "1"})
        state["panes"].append({"pane_id": "w9:p1", "tab_id": "w9:t1"})
        result = {"tab": {"tab_id": "w9:t1"}, "root_pane": {"pane_id": "w9:p1"}}
    elif args[:2] == ["tab", "rename"]:
        next(tab for tab in state["tabs"] if tab["tab_id"] == args[2])["label"] = args[3]
    print(json.dumps({"id": "fake", "result": result}))
state_file.write_text(json.dumps(state))
'''

def open_daily_note(**state):
    with tempfile.TemporaryDirectory() as temporary:
        temp = Path(temporary)
        for tool in ["herdr", "osascript", "pkill"]:
            (temp / tool).write_text(fake_tool)
            (temp / tool).chmod(0o700)
        (temp / "state.json").write_text(json.dumps(state))
        result = subprocess.run(
            ["bash", str(root / "home/dot_local/share/vicinae/scripts/executable_obsidian-daily.sh")],
            capture_output=True, text=True,
            env={**os.environ, "PATH": str(temp) + os.pathsep + os.environ["PATH"],
                 "FAKE_STATE": str(temp / "state.json"), "FAKE_LOG": str(temp / "calls.log")},
        )
        assert result.returncode == 0, result.stderr
        reads = (["machine", "list"], ["session", "list"], ["tab", "list"], ["pane", "list"], ["pane", "process-info"])
        calls = [json.loads(line) for line in (temp / "calls.log").read_text().splitlines()]
        return [call for call in calls if call[0] != "herdr" or call[1:3] not in reads]

def window(attach):
    return [["pkill", "-HUP", "-fx", attach], ["osascript", "-", f"/bin/zsh -lic 'exec {attach}'"]]

notes = {
    "tabs": [{"tab_id": "w5:t1", "label": "agent"}, {"tab_id": "w6:t1", "label": "notes"}],
    "panes": [{"pane_id": "w5:p2", "tab_id": "w5:t1"}, {"pane_id": "w6:p1", "tab_id": "w6:t1"}],
}
# A remote attach also leaves a local sessions/ov folder, which must not change the route.
bair = {"machines": ["bmax", "bmax/ov"], "sessions": ["default", "ov"], "target": ["--machine", "bmax/ov"]}
remote = window("herdr --remote bmax --session ov")
daily = "cd ~/Notes/Obsidian/PKM && nvim -c 'Obsidian today'"
assert open_daily_note(**bair, running=True, busy=False, **notes) == [
    ["herdr", "pane", "run", "w6:p1", daily], ["herdr", "tab", "focus", "w6:t1"], *remote,
], "a Mac with the saved bmax/ov machine opens nvim in bmax's idle notes shell"
assert open_daily_note(**bair, running=False, busy=False, tabs=[], panes=[]) == [
    *remote,
    ["herdr", "workspace", "create", "--label", "notes"],
    ["herdr", "tab", "rename", "w9:t1", "notes"],
    ["herdr", "pane", "run", "w9:p1", daily],
    ["herdr", "tab", "focus", "w9:t1"],
    *remote,
], "attaching starts a stopped session, which then gains a notes tab"
assert open_daily_note(
    machines=[], sessions=["default", "ov"], target=["--session", "ov"],
    running=True, busy=True, **notes,
) == [
    ["herdr", "tab", "focus", "w6:t1"], *window("herdr --session ov"),
], "bmax uses its local session, and a running editor never receives typed input"

# Definitions and bindings share one source, so their IDs cannot drift apart.
fields = {"id", "name", "url", "icon", "app"}
ids = {item["id"] for item in definitions}
assert len(ids) == len(definitions)
assert set(providers["shortcuts"]["entrypoints"]) == ids
for item in definitions:
    assert set(item) <= fields | {"enabled", "alias", "shortcut"}
    assert fields <= set(item)
    assert providers["shortcuts"]["entrypoints"][item["id"]] == {
        key: value for key, value in item.items() if key not in fields
    }
assert providers["shortcuts"]["entrypoints"]["sct-77fc8e8817f1"]["enabled"] is False
assert providers["@chkpwd/store.raycast.ente-auth"]["entrypoints"] == {
    "index": {"shortcut": "super+control+alt+O"},
}, "do not restore the removed Ente command overrides from the old migration"

# Reviewable public search services only; no private Notion/internal destinations.
from urllib.parse import urlsplit
public_hosts = {
    "itunes.apple.com", "open.spotify.com", "wphive.com", "web.archive.org",
    "builtwith.com", "www.goodreads.com", "github.com", "www.ebay.com.au",
    "docs.generatepress.com", "docs.generateblocks.com", "translate.google.com",
    "reddit.com", "www.etsy.com", "hub.docker.com", "www.bunnings.com.au",
    "www.amazon.com.au", "en.wikipedia.org", "giphy.com", "stackoverflow.com",
    "www.google.com", "www.youtube.com", "google.com", "duckduckgo.com",
}
for item in definitions:
    url = urlsplit(item["url"])
    assert not url.scheme or url.hostname in public_hosts

# Secret-backed shortcuts are optional and never put their URL in the shared profile.
weekly_id = "sct-a066c2457a04"
webhook = 'https://hooks.example.invalid/webhook/weekly-task-secret?label="quoted"'
secret_data = {"bw_vicinae": {"weekly_tasks_url": webhook}}
definition_template = root / "home/.chezmoitemplates/vicinae-shortcuts.json.tmpl"
assert weekly_id not in ids
for cache in [{}, {"weekly_tasks_url": ""}]:
    assert render(definition_template, "/Users/alice", {"bw_vicinae": cache}) == definitions
with_secret = render(definition_template, "/Users/alice", secret_data)
assert {item["id"] for item in with_secret} == ids | {weekly_id}
weekly = next(item for item in with_secret if item["id"] == weekly_id)
assert weekly["name"] == "[ws] weekly tasks" and weekly["url"] == webhook
secret_profile = render(config / "profile.json.tmpl", "/Users/alice", secret_data)
assert secret_profile["providers"]["shortcuts"]["entrypoints"][weekly_id] == {}
assert "weekly-task-secret" not in json.dumps(secret_profile)

# Render for another user, including a home path needing JSON escaping.
other_home = '/Users/Bob "Test"'
other_profile = render(config / "profile.json.tmpl", other_home)
other_definitions = render(root / "home/.chezmoitemplates/vicinae-shortcuts.json.tmpl", other_home)
assert "/Users/alice" not in json.dumps(other_profile) + json.dumps(other_definitions)
assert other_profile["providers"]["scripts"]["preferences"]["customDirs"] == [
    other_home + "/.config/kanata/scripts/raycast",
]
assert other_profile["providers"]["@vimtor/store.raycast.video-downloader"]["preferences"]["downloadPath"] == other_home + "/Downloads"
assert next(x for x in other_definitions if x["name"] == "Downloads")["url"] == other_home + "/Downloads"
assert next(x for x in other_definitions if x["name"] == "Home")["alias"] == "~"
for source in [config / "profile.json.tmpl", root / "home/.chezmoitemplates/vicinae-shortcuts.json.tmpl"]:
    assert "/Users/" not in source.read_text(), "source must not hardcode a username"

# Exercise real chezmoi apply, not just a separately implemented merge.
with tempfile.TemporaryDirectory() as temporary:
    tmp = Path(temporary)
    fixture = tmp / "source"
    shutil.copytree(config, fixture / "dot_config/vicinae")
    partials = fixture / ".chezmoitemplates"
    partials.mkdir()
    shutil.copy(root / "home/.chezmoitemplates/vicinae-shortcuts.json.tmpl", partials)
    shutil.copytree(root / "home/dot_local/share/vicinae", fixture / "dot_local/share/vicinae")
    (fixture / ".chezmoidata").mkdir()
    shutil.copy(root / "home/.chezmoidata/themes.yml", fixture / ".chezmoidata")
    (tmp / "config.toml").write_text('[data]\ntheme = "moonfly"\n')

    no_vault_env = without_vault(tmp)

    def apply(home, *, check=True, dry_run=False, data=None):
        command = [
            "chezmoi", "apply", "--source", str(fixture), "--destination", str(home),
            "--config", str(tmp / "config.toml"), "--persistent-state", str(tmp / "state.boltdb"),
            "--override-data", json.dumps({"chezmoi": {"homeDir": str(home), "os": "darwin"}, **(data or {})}),
            "--no-tty",
        ]
        if dry_run:
            command.append("--dry-run")
        return subprocess.run(command, check=check, capture_output=True, text=True, env=no_vault_env)

    fresh = tmp / "fresh"
    fresh.mkdir()
    apply(fresh, dry_run=True)
    assert not list(fresh.iterdir()), "dry-run must not create application state"
    apply(fresh)
    fresh_settings = fresh / ".config/vicinae/settings.json"
    theme_file = fresh / ".local/share/vicinae/themes/chezmoi.toml"
    check_theme(tomllib.loads(theme_file.read_text()), "moonfly", themes["moonfly"]["palette"])
    target = fresh / ".local/share/vicinae/shortcuts/shortcuts.json"
    assert json.loads(fresh_settings.read_text()) == {"imports": ["./profile.json"]}
    assert os.access(fresh / ".local/share/vicinae/scripts/obsidian-daily.sh", os.X_OK)
    created = json.loads(target.read_text())
    assert {x["id"] for x in created} == ids
    assert all(x["openCount"] == 0 and isinstance(x["createdAt"], int) and x["createdAt"] > 0 for x in created)
    assert all(x["createdAt"] == x["updatedAt"] for x in created)
    assert target.stat().st_mode & 0o777 == 0o600
    assert fresh_settings.stat().st_mode & 0o777 == 0o600
    before = target.read_bytes()
    apply(fresh)
    assert target.read_bytes() == before, "reapplying must not reset creation times or history"

    # Mutable settings, including explicit theme overrides, stay byte-for-byte local.
    settings_bytes = b'// local settings\n{"imports":["./local.json"],"theme":{"dark":{"name":"local-choice"}},"providers":{"private":{"preferences":{"apiToken":"fixture-secret"}},"shortcuts":{"entrypoints":{"local-private":{"alias":"private"}}}}\n'
    fresh_settings.write_bytes(settings_bytes)
    managed = created[0] | {
        "name": "Old managed name", "url": created[1]["url"], "app": "old-opener",
        "openCount": 17, "createdAt": 10, "updatedAt": 20, "lastUsedAt": 30,
        "futureMetadata": {"keep": True},
    }
    local = {
        "id": "local-private", "name": "Private", "url": "https://private.invalid/work",
        "icon": "local-icon", "app": "local-app", "openCount": 5,
        "createdAt": 1, "updatedAt": 2, "lastUsedAt": 3,
    }
    target.write_text(json.dumps([managed, local]))
    apply(fresh, data={"theme": "kanagawa-wave"})
    check_theme(tomllib.loads(theme_file.read_text()), "kanagawa-wave", themes["kanagawa-wave"]["palette"])
    assert [p.name for p in theme_file.parent.iterdir()] == ["chezmoi.toml"]
    result = {x["id"]: x for x in json.loads(target.read_text())}
    assert result[local["id"]] == local
    assert {key: result[managed["id"]][key] for key in fields} == {key: created[0][key] for key in fields}
    for key in set(managed) - fields:
        assert result[managed["id"]][key] == managed[key], key
    assert fresh_settings.read_bytes() == settings_bytes
    before = target.read_bytes()
    apply(fresh)
    assert target.read_bytes() == before

    # Adding/rotating a cached webhook preserves its stable ID, history, and local settings.
    apply(fresh, data=secret_data)
    records = json.loads(target.read_text())
    weekly = next(item for item in records if item["id"] == weekly_id)
    assert weekly["url"] == webhook
    assert target.stat().st_mode & 0o777 == 0o600
    assert "weekly-task-secret" not in (fresh / ".config/vicinae/profile.json").read_text()
    weekly.update(openCount=9, createdAt=101, updatedAt=202, lastUsedAt=303)
    target.write_text(json.dumps(records))
    original_weekly = weekly.copy()
    apply(fresh, data=secret_data)
    records = json.loads(target.read_text())
    assert sum(item["id"] == weekly_id for item in records) == 1
    assert next(item for item in records if item["id"] == weekly_id) == original_weekly
    replacement = "https://hooks.example.invalid/webhook/replacement-secret"
    apply(fresh, data={"bw_vicinae": {"weekly_tasks_url": replacement}})
    rotated = next(item for item in json.loads(target.read_text()) if item["id"] == weekly_id)
    assert rotated == original_weekly | {"url": replacement}
    before = target.read_bytes()
    apply(fresh, data={"bw_vicinae": {"weekly_tasks_url": ""}})
    assert target.read_bytes() == before, "missing secrets must not erase existing local shortcuts"
    assert fresh_settings.read_bytes() == settings_bytes

    # Reject non-web URLs without leaking the supplied value or changing shortcut data.
    failure = apply(fresh, check=False, data={
        "bw_vicinae": {"weekly_tasks_url": "javascript:weekly-task-secret"},
    })
    assert failure.returncode and "HTTP(S)" in failure.stderr
    assert "weekly-task-secret" not in failure.stdout + failure.stderr
    assert target.read_bytes() == before

    # Independent IDs require explicit reconciliation, not replacement.
    foreign = managed | {"id": "another-macs-id", "url": "~/Downloads"}
    target.write_text(json.dumps([foreign]))
    before = target.read_bytes()
    failure = apply(fresh, check=False)
    assert failure.returncode and "reconcile IDs" in failure.stderr
    assert target.read_bytes() == before and fresh_settings.read_bytes() == settings_bytes

    target.write_text("[broken")
    failure = apply(fresh, check=False)
    assert failure.returncode and target.read_text() == "[broken"

path = config / "executable_install-extensions.py"
spec = importlib.util.spec_from_file_location("installer", path)
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)

def bundle(name="example", extra=None, preferences=None):
    data = io.BytesIO()
    with zipfile.ZipFile(data, "w") as archive:
        archive.writestr("example/package.json", json.dumps({
            "name": name, "commands": [], "preferences": preferences or []
        }))
        archive.writestr("example/index.js", "// fixture, never executed")
        if extra:
            archive.writestr(*extra)
    return data.getvalue()

def rejected(data, destination):
    try:
        installer.extract_bundle(data, destination, "example")
    except ValueError:
        return
    raise AssertionError("unsafe bundle accepted")

with tempfile.TemporaryDirectory() as temporary:
    tmp = Path(temporary)
    installer.extract_bundle(bundle(), tmp / "valid", "example")
    assert (tmp / "valid/index.js").is_file()
    rejected(bundle(name="wrong"), tmp / "wrong")
    rejected(bundle(extra=("../escaped", "no")), tmp / "traversal")
    rejected(bundle(extra=("/absolute", "no")), tmp / "absolute")
    link = zipfile.ZipInfo("example/link")
    link.create_system = 3
    link.external_attr = 0o120777 << 16
    rejected(bundle(extra=(link, "../escaped")), tmp / "symlink")
    rejected(bundle(preferences=[{"name": "apiToken", "type": "textfield"}]), tmp / "token")
    assert not (tmp / "escaped").exists()
    installer.validate_package({
        "name": "example", "preferences": [{"name": "apiToken", "type": "password"}]
    }, "example")
    calls = []
    def fetch(url, limit):
        calls.append(url)
        if url.startswith(installer.API):
            return json.dumps({
                "name": "example",
                "download_url": "https://extensions.raycast-releases.com/fixture",
            }).encode()
        return bundle()
    installer.fetch = fetch
    extension = {"author": "author", "name": "example"}
    assert installer.install(extension, tmp / "extensions").startswith("installed")
    target = tmp / "extensions/store.raycast.example/index.js"
    target.write_text("local edit")
    calls.clear()
    assert installer.install(extension, tmp / "extensions").startswith("already present")
    assert not calls and target.read_text() == "local edit"
    assert not list((tmp / "extensions").glob(".staging-*"))

# The default command is a plan, not an installation or a network request.
result = subprocess.run([sys.executable, str(path), "http-status-codes"],
                        check=True, capture_output=True, text=True)
assert result.stdout.startswith("http-status-codes: planned -> ")
print("Vicinae config and installer ownership, privacy, and safety contracts ok")
PY
