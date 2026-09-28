#!/usr/bin/env python3
"""Prepare and exercise this worktree without applying dotfiles or using live history."""
import argparse
import json
import os
from pathlib import Path
import pty
import select
import shutil
import signal
import statistics
import struct
import subprocess
import sys
import tempfile
import termios
import time
import tomllib
import fcntl

REPO = Path(__file__).resolve().parents[2]
MODES = ("off", "ftl")
MARKER = b"\x1b]777;ftl-trial-ready\x07"


def run(args, **kwargs):
    return subprocess.check_output(args, text=True, **kwargs).strip()


def environment(root, mode):
    meta = json.loads((root / "trial.json").read_text())
    home = root / mode
    # Deliberately do not inherit credentials, Atuin/Mise state, ZDOTDIR, TMUX,
    # terminal shell-integration injectors or the real user's history paths.
    return {
        "HOME": str(home), "ZDOTDIR": str(home), "PATH": meta["path"],
        "USER": meta["user"], "LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8",
        "TERM": os.environ.get("TERM", "xterm-256color"), "COLORTERM": "truecolor",
        "XDG_CONFIG_HOME": str(home / ".config"),
        "XDG_CACHE_HOME": str(home / ".cache"),
        "XDG_DATA_HOME": str(home / ".local/share"),
        "XDG_STATE_HOME": str(home / ".local/state"),
        "ATUIN_CONFIG_DIR": str(home / ".config/atuin"),
        "GH_TOKEN_AUTOEXPORT": "0", "GIT_OPTIONAL_LOCKS": "0",
        "STARSHIP_FTL": "0" if mode == "off" else "1",
        "TMPDIR": str(home / "tmp"),
    }


def stop_daemon(root, mode):
    env = environment(root, mode)
    config = tomllib.loads((root / mode / ".config/atuin/config.toml").read_text())
    # Refuse a modified fixture pointing back at the user's real daemon.
    for field in ("socket_path", "pidfile_path"):
        if not Path(config["daemon"][field]).is_relative_to(root / mode):
            raise RuntimeError("Refusing to manage an Atuin daemon outside the sandbox")
    subprocess.run(["atuin", "daemon", "stop"], env=env, cwd=root / "repo",
                   stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True, timeout=15)


def stop_deja_daemon(root, mode):
    env = environment(root, mode)
    data_dir = root / mode / ".local/share/deja"
    sock, pidfile = data_dir / "sock", data_dir / "daemon.pid"
    if not sock.is_file() or not pidfile.is_file():
        return
    if subprocess.run(["deja", "ping"], env=env, stdout=subprocess.DEVNULL,
                      stderr=subprocess.DEVNULL, timeout=2).returncode != 0:
        return
    os.kill(int(pidfile.read_text()), signal.SIGTERM)
    deadline = time.monotonic() + 2
    while sock.exists() and time.monotonic() < deadline:
        time.sleep(0.01)
    if sock.exists():
        raise RuntimeError(f"Deja daemon did not release {sock}")


