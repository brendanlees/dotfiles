#!/bin/sh
set -e

CHEZMOI_BIN_DIR="$HOME/.local/bin"

mkdir -p "$CHEZMOI_BIN_DIR"

if command -v curl >/dev/null 2>&1; then
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$CHEZMOI_BIN_DIR"
elif command -v wget >/dev/null 2>&1; then
  sh -c "$(wget -qO- get.chezmoi.io)" -- -b "$CHEZMOI_BIN_DIR"
else
  echo "error: curl or wget required" >&2
  exit 1
fi

export PATH="$CHEZMOI_BIN_DIR:$PATH"
chezmoi init --apply brendanlees
