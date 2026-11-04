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
    "@thomaslombart/store.raycast.github": "includeTeamReviewRequests isOpenInBrowser repositoryCloneProtocol repositoryFilterMode",
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
assert providers["@thomaslombart/store.raycast.github"]["preferences"]["isOpenInBrowser"] is True
# On macOS Qt's control is Command; super is physical Control.
assert providers["applications"]["entrypoints"]["com.apple.finder"]["shortcut"] == "control+alt+F"
assert providers["applications"]["entrypoints"]["io.robbie.HomeAssistant"]["shortcut"] == "super+alt+H"
assert providers["applications"]["entrypoints"].get("com.spotify.client") == {
    "enabled": True, "shortcut": "alt+Y",
}, "Vicinae must launch Spotify with Option+Y"
assert providers["snippets"]["entrypoints"]["manage"]["enabled"] is False
assert providers["core"]["entrypoints"]["search-emojis"]["shortcut"] == "super+alt+SPACE"
assert providers["files"]["entrypoints"]["search"]["enabled"] is True
assert "shortcut" not in providers["applications"]["entrypoints"]["md.obsidian"]
assert providers["scripts"]["entrypoints"]["obsidian-daily.sh"] == {"enabled": True}
assert "alt+N" not in shortcuts, "AeroSpace owns Alt+N without Vicinae's success HUD"
aerospace = tomllib.loads((root / "home/dot_config/aerospace/aerospace.toml").read_text())
assert "alt-y" not in aerospace["mode"]["main"]["binding"], "Vicinae alone owns Option+Y"
notes_binding = aerospace["mode"]["main"]["binding"]["alt-n"]
assert notes_binding.startswith("exec-and-forget ")
notes_command = notes_binding.removeprefix("exec-and-forget ")
assert providers["applications"]["entrypoints"]["com.mitchellh.ghostty"] == {"enabled": True}
assert "alt+T" not in shortcuts, "AeroSpace owns Alt+T without activating the notes window"
terminal_binding = aerospace["mode"]["main"]["binding"]["alt-t"]
assert terminal_binding.startswith("exec-and-forget ")
terminal_command = terminal_binding.removeprefix("exec-and-forget ")

