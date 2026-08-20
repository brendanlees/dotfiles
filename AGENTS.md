# project preferences

## tests

- Before changing behavior or configuration, identify the nearest owning test in `tests/` and run it to reproduce the current behavior when practical.
- Every behavior or configuration change must either update its owning test or preserve an existing test that already covers the changed contract. State which test covers it in the final report.
- Prefer extending one existing contract test over adding another file. Add a focused regression test for user-visible bugs that lacked coverage.
- Test observable behavior, role or OS routing, destructive transitions, and regressions. Leave syntax, rendering, and broad apply coverage to the existing CI smoke jobs.
- Keep one clear test owner per contract. Avoid duplicate assertions, implementation snapshots, and low-value matrices.
- When behavior is removed or absorbed by broader coverage, remove or merge its stale tests and fixtures in the same change.
- After the final edit, run the targeted owning tests, then `bash tests/ci/check-static.sh` and `bash tests/ci/run-chezmoi-tests.sh`.
- For template changes, also reproduce the template smoke job:
  ```bash
  config_dir=$(mktemp -d)
  printf '%s\n' '[data]' 'personal = false' 'work = false' 'homelab = false' \
    'ephemeral = true' 'headless = true' 'theme = "black-metal-bathory"' \
    >"$config_dir/chezmoi.toml"
  CHEZMOI_CONFIG_FILE="$config_dir/chezmoi.toml" bash tests/ci/render-and-lint.sh
  rm -rf "$config_dir"
  ```
- Do not commit, push, or claim completion while a required check is failing. Report the exact checks run and their results.

### test validation boundaries

Template smoke skips these caller-dependent inputs:

- `home/.chezmoi.toml.tmpl` and `home/.chezmoiexternal.toml.tmpl` require chezmoi initialization context such as `stdinIsATTY` and prompt helpers.
- `home/.chezmoitemplates/` contains partials rendered by callers. Focused repository tests cover those contracts.

Static Taplo excludes `home/.chezmoitemplates/alacritty.toml` because it is a Go-template partial despite its `.toml` suffix.

Strict JSON parsing excludes Zed's JSONC-compatible files:

- `home/dot_config/zed/keymap.json`
- `home/dot_config/zed/tasks.json`
- Rendered `home/dot_config/zed/private_settings.json.tmpl`

These files intentionally contain comments and trailing commas accepted by Zed. Other tracked and rendered `.json` files must parse as strict JSON.

### updating ci dependencies

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
