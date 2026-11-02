#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
unset OBSIDIAN_AUTH_TOKEN

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
home="$tmpdir/home & test"
vault="$home/Notes/PKM's Vault"
: >"$tmpdir/config.toml"
mkdir -p "$home/.local/bin" "$vault/.obsidian" "$tmpdir/bin"
real_python=$(command -v python3)
export REAL_PYTHON="$real_python" SERVICE_STATE="$tmpdir/loaded" SERVICE_LOG="$tmpdir/service.log"
export SYNC_LOG="$tmpdir/sync.log" SETUP_READY=1 CONFIG_DIR=.obsidian
cp "$repo_root/home/dot_local/bin/executable_cz-obsidian" "$home/.local/bin/cz-obsidian"
fixture="$tmpdir/source"
mkdir -p "$fixture/dot_local/bin"
cp "$repo_root/home/.chezmoiignore" "$fixture/.chezmoiignore"
cp "$repo_root/home/dot_local/bin/executable_cz-obsidian" "$fixture/dot_local/bin/executable_cz-obsidian"

render() {
  local name=$1 os=$2 personal=$3 enabled=$4 data
  data=$(jq -n --arg home "$home" --arg vault "$vault" --arg os "$os" \
    --argjson personal "$personal" --argjson enabled "$enabled" \
    '{personal:$personal,work:false,homelab:false,ephemeral:false,headless:false,
      chezmoi:{os:$os,homeDir:$home},obsidian_headless:{enabled:$enabled,vault_path:$vault}}')
  chezmoi execute-template --config "$tmpdir/config.toml" --source "$repo_root" --override-data "$data" \
    --file "$repo_root/home/.chezmoiignore" >"$tmpdir/$name.ignore"
  chezmoi execute-template --config "$tmpdir/config.toml" --source "$repo_root" --override-data "$data" \
    --file "$repo_root/home/Library/LaunchAgents/private_com.brendan.obsidian-headless.plist.tmpl" >"$tmpdir/$name.plist"
  chezmoi execute-template --config "$tmpdir/config.toml" --source "$repo_root" --override-data "$data" \
    --file "$repo_root/home/.chezmoiscripts/darwin/run_onchange_after_configure-obsidian-headless.sh.tmpl" >"$tmpdir/$name.sh"
  chezmoi managed --source "$fixture" --config "$tmpdir/config.toml" --override-data "$data" \
    >"$tmpdir/$name.managed"
}
render enabled darwin true true
render disabled darwin true false
render work darwin false true
render linux linux true true

agent=Library/LaunchAgents/com.brendan.obsidian-headless.plist
if grep -Fxq "$agent" "$tmpdir/enabled.ignore"; then
  echo "Opted-in service must not be ignored" >&2
  exit 1
fi
for scope in disabled work linux; do grep -Fxq "$agent" "$tmpdir/$scope.ignore"; done
for scope in enabled disabled; do grep -Fxq ".local/bin/cz-obsidian" "$tmpdir/$scope.managed"; done
for scope in work linux; do
  if grep -Fxq ".local/bin/cz-obsidian" "$tmpdir/$scope.managed"; then
    echo "Setup helper must be personal macOS only" >&2; exit 1
  fi
done
python3 - "$tmpdir/enabled.plist" "$home" "$vault" <<'PY'
import plistlib
import sys
from pathlib import Path
agent = plistlib.loads(Path(sys.argv[1]).read_bytes())
home, vault = sys.argv[2:]
assert agent["ProgramArguments"] == [
    home + "/.local/bin/mise", "--cd", home, "exec", "--",
    "python3", home + "/.local/bin/cz-obsidian", "run", "--path", vault,
]
assert agent["RunAtLoad"] and agent["KeepAlive"]
assert agent["ThrottleInterval"] >= 30 and agent["Umask"] == 0o077
assert agent["StandardOutPath"].startswith(home + "/Library/Logs/ObsidianHeadless/")
PY

cat >"$tmpdir/bin/launchctl" <<'SH'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$1" >>"$SERVICE_LOG"
case "$1" in
  print) test -f "$SERVICE_STATE" ;;
  bootout) rm "$SERVICE_STATE" ;;
  bootstrap) test -f "$3"; touch "$SERVICE_STATE" ;;
  *) exit 90 ;;
esac
SH
cat >"$home/.local/bin/mise" <<'SH'
#!/bin/bash
set -euo pipefail
[[ $1 == --cd && $2 == "$HOME" && $3 == exec && $4 == -- ]]
shift 4
[[ $1 == python3 && $2 == "$HOME/.local/bin/cz-obsidian" ]]
shift
exec "$REAL_PYTHON" "$@"
SH
cat >"$tmpdir/bin/ob" <<'SH'
#!/bin/bash
set -euo pipefail
case "$1" in
  sync-status)
    [[ $2 == --path && -d $3 && $4 == --json && $SETUP_READY == 1 ]] || exit 3
    printf '{"configDir":"%s"}\n' "$CONFIG_DIR"
    ;;
  sync)
    [[ $2 == --continuous && $3 == --path && -d $4 ]] || exit 3
    printf 'sync started\n' >>"$SYNC_LOG"
    ;;
  *) exit 91 ;;
