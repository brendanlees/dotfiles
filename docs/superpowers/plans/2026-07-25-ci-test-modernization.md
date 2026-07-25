# CI and Test Modernization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the maintained chezmoi tests mandatory in a reproducible five-job GitHub Actions workflow with focused Linux, macOS, and Windows coverage.

**Architecture:** Keep `.github/workflows/ci.yml` as the single orchestrator and move locally runnable test, static-check, template-render, and PowerShell parsing behavior into focused files under `tests/ci/`. Restore the post-theme-branch test baseline first, then wire those checks into pinned, least-privilege CI jobs with explicit timeouts and concurrency cancellation.

**Tech Stack:** GitHub Actions, Bash 4+, PowerShell 7, Python 3.11+, chezmoi 2.71.1, actionlint 1.7.12, ShellCheck 0.11.0, Taplo 0.10.0, yamllint 1.38.0, jq

## Global Constraints

- Start only after `feat/add-terminal-themes` is merged, or rebase this branch onto commit `2576e2e` or its merged descendant.
- Work only from an isolated branch or worktree, never `main` or `master`.
- Retain one workflow at `.github/workflows/ci.yml` with five bounded jobs: policy/lint, repository tests, template smoke, apply dry-run, and focused Windows.
- Keep workflow permissions at `contents: read`; grant no write permissions.
- Use explicit runner labels: `ubuntu-24.04`, `macos-15`, and `windows-2025`.
- Pin GitHub Actions to full commit SHAs with version comments. Use `actions/checkout` v7 at `3d3c42e5aac5ba805825da76410c181273ba90b1` unless current documentation requires a newer immutable commit at execution time.
- Pin CLI versions to chezmoi 2.71.1, actionlint 1.7.12, ShellCheck 0.11.0, Taplo 0.10.0, and yamllint 1.38.0 unless a newer version is deliberately selected and documented before implementation.
- Require Bash 4+ and Python 3.11+ for the repository test job.
- Never access real secrets or Bitwarden in CI; role fixtures must use explicit non-secret data.
- Keep tests serial until measured runtime and isolation evidence justify parallel execution.
- Do not add caching, artifact handoff, path filters, sharding, reusable workflows, or a third-party shell test framework.
- Keep all production behavior unchanged unless a restored test proves an actual production regression and the user separately approves that fix.

---

## File map

- Modify `.github/workflows/ci.yml`: orchestrate the five jobs, pinned tools/actions, concurrency, permissions, and timeouts.
- Create `.github/dependabot.yml`: weekly grouped updates for GitHub Actions only.
- Create `tests/ci/run-chezmoi-tests.sh`: discover, run, time, summarize, and aggregate the shell test suite.
- Create `tests/ci/test-run-chezmoi-tests.sh`: verify runner selection and aggregate failure behavior with fake tests.
- Create `tests/ci/install-linux-tools.sh`: install pinned Linux CI tools with hard-coded SHA-256 verification.
- Create `tests/ci/check-static.sh`: lint tracked static shell, YAML, TOML, JSON, workflow, and repository policy.
- Create `tests/ci/render-and-lint.sh`: render each supported template once and validate rendered shell, YAML, TOML, and JSON.
- Create `tests/ci/check-powershell.ps1`: parse static and rendered PowerShell on Windows.
- Create `tests/chezmoi/test-role-routing.sh`: smoke-test representative role routing without secret access.
- Modify or remove stale `tests/chezmoi/test-sketchybar-*.sh` files listed in Task 2.
- Modify `docs/testing.md`: document jobs, local commands, runtime contracts, exclusions, and update procedure.

---

### Task 1: Integrate the prerequisite branch and record the fresh baseline

**Files:**
- No source files changed
- Inspect: `tests/chezmoi/test-*.sh`

**Interfaces:**
- Consumes: merged descendant of `feat/add-terminal-themes` commit `2576e2e`
- Produces: a clean branch whose baseline includes the concurrent test repairs and theme-registry test

- [ ] **Step 1: Verify isolation and prerequisite ancestry**

Run:

```bash
git status --short --branch
git branch --show-current
git merge-base --is-ancestor 2576e2e HEAD
```

Expected: the branch is neither `main` nor `master`, the worktree is clean, and `merge-base` exits 0. If it exits nonzero, stop and rebase onto the merged theme branch before continuing.

- [ ] **Step 2: Verify required local tools or use the Ubuntu CI-equivalent environment**

Run:

```bash
bash -c '(( BASH_VERSINFO[0] >= 4 ))'
python3 -c 'import sys, tomllib; assert sys.version_info >= (3, 11)'
chezmoi --version
jq --version
```

Expected: every command exits 0. On macOS with system Bash 3 or Python below 3.11, use Homebrew/mise binaries by placing them first in `PATH`; do not modify tests to accommodate obsolete interpreters.

- [ ] **Step 3: Run every post-merge test and save the evidence**

Run:

```bash
failures=0
for test_file in tests/chezmoi/test-*.sh; do
  printf 'RUN  %s\n' "$test_file"
  bash "$test_file" || failures=$((failures + 1))
done
printf 'baseline failures: %s\n' "$failures"
((failures == 0))
```

Expected before Task 2: failures remain in the stale SketchyBar tests. Do not edit unrelated production files in response.

---

### Task 2: Reconcile stale SketchyBar tests with current intended behavior

**Files:**
- Modify: `tests/chezmoi/test-sketchybar-calendar-sourcing.sh`
- Modify: `tests/chezmoi/test-sketchybar-front-app-center-pill.sh`
- Modify: `tests/chezmoi/test-sketchybar-live-workspace-icons.sh`
- Modify: `tests/chezmoi/test-sketchybar-right-anchor-polish.sh`
- Delete: `tests/chezmoi/test-sketchybar-soundsource-launcher.sh`
- Modify: `tests/chezmoi/test-sketchybar-spotify-now-playing.sh`
- Modify: `tests/chezmoi/test-sketchybar-tailscale-sourcing.sh`
- Modify: `tests/chezmoi/test-sketchybar-tailscale-status.sh`

