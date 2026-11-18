#!/usr/bin/env bash
set -euo pipefail

# Keep the prompt on the terminal; only the secret is returned to chezmoi.
IFS= read -r -s -p 'GitHub download token (public releases, input hidden): ' token </dev/tty 2>/dev/tty
printf '\n' >/dev/tty
printf '%s' "$token"