esac
SH
chmod +x "$tmpdir/bin/launchctl" "$tmpdir/bin/ob" "$home/.local/bin/mise"
mkdir -p "$home/Library/LaunchAgents" "$home/.obsidian-headless"
printf 'keep credentials\n' >"$home/.obsidian-headless/auth_token"
printf 'keep notes\n' >"$vault/note.md"
printf '[]\n' >"$vault/.obsidian/core-plugins.json"
cp "$tmpdir/enabled.plist" "$home/$agent"
run_hook() { HOME="$home" PATH="$tmpdir/bin:/usr/bin:/bin" bash "$tmpdir/$1.sh"; }
run_client() { HOME="$home" PATH="$tmpdir/bin:/usr/bin:/bin" "$real_python" "$home/.local/bin/cz-obsidian" run --path "$vault"; }

run_hook enabled
test -f "$SERVICE_STATE"
python3 - "$home/Library/Logs/ObsidianHeadless" <<'PY'
import os
import stat
import sys
assert stat.S_IMODE(os.stat(sys.argv[1]).st_mode) == 0o700
PY
run_hook enabled
[[ $(grep -c '^bootstrap$' "$SERVICE_LOG") == 2 ]]
[[ $(grep -c '^bootout$' "$SERVICE_LOG") == 1 ]]

SETUP_READY=0
if run_hook enabled; then echo 'Unlinked vault must not start syncing' >&2; exit 1; fi
test ! -f "$SERVICE_STATE"
SETUP_READY=1
mv "$home/.obsidian-headless/auth_token" "$tmpdir/saved-token"
if run_hook enabled; then echo 'Missing login must block service startup' >&2; exit 1; fi
test ! -f "$SERVICE_STATE"
mv "$tmpdir/saved-token" "$home/.obsidian-headless/auth_token"
for plugins in '["sync"]' '{"sync":true}'; do
  printf '%s\n' "$plugins" >"$vault/.obsidian/core-plugins.json"
  if run_client; then echo 'Desktop Sync must block every service start' >&2; exit 1; fi
  test ! -f "$SYNC_LOG"
done
printf 'broken JSON\n' >"$vault/.obsidian/core-plugins.json"
if run_client; then echo 'Unreadable plugin state must block startup' >&2; exit 1; fi
test ! -f "$SYNC_LOG"
rm "$vault/.obsidian/core-plugins.json"
# A newly linked vault need not have desktop configuration files yet.
run_client
grep -Fxq 'sync started' "$SYNC_LOG"
rm "$SYNC_LOG"
CONFIG_DIR=.custom-obsidian
mkdir "$vault/$CONFIG_DIR"
printf '["sync"]\n' >"$vault/$CONFIG_DIR/core-plugins.json"
if run_client; then echo 'Custom config directory must also be guarded' >&2; exit 1; fi
test ! -f "$SYNC_LOG"
CONFIG_DIR=.obsidian
printf '[]\n' >"$vault/.obsidian/core-plugins.json"
run_hook enabled
run_hook disabled
test ! -f "$SERVICE_STATE"
test ! -e "$home/$agent"
grep -Fxq 'keep credentials' "$home/.obsidian-headless/auth_token"
grep -Fxq 'keep notes' "$vault/note.md"
cp "$SERVICE_LOG" "$tmpdir/before-linux.log"
run_hook linux
cmp "$SERVICE_LOG" "$tmpdir/before-linux.log"
echo 'Headless Sync host opt-in, startup guards, restart and safe opt-out passed'

python3 - "$repo_root/home/dot_local/bin/executable_cz-obsidian" <<'PY'
import contextlib
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

script = sys.argv[1]
loader = importlib.machinery.SourceFileLoader("obsidian_setup", script)
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)


class SetupTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.home = Path(temporary.name).resolve()
        environment = patch.dict(os.environ, {"HOME": str(self.home)})
        environment.start()
        self.addCleanup(environment.stop)
        original_umask = os.umask(0o077)
        self.addCleanup(os.umask, original_umask)
        self.calls = []
        self.fail = None
        self.active = False
        self.bw_status = 0
        self.notes = json.dumps({
            "email": "fixture@example.invalid", "vault": "vault-id",
            "sync": {"configs": [], "excluded_folders": [".trash"], "conflict_strategy": "conflict"},
        })

    def run_command(self, command, **kwargs):
        self.calls.append((command, kwargs))
        if command == ["bw", "--nointeraction", "get", "notes", "metadata-item"]:
            return subprocess.CompletedProcess(command, self.bw_status, self.notes, "")
        if command[0] == "launchctl":
            self.assertEqual(command[1], "print")
            return subprocess.CompletedProcess(command, 0 if self.active else 1)
        self.assertEqual(command[0], "ob")
        self.assertIn(command[1], ("login", "sync-setup", "sync-config"))
        # All secret prompts inherit the user's terminal, not a pipe or supplied flags.
        self.assertEqual(kwargs, {"check": True})
        self.assertNotIn("--password", command)
        self.assertNotIn("--mfa", command)
        if command[1] == self.fail:
            raise subprocess.CalledProcessError(2, command)
        return subprocess.CompletedProcess(command, 0)

    def invoke(self, options=None, answers=("yes",), tty=True):
        if options is None:
            options = ["--item", "metadata-item"]
        with patch.object(sys, "argv", ["cz-obsidian", "setup", *options]), \
                patch.object(sys.stdin, "isatty", return_value=tty), \
                patch("builtins.input", side_effect=answers), \
                patch.object(module.subprocess, "run", side_effect=self.run_command), \
                contextlib.redirect_stdout(io.StringIO()) as out, \
                contextlib.redirect_stderr(io.StringIO()) as err:
            code = module.main()
        return code, out.getvalue() + err.getvalue()

    def test_metadata_only_with_interactive_secrets_and_explicit_enable(self):
        code, output = self.invoke()
        self.assertEqual(code, 0, output)
        commands = [cmd for cmd, _ in self.calls]
        self.assertIn(["ob", "login", "--email", "fixture@example.invalid"], commands)
        setup = next(cmd for cmd in commands if cmd[:2] == ["ob", "sync-setup"])
        self.assertEqual(setup[2:6], ["--vault", "vault-id", "--path", str(self.home / "Notes/Obsidian/PKM")])
        self.assertIn("--device-name", setup)
        config = next(cmd for cmd in commands if cmd[:2] == ["ob", "sync-config"])
        self.assertEqual(config[4:], ["--configs", "", "--excluded-folders", ".trash", "--conflict-strategy", "conflict"])
        saved = module.preferences_path()
        self.assertEqual(json.loads(saved.read_text()), {"bitwarden_item": "metadata-item"})
        self.assertEqual(stat.S_IMODE(saved.stat().st_mode), 0o600)
        self.assertIn("syncing has not started", output)
        self.assertFalse((self.home / ".obsidian-headless").exists())

        self.calls.clear()
        code, output = self.invoke(options=[])
        self.assertEqual(code, 0, output)
        self.assertEqual(self.calls[0][0], ["bw", "--nointeraction", "get", "notes", "metadata-item"])

    def test_manual_metadata_never_reads_bitwarden(self):
        code, output = self.invoke(options=["--item", ""], answers=("manual@example.invalid", "My Vault", "yes"))
        self.assertEqual(code, 0, output)
        self.assertFalse(any(cmd[0] == "bw" for cmd, _ in self.calls))
        self.assertIn(["ob", "login", "--email", "manual@example.invalid"], [cmd for cmd, _ in self.calls])

    def test_cancellation_has_no_obsidian_or_cache_side_effects(self):
        self.assertEqual(self.invoke(answers=("no",))[0], 0)
        self.assertEqual(len(self.calls), 1)
        self.assertFalse(module.preferences_path().exists())

    def test_noninteractive_setup_does_not_fetch_metadata(self):
        self.assertEqual(self.invoke(tty=False)[0], 1)
        self.assertEqual(self.calls, [])

    def test_locked_bitwarden_stops_before_login(self):
        self.bw_status = 1
        code, output = self.invoke()
        self.assertEqual(code, 1)
        self.assertIn("bw unlock", output)
        self.assertEqual(len(self.calls), 1)

    def test_password_fields_are_rejected_without_echoing_values(self):
        self.notes = json.dumps({"email": "fixture@example.invalid", "vault": "vault-id", "password": "DO-NOT-PRINT"})
        code, output = self.invoke()
        self.assertEqual(code, 1)
        self.assertNotIn("DO-NOT-PRINT", output)
        self.assertEqual(len(self.calls), 1)

    def test_running_service_blocks_reconfiguration(self):
        self.active = True
        self.assertEqual(self.invoke()[0], 1)
        self.assertFalse(any(cmd[0] == "ob" for cmd, _ in self.calls))

    def test_authentication_or_setup_failure_does_not_continue(self):
        for failure in ("login", "sync-setup", "sync-config"):
            with self.subTest(failure=failure):
                self.calls.clear()
                self.fail = failure
                self.assertEqual(self.invoke()[0], 1)
                self.assertEqual(self.calls[-1][0][1], failure)
                self.assertFalse(module.preferences_path().exists())


unittest.main(argv=[sys.argv[0]], verbosity=2)
PY