**Interfaces:**
- Consumes: current `dot_config/sketchybar/` item and plugin behavior
- Produces: maintained behavioral tests that pass against the current flattened item configuration

- [ ] **Step 1: Reproduce each stale expectation individually**

Run:

```bash
for test_file in \
  tests/chezmoi/test-sketchybar-calendar-sourcing.sh \
  tests/chezmoi/test-sketchybar-front-app-center-pill.sh \
  tests/chezmoi/test-sketchybar-live-workspace-icons.sh \
  tests/chezmoi/test-sketchybar-right-anchor-polish.sh \
  tests/chezmoi/test-sketchybar-soundsource-launcher.sh \
  tests/chezmoi/test-sketchybar-spotify-now-playing.sh \
  tests/chezmoi/test-sketchybar-tailscale-sourcing.sh \
  tests/chezmoi/test-sketchybar-tailscale-status.sh; do
  bash "$test_file" || true
done
```

Expected: failures identify stale item order, removed SoundSource item, removed dynamic plugin borders, and outdated dimensions/colors.

- [ ] **Step 2: Update right-side source-order assertions**

In both sourcing tests, replace the old four-item expectation with:

```bash
expect=$'calendar\nbattery\nbackup_status\ntailscale\nspotify'
```

In `test-sketchybar-right-anchor-polish.sh`, assert the current source list and ordering:

```python
expected = [
    'source "$ITEM_DIR/spaces.sh"',
    'source "$ITEM_DIR/front_app.sh"',
    'source "$ITEM_DIR/calendar.sh"',
    'source "$ITEM_DIR/battery.sh"',
    'source "$ITEM_DIR/backup_status.sh"',
    'source "$ITEM_DIR/tailscale.sh"',
    'source "$ITEM_DIR/spotify.sh"',
]
assert source_lines == expected, source_lines
```

Remove assertions about a shelved `app_soundsource.sh` line because the production item was deliberately deleted by `f06c00b`.

- [ ] **Step 3: Align front-app assertions with its current environment contract**

Provide all variables consumed by `items/front_app.sh`:

```bash
ITEM_PADDING=6 \
SURFACE=0xff202020 \
BORDER_RADIUS=8 \
PILL_HEIGHT=28 \
```

Replace stale assertions with:

```python
assert 'background.drawing=on' in log, log
assert 'background.color=0xff202020' in log, log
assert 'background.border_color=0xff202020' in log, log
assert 'background.corner_radius=8' in log, log
assert 'background.height=28' in log, log
assert 'icon.font=sketchybar-app-font:Regular:11.0' in log, log
```

- [ ] **Step 4: Remove plugin border assertions that production no longer emits**

Delete these stale assertions:

```bash
assert_log_contains 'background.border_color=0xffffff00'
assert_log_contains 'background.border_color=0xff00ff80'
```

Change `assert_visible` in `test-sketchybar-tailscale-status.sh` to validate only behavior emitted by the plugin:

```bash
assert_visible() {
  local scenario="$1" label="$2" color="$3"
  assert_field "$scenario" "drawing" "on"
  assert_field "$scenario" "label" "$label"
  assert_field "$scenario" "icon.color" "$color"
}
```

Update its comment from "icon AND pill border" to "icon color".

- [ ] **Step 5: Align the static calendar and Spotify item assertions**

In both `test-sketchybar-calendar-sourcing.sh` and `test-sketchybar-right-anchor-polish.sh`, pass the complete current calendar environment:

```bash
ICON_CLOCK=CLOCK \
ITEM_PADDING=6 \
SURFACE=0xff202020 \
BORDER_RADIUS=8 \
PILL_HEIGHT=28 \
```

Replace the Python assertion block in `test-sketchybar-calendar-sourcing.sh` with current date/time item behavior:

```python
from pathlib import Path
import sys
log = Path(sys.argv[1]).read_text()
for name in ['calendar', 'calendar_event_clock', 'calendar_time']:
    assert f'--add item {name} right' in log, (name, log)
for removed in ['cal_dot_fam', 'cal_dot_work', 'cal_dot_per', 'cal_dot_neutral']:
    assert f'--add item {removed} right' not in log, (removed, log)
assert '--add bracket calendar_group' in log, log
assert 'background.color=0x88262626' in log, log
assert 'background.border_color=0xff202020' in log, log
assert 'icon=CAL' in log, log
assert 'icon=CLOCK' in log, log
assert 'label.color=0xffffffff' in log, log
assert 'script=/tmp/plugins/calendar.sh' in log, log
assert 'script=/tmp/plugins/calendar_dots.sh' in log, log
assert 'update_freq=15' in log, log
assert 'update_freq=300' in log, log
assert 'control down' in log and 'option down' in log, log
assert 'open -a Itsycal' in log, log
```

In `test-sketchybar-right-anchor-polish.sh`, replace stale calendar border assertions with:

```python
assert '--add bracket calendar_group' in log, log
assert 'background.border_color=0xff202020' in log, log
assert 'background.drawing=off' in log, log
```

For the static Spotify item invocation, pass:

```bash
SURFACE=0xff202020 \
TRANSPARENT=0x00000000 \
BORDER_RADIUS=8 \
PILL_HEIGHT=28 \
ITEM_PADDING=6 \
```

Then assert:

```bash
assert_log_contains 'background.color=0xff202020'
assert_log_contains 'background.border_color=0x00000000'
```

Keep the icon, update frequency, script, and click behavior assertions.

- [ ] **Step 6: Delete the obsolete SoundSource test**

Run:

```bash
git rm tests/chezmoi/test-sketchybar-soundsource-launcher.sh
```

Expected: only the test is removed; no production SoundSource file is recreated.

- [ ] **Step 7: Run the reconciled SketchyBar suite**

Run:

```bash
for test_file in tests/chezmoi/test-sketchybar-*.sh; do bash "$test_file"; done
```

Expected: all remaining SketchyBar tests pass.

- [ ] **Step 8: Commit the reconciliation**

```bash
git add tests/chezmoi
git commit -m "test(sketchybar): reconcile current item behavior"
```

---

### Task 3: Add an aggregate repository test runner

