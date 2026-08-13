# Project agent instructions

- Before changing behavior or configuration, identify the nearest owning test in `tests/` and run it to reproduce the current behavior when practical.
- Every behavior or configuration change must either update its owning test or preserve an existing test that already covers the changed contract. State which test covers it in the final report.
- Prefer extending one existing contract test over adding another file. Add a focused regression test for user-visible bugs that lacked coverage.
- Test observable behavior, role or OS routing, destructive transitions, and regressions. Leave syntax, rendering, and broad apply coverage to the existing CI smoke jobs.
- Keep one clear test owner per contract. Avoid duplicate assertions, implementation snapshots, and low-value matrices.
- When behavior is removed or absorbed by broader coverage, remove or merge its stale tests and fixtures in the same change.
- After the final edit, run the targeted owning tests, then `bash tests/ci/check-static.sh` and `bash tests/ci/run-chezmoi-tests.sh`.
- Run repository tests through Crabbox on personal machines or whenever the `crabbox` CLI is available. Inspect the repository and Crabbox configuration first, and do not expose secrets or start paid infrastructure without explicit approval.
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
