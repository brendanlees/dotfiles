#!/usr/bin/env python3
"""Static SkillSpector scan of agent skills with a compact, triage-ready summary.

Each skill is scanned separately at its resolved path, because SkillSpector
rejects symlinked inputs and skips symlinked children in recursive scans.
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

DEFAULT_ROOTS = ["~/.agents/skills", "~/.pi/agent/skills", "~/.codex/skills"]
SKILL_LOCK = Path("~/.agents/.skill-lock.json").expanduser()
SEVERITY_ORDER = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3, "INFO": 4}


def skill_dirs(paths: list[str]) -> list[Path]:
    found: dict[Path, None] = {}
    for raw in paths:
        path = Path(raw).expanduser()
        if not path.exists():
            if raw not in DEFAULT_ROOTS:
                print(f"skipped missing path: {raw}", file=sys.stderr)
            continue
        path = path.resolve()
        if (path / "SKILL.md").is_file():
            found[path] = None
            continue
        for child in sorted(path.iterdir()):
            if (child / "SKILL.md").is_file():
                found[child.resolve()] = None
    return list(found)


def upstream_skills() -> set[str]:
    if not SKILL_LOCK.is_file():
        return set()
    return set(json.loads(SKILL_LOCK.read_text()).get("skills", {}))


def owner(skill: Path, upstream: set[str]) -> str:
    if skill.name in upstream:
        return "upstream (skill-lock)"
    result = subprocess.run(["git", "-C", str(skill), "rev-parse", "--show-toplevel"],
                            capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else "not in git"


def scan(skill: Path, report: Path) -> dict | str:
    result = subprocess.run(["skillspector", "scan", str(skill), "--no-llm", "--format", "json",
                             "--output", str(report)], capture_output=True, text=True)
    if not report.is_file():
        return " ".join((result.stderr or result.stdout).split()) or f"exit {result.returncode}"
    return json.loads(report.read_text())


def main() -> int:
    skills = skill_dirs(sys.argv[1:] or DEFAULT_ROOTS)
    if not skills:
        print("no skills found")
        return 1
    upstream = upstream_skills()
    out_dir = Path(tempfile.mkdtemp(prefix="skillspector-review-"))
    rows, findings, failures = [], [], []
    for index, skill in enumerate(skills):
        result = scan(skill, out_dir / f"{index:02d}-{skill.name}.json")
        if not isinstance(result, dict):
            failures.append(f"{skill}: {result}")
            continue
        risk = result["risk_assessment"]
        coverage = result.get("analysis_completeness", {}).get("status", "?")
        issues = result.get("issues", [])
        rows.append((risk["score"], skill.name, risk["severity"], len(issues), coverage, owner(skill, upstream), skill))
        for issue in issues:
            loc = issue.get("location") or {}
            findings.append((SEVERITY_ORDER.get(issue["severity"], 9), skill.name, issue["severity"],
                             f"{issue['category']} / {issue['pattern']}",
                             f"{skill}/{loc.get('file', '?')}:{loc.get('start_line') or '?'}",
                             issue.get("finding", "")[:100]))

    print(f"Scanned {len(rows)} skill(s), {len(failures)} failed. Full JSON reports: {out_dir}\n")
    print("| skill | severity | score | findings | coverage | owner |")
    print("|---|---|---|---|---|---|")
    for score, name, severity, count, coverage, repo, _ in sorted(rows, key=lambda r: (-r[0], r[1])):
        print(f"| {name} | {severity} | {score} | {count} | {coverage} | {repo} |")
    if findings:
        print("\nFindings, most severe first:")
        for _, name, severity, rule, where, text in sorted(findings):
            print(f"- [{severity}] {name}: {rule} at {where} - matched {json.dumps(text)}")
    if failures:
        print("\nFailed scans:")
        for line in failures:
            print(f"- {line}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
