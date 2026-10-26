#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/home/Library/Application Support/private_Syncthing/private_executable_check-health.py"
PLIST="$ROOT/home/Library/LaunchAgents/private_com.brendan.syncthing-health.plist.tmpl"

python3 - "$SCRIPT" "$PLIST" <<'PY'
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

script, plist_path = sys.argv[1:]


class MonitorTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        spec = importlib.util.spec_from_file_location("sync_health", script)
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)
        self.module.BRIDGE_ROOT = self.root / "bridge"
        self.module.STATE = self.root / "state.json"
        # Keep regressions to the legacy checker away from the live configuration.
        self.module.CONFIG = self.root / "missing-syncthing.xml"
        self.module.BRIDGE_ROOT.mkdir()
        self.config = self.module.BRIDGE_ROOT / "config.local.json"
        self.config.write_text("{}\n")
        self.healthy = subprocess.CompletedProcess(
            [], 0, "Healthy: configured bridge. Obsidian Sync delivery is not checked.\n", ""
        )

    def invoke(self):
        with patch.object(sys, "argv", ["check-health.py"]), \
                contextlib.redirect_stdout(io.StringIO()) as output:
            code = self.module.main()
        return code, output.getvalue()

    def test_inactive_mac_does_not_contact_services_or_write_state(self):
        self.config.unlink()
        with patch.object(self.module.subprocess, "run") as run, \
                patch.object(self.module, "notify") as notify:
            code, output = self.invoke()
        self.assertEqual(code, 0)
        self.assertIn("INACTIVE", output)
        run.assert_not_called()
        notify.assert_not_called()
        self.assertFalse(self.module.STATE.exists())

    def test_configured_bridge_delegates_to_read_only_health_command(self):
        with patch.object(self.module.subprocess, "run", return_value=self.healthy) as run, \
                patch.object(self.module, "notify") as notify:
            code, output = self.invoke()
        self.assertEqual(code, 0)
        self.assertEqual(run.call_args.args[0], [
            sys.executable, str(self.module.BRIDGE_ROOT / "bootstrap.py"),
            "health", "--config", str(self.config),
        ])
        self.assertNotIn("shell", run.call_args.kwargs)
        self.assertIn("Obsidian Sync delivery is not checked", output)
        self.assertEqual(json.loads(self.module.STATE.read_text())["status"], "healthy")
        notify.assert_not_called()

    def test_failure_notifications_are_deduplicated_and_recovery_is_reported(self):
        failure = subprocess.CompletedProcess([], 1, "", "Mutagen notes: paused\n")
        with patch.object(self.module.subprocess, "run", return_value=failure), \
                patch.object(self.module, "notify") as notify:
            self.assertEqual(self.invoke()[0], 1)
            self.assertEqual(self.invoke()[0], 1)
            notify.assert_called_once_with("Sync services need attention", "Mutagen notes: paused")
        self.assertEqual(json.loads(self.module.STATE.read_text())["status"], "unhealthy")
        with patch.object(self.module.subprocess, "run", return_value=self.healthy), \
                patch.object(self.module, "notify") as notify:
            self.assertEqual(self.invoke()[0], 0)
            self.assertEqual(notify.call_args.args[0], "Sync services recovered")

    def test_unavailable_checker_is_reported_without_repair_attempts(self):
        with patch.object(self.module.subprocess, "run",
                          side_effect=subprocess.TimeoutExpired(["fixture"], 120)) as run, \
                patch.object(self.module, "notify"):
            code, output = self.invoke()
        self.assertEqual(code, 1)
        self.assertIn("Bridge health check failed", output)
        self.assertEqual(run.call_count, 1)

    def test_launch_agent_uses_homebrew_python_and_mutagen_path(self):
        template = Path(plist_path).read_text()
        self.assertNotIn("/Users/", template)
        plist = plistlib.loads(template.replace("{{ .chezmoi.homeDir }}", "/fixture").encode())
        self.assertEqual(plist["ProgramArguments"], [
            "/usr/bin/env", "python3", "/fixture/Library/Application Support/Syncthing/check-health.py",
        ])
        self.assertEqual(plist["EnvironmentVariables"]["PATH"],
                         "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin")


unittest.main(argv=["sync-health-monitor"], verbosity=2)
PY
