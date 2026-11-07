#!/usr/bin/env python3
"""Save Vicinae GUI changes into the chezmoi profile.

Vicinae writes GUI changes to settings.json, which overrides the imported profile.
This copies them into profile.json.tmpl, applies the profile, then removes the copies
from settings.json (backup: settings.json.bak) so the profile stays in charge.
Vicinae reloads both files automatically.
"""

import json
from pathlib import Path
import re
import subprocess
import sys

HOME = Path.home()
SETTINGS = HOME / ".config/vicinae/settings.json"
PROFILE = HOME / ".config/vicinae/profile.json"
# Bookkeeping keys that belong to settings.json itself.
KEEP = {"$schema", "imports"}
EXPRESSION = re.compile(r"\{\{.*?\}\}")
HOME_EXPRESSION = re.compile(r'\{\{ (?:printf ("%s/.*") )?\.chezmoi\.homeDir \| toJson \}\}')
MISSING = object()
TEMPLATED = object()


def marker(index):
    return f"\0template-{index}"


def load_template(text):
    # The header computes template variables before the JSON body starts.
    start = text.index("\n{\n") + 1 if text.startswith("{{") else 0
    expressions = []

    def hold(match):
        expressions.append(match.group(0))
        return json.dumps(marker(len(expressions) - 1))

    return text[:start], json.loads(EXPRESSION.sub(hold, text[start:])), expressions


def dump_template(header, data, expressions):
    text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    for index, expression in enumerate(expressions):
        text = text.replace(json.dumps(marker(index), ensure_ascii=False), expression)
    return header + text


def resolve(value, expressions):
    """Return a template value as rendered for this home, or TEMPLATED if unknown."""
    if isinstance(value, str) and value.startswith(marker("")):
        match = HOME_EXPRESSION.fullmatch(expressions[int(value[len(marker("")):])])
        if not match:
            return TEMPLATED
        suffix = json.loads(match.group(1))[2:].replace("%%", "%") if match.group(1) else ""
        return str(HOME) + suffix
    if isinstance(value, list):
        items = [resolve(item, expressions) for item in value]
        return TEMPLATED if TEMPLATED in items else items
    return value


def templated(value, expressions):
    """Store home paths as template expressions so the profile works for any user."""
    if isinstance(value, dict):
        return {key: templated(item, expressions) for key, item in value.items()}
    if isinstance(value, list):
        return [templated(item, expressions) for item in value]
    if isinstance(value, str) and (value == str(HOME) or value.startswith(f"{HOME}/")):
        suffix = value[len(str(HOME)):]
        if suffix:
            literal = json.dumps("%s" + suffix.replace("%", "%%"), ensure_ascii=False)
            expressions.append(f"{{{{ printf {literal} .chezmoi.homeDir | toJson }}}}")
        else:
            expressions.append("{{ .chezmoi.homeDir | toJson }}")
        return marker(len(expressions) - 1)
    return value


def leaves(value, path=()):
    if isinstance(value, dict):
        for key, item in value.items():
            yield from leaves(item, path + (key,))
    elif path and path[0] not in KEEP:
        yield path, value


def lookup(data, path, expressions=()):
    node = data
    for key in path:
        if isinstance(node, str) and node.startswith(marker("")):
            return TEMPLATED
        if not isinstance(node, dict) or key not in node:
            return MISSING
        node = node[key]
    return resolve(node, expressions)


def put(data, path, value):
    node = data
    for key in path[:-1]:
        if not isinstance(node.get(key), dict):
            node[key] = {}
        node = node[key]
    keys = list(node)
    node[path[-1]] = value
    # Keep alphabetical sections alphabetical, so diffs stay small.
    if path[-1] not in keys and keys == sorted(keys):
        items = sorted(node.items())
        node.clear()
        node.update(items)


def remove(data, path):
    parents = [data]
    for key in path[:-1]:
        parents.append(parents[-1][key])
    del parents[-1][path[-1]]
    for node, key in zip(reversed(parents[:-1]), reversed(path[:-1])):
        if node[key]:
            break
        del node[key]


def main():
    text = SETTINGS.read_text()
    body = text.lstrip()
    # Vicinae writes a comment header; keep it when rewriting the file.
    while body.startswith("//"):
        body = body.partition("\n")[2].lstrip()
    comment, settings = text[:len(text) - len(body)], json.loads(body)
    if PROFILE.resolve() not in {(SETTINGS.parent / item).resolve() for item in settings.get("imports", [])}:
        sys.exit("settings.json does not import profile.json; nothing was changed")

    template = Path(subprocess.run(
        ["chezmoi", "source-path", str(PROFILE)], check=True, capture_output=True, text=True,
    ).stdout.strip())
    header, data, expressions = load_template(template.read_text())
    copied = []
    for path, value in leaves(settings):
        current = lookup(data, path, expressions)
        if current is not TEMPLATED and current != value:
            put(data, path, templated(value, expressions))
            copied.append(path)
    if copied:
        output = dump_template(header, data, expressions)
        load_template(output)  # Fail before writing if the result is not valid JSON.
        template.write_text(output)
    if subprocess.run(["chezmoi", "apply", str(PROFILE)]).returncode:
        sys.exit("chezmoi apply failed; settings.json was not changed")

    profile = json.loads(PROFILE.read_text())
    redundant = [path for path, value in leaves(settings) if lookup(profile, path) == value]
    if redundant:
        SETTINGS.with_name("settings.json.bak").write_text(text)
        for path in redundant:
            remove(settings, path)
        temporary = SETTINGS.with_name("settings.json.tmp")
        temporary.write_text(comment + json.dumps(settings, indent=2, ensure_ascii=False) + "\n")
        temporary.replace(SETTINGS)

    for path in copied:
        print(f"saved {'/'.join(path)}")
    kept = sum(1 for _ in leaves(settings))
    if kept:
        print(f"{kept} settings stay in settings.json because a template generates them; edit those by hand.")
    if copied:
        print(f"Updated {template}; commit it in the chezmoi repo.")
    else:
        print("No new GUI changes.")


if __name__ == "__main__":
    main()