**Files:**
- Create: `tests/ci/run-chezmoi-tests.sh`
- Create: `tests/ci/test-run-chezmoi-tests.sh`

**Interfaces:**
- Consumes: zero or more explicit test paths; no arguments means sorted `tests/chezmoi/test-*.sh`
- Produces: `RUN`, `PASS`, `FAIL`, and `SUMMARY` output; exit 0 only when all selected tests pass

- [ ] **Step 1: Write the runner self-test first**

Create `tests/ci/test-run-chezmoi-tests.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/pass.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat >"$tmpdir/fail-one.sh" <<'SH'
#!/usr/bin/env bash
echo 'first failure' >&2
exit 3
SH
cat >"$tmpdir/fail-two.sh" <<'SH'
#!/usr/bin/env bash
echo 'second failure' >&2
exit 7
SH
chmod +x "$tmpdir"/*.sh

set +e
output=$("$repo_root/tests/ci/run-chezmoi-tests.sh" \
  "$tmpdir/pass.sh" "$tmpdir/fail-one.sh" "$tmpdir/fail-two.sh" 2>&1)
status=$?
set -e

[[ $status -eq 1 ]]
grep -Fq "PASS $tmpdir/pass.sh" <<<"$output"
grep -Fq "FAIL $tmpdir/fail-one.sh (exit 3" <<<"$output"
grep -Fq "FAIL $tmpdir/fail-two.sh (exit 7" <<<"$output"
grep -Fq 'SUMMARY: 1 passed, 2 failed' <<<"$output"

echo 'aggregate runner behavior ok'
```

- [ ] **Step 2: Run the self-test and verify the missing-runner failure**

Run:

```bash
bash tests/ci/test-run-chezmoi-tests.sh
```

Expected: FAIL because `tests/ci/run-chezmoi-tests.sh` does not exist.

- [ ] **Step 3: Implement the runner**

Create `tests/ci/run-chezmoi-tests.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
if (($#)); then
  tests=("$@")
else
  shopt -s nullglob
  tests=("$repo_root"/tests/chezmoi/test-*.sh)
fi

if ((${#tests[@]} == 0)); then
  echo 'FAIL no chezmoi tests found' >&2
  exit 1
fi

passed=0
failed=0
failed_names=()
suite_start=$SECONDS
for test_file in "${tests[@]}"; do
  start=$SECONDS
  printf 'RUN  %s\n' "$test_file"
  if bash "$test_file"; then
    passed=$((passed + 1))
    printf 'PASS %s (%ss)\n' "$test_file" "$((SECONDS - start))"
  else
    status=$?
    failed=$((failed + 1))
    failed_names+=("$test_file")
    printf 'FAIL %s (exit %s, %ss)\n' "$test_file" "$status" "$((SECONDS - start))" >&2
  fi
done

printf 'SUMMARY: %s passed, %s failed (%ss)\n' \
  "$passed" "$failed" "$((SECONDS - suite_start))"
if ((failed)); then
  printf 'FAILED TESTS:\n' >&2
  printf '  %s\n' "${failed_names[@]}" >&2
  exit 1
fi
```

- [ ] **Step 4: Verify the self-test and complete suite**

Run:

```bash
bash tests/ci/test-run-chezmoi-tests.sh
bash tests/ci/run-chezmoi-tests.sh
```

Expected: runner self-test passes and the maintained suite reports zero failures under Bash 4+ and Python 3.11+.

- [ ] **Step 5: Commit the runner**

```bash
git add tests/ci/run-chezmoi-tests.sh tests/ci/test-run-chezmoi-tests.sh
git commit -m "test(ci): add aggregate chezmoi test runner"
```

---

### Task 4: Add representative role-routing coverage

**Files:**
- Create: `tests/chezmoi/test-role-routing.sh`

**Interfaces:**
- Consumes: `.chezmoiignore` rendered with explicit role and OS data
- Produces: assertions for ephemeral/headless, personal, work, and homelab routing without secret lookups

- [ ] **Step 1: Write the role matrix test**

Create `tests/chezmoi/test-role-routing.sh` with a renderer and explicit cases:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

render_ignore() {
  local name=$1 data=$2
  chezmoi execute-template --source "$repo_root" --override-data "$data" \
    <"$repo_root/.chezmoiignore" >"$tmpdir/$name.ignore"
}

assert_has() { grep -Fxq "$2" "$tmpdir/$1.ignore"; }
assert_lacks() { ! grep -Fxq "$2" "$tmpdir/$1.ignore"; }

render_ignore ephemeral '{"personal":false,"work":false,"homelab":false,"ephemeral":true,"headless":true,"chezmoi":{"os":"linux"}}'
render_ignore personal  '{"personal":true,"work":false,"homelab":false,"ephemeral":false,"headless":false,"chezmoi":{"os":"darwin"}}'
render_ignore work      '{"personal":false,"work":true,"homelab":false,"ephemeral":false,"headless":false,"chezmoi":{"os":"linux"}}'
render_ignore homelab   '{"personal":false,"work":false,"homelab":true,"ephemeral":false,"headless":true,"chezmoi":{"os":"linux"}}'

personal_project='.config/herdr/plugins/config/cloudmanic.herdr-plus/projects/personal-*.toml'
work_project='.config/herdr/plugins/config/cloudmanic.herdr-plus/projects/work-*.toml'
homelab_project='.config/herdr/plugins/config/cloudmanic.herdr-plus/projects/homelab-*.toml'

assert_has ephemeral '.config/ghostty'
assert_has ephemeral "$personal_project"
assert_has ephemeral "$work_project"
assert_has ephemeral "$homelab_project"

assert_lacks personal "$personal_project"
assert_has personal "$work_project"
assert_has personal "$homelab_project"

assert_has work "$personal_project"
assert_lacks work "$work_project"
assert_has work "$homelab_project"

assert_has homelab "$personal_project"
assert_has homelab "$work_project"
assert_lacks homelab "$homelab_project"

