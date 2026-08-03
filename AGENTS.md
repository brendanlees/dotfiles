# Project agent instructions

- When changing behavior or configuration, inspect and update the related tests in `tests/`.
- After the final edit, run `bash tests/ci/check-static.sh` and `bash tests/ci/run-chezmoi-tests.sh`.
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
