#!/usr/bin/env python3
"""Install the listed Raycast Store bundles into Vicinae, without copying user data."""

import argparse
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import tempfile
import urllib.parse
import zipfile

API = "https://backend.raycast.com/api/v1/extensions"
MAX_DOWNLOAD = 100 * 1024 * 1024
MAX_EXPANDED = 500 * 1024 * 1024


def fetch(url, limit):
    # Python's macOS system-proxy discovery can hang before its socket timeout.
    # curl also bounds redirects and transfer size, without logging signed URLs.
    result = subprocess.run(
        ["curl", "--fail", "--silent", "--show-error", "--location",
         "--proto", "=https", "--proto-redir", "=https", "--max-time", "60",
         "--max-filesize", str(limit), url],
        capture_output=True, timeout=70, check=False,
    )
    if result.returncode:
        raise ValueError(f"download failed (curl exit {result.returncode})")
    data = result.stdout
    if len(data) > limit:
        raise ValueError("download exceeds size limit")
    return data


def validate_package(package, name):
    if package.get("name") != name:
        raise ValueError("downloaded package does not match requested extension")
    preferences = package.get("preferences", []) + [
        pref for cmd in package.get("commands", []) for pref in cmd.get("preferences", [])
    ]
    for pref in preferences:
        # Some extensions declare API tokens as ordinary text, which Vicinae
        # would persist in settings.json. Do not install those unnoticed.
        if pref.get("type") == "textfield" and re.search(
            r"token|password|secret|api.?key", pref.get("name", ""), re.IGNORECASE
        ):
            raise ValueError("credential declared as plain text; review before installing")


def extract_bundle(data, destination, name):
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        members = archive.infolist()
        if sum(item.file_size for item in members) > MAX_EXPANDED:
            raise ValueError("expanded archive exceeds size limit")
        for item in members:
            path = PurePosixPath(item.filename)
            mode = item.external_attr >> 16
            if (
                path.is_absolute()
                or ".." in path.parts
                or "\\" in item.filename
                or stat.S_ISLNK(mode)
            ):
                raise ValueError("unsafe archive member")
        roots = {PurePosixPath(item.filename).parts[0] for item in members}
        if len(roots) != 1:
            raise ValueError("expected one top-level bundle directory")
        root = next(iter(roots))
        validate_package(json.loads(archive.read(f"{root}/package.json")), name)
        # Like Vicinae's installer, strip the store archive's first component.
        for item in members:
            parts = PurePosixPath(item.filename).parts[1:]
            if not parts:
                if not item.is_dir():
                    raise ValueError("unexpected file at archive root")
                continue
            path = destination.joinpath(*parts)
            if item.is_dir():
                path.mkdir(parents=True, exist_ok=True)
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(archive.read(item))
                path.chmod(0o644 | ((item.external_attr >> 16) & 0o111))


def install(extension, directory):
    name = extension["name"]
    target = directory / f"store.raycast.{name}"
    if target.exists() or target.is_symlink():
        return "already present; unchanged"
    author = urllib.parse.quote(extension["author"], safe="")
    slug = urllib.parse.quote(name, safe="")
    metadata = json.loads(fetch(f"{API}/{author}/{slug}", 5 * 1024 * 1024))
    if metadata.get("name") != name:
        raise ValueError("store metadata does not match requested extension")
    url = metadata["download_url"]
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.hostname != "extensions.raycast-releases.com":
        raise ValueError("unexpected bundle download host")
    data = fetch(url, MAX_DOWNLOAD)
    directory.mkdir(parents=True, exist_ok=True)
    # Vicinae ignores dot-prefixed directories while the bundle is incomplete.
    with tempfile.TemporaryDirectory(prefix=".staging-", dir=directory) as temporary:
        staged = Path(temporary) / "bundle"
        staged.mkdir()
        extract_bundle(data, staged, name)
        if target.exists() or target.is_symlink():
            return "already present; unchanged"
        staged.rename(target)
    return "installed; compatibility and sign-in still need testing"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install", action="store_true",
                        help="download missing bundles; otherwise only list the plan")
    parser.add_argument("names", nargs="*", help="optional extension slugs; default: all")
    args = parser.parse_args()
    inventory = json.loads(Path(__file__).with_name("extensions.json").read_text())
    known = {item["name"] for item in inventory}
    if set(args.names) - known:
        parser.error("unknown extension name")
    directory = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "vicinae/extensions"
    failures = 0
    for extension in inventory:
        name = extension["name"]
        if args.names and name not in args.names:
            continue
        if not re.fullmatch(r"[A-Za-z0-9_-]+", name):
            parser.error("unsafe extension name in inventory")
        if not args.install:
            print(f"{name}: planned -> {directory / ('store.raycast.' + name)}")
            continue
        try:
            print(f"{name}: {install(extension, directory)}")
        except ValueError as error:
            print(f"{name}: not installed: {error}")
            failures += 1
        except Exception as error:
            # Network errors may contain signed download URLs. Do not print them.
            print(f"{name}: not installed ({type(error).__name__}); retry or use Vicinae's Raycast Store")
            failures += 1
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