# Alt+N and Alt+T must not interfere with each other's Ghostty windows.
# Keep these launcher regressions with the binding's existing contract owner.
fake_tool = r'''#!/usr/bin/env python3
import fcntl, json, os, sys, time
from pathlib import Path

tool, args = Path(sys.argv[0]).name, sys.argv[1:]
if tool == "lockf":
    assert args == ["-s", "-t", "0", "9"]
    try:
        fcntl.flock(9, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(75)
    sys.exit(0)

# The local headless server starts in the background; serialize fixture state.
with open(os.environ["FAKE_STATE"] + ".lock", "w") as guard:
    fcntl.flock(guard, fcntl.LOCK_EX)
    state_file = Path(os.environ["FAKE_STATE"])
    state = json.loads(state_file.read_text())
    target = args[:2] if tool == "herdr" and args[:1] in (["--machine"], ["--session"]) else []
    args = args[len(target):]
    with open(os.environ["FAKE_LOG"], "a") as log:
        log.write(json.dumps([tool, *args]) + "\n")
    if tool == "ssh":
        sys.exit("notes launcher must not use SSH")
    elif tool in ("pkill", "kill"):
        sys.exit("must not disconnect another client")
    elif tool == "sleep":
        pass
    elif tool == "aerospace":
        if args[:1] == ["list-windows"]:
            assert args == ["list-windows", "--all", "--format",
                            "%{window-id} %{app-bundle-id} %{window-title}", "--json"]
            if state.get("aerospace_failed"):
                sys.exit("AeroSpace unavailable")
            if state.get("pending_window") and not state.get("window_missing"):
                if state.get("window_delay", 0):
                    state["window_delay"] -= 1
                else:
                    state["windows"].append(state.pop("pending_window"))
            print(json.dumps(state["windows"]))
        elif args[:1] == ["move-node-to-workspace"]:
            assert args[1:2] == ["--window-id"] and args[3:] == ["8-notes"]
            state["moved"] = int(args[2])
        elif args[:1] == ["focus"]:
            assert args[1:2] == ["--window-id"]
            if state.get("focus_failed"):
                sys.exit("Window unavailable")
            state["focused"] = int(args[2])
        else:
            raise AssertionError(args)
    elif tool == "osascript":
        script = sys.stdin.read()
        assert 'tell application "Ghostty"' in script
        if args == ["-"]:
            assert "set terminalWindow to new window" in script
            assert "activate window terminalWindow" in script
            if state.get("osascript_failed"):
                sys.exit("Ghostty unavailable")
            state["windows"].append({
                "window-id": 43, "app-bundle-id": "com.mitchellh.ghostty", "window-title": " ",
            })
            state["focused"] = 43
        else:
            assert "set name override of notesTab to item 2 of argv" in script
            assert "set name override of focused terminal of notesTab to item 2 of argv" in script
            assert state["focused_tab"] == next(t["tab_id"] for t in state["tabs"] if t["label"] == "notes")
            state["pending_window"] = {
                "window-id": 42, "app-bundle-id": "com.mitchellh.ghostty", "window-title": args[2],
            }
    elif tool == "nohup":
        # Background servers must not inherit the launch lock.
        try:
            os.fstat(9)
        except OSError:
            pass
        else:
            raise AssertionError("headless server inherited launch lock")
        assert args == ["herdr", "--session", "ov", "server"]
        assert Path.cwd() == (Path.home() / "Notes/Obsidian/PKM").resolve()
        state["running"] = not state.get("start_failed", False)
    elif args == ["machine", "list", "--json"]:
        sys.exit("notes launcher must not query saved SSH machines")
    else:
        assert tool == "herdr" and target == ["--session", "ov"], (tool, target)
        if not state["running"]:
            sys.exit("server_not_running")
        result = {}
        if args[:2] == ["tab", "list"]:
            result = {"tabs": state["tabs"]}
        elif args[:2] == ["pane", "list"]:
            result = {"panes": state["panes"]}
        elif args[:2] == ["pane", "process-info"]:
            result = {"process_info": state.get("process_info", {
                "shell_pid": 10, "foreground_process_group_id": 20 if state["busy"] else 10,
            })}
        elif args[:2] == ["workspace", "create"]:
            assert args[2:] == ["--label", "notes", "--cwd", str(Path.home() / "Notes/Obsidian/PKM")]
            state["tabs"].append({"tab_id": "w9:t1", "label": "1"})
            state["panes"].append({"pane_id": "w9:p1", "tab_id": "w9:t1"})
            result = {"tab": {"tab_id": "w9:t1"}, "root_pane": {"pane_id": "w9:p1"}}
        elif args[:2] == ["tab", "rename"]:
            next(tab for tab in state["tabs"] if tab["tab_id"] == args[2])["label"] = args[3]
        elif args[:2] == ["tab", "focus"]:
            state["focused_tab"] = args[2]
        elif args[:2] == ["pane", "run"]:
            state["busy"] = True
        else:
            raise AssertionError(args)
        print(json.dumps({"id": "fake", "result": result}))
    state_file.write_text(json.dumps(state))
if tool == "sleep":
    time.sleep(0.01)
'''

notes = {
    "tabs": [{"tab_id": "w5:t1", "label": "agent"}, {"tab_id": "w6:t1", "label": "notes"}],
    "panes": [{"pane_id": "w5:p2", "tab_id": "w5:t1"}, {"pane_id": "w6:p1", "tab_id": "w6:t1"}],
}
title = "Obsidian Notes (Herdr)"
unrelated_windows = [
    {"window-id": 11, "app-bundle-id": "com.mitchellh.ghostty", "window-title": " "},
    {"window-id": 12, "app-bundle-id": "com.mitchellh.ghostty", "window-title": "another project"},
    {"window-id": 13, "app-bundle-id": "unrelated.app", "window-title": title},
]
daily = "cd ~/Notes/Obsidian/PKM && nvim -c 'Obsidian today'"
focus_notes = [
    ["aerospace", "move-node-to-workspace", "--window-id", "42", "8-notes"],
    ["aerospace", "focus", "--window-id", "42"],
]
def window(attach):
    return [["osascript", "-", f"/bin/zsh -lic 'exec {attach}'", title], *focus_notes]

