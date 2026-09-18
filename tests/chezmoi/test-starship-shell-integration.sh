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

# The download and activation scopes must agree. Out-of-scope shells use native
# Starship even when a previous personal-Mac plugin directory remains on disk.
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
    plugin = external.get(".local/share/zsh/plugins/starship-ftl")
    if name == "personal-mac":
        assert plugin is not None, "personal Mac must provision FTL"
        assert plugin["url"].endswith("/56bea62528c1419ed47b0cda5afaac579bf4739a.tar.gz")
        assert plugin["type"] == "archive" and plugin["stripComponents"] == 1
    else:
        assert plugin is None, f"FTL must not be provisioned for {name}"

starship = tomllib.loads(render("dot_config/starship/private_starship.toml.tmpl", base))
assert starship["git_status"]["ignore_submodules"] is True
accent = starship["palettes"][starship["palette"]]["accent"]

for name, role, tty, optout, missing, failure, term in [
    ("enabled", "personal-mac", True, False, False, False, "xterm-256color"),
    ("optout", "personal-mac", True, True, False, False, "xterm-256color"),
    ("missing", "personal-mac", True, False, True, False, "xterm-256color"),
    ("failure", "personal-mac", True, False, False, True, "xterm-256color"),
    ("pipe", "personal-mac", False, False, False, False, "xterm-256color"),
    ("dumb", "personal-mac", True, False, False, False, "dumb"),
    *[(role, role, True, False, False, False, "xterm-256color")
      for role in variants if role != "personal-mac"],
]:
    home = tmp / name
    plugins = home / ".local/share/zsh/plugins"
    for path in [home / ".config/zsh/aliases.zsh",
                 plugins / "zsh-autosuggestions/zsh-autosuggestions.zsh",
                 plugins / "fzf-tab/fzf-tab.plugin.zsh",
                 plugins / "zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"]:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.touch()
    tools = home / "tools"
    tools.mkdir()
    # Starship is only made available by the Mise init, not inherited PATH.
    starship_bin = tools / "starship"
    starship_bin.write_text("#!/bin/sh\nprintf '%s\\n' 'print -r -- native >>\"$TEST_CALLS\"'\n")
    starship_bin.chmod(0o755)
    bin_dir = home / "bin"
    bin_dir.mkdir()
    mise = bin_dir / "mise"
    mise.write_text(f"#!/bin/sh\nprintf '%s\\n' 'export PATH=\"{tools}:$PATH\"'\n")
    mise.chmod(0o755)
    if not missing:
        plugin = plugins / "starship-ftl/ftl-prompt.zsh"
        plugin.parent.mkdir()
        plugin.write_text('''ftl-prompt() {
  print -r -- "ftl:${*}:config=$STARSHIP_CONFIG" >>"$TEST_CALLS"
  [[ ${FTL_TEST_FAIL:-0} != 1 ]]
}
''')
    rc = home / "zshrc"
    rc.write_text(rendered[role])
    calls = home / "calls"
    env = {
        "HOME": str(home), "ZDOTDIR": str(home), "PATH": f"{bin_dir}:/usr/bin:/bin",
        "XDG_CONFIG_HOME": str(home / ".config"),
        "XDG_DATA_HOME": str(home / ".local/share"),
        "XDG_STATE_HOME": str(home / ".local/state"),
        "XDG_CACHE_HOME": str(home / ".cache"),
        "GH_TOKEN_AUTOEXPORT": "0", "TERM": term,
        "STARSHIP_FTL": "0" if optout else "1",
        "FTL_TEST_FAIL": "1" if failure else "0", "TEST_CALLS": str(calls),
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
    assert not any("transient" in line for line in lines), lines

print("Starship FTL scope, early Mise PATH, palette, opt-out, fallback and submodule policy ok")
PY