echo 'role routing matrix ok'
```

- [ ] **Step 2: Run the role matrix test**

Run:

```bash
bash tests/chezmoi/test-role-routing.sh
```

Expected: PASS with `role routing matrix ok`.

- [ ] **Step 3: Verify role coverage and the full suite**

Run:

```bash
bash tests/chezmoi/test-role-routing.sh
bash tests/ci/run-chezmoi-tests.sh
```

Expected: all four role cases and the complete suite pass without `bw` in `PATH` and without network access.

- [ ] **Step 4: Commit role coverage**

```bash
git add tests/chezmoi/test-role-routing.sh
git commit -m "test(chezmoi): cover role routing matrix"
```

---

### Task 5: Extract static policy and lint checks

**Files:**
- Create: `tests/ci/install-linux-tools.sh`
- Create: `tests/ci/check-static.sh`
- Test: `tests/ci/check-static.sh`

**Interfaces:**
- `install-linux-tools.sh lint|chezmoi|all` installs verified binaries into `$HOME/.local/bin`
- `check-static.sh` consumes tracked repository files plus `actionlint`, `shellcheck`, `yamllint`, `taplo`, and Python on `PATH`
- Produces: one locally runnable static check with nonzero status on syntax, lint, JSON, banned-pattern, or mutable-action failures

- [ ] **Step 1: Create a temporary mutable-action fixture and verify policy red state**

Before implementing the action-reference rule, save the current workflow and append a temporary fixture:

```bash
cp .github/workflows/ci.yml "$TMPDIR/ci.yml.audit-backup"
printf '\n# uses: actions/checkout@v7\n' >>.github/workflows/ci.yml
```

Expected after the script exists: `check-static.sh` must reject this tag reference. Restore the workflow immediately after the red test with:

```bash
mv "$TMPDIR/ci.yml.audit-backup" .github/workflows/ci.yml
```

- [ ] **Step 2: Implement the verified Linux tool installer**

Create `tests/ci/install-linux-tools.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

mode=${1:-all}
case "$mode" in lint|chezmoi|all) ;; *) echo "usage: $0 lint|chezmoi|all" >&2; exit 2 ;; esac

actionlint_version=${ACTIONLINT_VERSION:-1.7.12}
chezmoi_version=${CHEZMOI_VERSION:-2.71.1}
shellcheck_version=${SHELLCHECK_VERSION:-0.11.0}
taplo_version=${TAPLO_VERSION:-0.10.0}
yamllint_version=${YAMLLINT_VERSION:-1.38.0}

bin_dir=${HOME}/.local/bin
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$bin_dir"
[[ -z ${GITHUB_PATH:-} ]] || printf '%s\n' "$bin_dir" >>"$GITHUB_PATH"

fetch() { curl --fail --silent --show-error --location "$1" --output "$2"; }
verify() { printf '%s  %s\n' "$1" "$2" | sha256sum --check --status; }

install_lint() {
  fetch "https://github.com/rhysd/actionlint/releases/download/v${actionlint_version}/actionlint_${actionlint_version}_linux_amd64.tar.gz" "$work/actionlint.tar.gz"
  verify 8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8 "$work/actionlint.tar.gz"
  tar -xzf "$work/actionlint.tar.gz" -C "$work" actionlint
  install -m 0755 "$work/actionlint" "$bin_dir/actionlint"

  fetch "https://github.com/koalaman/shellcheck/releases/download/v${shellcheck_version}/shellcheck-v${shellcheck_version}.linux.x86_64.tar.xz" "$work/shellcheck.tar.xz"
  verify 8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198 "$work/shellcheck.tar.xz"
  tar -xJf "$work/shellcheck.tar.xz" -C "$work"
  install -m 0755 "$work/shellcheck-v${shellcheck_version}/shellcheck" "$bin_dir/shellcheck"

  fetch "https://github.com/tamasfe/taplo/releases/download/${taplo_version}/taplo-linux-x86_64.gz" "$work/taplo.gz"
  verify 8fe196b894ccf9072f98d4e1013a180306e17d244830b03986ee5e8eabeb6156 "$work/taplo.gz"
  gzip -dc "$work/taplo.gz" >"$bin_dir/taplo"
  chmod 0755 "$bin_dir/taplo"

  pipx install --force "yamllint==${yamllint_version}"
}

install_chezmoi() {
  fetch "https://github.com/twpayne/chezmoi/releases/download/v${chezmoi_version}/chezmoi_${chezmoi_version}_linux_amd64.tar.gz" "$work/chezmoi.tar.gz"
  verify e1fb16c962644d57f4d451c324aa86163d00faf5d035500f41fb48943a66dfed "$work/chezmoi.tar.gz"
  tar -xzf "$work/chezmoi.tar.gz" -C "$work" chezmoi
  install -m 0755 "$work/chezmoi" "$bin_dir/chezmoi"
}

case "$mode" in
  lint) install_lint ;;
  chezmoi) install_chezmoi ;;
  all) install_lint; install_chezmoi ;;
