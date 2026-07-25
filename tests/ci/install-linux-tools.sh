#!/usr/bin/env bash
set -euo pipefail

mode=${1:-all}
case "$mode" in
  lint | chezmoi | all) ;;
  *)
    echo "usage: $0 lint|chezmoi|all" >&2
    exit 2
    ;;
esac

[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || {
  echo 'install-linux-tools.sh requires Linux x86_64' >&2
  exit 2
}

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
  fetch \
    "https://github.com/rhysd/actionlint/releases/download/v${actionlint_version}/actionlint_${actionlint_version}_linux_amd64.tar.gz" \
    "$work/actionlint.tar.gz"
  verify 8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8 \
    "$work/actionlint.tar.gz"
  tar -xzf "$work/actionlint.tar.gz" -C "$work" actionlint
  install -m 0755 "$work/actionlint" "$bin_dir/actionlint"

  fetch \
    "https://github.com/koalaman/shellcheck/releases/download/v${shellcheck_version}/shellcheck-v${shellcheck_version}.linux.x86_64.tar.xz" \
    "$work/shellcheck.tar.xz"
  verify 8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198 \
    "$work/shellcheck.tar.xz"
  tar -xJf "$work/shellcheck.tar.xz" -C "$work"
  install -m 0755 "$work/shellcheck-v${shellcheck_version}/shellcheck" \
    "$bin_dir/shellcheck"

  fetch \
    "https://github.com/tamasfe/taplo/releases/download/${taplo_version}/taplo-linux-x86_64.gz" \
    "$work/taplo.gz"
  verify 8fe196b894ccf9072f98d4e1013a180306e17d244830b03986ee5e8eabeb6156 \
    "$work/taplo.gz"
  gzip -dc "$work/taplo.gz" >"$bin_dir/taplo"
  chmod 0755 "$bin_dir/taplo"

  PIPX_HOME="$HOME/.local/pipx" \
    PIPX_BIN_DIR="$bin_dir" \
    pipx install --force "yamllint==${yamllint_version}"
}

install_chezmoi() {
  fetch \
    "https://github.com/twpayne/chezmoi/releases/download/v${chezmoi_version}/chezmoi_${chezmoi_version}_linux_amd64.tar.gz" \
    "$work/chezmoi.tar.gz"
  verify e1fb16c962644d57f4d451c324aa86163d00faf5d035500f41fb48943a66dfed \
    "$work/chezmoi.tar.gz"
  tar -xzf "$work/chezmoi.tar.gz" -C "$work" chezmoi
  install -m 0755 "$work/chezmoi" "$bin_dir/chezmoi"
}

case "$mode" in
  lint) install_lint ;;
  chezmoi) install_chezmoi ;;
  all)
    install_lint
    install_chezmoi
    ;;
esac
