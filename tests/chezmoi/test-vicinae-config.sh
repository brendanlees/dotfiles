#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
python3 - "$repo_root" <<'PY'
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

sys.dont_write_bytecode = True
root = Path(sys.argv[1])
config = root / "home/dot_config/vicinae"
profile = json.loads((config / "profile.json").read_text())
inventory = json.loads((config / "extensions.json").read_text())
names = {item["name"] for item in inventory}
assert len(names) == len(inventory)
assert all(set(item) == {"name", "author"} for item in inventory)
assert set(profile) == {"$schema", "global_shortcuts", "launcher_window", "providers"}
# Qt maps super to the physical Control key on macOS.
assert profile["global_shortcuts"] == {"toggle": "super+SPACE"}
assert not (config / "settings.json").exists(), "writable local settings must not be tracked"
assert not list(config.glob("*settings.json*")), "do not capture local settings via a chezmoi attribute"
shortcuts = [profile["global_shortcuts"]["toggle"]]
for provider, data in profile["providers"].items():
    assert set(data) == {"entrypoints"}, "extension preferences must remain local"
    if provider.startswith("store.raycast."):
        assert provider.removeprefix("store.raycast.") in names
    for item in data["entrypoints"].values():
        assert set(item) <= {"alias", "shortcut", "enabled"}
        assert isinstance(item["enabled"], bool)
        if "alias" in item:
            assert isinstance(item["alias"], str) and item["alias"].strip()
        if "shortcut" in item:
            assert item["shortcut"] and not any(c.isspace() for c in item["shortcut"])
            if item["enabled"]:
                shortcuts.append(item["shortcut"])
assert len(shortcuts) == len(set(shortcuts)), "active global shortcuts must not collide"
providers = profile["providers"]
# On macOS Qt's control is Command; super is physical Control.
assert providers["applications"]["entrypoints"]["com.apple.finder"]["shortcut"] == "control+alt+F"
assert providers["applications"]["entrypoints"]["io.robbie.HomeAssistant"]["shortcut"] == "super+alt+H"
assert providers["snippets"]["entrypoints"]["manage"]["enabled"] is False
assert providers["core"]["entrypoints"]["search-emojis"]["shortcut"] == "super+alt+SPACE"
assert providers["files"]["entrypoints"]["search"]["enabled"] is True

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
