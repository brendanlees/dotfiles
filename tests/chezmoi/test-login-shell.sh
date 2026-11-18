#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
python3 - "$repo_root" <<'PY'
from contextlib import contextmanager
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile

root = Path(sys.argv[1])
chezmoi = shutil.which('chezmoi')
template = root / 'home/.chezmoiscripts/run_after_03-configure-login-shell.sh.tmpl'

fake_tool = r'''
import json
import os
from pathlib import Path
import sys

tool = Path(sys.argv[0]).name
args = sys.argv[1:]
account = Path(os.environ['FIXTURE_ACCOUNT'])
if tool == 'id':
    assert args == ['-u'], args
    print(os.environ['FIXTURE_UID'])
elif tool == 'getent':
    assert args == ['passwd', os.environ['FIXTURE_UID']], args
    if os.environ.get('LOOKUP_FAILED') == '1':
        sys.exit(2)
    print(account.read_text(), end='')
elif tool == 'chsh':
    assert args == ['-s', os.environ['FIXTURE_ZSH'], os.environ['FIXTURE_USER']], args
    with open(os.environ['CHSH_LOG'], 'a') as log:
        log.write(json.dumps(args) + '\n')
    if os.environ.get('CHSH_FAILED') == '1':
        sys.exit(42)
    fields = account.read_text().strip().split(':')
    fields[-1] = args[1]
    account.write_text(':'.join(fields) + '\n')
else:
    raise AssertionError(tool)
'''

@contextmanager
def fixture(*, current='bash', lookup=True, registered=True, uid='1001', minimal=False):
    with tempfile.TemporaryDirectory(prefix='login shell ') as directory:
        temp = Path(directory)
        home, source, binaries = [temp / name for name in ('home', 'source', 'bin')]
        for path in (home, source / '.chezmoiscripts', binaries):
            path.mkdir(parents=True)
        config = temp / 'config.toml'
        config.write_text('[data]\npersonal=false\nwork=true\nhomelab=false\n'
                          f'headless=true\nephemeral=false\nminimal={str(minimal).lower()}\n')
        zsh = binaries / 'zsh'
        zsh.write_text('#!/bin/sh\nexit 0\n')
        zsh.chmod(0o755)
        user = 'root' if uid == '0' else 'fixture-user'
        shell = '/bin/bash'
        if current == 'zsh':
            shell = str(zsh)
        elif current == 'alias':
            alias = binaries / 'zsh-alias'
            alias.symlink_to(zsh)
            shell = str(alias)
        account = temp / 'passwd'
        account.write_text(f'{user}:x:{uid}:1001:Fixture:{home}:{shell}\n')
        shells = temp / 'shells'
        shells.write_text(str(zsh) + '\n' if registered else '/bin/bash\n')
        log = temp / 'chsh.log'
        for tool in ('id', 'chsh', *(['getent'] if lookup else [])):
            path = binaries / tool
            path.write_text(f'#!{sys.executable}\n' + fake_tool)
            path.chmod(0o755)
        for tool in ('awk', 'grep'):
            (binaries / tool).symlink_to(shutil.which(tool))
        rendered = subprocess.check_output([
            chezmoi, 'execute-template', '--source', str(root), '--config', str(config),
            '--override-data', '{"chezmoi":{"os":"linux"}}', '--file', str(template),
        ], text=True)
        rendered = rendered.replace('/etc/passwd', shlex.quote(str(account)))
        rendered = rendered.replace('/etc/shells', shlex.quote(str(shells)))
        (source / '.chezmoiscripts/run_after_03-configure-login-shell.sh').write_text(rendered)
        shutil.copy(root / 'home/.chezmoiignore', source)
        # Existing configuration must never be mistaken for the account's shell.
        (home / '.zshrc').write_text('# existing shell configuration\n')
        env = {**os.environ, 'HOME': str(home), 'PATH': str(binaries),
               'SHELL': str(zsh) if current == 'bash' else '/bin/bash',
               'USER': 'not-the-target-account', 'LOGNAME': 'not-the-target-account',
               'FIXTURE_UID': uid, 'FIXTURE_USER': user, 'FIXTURE_ZSH': str(zsh),
               'FIXTURE_ACCOUNT': str(account), 'CHSH_LOG': str(log)}

        def apply(**overrides):
            return subprocess.run([
                chezmoi, 'apply', '--source', str(source), '--destination', str(home),
                '--config', str(config), '--persistent-state', str(temp / 'state.boltdb'),
                '--override-data', '{"chezmoi":{"os":"linux"}}', '--no-tty', '--force',
            ], env={**env, **overrides}, capture_output=True, text=True, timeout=15)

        def calls():
            return [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []

        yield apply, calls, account, zsh, binaries, shell

# Repair a preexisting .zshrc and stale SHELL, then no-op on repeated apply.
for uid in ('1001', '0'):
    with fixture(uid=uid) as (apply, calls, account, zsh, _, _):
        result = apply()
        assert result.returncode == 0, result.stderr
        assert account.read_text().strip().split(':')[-1] == str(zsh), result.stdout
        assert len(calls()) == 1, calls()
        assert 'reconnect' in result.stdout.lower(), result.stdout
        assert apply().returncode == 0
        assert len(calls()) == 1, calls()

for current in ('zsh', 'alias'):
    with fixture(current=current) as (apply, calls, *_):
        result = apply()
        assert result.returncode == 0, result.stderr
        assert not calls(), calls()

# Local-account fallback for hosts without getent.
with fixture(lookup=False) as (apply, calls, *_):
    result = apply()
    assert result.returncode == 0 and len(calls()) == 1, result

with fixture(registered=False) as (apply, calls, account, _, _, shell):
    result = apply()
    assert result.returncode != 0 and 'not registered' in result.stderr, result
    assert not calls() and account.read_text().strip().endswith(shell)

with fixture() as (apply, calls, account, zsh, *_):
    result = apply(CHSH_FAILED='1')
    assert result.returncode != 0, result
    assert not account.read_text().strip().endswith(str(zsh))
    assert apply().returncode == 0
    assert len(calls()) == 2

with fixture() as (apply, calls, *_):
    result = apply(LOOKUP_FAILED='1')
    assert result.returncode != 0 and not calls(), result

for missing in ('zsh', 'chsh'):
    with fixture() as (apply, calls, _, _, binaries, _):
        (binaries / missing).unlink()
        result = apply()
        assert result.returncode != 0 and not calls(), result

with fixture(minimal=True) as (apply, calls, *_):
    assert apply().returncode == 0
    assert not calls()

for os_name in ('darwin', 'windows'):
    with tempfile.TemporaryDirectory() as directory:
        config = Path(directory) / 'config.toml'
        config.write_text('[data]\n')
        rendered = subprocess.check_output([
            chezmoi, 'execute-template', '--source', str(root), '--config', str(config),
            '--override-data', json.dumps({'chezmoi': {'os': os_name}}),
            '--file', str(template),
        ], text=True)
        assert not rendered.strip(), (os_name, rendered)

print('Linux login-shell reconciliation, retry, account boundaries and minimal/OS scope ok')
PY
