# testing

## automated ci

every push to `main` and every pull request runs `.github/workflows/ci.yml`.
superseded runs on the same branch or pull request are cancelled automatically.
the workflow has read-only repository permissions and an explicit timeout on every job.

- **`policy-lint` on Ubuntu 24.04** - validates the workflow with actionlint, then scopes ShellCheck, YAML, TOML, JSON, and policy checks to `.github/`, `home/`, `tests/`, `install.sh`, and the root skill lock. Skill assets under `agents/skills/` are scanned separately by SkillSpector when distributed.
- **`repository-tests` on Ubuntu 24.04** - runs every maintained `tests/chezmoi/test-*.sh` through the aggregate runner.
- **`template-smoke` on Ubuntu 24.04** - renders the supported template inventory once under the `ephemeral,headless` role, then validates rendered shell, YAML, TOML, and strict JSON.
- **`apply-dry-run` on Ubuntu 24.04 and macOS 15** - initializes an isolated `ephemeral,headless` config and runs `chezmoi apply --dry-run --exclude=externals`. The macOS leg also lints every tracked plist with `plutil`.
- **`powershell-windows` on Windows 2025** - parses tracked and rendered PowerShell, then executes the synthetic private-agent-skills junction and lifecycle contract.

## local checks

static policy and lint checks:

```sh
bash tests/ci/check-static.sh
```

complete repo suite:

```sh
bash tests/ci/run-chezmoi-tests.sh
```

one or more focused tests:

```sh
bash tests/ci/run-chezmoi-tests.sh tests/chezmoi/test-role-routing.sh
```

init a non-secret render config and validate the supported template inventory:

```sh
config="$HOME/.config/chezmoi-ci/config.toml"
mkdir -p "$(dirname "$config")"
CHEZMOI_ROLE=ephemeral,headless chezmoi init \
  --source="$PWD" \
  --config="$config" \
  --apply=false
CHEZMOI_CONFIG_FILE="$config" bash tests/ci/render-and-lint.sh
```

the renderer removes directories containing a `bw` executable from the template lookup path. This keeps local rendering aligned with ephemeral CI and prevents accidental secret-provider access.

on windows, initialize the same role and run:

```powershell
$env:CHEZMOI_ROLE = 'ephemeral,headless'
$config = Join-Path $env:TEMP 'chezmoi-ci.toml'
chezmoi init --source=$PWD --config=$config --apply=false
$env:CHEZMOI_CONFIG_FILE = $config
pwsh -NoProfile -File tests/ci/check-powershell.ps1
pwsh -NoProfile -File tests/chezmoi/test-private-agent-skills-windows.ps1
```
