# testing

## automated ci

every push and pull request runs `.github/workflows/ci.yml`:

- **shellcheck** — lints all static `.sh` files and rendered `.sh.tmpl` outputs.
- **render-templates** — runs `chezmoi execute-template` across every `.tmpl` under `CHEZMOI_ROLE=ephemeral,headless` to catch missing keys and bad guards. a small skip list covers init-only templates that use `stdinIsATTY` (unavailable in `execute-template` context).
- **dry-run** — matrix on `ubuntu-latest` and `macos-latest`: `chezmoi init` then `chezmoi apply --dry-run` against a bare runner.
- **lint-configs** — yamllint (relaxed ruleset) over tracked `.yml`/`.yaml` files and `taplo` over tracked `.toml` files.
- **plist-lint** — `plutil -lint` over tracked `.plist` files.

ci runs as the `ephemeral,headless` role so templates resolve without personal keys or interactive prompts. see [scoping](scoping.md) for how roles are defined.

## apply a branch before merging

fetch and apply a specific branch without changing the local source directory:

```sh
chezmoi init --apply --branch <branch-name> brendanlees
```

to test a remote branch on a target machine, ssh in and run:

```sh
chezmoi init --apply --branch <branch-name> brendanlees
```

chezmoi will re-initialise from the branch. previously cached state means `run_once` scripts
will only re-run if their content has changed.

to force re-run of once scripts (e.g. to re-test cleanup):

```sh
chezmoi state delete-bucket --bucket=scriptState
chezmoi apply
```

to return to tracking `main`:

```sh
chezmoi init --apply brendanlees
```
