#!/usr/bin/env python3
"""Bounded, read-only inventory of Claude and Pi prompt configuration files."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

HEADING = re.compile(r"^#{1,6}\s+(.+?)\s*#*\s*$")


def file_record(path: Path, display: str) -> dict[str, object]:
    record: dict[str, object] = {"path": display, "exists": False, "kind": "missing", "lines": 0, "bytes": 0}
    try:
        stat = path.lstat()
    except FileNotFoundError:
        return record

    record["exists"] = True
    if path.is_symlink():
        record["kind"] = "symlink"
        record["target"] = os.readlink(path)
        record["resolves_to"] = str(path.resolve(strict=False))
        if not path.exists():
            return record
    elif path.is_file():
        record["kind"] = "file"
    elif path.is_dir():
        record["kind"] = "directory"
        return record
    else:
        record["kind"] = "other"
        return record

    data = path.read_bytes()
    text = data.decode("utf-8", errors="replace")
    record["bytes"] = len(data)
    record["lines"] = len(text.splitlines())
    record["mode"] = oct(stat.st_mode & 0o777)
    return record


def claude_link_status(root: Path) -> dict[str, object]:
    claude = root / "CLAUDE.md"
    agents = root / "AGENTS.md"
    result: dict[str, object] = {"path": "CLAUDE.md", "expected_target": "AGENTS.md"}

    try:
        claude.lstat()
    except FileNotFoundError:
        result["status"] = "missing"
        return result

    if not claude.is_symlink():
        result["status"] = "regular-file"
        result["content_differs"] = not agents.is_file() or claude.read_bytes() != agents.read_bytes()
        return result

    result["target"] = os.readlink(claude)
    result["resolves_to"] = str(claude.resolve(strict=False))
    if not claude.exists():
        result["status"] = "broken"
    elif claude.resolve() == agents.resolve(strict=False):
        result["status"] = "correct"
    else:
        result["status"] = "wrong-target"
    return result


def duplicate_headings(paths: list[Path]) -> dict[str, list[int]]:
    locations: dict[str, list[int]] = {}
    for path in paths:
        if path.is_symlink() or not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for lineno, line in enumerate(text.splitlines(), start=1):
            match = HEADING.match(line)
            if not match:
                continue
            normalized = " ".join(match.group(1).casefold().split())
            locations.setdefault(normalized, []).append(lineno)
    return {heading: lines for heading, lines in sorted(locations.items()) if len(lines) > 1}


def inspect(root: Path, global_pi_root: Path) -> dict[str, object]:
    root = root.expanduser().resolve()
    global_pi_root = global_pi_root.expanduser().absolute()
    project_paths = [
        (root / "AGENTS.md", "AGENTS.md"),
        (root / "CLAUDE.md", "CLAUDE.md"),
        (root / ".pi" / "SYSTEM.md", ".pi/SYSTEM.md"),
        (root / ".pi" / "APPEND_SYSTEM.md", ".pi/APPEND_SYSTEM.md"),
    ]
    global_paths = [
        (global_pi_root / "SYSTEM.md", str(global_pi_root / "SYSTEM.md")),
        (global_pi_root / "APPEND_SYSTEM.md", str(global_pi_root / "APPEND_SYSTEM.md")),
    ]
    all_paths = project_paths + global_paths
    records = [file_record(path, display) for path, display in all_paths]
    replacement_exists = any(
        record["exists"] and str(record["path"]).endswith("SYSTEM.md") and not str(record["path"]).endswith("APPEND_SYSTEM.md")
        for record in records
    )
    return {
        "root": str(root),
        "files": records,
        "claude_link": claude_link_status(root),
        "duplicate_headings": duplicate_headings([path for path, _ in all_paths]),
        "warnings": ["replacement-system-prompt"] if replacement_exists else [],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True, help="Project root to inspect")
    parser.add_argument(
        "--global-pi-root",
        type=Path,
        default=Path(os.environ.get("PI_CODING_AGENT_DIR", "~/.pi/agent")),
        help="Pi global config root (default: PI_CODING_AGENT_DIR or ~/.pi/agent)",
    )
    args = parser.parse_args(argv)
    root = args.root.expanduser()
    if not root.is_dir():
        parser.error(f"root is not a directory: {root}")
    print(json.dumps(inspect(root, args.global_pi_root), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