from contextlib import contextmanager
@contextmanager
def ghostty_launcher(command=notes_command, **state):
    with tempfile.TemporaryDirectory(prefix="ghostty launcher ") as temporary:
        temp = Path(temporary)
        (temp / "Notes/Obsidian/PKM").mkdir(parents=True)
        script = temp / ".local/share/vicinae/scripts/obsidian-daily.sh"
        script.parent.mkdir(parents=True)
        shutil.copy(root / "home/dot_local/share/vicinae/scripts/executable_obsidian-daily.sh", script)
        terminal_script = temp / ".config/aerospace/focus-terminal.sh"
        terminal_script.parent.mkdir(parents=True)
        shutil.copy(root / "home/dot_config/aerospace/executable_focus-terminal.sh", terminal_script)
        initial_windows = state.get("windows", unrelated_windows)
        for tool in ["herdr", "osascript", "aerospace", "ssh", "nohup", "sleep", "lockf", "pkill", "kill"]:
            (temp / tool).write_text(fake_tool)
            (temp / tool).chmod(0o700)
        state_file, log_file = temp / "state.json", temp / "calls.log"
        state_file.write_text(json.dumps({
            "running": True, "busy": False, "windows": unrelated_windows, **notes, **state,
        }))
        def invoke(*, fail=None):
            log_file.write_text("")
            result = subprocess.run(
                ["/bin/bash", "-c", command],
                capture_output=True, text=True, timeout=15,
                env={**os.environ, "HOME": str(temp),
                     "PATH": str(temp) + os.pathsep + os.environ["PATH"],
                     "FAKE_STATE": str(state_file), "FAKE_LOG": str(log_file)},
            )
            if fail:
                assert result.returncode != 0 and fail in result.stderr, result
            else:
                assert result.returncode == 0, result.stderr
            reads = (["tab", "list"], ["pane", "list"], ["pane", "process-info"])
            calls = [json.loads(line) for line in log_file.read_text().splitlines()]
            calls = [call for call in calls if not (
                (call[0] == "herdr" and call[1:3] in reads)
                or call[:2] == ["aerospace", "list-windows"] or call[0] == "sleep"
            )]
            current = json.loads(state_file.read_text())
            assert current["windows"][:len(initial_windows)] == initial_windows, "existing windows stay untouched"
            return calls, current
        yield invoke, state_file, temp

with ghostty_launcher(window_delay=2) as (invoke, state_file, temp):
    calls, state = invoke()
    assert calls == [
        ["herdr", "pane", "run", "w6:p1", daily],
        ["herdr", "tab", "focus", "w6:t1"],
        *window("herdr --session ov"),
    ]
    assert state["moved"] == state["focused"] == 42
    calls, state = invoke()
    assert calls == focus_notes, "repeat Alt+N only focuses the existing notes window"
    # Closing notes must not lose the editor or leave a stale window-ID cache.
    state["windows"] = unrelated_windows
    state_file.write_text(json.dumps(state))
    calls, _ = invoke()
    assert calls == [
        ["herdr", "tab", "focus", "w6:t1"], *window("herdr --session ov"),
    ], "reopening attaches locally without restarting Neovim"

with ghostty_launcher(busy=True) as (invoke, _, _):
    calls, _ = invoke()
    assert calls == [
        ["herdr", "tab", "focus", "w6:t1"], *window("herdr --session ov"),
    ], "local routing never sends input to a running editor"

with ghostty_launcher(process_info={}) as (invoke, _, _):
    calls, _ = invoke()
    assert not any(call[:3] == ["herdr", "pane", "run"] for call in calls), "unknown process is not an idle shell"