def prepare():
    for tool in ("chezmoi", "zsh", "starship", "atuin", "deja", "mise", "git", "fzf", "carapace", "wt", "zoxide"):
        if not shutil.which(tool):
            raise SystemExit(f"Required installed tool missing: {tool}")
    root = Path(tempfile.mkdtemp(prefix="starship-ftl-trial-", dir="/tmp")).resolve()
    theme = run(["chezmoi", "execute-template", "{{ .theme }}"])
    data = dict(personal=True, work=False, homelab=False, headless=False,
                ephemeral=False, theme=theme, chezmoi={"os": "darwin"})
    meta = dict(path=os.environ["PATH"], user=os.environ.get("USER", "trial"),
                worktree=str(REPO), theme=theme, zsh=shutil.which("zsh"), versions={})
    for tool in ("starship", "atuin", "deja", "mise", "zsh"):
        meta["versions"][tool] = run([tool, "--version"]).splitlines()[0]
    (root / "trial.json").write_text(json.dumps(meta, indent=2))

    def render(text):
        return subprocess.check_output([
            "chezmoi", "execute-template", "--source", str(REPO),
            "--override-data", json.dumps(data),
        ], input=text, text=True)

    real_zinit = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "zinit"
    if not (real_zinit / "zinit.git/zinit.zsh").is_file():
        raise SystemExit(f"Zinit is not installed under {real_zinit}")
    plugin_repos = (
        "zsh-users---zsh-completions",
        "Aloxaf---fzf-tab",
        "zsh-users---zsh-syntax-highlighting",
        "Giammarco-Ferranti---deja",
        "mattmc3---starship-ftl",
    )
    for mode in MODES:
        home = root / mode
        for directory in (".config/zsh", ".config/starship", ".config/atuin/themes", ".local/state/zsh",
                          ".local/share/atuin", ".cache", "tmp"):
            (home / directory).mkdir(parents=True)
        (home / ".config/zsh/aliases.zsh").write_text("# Trial: user aliases intentionally omitted.\n")
        shutil.copytree(real_zinit / "zinit.git", home / ".local/share/zinit/zinit.git")
        for plugin in plugin_repos:
            source_plugin = real_zinit / "plugins" / plugin
            if not source_plugin.is_dir():
                raise SystemExit(f"Zinit plugin is not installed: {source_plugin}")
            destination = home / ".local/share/zinit/plugins" / plugin
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(source_plugin, destination)

        def source(name):
            return (REPO / "home" / name).read_text()

        rc = render(source("dot_zshrc.tmpl"))
        rc += '''
# Private benchmark marker; absent from ordinary interactive trial output.
if [[ ${FTL_TRIAL_BENCH:-0} == 1 ]]; then
  zmodload zsh/zutil
  autoload -Uz add-zle-hook-widget
  _trial_ready() { print -rn -- $'\\e]777;ftl-trial-ready\\a'; }
  add-zle-hook-widget zle-line-init _trial_ready
fi
# Keep the disposable shell from querying the real chezmoi config for tokens.
gh-token() { return 1 }
'''
        (home / ".zshrc").write_text(rc)
        (home / ".config/starship/starship.toml").write_text(render(source("dot_config/starship/private_starship.toml.tmpl")))
        config = source("dot_config/atuin/private_config.toml")
        atuin_data = home / ".local/share/atuin"
        replacements = {
            '# data_dir = "~/.local/share/atuin"': f'data_dir = "{atuin_data}"',
            '# auto_sync = true': 'auto_sync = false',
            '# update_check = true': 'update_check = false',
            'socket_path = "~/.local/share/atuin/atuin.sock"': f'socket_path = "{atuin_data}/atuin.sock"',
            '# pidfile_path = "~/.local/share/atuin/atuin-daemon.pid"': f'pidfile_path = "{atuin_data}/atuin-daemon.pid"',
        }
        for old, new in replacements.items():
            if config.count(old) != 1:
                raise RuntimeError(f"Expected exactly one sandbox setting: {old}")
            config = config.replace(old, new)
        (home / ".config/atuin/config.toml").write_text(config)
        theme_text = render((REPO / "home/dot_config/atuin/themes/chezmoi.toml.tmpl").read_text())
        (home / ".config/atuin/themes/chezmoi.toml").write_text(theme_text)
        history = home / ".local/state/zsh/history"
        history.write_text(": 1700000000:0;echo trial-local-history\n")
        subprocess.run(["deja", "import", "--file", str(history)],
                       env=environment(root, mode), cwd=REPO, check=True,
                       stdout=subprocess.DEVNULL)

    env = environment(root, "ftl")
    fixture = root / "repo"
    fixture.mkdir()
    for number in range(500):
        (fixture / f"file-{number:04}.txt").write_text("prompt benchmark fixture\n")
    subprocess.run(["git", "init", "-q", str(fixture)], env=env, check=True)
    subprocess.run(["git", "add", "."], cwd=fixture, env=env, check=True)
    subprocess.run(["git", "-c", "user.name=Trial", "-c", "user.email=trial@example.invalid",
                    "commit", "-qm", "fixture"], cwd=fixture, env=env, check=True)
    for mode in MODES:
        env = environment(root, mode)
        env["ATUIN_SESSION"] = run(["atuin", "uuid"], env=env, cwd=fixture)
        try:
            # Synthetic entry only. Never import or open the real history database.
            history_id = run(["atuin", "history", "start", "--", "echo trial-atuin-only"], env=env, cwd=fixture)
            subprocess.run(["atuin", "history", "end", "--exit", "0", "--duration", "1", "--", history_id],
                           env=env, cwd=fixture, check=True, stdout=subprocess.DEVNULL)
        finally:
            stop_daemon(root, mode)
    print(f"Prepared: {root}\nCopied Zinit plugins and seeded synthetic history; no live data modified.")


