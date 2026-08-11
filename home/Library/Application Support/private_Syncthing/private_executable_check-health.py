#!/usr/bin/python3
"""Check local Syncthing and Mutagen health, notifying only when needed."""

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

CONFIG = Path.home() / "Library/Application Support/Syncthing/config.xml"
STATE = Path.home() / "Library/Application Support/Syncthing/health-check-state.json"
EXPECTED_ROOT = Path.home() / "hermes-agent"
MUTAGEN = Path("/opt/homebrew/bin/mutagen")
EXPECTED_MUTAGEN_SESSIONS = {
    "vault-ro-study",
    "vault-ro-daily-2026",
    "vault-hermes-overlay",
}
RENOTIFY_AFTER_SECONDS = 24 * 60 * 60


def notify(title, message):
    def escape(value):
        return value.replace("\\", "\\\\").replace('"', '\\"')

    script = 'display notification "{}" with title "{}"'.format(
        escape(message), escape(title)
    )
    subprocess.run(["/usr/bin/osascript", "-e", script], check=True)


def request_json(base_url, api_key, endpoint, query=None):
    url = base_url + endpoint
    if query:
        url += "?" + urllib.parse.urlencode(query)
    request = urllib.request.Request(url, headers={"X-API-Key": api_key})
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.load(response)


def load_config():
    root = ET.parse(CONFIG).getroot()
    gui = root.find("gui")
    if gui is None:
        raise RuntimeError("Syncthing GUI configuration is missing")

    address = gui.findtext("address") or "127.0.0.1:8384"
    if address.startswith("0.0.0.0:"):
        address = "127.0.0.1:" + address.rsplit(":", 1)[1]
    elif address.startswith("[::]:"):
        address = "[::1]:" + address.rsplit(":", 1)[1]
    scheme = "https" if gui.get("tls") == "true" else "http"
    api_key = gui.findtext("apikey")
    if not api_key:
        raise RuntimeError("Syncthing API key is missing")

    folders = []
    for folder in root.findall("folder"):
        if folder.findtext("paused") == "true":
            continue
        raw_path = folder.get("path", "")
        expanded_path = Path(os.path.expanduser(raw_path)).resolve()
        folders.append(
            {
                "id": folder.get("id"),
                "label": folder.get("label") or folder.get("id"),
                "path": expanded_path,
            }
        )

    return f"{scheme}://{address}", api_key, folders


