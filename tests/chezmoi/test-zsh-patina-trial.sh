#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

defaults="$repo_root/.chezmoidata/defaults.yml"
externals="$repo_root/.chezmoiexternal.toml.tmpl"
ignore="$repo_root/.chezmoiignore"
zshrc="$repo_root/dot_zshrc.tmpl"
config="$repo_root/dot_config/zsh-patina/config.toml.tmpl"

grep -Fqx 'zsh_patina_trial: false' "$defaults"
grep -Fqx 'zsh_patina_theme: "patina"' "$defaults"

grep -Fq 'zsh-patina-v1.8.0-aarch64-apple-darwin.tar.gz' "$externals"
grep -Fq 'checksum.sha256 = "b1b7afb9e7c8840f269e9f342ffce3c2b90faa221f288484654a80f2a244b296"' "$externals"
grep -Fq 'zsh-patina-v1.8.0-x86_64-apple-darwin.tar.gz' "$externals"
grep -Fq 'checksum.sha256 = "5ff05eaaa9d4dcdb14d145d1d36f290917d087b0942fa707be6a9686e353f3b9"' "$externals"
grep -Fq 'executable = true' "$externals"

if grep -Eq '_cached_eval[^\n]*zsh-patina|zsh-patina[^\n]*_cached_eval' "$zshrc"; then
  echo 'zsh-patina activation must not be cached' >&2
  exit 1
fi

chezmoi execute-template \
  --source "$repo_root" \
  --override-data '{"zsh_patina_trial":false,"zsh_patina_theme":"patina"}' \
  --file "$zshrc" \
  > "$tmpdir/zshrc-disabled"

disabled_last=$(grep -Ev '^[[:space:]]*(#|$)' "$tmpdir/zshrc-disabled" | tail -1)
# shellcheck disable=SC2016
expected_disabled='source "$XDG_DATA_HOME/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"'
if [[ "$disabled_last" != "$expected_disabled" ]]; then
  echo "disabled zshrc must end with incumbent highlighter, got: $disabled_last" >&2
  exit 1
fi
if grep -Fq 'zsh-patina" activate' "$tmpdir/zshrc-disabled"; then
  echo 'disabled zshrc unexpectedly activates zsh-patina' >&2
  exit 1
fi

if [[ $(uname -s) == Darwin ]]; then
  arch=$(uname -m)
  case "$arch" in
    arm64)
      expected_asset='zsh-patina-v1.8.0-aarch64-apple-darwin.tar.gz'
      ;;
    x86_64)
      expected_asset='zsh-patina-v1.8.0-x86_64-apple-darwin.tar.gz'
      ;;
    *)
      echo "unsupported macOS architecture in test: $arch" >&2
      exit 1
      ;;
  esac

  chezmoi execute-template \
    --source "$repo_root" \
    --override-data '{"zsh_patina_trial":true,"zsh_patina_theme":"patina"}' \
    --file "$externals" \
    > "$tmpdir/externals-enabled"
  grep -Fq "$expected_asset" "$tmpdir/externals-enabled"

  chezmoi execute-template \
    --source "$repo_root" \
    --override-data '{"zsh_patina_trial":true,"zsh_patina_theme":"patina"}' \
    --file "$ignore" \
    > "$tmpdir/ignore-enabled"
  grep -Fqx '!.local/bin/zsh-patina' "$tmpdir/ignore-enabled"

  chezmoi execute-template \
    --source "$repo_root" \
    --override-data '{"zsh_patina_trial":true,"zsh_patina_theme":"patina"}' \
    --file "$zshrc" \
    > "$tmpdir/zshrc-enabled"

  enabled_last=$(grep -Ev '^[[:space:]]*(#|$)' "$tmpdir/zshrc-enabled" | tail -1)
  # shellcheck disable=SC2016
  expected_enabled='eval "$(zsh-patina activate)"'
  if [[ "$enabled_last" != "$expected_enabled" ]]; then
    echo "enabled zshrc must end with zsh-patina activation, got: $enabled_last" >&2
    exit 1
  fi
  # shellcheck disable=SC2016
  if grep -Fq 'source "$XDG_DATA_HOME/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"' "$tmpdir/zshrc-enabled"; then
    echo 'enabled zshrc unexpectedly sources incumbent highlighter' >&2
    exit 1
  fi
fi

chezmoi execute-template \
  --source "$repo_root" \
  --override-data '{"zsh_patina_trial":true,"zsh_patina_theme":"tokyonight"}' \
  --file "$config" \
  > "$tmpdir/config"
grep -Fqx 'theme = "tokyonight"' "$tmpdir/config"
grep -Fqx 'dynamic = true' "$tmpdir/config"

echo 'zsh-patina trial templates ok'