def sample(root, mode):
    env = environment(root, mode)
    env.update(TERM="xterm-256color", FTL_TRIAL_BENCH="1")
    meta = json.loads((root / "trial.json").read_text())
    start = time.perf_counter()
    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(root / "repo")
        fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
        os.execve(meta["zsh"], [meta["zsh"], "-di"], env)
    stream = b""
    first = None

    def until_ready():
        nonlocal stream, first
        buffer = b""
        deadline = time.perf_counter() + 15
        while time.perf_counter() < deadline:
            if not select.select([fd], [], [], .1)[0]:
                continue
            chunk = os.read(fd, 65536)
            if not chunk:
                break
            stream += chunk
            buffer += chunk
            now = time.perf_counter()
            if first is None and "❯".encode() in stream:
                first = (now - start) * 1000
            if MARKER in buffer:
                return now
        raise RuntimeError(f"{mode}: no ready marker; see terminal log")

    try:
        ready = until_ready()
        command_times = []
        for _ in range(3):
            sent = time.perf_counter()
            # CR, not LF: the actual config binds Ctrl-J to history navigation.
            os.write(fd, b":\r")
            command_times.append((until_ready() - sent) * 1000)
        if first is None:
            raise RuntimeError("Prompt glyph not found")
        return {"first_glyph_ms": first, "ready_ms": (ready - start) * 1000,
                "command_to_next_prompt_ms": statistics.median(command_times)}
    finally:
        (root / f"{mode}-terminal.log").write_bytes(stream)
        os.kill(pid, signal.SIGKILL)
        os.waitpid(pid, 0)
        os.close(fd)


def benchmark(root, count):
    measurements = {mode: [] for mode in MODES}
    try:
        for mode in MODES:
            print(f"Warming {mode}...", flush=True)
            sample(root, mode)  # Warm each init cache and its private daemon/index.
        for number in range(count):
            for mode in MODES:
                measurements[mode].append(sample(root, mode))
            print(f"Completed round {number + 1}/{count}", flush=True)
        summary = {}
        for mode, rows in measurements.items():
            summary[mode] = {}
            for key in rows[0]:
                values = sorted(row[key] for row in rows)
                summary[mode][key] = {
                    "median": round(statistics.median(values), 2),
                    "p95": round(values[min(len(values)-1, int(len(values)*.95))], 2),
                }
        output = {"runs": count, "summary": summary, "samples": measurements,
                  "scope": "Warm rendered rc; synthetic Git/history; no aliases, token lookup, login files, TMUX or terminal integration. Not pixel timing."}
        (root / "benchmarks.json").write_text(json.dumps(output, indent=2))
        print(json.dumps(summary, indent=2))
        print(f"Results: {root / 'benchmarks.json'}")
    finally:
        for mode in MODES:
            stop_daemon(root, mode)
            stop_deja_daemon(root, mode)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("prepare", help="Create disposable Zinit/FTL fixtures")
    for command in ("shell", "benchmark"):
        p = commands.add_parser(command)
        p.add_argument("directory", type=Path)
        if command == "shell":
            p.add_argument("--mode", choices=MODES, default="ftl")
        else:
            p.add_argument("--runs", type=int, default=12)
    args = parser.parse_args()
    if args.command == "prepare":
        prepare()
        return
    root = args.directory.resolve(strict=True)
    if args.command == "benchmark":
        if args.runs < 1:
            parser.error("--runs must be positive")
        benchmark(root, args.runs)
    else:
        meta = json.loads((root / "trial.json").read_text())
        print(f"Disposable {args.mode} shell. HOME={root / args.mode}\nUse exit to return. History is synthetic; TMUX is not inherited.", flush=True)
        try:
            subprocess.run([meta["zsh"], "-di"], env=environment(root, args.mode), cwd=root / "repo", check=False)
        finally:
            stop_daemon(root, args.mode)
            stop_deja_daemon(root, args.mode)


if __name__ == "__main__":
    main()