esac
```

Run:

```bash
bash tests/ci/install-linux-tools.sh all
export PATH="$HOME/.local/bin:$PATH"
actionlint -version
shellcheck --version
taplo --version
yamllint --version
chezmoi --version
```

Expected: exact pinned versions are reported.

- [ ] **Step 3: Implement `tests/ci/check-static.sh`**

The script must use `git ls-files -z`, not broad `find`, so generated and ignored files do not enter lint. Implement these exact stages:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$repo_root"

require() { command -v "$1" >/dev/null || { echo "missing required tool: $1" >&2; exit 1; }; }
for tool in actionlint shellcheck yamllint taplo python3; do require "$tool"; done

actionlint

mapfile -d '' shell_files < <(git ls-files -z '*.sh' '*.zsh')
((${#shell_files[@]} == 0)) || shellcheck -e SC1091 "${shell_files[@]}"

mapfile -d '' yaml_files < <(git ls-files -z '*.yml' '*.yaml')
yamllint -d '{extends: relaxed, rules: {line-length: disable, trailing-spaces: disable, empty-lines: disable, document-start: disable, comments: disable, truthy: disable}}' "${yaml_files[@]}"

mapfile -d '' toml_files < <(git ls-files -z '*.toml')
((${#toml_files[@]} == 0)) || taplo lint --no-schema "${toml_files[@]}"

python3 - <<'PY'
import json, subprocess
from pathlib import Path
paths = subprocess.check_output(["git", "ls-files", "*.json"], text=True).splitlines()
for path in paths:
    json.loads(Path(path).read_text())
print(f"validated {len(paths)} static JSON files")
PY

if grep -nrE 'uses:[[:space:]]+[^[:space:]#]+@[^[:space:]#]+' .github/workflows \
  | grep -vE '@[0-9a-f]{40}([[:space:]]+#.*)?$'; then
  echo 'GitHub Action references must use full commit SHAs' >&2
  exit 1
fi

fails=0
if grep -nrE 'chmod[[:space:]]+(-[Rr][[:space:]]+)?777\b' \
    --include='*.sh' --include='*.zsh' --include='*.tmpl' \
    --include='*.yml' --include='*.yaml' --include='*.toml' \
    --exclude-dir=.git --exclude='ci.yml' .; then
  echo 'world-writable mode found' >&2
  fails=$((fails + 1))
fi

is_approved_chezmoi_installer() {
  grep -qxE '[[:space:]]*curl[[:space:]]+(-[A-Za-z0-9]+[[:space:]]+)*(https?://)?get\.chezmoi\.io[[:space:]]*\|[[:space:]]*sh[[:space:]]*' <<<"$1"
}

is_approved_mise_installer() {
  local file=$1 line_no=$2 line=$3 current='' current_no=0 url_line=0 confirm_line=0
  if ! grep -qxE '[[:space:]]*curl[[:space:]]+"\$mise_install_url"[[:space:]]*\|[[:space:]]*sh[[:space:]]*' <<<"$line"; then
    return 1
  fi
  while IFS= read -r current; do
    current_no=$((current_no + 1))
    ((current_no < line_no)) || break
    if grep -qE '^[[:space:]]*mise_install_url=' <<<"$current"; then
      ((confirm_line == 0)) || return 1
      if grep -qxE '^[[:space:]]*mise_install_url="https://mise\.run"[[:space:]]*$' <<<"$current"; then
        url_line=$current_no
      else
        url_line=0
      fi
    fi
    if grep -qxE '^[[:space:]]*confirm_remote_script[[:space:]]+"mise"[[:space:]]+"\$mise_install_url"[[:space:]]*$' <<<"$current"; then
      ((url_line > 0)) || return 1
      confirm_line=$current_no
    fi
  done <"$file"
  ((url_line > 0 && confirm_line > url_line))
}

unsafe=''
while IFS=: read -r file line_no line; do
  is_approved_chezmoi_installer "$line" && continue
  is_approved_mise_installer "$file" "$line_no" "$line" && continue
  printf -v unsafe '%s%s:%s:%s\n' "$unsafe" "$file" "$line_no" "$line"
done < <(grep -nrE 'curl[^|]+\|[[:space:]]*(sh|bash)\b' \
  --include='*.sh' --include='*.tmpl' --include='*.yml' --include='*.yaml' \
  --exclude-dir=.git . || true)
if [[ -n $unsafe ]]; then
  printf '%s' "$unsafe" >&2
  echo 'curl pipe found outside approved allowlist' >&2
  fails=$((fails + 1))
fi

((fails == 0))
```

- [ ] **Step 4: Run the mutable-action red/green check**

Run with the temporary `@v7` comment present:

```bash
bash tests/ci/check-static.sh
```

Expected: FAIL with `GitHub Action references must use full commit SHAs`.

Restore the workflow, pin its existing checkout references temporarily to the approved v7 SHA, then rerun:

```bash
bash tests/ci/check-static.sh
```

Expected: PASS.

- [ ] **Step 5: Commit static checks**

```bash
git add tests/ci/install-linux-tools.sh tests/ci/check-static.sh .github/workflows/ci.yml
git commit -m "refactor(ci): extract static policy checks"
```

---

### Task 6: Extract single-pass template rendering and rendered-file lint

**Files:**
- Create: `tests/ci/render-and-lint.sh`

**Interfaces:**
- Consumes: initialized chezmoi config path in `CHEZMOI_CONFIG_FILE`, plus chezmoi, ShellCheck, yamllint, Taplo, and Python
- Produces: validated rendered shell/YAML/TOML/JSON files in an automatically removed staging directory

- [ ] **Step 1: Write a temporary invalid rendered-JSON fixture**

Create an untracked fixture under a tracked test path, then add it to the render inventory during the initial red run:

```bash
mkdir -p tests/fixtures/template-smoke
printf '{{ "{" }}\n' >tests/fixtures/template-smoke/invalid.json.tmpl
```

Expected after script implementation: rendered JSON validation reports this fixture as invalid. Remove the fixture after proving red behavior.

- [ ] **Step 2: Implement `tests/ci/render-and-lint.sh`**

Use a single staging directory and one inventory loop. The core structure must be:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
config=${CHEZMOI_CONFIG_FILE:?CHEZMOI_CONFIG_FILE must name an initialized config}
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT

