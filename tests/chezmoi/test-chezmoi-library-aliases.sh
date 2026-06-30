#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$ROOT/dot_config/zsh/exact_aliases.d/chezmoi.zsh.tmpl"

zsh -fc 'source "'$HELPER'"; for name in cz-lib-apply cz-lib-readd; do whence -w "$name" >/dev/null || { echo "missing alias: $name" >&2; exit 1; }; done'
