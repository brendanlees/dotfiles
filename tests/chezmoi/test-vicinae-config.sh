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

def render(template, home, data=None):
    with tempfile.TemporaryDirectory() as temporary:
        temp = Path(temporary)
        (temp / "config.toml").write_text("[data]\n")
        result = subprocess.run([
            "chezmoi", "execute-template", "--source", str(root),
            "--config", str(temp / "config.toml"),
            "--persistent-state", str(temp / "state.boltdb"),
            "--override-data", json.dumps({"chezmoi": {"homeDir": home}, **(data or {})}),
        ], input=template.read_text(), check=True, capture_output=True, text=True,
           env=without_vault(temp))
        return json.loads(result.stdout)

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
    (tmp / "config.toml").write_text("[data]\n")

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
    target = fresh / ".local/share/vicinae/shortcuts/shortcuts.json"
    assert json.loads(fresh_settings.read_text()) == {"imports": ["./profile.json"]}
    created = json.loads(target.read_text())
    assert {x["id"] for x in created} == ids
    assert all(x["openCount"] == 0 and isinstance(x["createdAt"], int) and x["createdAt"] > 0 for x in created)
    assert all(x["createdAt"] == x["updatedAt"] for x in created)
    assert target.stat().st_mode & 0o777 == 0o600
    assert fresh_settings.stat().st_mode & 0o777 == 0o600
    before = target.read_bytes()
    apply(fresh)
    assert target.read_bytes() == before, "reapplying must not reset creation times or history"

    # Mutable settings (including JSONC, secrets, imports, and aliases) stay byte-for-byte local.
    settings_bytes = b'// local settings\n{"imports":["./local.json"],"providers":{"private":{"preferences":{"apiToken":"fixture-secret"}},"shortcuts":{"entrypoints":{"local-private":{"alias":"private"}}}}\n'
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
    apply(fresh)
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
