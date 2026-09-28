#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

python3 - "$repo_root" "$tmpdir" "$(command -v zsh)" <<'PY'
import json
import os
from pathlib import Path
import pty
import subprocess
import sys
import tomllib

repo, tmp, zsh = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
base = dict(personal=True, work=False, homelab=False, headless=False,
            ephemeral=False, theme="guts", chezmoi={"os": "darwin", "username": "test"})

def render(name, data):
    return subprocess.check_output([
        "chezmoi", "execute-template", "--source", str(repo),
        "--override-data", json.dumps(data), "--file", str(repo / "home" / name),
    ], text=True)

variants = {
    "personal-mac": base,
    "work-mac": dict(base, personal=False, work=True),
    "headless-mac": dict(base, headless=True),
    "personal-linux": dict(base, chezmoi={"os": "linux", "username": "test"}),
    "personal-windows": dict(base, chezmoi={"os": "windows", "username": "test"}),
}
rendered = {}
for name, data in variants.items():
    rendered[name] = render("dot_zshrc.tmpl", data)
    external = tomllib.loads(render(".chezmoiexternal.toml.tmpl", data))
    assert not any(path.startswith(".local/share/zsh/plugins/") for path in external), external
    enabled = name == "personal-mac"
    assert ("zinit light mattmc3/starship-ftl" in rendered[name]) == enabled
    assert ('ver"56bea62528c1419ed47b0cda5afaac579bf4739a"' in rendered[name]) == enabled

starship = tomllib.loads(render("dot_config/starship/private_starship.toml.tmpl", base))
assert starship["git_status"]["ignore_submodules"] is True
accent = starship["palettes"][starship["palette"]]["accent"]

for name, role, tty, optout, missing, failure, term in [
    ("enabled", "personal-mac", True, False, False, False, "xterm-256color"),
    ("optout", "personal-mac", True, True, False, False, "xterm-256color"),
    ("missing", "personal-mac", True, False, True, False, "xterm-256color"),
    ("no-zinit", "personal-mac", True, False, False, False, "xterm-256color"),
    ("failure", "personal-mac", True, False, False, True, "xterm-256color"),
    ("pipe", "personal-mac", False, False, False, False, "xterm-256color"),
    ("dumb", "personal-mac", True, False, False, False, "dumb"),
    *[(role, role, True, False, False, False, "xterm-256color")
      for role in variants if role != "personal-mac"],
]:
    home = tmp / name
    zinit_dir = home / ".local/share/zinit/zinit.git"
    if name != "no-zinit":
        zinit_dir.mkdir(parents=True)
        manager = zinit_dir / "zinit.zsh"
        manager.write_text('''typeset -g _zinit_test_ice=''
zinit() {
  if [[ $1 == ice ]]; then
    shift
    _zinit_test_ice="$*"
  elif [[ $1 == light ]]; then
    print -r -- "${_zinit_test_ice}|$2" >>"$ZINIT_LOG"
    if [[ $2 == mattmc3/starship-ftl ]]; then
      if [[ ${FTL_TEST_MISSING:-0} == 1 || ! -r $FTL_TEST_PLUGIN ]]; then
        return 1
      fi
      source "$FTL_TEST_PLUGIN"
    fi
    _zinit_test_ice=''
  fi
}
''')
    for path in (home / ".config/zsh/aliases.zsh",):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.touch()

    tools = home / "tools"
    tools.mkdir()
    starship_bin = tools / "starship"
    starship_bin.write_text('''#!/bin/sh
printf '%s\\n' 'print -r -- native >>"$TEST_CALLS"'
''')
    starship_bin.chmod(0o755)
    bin_dir = home / "bin"
    bin_dir.mkdir()
    mise = bin_dir / "mise"
    mise.write_text(f'''#!/bin/sh
printf '%s\\n' 'export PATH="{tools}:$PATH"'
''')
    mise.chmod(0o755)

    ftl_plugin = home / "ftl-prompt.zsh"
    ftl_plugin.write_text('''ftl-prompt() {
  print -r -- "ftl:${*}:config=$STARSHIP_CONFIG" >>"$TEST_CALLS"
  [[ ${FTL_TEST_FAIL:-0} != 1 ]]
}
''')
    rc = home / "zshrc"
    rc.write_text(rendered[role])
    calls = home / "calls"
    zinit_log = home / "zinit.log"
    env = {
        "HOME": str(home), "ZDOTDIR": str(home), "PATH": f"{bin_dir}:/usr/bin:/bin",
        "XDG_CONFIG_HOME": str(home / ".config"),
        "XDG_DATA_HOME": str(home / ".local/share"),
        "XDG_STATE_HOME": str(home / ".local/state"),
        "XDG_CACHE_HOME": str(home / ".cache"),
        "GH_TOKEN_AUTOEXPORT": "0", "TERM": term,
        "STARSHIP_FTL": "0" if optout else "1",
        "FTL_TEST_FAIL": "1" if failure else "0",
        "FTL_TEST_MISSING": "1" if missing else "0",
        "FTL_TEST_PLUGIN": str(ftl_plugin), "ZINIT_LOG": str(zinit_log),
        "TEST_CALLS": str(calls),
    }
    master, slave = pty.openpty() if tty else (None, None)
    try:
        result = subprocess.run([zsh, "-dfic", 'source "$1"; :', "zsh", str(rc)],
                                env=env, stdin=slave if tty else subprocess.DEVNULL,
                                stdout=slave if tty else subprocess.PIPE,
                                stderr=subprocess.PIPE, timeout=15)
        assert result.returncode == 0, (name, result.stderr.decode())
    finally:
        if tty:
            os.close(slave)
            os.close(master)

    lines = calls.read_text().splitlines() if calls.exists() else []
    enabled = name == "enabled"
    assert lines.count("native") == (0 if enabled else 1), (name, lines)
    ftl = [line for line in lines if line.startswith("ftl:")]
    assert len(ftl) == (1 if enabled or failure else 0), (name, lines)
    if enabled:
        assert ftl == [f"ftl:-p %F{{{accent}}}❯%f  starship:config={home}/.config/starship/starship.toml"], ftl
        assert any("56bea62528c1419ed47b0cda5afaac579bf4739a" in line and
                   "mattmc3/starship-ftl" in line for line in zinit_log.read_text().splitlines())
    assert not any("transient" in line for line in lines), lines

print("Zinit FTL pin, scope, early Mise PATH, opt-out, fallback and prompt policy ok")
PY
