#!/usr/bin/python3
"""Notify about the configured Hermes bridge; stay inactive on other Macs."""

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

BRIDGE_ROOT = Path.home() / "Code/homelab/hermes-obsidian-overlay"
STATE = Path.home() / "Library/Application Support/Syncthing/health-check-state.json"
RENOTIFY_AFTER_SECONDS = 24 * 60 * 60


def notify(title, message):
    def escape(value):
        return value.replace("\\", "\\\\").replace('"', '\\"')

    script = 'display notification "{}" with title "{}"'.format(
        escape(message), escape(title)
    )
    subprocess.run(["/usr/bin/osascript", "-e", script], check=True)


def check_health():
    try:
        result = subprocess.run(
            [sys.executable, str(BRIDGE_ROOT / "bootstrap.py"), "health",
             "--config", str(BRIDGE_ROOT / "config.local.json")],
            capture_output=True, text=True, timeout=120,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        return [f"Bridge health check failed: {error}"], ""
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip() or "Bridge health check failed"
        return [detail], ""
    return [], result.stdout.strip()


def load_state():
    try:
        return json.loads(STATE.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_state(data):
    temporary = STATE.with_suffix(".tmp")
    temporary.write_text(json.dumps(data, sort_keys=True) + "\n")
    os.chmod(temporary, 0o600)
    os.replace(temporary, STATE)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--test-notification", action="store_true")
    args = parser.parse_args()

    if args.test_notification:
        notify("Sync services monitor", "Native failure notifications are configured.")
        print("Test notification sent.")
        return 0

    now = int(time.time())
    timestamp = datetime.now().astimezone().isoformat(timespec="seconds")
    if not (BRIDGE_ROOT / "config.local.json").is_file():
        print(f"{timestamp} INACTIVE: no local Hermes bridge configuration.")
        return 0
    previous = load_state()

    problems, health_summary = check_health()

    if problems:
        summary = "; ".join(problems)
        fingerprint = hashlib.sha256(summary.encode()).hexdigest()
        last_notified = int(previous.get("last_notified") or 0)
        should_notify = (
            previous.get("status") != "unhealthy"
            or previous.get("fingerprint") != fingerprint
            or now - last_notified >= RENOTIFY_AFTER_SECONDS
        )
        if should_notify:
            notify("Sync services need attention", summary[:240])
            last_notified = now
        save_state(
            {
                "status": "unhealthy",
                "fingerprint": fingerprint,
                "last_checked": now,
                "last_notified": last_notified,
            }
        )
        print(f"{timestamp} UNHEALTHY: {summary}")
        return 1

    if previous.get("status") == "unhealthy":
        notify(
            "Sync services recovered",
            "Configured Hermes bridge checks are passing.",
        )
    save_state({"status": "healthy", "last_checked": now})
    print(f"{timestamp} {health_summary}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
