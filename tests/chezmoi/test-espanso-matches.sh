#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
match_dir="$repo_root/home/dot_config/espanso/match"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/rendered"

# Enable the gated matches using fixture data, without contacting Bitwarden.
printf '#!/bin/sh\nexit 99\n' >"$tmp/bin/bw"
chmod +x "$tmp/bin/bw"
printf '[data]\npersonal = true\nwork = true\n' >"$tmp/chezmoi.toml"
fixture_data=$(python3 - <<'PY'
import json

fields = {
    "bw_info": "email email_old email_shop email_pub email_hbd email_rw full_name phone abn po_box bnkn",
    "bw_work": "email_work work_phone booking_url form_policies staging_url email_ws",
    "bw_homelab": "url_stxa",
    "bw_github": "read_only_token",
}
print(json.dumps({
    group: {field: f"fixture-{field}" for field in names.split()}
    for group, names in fields.items()
}))
PY
)

for source in "$match_dir"/*.yml "$match_dir"/*.yml.tmpl; do
  output="$tmp/rendered/$(basename "${source%.tmpl}")"
  if [[ $source == *.tmpl ]]; then
    PATH="$tmp/bin:$PATH" chezmoi execute-template --source "$repo_root" \
      --config "$tmp/chezmoi.toml" --override-data "$fixture_data" \
      --file "$source" >"$output"
  else
    cp "$source" "$output"
  fi
  # Use chezmoi's YAML parser so this test needs no extra Python packages.
  chezmoi execute-template --source "$repo_root" --config "$tmp/chezmoi.toml" \
    "{{ include \"$output\" | fromYaml | toJson }}" >>"$tmp/matches.jsonl"
  printf '\n' >>"$tmp/matches.jsonl"
done

python3 - "$tmp/matches.jsonl" <<'PY'
import json
import re
import sys
from collections import defaultdict

matches = [
    match
    for line in open(sys.argv[1])
    for match in json.loads(line).get("matches", [])
]
by_trigger = defaultdict(list)
for match in matches:
    triggers = match.get("triggers", [match.get("trigger")])
    for trigger in triggers:
        assert trigger and not trigger.startswith(":"), f"old prefix: {trigger}"
        by_trigger[trigger].append(match)

# Include gated personal/work matches and preserve the unrelated trigger styles.
for trigger in (
    ";dd8", ";bmail", ";wmail", ";stxa", ";mq-md", ";cts", ";chz",
    "==cz-init-d", "==cz-init-gh", "==fnd", "<br", "&nb",
    ";;pfwk", ";;pfws", ";;pfsd",
):
    assert len(by_trigger[trigger]) == 1, f"missing or ambiguous: {trigger}"

shells = {"bash": "#!/usr/bin/env bash", "sh": "#!/bin/sh", "zsh": "#!/usr/bin/env zsh"}
for language in ("css", "yaml", "jinja", "toml", "go", "bash", "lua", "sh", "zsh"):
    for suffix in ("", "ex"):
        trigger = f";{language}{suffix}"
        assert len(by_trigger[trigger]) == 1, f"missing or ambiguous: {trigger}"
        match = by_trigger[trigger][0]
        assert match.get("right_word") is True, f"{trigger} must wait for a separator"
        lines = match["replace"].splitlines()
        assert lines[0] == f"```{language}" and lines[-1] == "```", trigger
        body = "\n".join(lines[1:-1])
        if language in shells:
            assert body.startswith(shells[language] + "\n"), trigger
            body = body.removeprefix(shells[language] + "\n")
        if not suffix:
            assert body.strip() == "$|$", f"{trigger} must be blank with a cursor hint"
        else:
            assert body.replace("$|$", "").strip(), f"{trigger} needs example code"

jinja = by_trigger[";jinjaex"][0]["replace"]
assert r"\{\{" in jinja, "Jinja braces must be emitted literally"
assert not re.search(r"(?<!\\)\{\{", jinja), "Jinja must not reference Espanso variables"

picker = by_trigger[";template"]
assert len(picker) > 1, "a shared trigger is needed to open the selection dialog"
labels = [match.get("label") for match in picker]
assert all(labels) and len(labels) == len(set(labels)), "picker labels must be distinct"
for trigger in (";mq-md", ";cth", ";ctjh", ";ctpf", ";ctbl", ";lmk", ";chz"):
    match = by_trigger[trigger][0]
    assert match in picker, f"{trigger} should also be available in the picker"
    assert not match.get("word") and not match.get("right_word"), trigger
assert by_trigger[";ctpf"][0]["vars"][0]["type"] == "date"
assert "{{mydate}}" in by_trigger[";ctpf"][0]["replace"]

# Only the picker may deliberately reuse a trigger. An immediate shorter match
# must not make a longer semicolon trigger impossible to finish typing.
for trigger, entries in by_trigger.items():
    assert len(entries) == 1 or trigger == ";template", f"duplicate: {trigger}"
    if not trigger.startswith(";"):
        continue
    for longer in by_trigger:
        if longer != trigger and longer.startswith(trigger):
            assert all(entry.get("word") or entry.get("right_word") for entry in entries), (
                f"{trigger} expands before {longer} can be typed"
            )

print("Espanso semicolon triggers, fenced code blocks, and template picker contracts passed")
PY