with ghostty_launcher(running=False, tabs=[], panes=[]) as (invoke, _, temp):
    calls, _ = invoke()
    assert calls == [
        ["nohup", "herdr", "--session", "ov", "server"],
        ["herdr", "workspace", "create", "--label", "notes", "--cwd", str(temp / "Notes/Obsidian/PKM")],
        ["herdr", "tab", "rename", "w9:t1", "notes"],
        ["herdr", "pane", "run", "w9:p1", daily],
        ["herdr", "tab", "focus", "w9:t1"],
        *window("herdr --session ov"),
    ], "cold start prepares the local vault before attaching exactly one window"

with ghostty_launcher(running=False, start_failed=True) as (invoke, _, _):
    calls, _ = invoke(fail="did not become ready")
    assert len(calls) == 1 and calls[0][0] == "nohup", "failed startup opens no window"

with ghostty_launcher() as (invoke, _, temp):
    (temp / "Notes/Obsidian/PKM").rmdir()
    calls, _ = invoke(fail="No such file or directory")
    assert not calls, "a missing local vault must not start a server or open a window"

with ghostty_launcher(aerospace_failed=True) as (invoke, _, _):
    calls, _ = invoke(fail="AeroSpace unavailable")
    assert not calls, "failed window discovery must not spawn duplicates"

with ghostty_launcher(window_missing=True) as (invoke, _, _):
    calls, _ = invoke(fail="AeroSpace could not find it")
    assert sum(call[0] == "osascript" for call in calls) == 1
    assert not any(call[:2] == ["aerospace", "focus"] for call in calls)

# Holding the same lock simulates a second hotkey while the first is starting.
import fcntl
with ghostty_launcher() as (invoke, _, temp):
    lock = temp / ".cache/vicinae/obsidian-notes.lock"
    lock.parent.mkdir(parents=True)
    with lock.open("w") as held:
        fcntl.flock(held, fcntl.LOCK_EX)
        calls, _ = invoke()
        assert not calls, "overlapping invocations do nothing"
    calls, _ = invoke()
    assert any(call[0] == "osascript" for call in calls), "released locks do not block future launches"

# Alt+T reuses a regular terminal across workspaces, never the named notes window.
notes_window = {"window-id": 42, "app-bundle-id": "com.mitchellh.ghostty", "window-title": title}
other_app = {"window-id": 14, "app-bundle-id": "unrelated.app", "window-title": "project"}
with ghostty_launcher(command=terminal_command, windows=[notes_window, other_app, *unrelated_windows]) as (invoke, _, _):
    calls, state = invoke()
    assert calls == [["aerospace", "focus", "--window-id", "11"]]
    assert state["focused"] == 11 and "moved" not in state
    calls, _ = invoke()
    assert calls == [["aerospace", "focus", "--window-id", "11"]], "repeated Alt+T reuses the terminal"

# With only notes, or with no Ghostty windows, create a normal window once.
for existing in [[notes_window, other_app], [other_app], []]:
    with ghostty_launcher(command=terminal_command, windows=existing) as (invoke, _, _):
        calls, state = invoke()
        assert calls == [["osascript", "-"]]
        assert state["focused"] == 43 and "moved" not in state
        assert len(state["windows"]) == len(existing) + 1
        calls, _ = invoke()
        assert calls == [["aerospace", "focus", "--window-id", "43"]], "reuse the newly opened terminal"

with ghostty_launcher(command=terminal_command, aerospace_failed=True) as (invoke, _, _):
    calls, _ = invoke(fail="AeroSpace unavailable")
    assert not calls, "failed discovery must not open another window"

with ghostty_launcher(command=terminal_command, focus_failed=True) as (invoke, _, _):
    calls, _ = invoke(fail="Window unavailable")
    assert calls == [["aerospace", "focus", "--window-id", "11"]], "failed focus must not open another window"

with ghostty_launcher(command=terminal_command, windows=[notes_window], osascript_failed=True) as (invoke, _, _):
    calls, state = invoke(fail="Ghostty unavailable")
    assert calls == [["osascript", "-"]] and state["windows"] == [notes_window]

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
    shutil.copytree(root / "home/dot_config/aerospace", fixture / "dot_config/aerospace")
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
    assert os.access(fresh / ".config/aerospace/focus-terminal.sh", os.X_OK)
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
