# testing

## automated ci

Every push to `main` and every pull request runs `.github/workflows/ci.yml`.
Superseded runs on the same branch or pull request are cancelled automatically.
The workflow has read-only repository permissions and an explicit timeout on every job.

- **`policy-lint` on Ubuntu 24.04** - validates the workflow with actionlint, runs ShellCheck over tracked shell files, lints tracked YAML and TOML, parses strict JSON, and enforces banned-pattern and immutable-action policies.
- **`repository-tests` on Ubuntu 24.04** - runs every maintained `tests/chezmoi/test-*.sh` through the aggregate runner.
- **`template-smoke` on Ubuntu 24.04** - renders the supported template inventory once under the `ephemeral,headless` role, then validates rendered shell, YAML, TOML, and strict JSON.
- **`apply-dry-run` on Ubuntu 24.04 and macOS 15** - initializes an isolated `ephemeral,headless` config and runs `chezmoi apply --dry-run --exclude=externals`. The macOS leg also lints every tracked plist with `plutil`.
- **`powershell-windows` on Windows 2025** - parses tracked and rendered PowerShell, then executes the synthetic private-agent-skills junction and lifecycle contract.

The repository test runtime contract is Bash 4 or newer, Python 3.11 or newer, chezmoi 2.71.1, jq, and zsh. CI tools are pinned to actionlint 1.7.12, ShellCheck 0.11.0, Taplo 0.10.0, and yamllint 1.38.0.

## local checks

Put the required tools on `PATH` before running these commands. On macOS, use a modern Homebrew or mise Bash and Python rather than the system Bash 3 or Python 3.9.

Run static policy and lint checks:

```sh
bash tests/ci/check-static.sh
```

Run the complete repository suite:

```sh
bash tests/ci/run-chezmoi-tests.sh
```

Run one or more focused tests:

```sh
bash tests/ci/run-chezmoi-tests.sh tests/chezmoi/test-role-routing.sh
```

Initialize a non-secret render config and validate the supported template inventory:

```sh
config="$HOME/.config/chezmoi-ci/config.toml"
mkdir -p "$(dirname "$config")"
CHEZMOI_ROLE=ephemeral,headless chezmoi init \
  --source="$PWD" \
  --config="$config" \
  --apply=false
CHEZMOI_CONFIG_FILE="$config" bash tests/ci/render-and-lint.sh
```

The renderer removes directories containing a `bw` executable from the template lookup path. This keeps local rendering aligned with ephemeral CI and prevents accidental secret-provider access.

On Windows, initialize the same role and run:

```powershell
$env:CHEZMOI_ROLE = 'ephemeral,headless'
$config = Join-Path $env:TEMP 'chezmoi-ci.toml'
chezmoi init --source=$PWD --config=$config --apply=false
$env:CHEZMOI_CONFIG_FILE = $config
pwsh -NoProfile -File tests/ci/check-powershell.ps1
pwsh -NoProfile -File tests/chezmoi/test-private-agent-skills-windows.ps1
```

## validation boundaries

Template smoke skips these caller-dependent inputs:

- `.chezmoi.toml.tmpl` and `.chezmoiexternal.toml.tmpl` require chezmoi initialization context such as `stdinIsATTY` and prompt helpers.
- `.chezmoitemplates/` contains partials rendered by callers. Focused repository tests cover those contracts.

Static Taplo excludes `.chezmoitemplates/alacritty.toml` because it is a Go-template partial despite its `.toml` suffix.

Strict JSON parsing excludes Zed's JSONC-compatible files:

- `dot_config/zed/keymap.json`
- `dot_config/zed/tasks.json`
- Rendered `dot_config/zed/private_settings.json.tmpl`

These files intentionally contain comments and trailing commas accepted by Zed. Other tracked and rendered `.json` files must parse as strict JSON.

## updating ci dependencies

Dependabot groups GitHub Actions updates weekly in `.github/dependabot.yml`. Action references remain pinned to full commit SHAs with readable version comments.

To update a pinned action or CLI:

1. Read the current upstream release and migration documentation.
2. Update the workflow version variable or action commit SHA.
3. Update every versioned release URL.
4. Recalculate and review each SHA-256 checksum.
5. Update the readable version comment for action SHAs.
6. Run static checks, repository tests, template smoke, and available platform dry-runs.
7. Confirm all five GitHub Actions jobs pass before merging.

Do not replace versioned URLs or full action SHAs with `latest`, a major-version tag, `main`, or `master`.

## apply a branch before merging

Fetch and apply a specific branch without changing the local source directory:

```sh
chezmoi init --apply --branch <branch-name> brendanlees
```

To test a remote branch on a target machine, connect over SSH and run the same command:

```sh
chezmoi init --apply --branch <branch-name> brendanlees
```

Chezmoi reinitializes from the branch. Previously cached state means `run_once` scripts only rerun when their content changes.

To force once scripts to rerun:

```sh
chezmoi state delete-bucket --bucket=scriptState
chezmoi apply
```

To return to `main`:

```sh
chezmoi init --apply brendanlees
```