def check_mutagen_health():
    template = (
        '{{range .}}{{.Name}}|{{.Status}}|{{.Paused}}|{{.Alpha.Connected}}|'
        '{{.Beta.Connected}}|{{with .SessionState}}{{len .Conflicts}}|'
        '{{.ExcludedConflicts}}|{{if .LastError}}true{{else}}false{{end}}'
        '{{else}}-1|-1|false{{end}}|{{with .Alpha.EndpointState}}'
        '{{len .ScanProblems}}|{{.ExcludedScanProblems}}|'
        '{{len .TransitionProblems}}|{{.ExcludedTransitionProblems}}'
        '{{else}}-1|-1|-1|-1{{end}}|{{with .Beta.EndpointState}}'
        '{{len .ScanProblems}}|{{.ExcludedScanProblems}}|'
        '{{len .TransitionProblems}}|{{.ExcludedTransitionProblems}}'
        '{{else}}-1|-1|-1|-1{{end}}{{"\\n"}}{{end}}'
    )
    result = subprocess.run(
        [str(MUTAGEN), "sync", "list", "--template", template],
        capture_output=True,
        text=True,
        timeout=30,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "unknown error"
        return [f"Mutagen health check failed: {detail}"], 0

    sessions = {}
    for line in result.stdout.splitlines():
        if not line:
            continue
        fields = line.split("|")
        if len(fields) != 16:
            return ["Mutagen returned an unexpected session status format"], 0
        sessions[fields[0]] = fields[1:]

    problems = []
    for name in sorted(EXPECTED_MUTAGEN_SESSIONS):
        if name not in sessions:
            problems.append(f"Mutagen session missing: {name}")
            continue

        (
            status,
            paused,
            alpha_connected,
            beta_connected,
            conflicts,
            excluded_conflicts,
            has_last_error,
            alpha_scan_problems,
            alpha_excluded_scan,
            alpha_transition_problems,
            alpha_excluded_transition,
            beta_scan_problems,
            beta_excluded_scan,
            beta_transition_problems,
            beta_excluded_transition,
        ) = sessions[name]

        if paused == "true":
            problems.append(f"Mutagen {name}: paused")
        if alpha_connected != "true" or beta_connected != "true":
            problems.append(f"Mutagen {name}: endpoint disconnected")
        if status == "Disconnected" or status.startswith("Halted") or "Error" in status:
            problems.append(f"Mutagen {name}: status is {status}")
        if has_last_error == "true":
            problems.append(f"Mutagen {name}: session has an error")

        issue_counts = [
            conflicts,
            excluded_conflicts,
            alpha_scan_problems,
            alpha_excluded_scan,
            alpha_transition_problems,
            alpha_excluded_transition,
            beta_scan_problems,
            beta_excluded_scan,
            beta_transition_problems,
            beta_excluded_transition,
        ]
        if any(int(count) > 0 for count in issue_counts):
            problems.append(f"Mutagen {name}: conflicts or synchronization problems")

    return problems, len(EXPECTED_MUTAGEN_SESSIONS & sessions.keys())


def check_syncthing_health():
    problems = []
    base_url, api_key, folders = load_config()

    health = request_json(base_url, api_key, "/rest/noauth/health")
    if health.get("status") != "OK":
        problems.append("Syncthing daemon health is not OK")

    system_errors = request_json(base_url, api_key, "/rest/system/error").get("errors") or []
    for error in system_errors:
        message = error.get("message") if isinstance(error, dict) else str(error)
        problems.append("Syncthing error: " + message)

    expected_root = EXPECTED_ROOT.resolve()
    for folder in folders:
        label = folder["label"]
        path = folder["path"]
        try:
            path.relative_to(expected_root)
        except ValueError:
            problems.append(f"{label}: configured outside {EXPECTED_ROOT}")
        if not path.is_dir():
            problems.append(f"{label}: folder path is unavailable")
        elif not (path / ".stfolder").exists():
            problems.append(f"{label}: .stfolder marker is missing")

        status = request_json(base_url, api_key, "/rest/db/status", {"folder": folder["id"]})
        state = str(status.get("state", "unknown"))
        invalid = status.get("invalid")
        error_count = int(status.get("errors") or 0)
        pull_errors = int(status.get("pullErrors") or 0)
        if invalid:
            problems.append(f"{label}: {invalid}")
        if "error" in state.lower():
            problems.append(f"{label}: folder state is {state}")
        if error_count or pull_errors:
            problems.append(
                f"{label}: {error_count} scan errors and {pull_errors} pull errors"
            )

    return problems, len(folders)


def check_health():
    problems = []
    syncthing_folder_count = 0
    mutagen_session_count = 0

    try:
        syncthing_problems, syncthing_folder_count = check_syncthing_health()
        problems.extend(syncthing_problems)
    except (OSError, RuntimeError, ET.ParseError, urllib.error.URLError, json.JSONDecodeError) as error:
        problems.append(f"Syncthing health check failed: {error}")

    try:
        mutagen_problems, mutagen_session_count = check_mutagen_health()
        problems.extend(mutagen_problems)
    except (OSError, RuntimeError, subprocess.TimeoutExpired, ValueError) as error:
        problems.append(f"Mutagen health check failed: {error}")

    return problems, syncthing_folder_count, mutagen_session_count


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
    previous = load_state()

    problems, syncthing_folder_count, mutagen_session_count = check_health()

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
            "Syncthing and all expected Mutagen sessions are healthy.",
        )
    save_state({"status": "healthy", "last_checked": now})
    print(
        f"{timestamp} HEALTHY: Syncthing with {syncthing_folder_count} folders; "
        f"Mutagen with {mutagen_session_count} sessions"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