is_init_only() {
  case "$1" in
    ./.chezmoi.toml.tmpl|./.chezmoiexternal.toml.tmpl) return 0 ;;
    ./.chezmoitemplates/*) return 0 ;; # caller-context partials have focused tests
    *) return 1 ;;
  esac
}

fails=0
while IFS= read -r template; do
  if is_init_only "$template"; then
    printf 'SKIP %s (init-only)\n' "$template"
    continue
  fi
  relative=${template#./}
  output="$staging/${relative%.tmpl}"
  mkdir -p "$(dirname "$output")"
  if ! chezmoi execute-template --source "$repo_root" --config "$config" \
      <"$template" >"$output"; then
    printf 'FAIL %s\n' "$template" >&2
    fails=$((fails + 1))
    continue
  fi
  [[ -s "$output" ]] || { rm -f "$output"; continue; }
  if [[ $template == *.sh.tmpl ]] && [[ $(head -n1 "$output") != '#!'* ]]; then
    printf 'FAIL %s (missing first-line shebang)\n' "$template" >&2
    fails=$((fails + 1))
  fi
done < <(find . -type f -name '*.tmpl' -not -path './.git/*' -not -path './.worktrees/*' | sort)

mapfile -d '' rendered_shell < <(find "$staging" -type f -name '*.sh' -print0)
((${#rendered_shell[@]} == 0)) || shellcheck -e SC1091 "${rendered_shell[@]}"
mapfile -d '' rendered_yaml < <(find "$staging" -type f \( -name '*.yml' -o -name '*.yaml' \) -print0)
yaml_config='{extends: relaxed, rules: {line-length: disable, trailing-spaces: disable, empty-lines: disable, document-start: disable, comments: disable, truthy: disable}}'
((${#rendered_yaml[@]} == 0)) || yamllint -d "$yaml_config" "${rendered_yaml[@]}"
mapfile -d '' rendered_toml < <(find "$staging" -type f -name '*.toml' -print0)
((${#rendered_toml[@]} == 0)) || taplo lint --no-schema "${rendered_toml[@]}"
python3 - "$staging" <<'PY'
import json, sys
from pathlib import Path
for path in Path(sys.argv[1]).rglob("*.json"):
    json.loads(path.read_text())
PY

((fails == 0))
```

The three explicit skip classes are the complete exclusion list. Document that `.chezmoitemplates/` contains caller-context partials covered by focused repository tests.

- [ ] **Step 3: Prove invalid JSON fails, then remove the fixture**

Initialize the test config and run:

```bash
config="$HOME/.config/chezmoi-ci/config.toml"
mkdir -p "$(dirname "$config")"
CHEZMOI_ROLE=ephemeral,headless chezmoi init \
  --source="$PWD" --config="$config" --apply=false
CHEZMOI_CONFIG_FILE="$config" bash tests/ci/render-and-lint.sh
rm -rf tests/fixtures/template-smoke
CHEZMOI_CONFIG_FILE="$config" bash tests/ci/render-and-lint.sh
```

Expected first render run: FAIL at JSON parsing. Expected second render run after fixture removal: PASS.

- [ ] **Step 4: Commit template smoke extraction**

```bash
git add tests/ci/render-and-lint.sh
git commit -m "refactor(ci): centralize rendered template validation"
```

---

### Task 7: Add focused native Windows PowerShell validation

**Files:**
- Create: `tests/ci/check-powershell.ps1`

**Interfaces:**
- Consumes: repository root, chezmoi on `PATH`, and an initialized Windows `CHEZMOI_CONFIG_FILE`
- Produces: parser errors grouped by static or rendered `.ps1` file; exits 1 if any parse error occurs

- [ ] **Step 1: Implement static and rendered parsing**

Create `tests/ci/check-powershell.ps1`:

```powershell
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$Config = $env:CHEZMOI_CONFIG_FILE
if (-not $Config) { throw 'CHEZMOI_CONFIG_FILE must name an initialized config' }
$Stage = Join-Path ([System.IO.Path]::GetTempPath()) "chezmoi-pwsh-$PID"
New-Item -ItemType Directory -Force -Path $Stage | Out-Null
$Failures = [System.Collections.Generic.List[string]]::new()

function Test-PowerShellFile([string]$Path) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $Path, [ref]$tokens, [ref]$errors
    ) | Out-Null
    foreach ($error in $errors) {
        $Failures.Add("${Path}:$($error.Extent.StartLineNumber): $($error.Message)")
    }
}

try {
    git -C $RepoRoot ls-files '*.ps1' |
        Where-Object { $_ } |
        ForEach-Object { Test-PowerShellFile (Join-Path $RepoRoot $_) }

    git -C $RepoRoot ls-files '*.ps1.tmpl' |
        Where-Object { $_ } |
        ForEach-Object {
            $Source = Join-Path $RepoRoot $_
            $SafeName = (($_ -replace '[\\/]', '__') -replace '\.tmpl$', '')
            $Output = Join-Path $Stage $SafeName
            Get-Content -Raw $Source |
                chezmoi execute-template --source $RepoRoot --config $Config |
                Set-Content -Encoding utf8NoBOM $Output
            if ((Get-Item $Output).Length -gt 0) { Test-PowerShellFile $Output }
        }

    if ($Failures.Count -gt 0) {
        $Failures | ForEach-Object { Write-Error $_ }
        exit 1
    }
    Write-Host 'PowerShell static and rendered syntax ok'
}
finally {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $Stage
}
```

- [ ] **Step 2: Prove parser errors are reported**

Temporarily add `tests/fixtures/invalid.ps1` containing:

```powershell
if (
```

Run on Windows:

```powershell
pwsh -NoProfile -File tests/ci/check-powershell.ps1
```

Expected: FAIL naming `tests/fixtures/invalid.ps1` and its parser error. Delete the fixture and rerun; expected PASS.

- [ ] **Step 3: Commit Windows validation**

```bash
git add tests/ci/check-powershell.ps1
git commit -m "test(ci): add native PowerShell syntax validation"
```

---

### Task 8: Refactor the workflow and pin dependencies

**Files:**
- Modify: `.github/workflows/ci.yml`
- Create: `.github/dependabot.yml`

**Interfaces:**
- Consumes: scripts created in Tasks 3, 5, 6, and 7
- Produces: five required CI jobs with immutable actions, explicit tools, cancellation, and timeouts

- [ ] **Step 1: Confirm current third-party documentation and release assets**

Before editing, fetch current documentation for GitHub Actions workflow concurrency, checkout, and every changed third-party install surface. Confirm these approved values or deliberately update the plan and documentation together:

```text
actions/checkout v7: 3d3c42e5aac5ba805825da76410c181273ba90b1
actionlint: 1.7.12
chezmoi: 2.71.1
ShellCheck: 0.11.0
Taplo: 0.10.0
yamllint: 1.38.0
```

- [ ] **Step 2: Add workflow-wide controls and version variables**

Start `.github/workflows/ci.yml` with:

```yaml
name: ci

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

env:
  ACTIONLINT_VERSION: 1.7.12
  CHEZMOI_VERSION: 2.71.1
  SHELLCHECK_VERSION: 0.11.0
  TAPLO_VERSION: 0.10.0
  YAMLLINT_VERSION: 1.38.0
```

- [ ] **Step 3: Define the five jobs**

Every job must use checkout as:

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.0
```

Use these exact job boundaries and timeouts:

```yaml
jobs:
  policy-lint:
    runs-on: ubuntu-24.04
    timeout-minutes: 10

  repository-tests:
    runs-on: ubuntu-24.04
    timeout-minutes: 15

  template-smoke:
    runs-on: ubuntu-24.04
    timeout-minutes: 15
    env:
      CHEZMOI_ROLE: ephemeral,headless

  apply-dry-run:
    timeout-minutes: 15
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-24.04, macos-15]
    runs-on: ${{ matrix.os }}
    env:
      CHEZMOI_ROLE: ephemeral,headless

  powershell-windows:
    runs-on: windows-2025
    timeout-minutes: 15
    env:
      CHEZMOI_ROLE: ephemeral,headless
```

- [ ] **Step 4: Install pinned tools and invoke repository scripts**

For GitHub release binaries, use versioned release URLs and the release checksum manifest when one is published. The policy job installs exact tools and runs static checks:

```yaml
- name: Install pinned lint tools
  run: bash tests/ci/install-linux-tools.sh lint
- name: Run static policy and lint
  run: bash tests/ci/check-static.sh
```

The repository test job installs chezmoi 2.71.1, asserts runtime contracts, and runs:

```yaml
- name: Install pinned chezmoi
  run: bash tests/ci/install-linux-tools.sh chezmoi
- name: Verify test runtimes
  run: |
    bash -c '(( BASH_VERSINFO[0] >= 4 ))'
    python3 -c 'import sys, tomllib; assert sys.version_info >= (3, 11)'
    jq --version
- name: Run repository tests
  run: bash tests/ci/run-chezmoi-tests.sh
```

The template job installs every Linux tool once, initializes the config once, and invokes:

```yaml
- name: Install pinned tools
  run: bash tests/ci/install-linux-tools.sh all
- name: Initialize ephemeral config
  shell: bash
  run: |
    config="${RUNNER_TEMP}/chezmoi-config.toml"
    chezmoi init --source="$GITHUB_WORKSPACE" --config="$config" --apply=false
- name: Render and lint templates
  env:
    CHEZMOI_CONFIG_FILE: ${{ runner.temp }}/chezmoi-config.toml
  run: bash tests/ci/render-and-lint.sh
```

In the dry-run matrix, install chezmoi on Linux through `install-linux-tools.sh`. On macOS, install the release artifact with architecture-specific verification:

```yaml
- name: Install pinned chezmoi on Linux
  if: runner.os == 'Linux'
  run: bash tests/ci/install-linux-tools.sh chezmoi
- name: Install pinned chezmoi on macOS
  if: runner.os == 'macOS'
  shell: bash
  run: |
    case "$(uname -m)" in
      arm64) arch=arm64; sha=9fad1201c328428634b8a086f767df0dfe6dd3ea1128a2a7c45bc0b16641e294 ;;
      x86_64) arch=amd64; sha=1551f07cab00441540a12e663ffbf4645664319c0f91d30a5f9a255470b561cc ;;
      *) echo "unsupported macOS architecture: $(uname -m)" >&2; exit 1 ;;
    esac
    mkdir -p "$HOME/.local/bin"
    asset="chezmoi_2.71.1_darwin_${arch}.tar.gz"
    curl -fsSLo "$RUNNER_TEMP/$asset" \
      "https://github.com/twpayne/chezmoi/releases/download/v2.71.1/$asset"
    printf '%s  %s\n' "$sha" "$RUNNER_TEMP/$asset" | shasum -a 256 -c -
    tar -xzf "$RUNNER_TEMP/$asset" -C "$RUNNER_TEMP" chezmoi
    install -m 0755 "$RUNNER_TEMP/chezmoi" "$HOME/.local/bin/chezmoi"
```

After initialization, the dry-run step executes:

```bash
config="${RUNNER_TEMP}/chezmoi-config.toml"
chezmoi init --source="$GITHUB_WORKSPACE" --config="$config" --apply=false
chezmoi apply --source="$GITHUB_WORKSPACE" --config="$config" \
  --dry-run --verbose --exclude=externals
```

On the macOS matrix leg, retain plist coverage with tracked files only:

```yaml
- name: Lint property lists
  if: runner.os == 'macOS'
  shell: bash
  run: |
    failures=0
    while IFS= read -r plist; do
      plutil -lint "$plist" || failures=$((failures + 1))
    done < <(git ls-files '*.plist')
    ((failures == 0))
```

The Windows job installs and verifies the exact ZIP before initialization:

```yaml
- name: Install pinned chezmoi
  shell: pwsh
  run: |
    $asset = 'chezmoi_2.71.1_windows_amd64.zip'
    $zip = Join-Path $env:RUNNER_TEMP $asset
    Invoke-WebRequest \
      "https://github.com/twpayne/chezmoi/releases/download/v2.71.1/$asset" \
      -OutFile $zip
    $actual = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLowerInvariant()
    if ($actual -ne 'efdb5ae7e8e455e8f7c1b3d7d97beb7e946d9234f58d73945b78aaf6a5e92de6') {
      throw "chezmoi checksum mismatch: $actual"
    }
    Expand-Archive $zip -DestinationPath "$env:RUNNER_TEMP/chezmoi"
    Add-Content $env:GITHUB_PATH "$env:RUNNER_TEMP/chezmoi"
- name: Initialize Windows ephemeral config
  shell: pwsh
  run: |
    $config = Join-Path $env:RUNNER_TEMP 'chezmoi-config.toml'
    chezmoi init --source=$env:GITHUB_WORKSPACE --config=$config --apply=false
- name: Parse static and rendered PowerShell
  shell: pwsh
  env:
    CHEZMOI_CONFIG_FILE: ${{ runner.temp }}/chezmoi-config.toml
  run: pwsh -NoProfile -File tests/ci/check-powershell.ps1
```

- [ ] **Step 5: Add grouped GitHub Actions Dependabot updates**

Create `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
    groups:
      github-actions:
        patterns:
          - '*'
```

- [ ] **Step 6: Validate the workflow and policy locally**

Run:

```bash
actionlint .github/workflows/ci.yml
bash tests/ci/check-static.sh
grep -nE 'uses:[[:space:]]+[^[:space:]#]+@(main|master|latest|v[0-9]+)' .github/workflows/ci.yml && exit 1 || true
```

Expected: all commands pass and no mutable action reference is printed.

- [ ] **Step 7: Commit the workflow**

```bash
git add .github/workflows/ci.yml .github/dependabot.yml
git commit -m "ci: modernize checks and run repository tests"
```

---

### Task 9: Update the testing guide

**Files:**
- Modify: `docs/testing.md`

**Interfaces:**
- Consumes: final commands and runtime contracts from Tasks 3 through 8
- Produces: one accurate operator and contributor guide linked from `README.md`

- [ ] **Step 1: Replace the stale CI inventory**

Document exactly these jobs and platforms:

```markdown
- `policy-lint` on Ubuntu 24.04
- `repository-tests` on Ubuntu 24.04
- `template-smoke` on Ubuntu 24.04
- `apply-dry-run` on Ubuntu 24.04 and macOS 15, with tracked plist lint on macOS
- `powershell-windows` on Windows 2025
```

State that repository tests require Bash 4+, Python 3.11+, chezmoi 2.71.1, and jq.

- [ ] **Step 2: Document local commands**

Include these copy-pasteable commands:

```bash
bash tests/ci/check-static.sh
bash tests/ci/run-chezmoi-tests.sh
bash tests/ci/run-chezmoi-tests.sh tests/chezmoi/test-role-routing.sh
CHEZMOI_CONFIG_FILE="$HOME/.config/chezmoi-ci/config.toml" bash tests/ci/render-and-lint.sh
```

Include the Windows command:

```powershell
pwsh -NoProfile -File tests/ci/check-powershell.ps1
```

- [ ] **Step 3: Document exclusions and update procedure**

Explain that `.chezmoi.toml.tmpl` and `.chezmoiexternal.toml.tmpl` are init-only because they use initialization context unavailable to `execute-template`. List any caller-context partial exclusions added during Task 6.

Document the update sequence:

1. Update the version variable.
2. Update each versioned download URL.
3. Update or revalidate checksums.
4. Update action SHA comments.
5. Run static, template, repository, and workflow checks.

- [ ] **Step 4: Verify documentation references real files and job names**

Run:

```bash
for path in \
  tests/ci/check-static.sh \
  tests/ci/run-chezmoi-tests.sh \
  tests/ci/render-and-lint.sh \
  tests/ci/check-powershell.ps1; do test -f "$path"; done
for job in policy-lint repository-tests template-smoke apply-dry-run powershell-windows; do
  grep -Fq "$job" docs/testing.md
done
```

Expected: every file exists and every job is documented.

- [ ] **Step 5: Commit documentation**

```bash
git add docs/testing.md
git commit -m "docs(ci): document tests and dependency updates"
```

---

### Task 10: End-to-end verification and review

**Files:**
- Verify all files changed by Tasks 2 through 9

**Interfaces:**
- Consumes: complete implementation
- Produces: fresh evidence that the suite, workflow, rendered templates, dry-runs, and documentation satisfy the approved design

- [ ] **Step 1: Verify branch and diff scope**

Run:

```bash
git status --short --branch
git diff --check main...HEAD
git diff --stat main...HEAD
git diff --name-status main...HEAD
```

Expected: clean worktree; only CI, tests, Dependabot, and testing documentation changes beyond the prerequisite theme branch.

- [ ] **Step 2: Run all host-compatible checks**

Run:

```bash
bash tests/ci/test-run-chezmoi-tests.sh
bash tests/ci/run-chezmoi-tests.sh
bash tests/ci/check-static.sh
CHEZMOI_CONFIG_FILE="$HOME/.config/chezmoi-ci/config.toml" bash tests/ci/render-and-lint.sh
```

Expected: zero failures. If the host lacks Bash 4+ or Python 3.11+, select the declared binaries first rather than skipping repository tests.

- [ ] **Step 3: Run dry-runs on available Unix platforms**

Run on the current Unix host:

```bash
config="$HOME/.config/chezmoi-ci/config.toml"
CHEZMOI_ROLE=ephemeral,headless chezmoi init \
  --source="$PWD" --config="$config" --apply=false
chezmoi apply --source="$PWD" --config="$config" \
  --dry-run --verbose --exclude=externals
```

Expected: successful dry-run. GitHub Actions supplies authoritative Ubuntu and macOS matrix evidence.

- [ ] **Step 4: Validate Windows through GitHub Actions**

Push the branch and inspect the `powershell-windows` job. Expected: all static and rendered PowerShell parses pass on `windows-2025`. Do not claim native Windows coverage from a Unix-only local run.

- [ ] **Step 5: Inspect the complete GitHub Actions run**

Run:

```bash
gh run list --branch "$(git branch --show-current)" --workflow ci.yml --limit 1
gh run watch "$(gh run list --branch "$(git branch --show-current)" --workflow ci.yml --limit 1 --json databaseId --jq '.[0].databaseId')" --exit-status
```

Expected: policy/lint, repository tests, template smoke, both dry-run matrix legs, and focused Windows all conclude `success`.

- [ ] **Step 6: Review maintainability and acceptance criteria**

Confirm from the final diff:

- Every maintained `tests/chezmoi/test-*.sh` is discovered by the runner.
- The runner self-test proves multiple failures are aggregated.
- Template rendering happens once in `template-smoke`.
- Every `uses:` reference is a 40-character SHA.
- Every job has `timeout-minutes`.
- Workflow permissions remain read-only.
- Dependabot updates only GitHub Actions.
- No cache, sharding, artifact handoff, or reusable workflow was added.
- `docs/testing.md` names every real command and job.

- [ ] **Step 7: Commit any verification-only corrections separately**

If verification exposed a correction, apply only that correction, rerun the directly affected check and the full relevant suite, then commit with a scoped Conventional Commit message. If no correction was needed, do not create an empty commit.
