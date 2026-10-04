#!/bin/sh
set -eu

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

confirm_remote_script() {
  if [ "${CHEZMOI_ALLOW_REMOTE_SCRIPTS:-}" = 1 ]; then
    printf 'CHEZMOI_ALLOW_REMOTE_SCRIPTS=1 set; allowing %s installer.\n' "$1"
    return 0
  fi
  printf 'About to run remote installer: %s\nSource: %s\nInspect first: curl -fsSL "%s" | less\n' "$1" "$2" "$2"
  if [ ! -t 0 ]; then
    echo "Refusing to run $1 installer without confirmation; set CHEZMOI_ALLOW_REMOTE_SCRIPTS=1 for automation." >&2
    return 1
  fi
  printf 'Continue? [y/N] '
  read -r answer
  case "$answer" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

download() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$1"
  else
    echo 'error: curl or wget required' >&2
    return 1
  fi
}

os=$(uname -s)
if [ "$os" = Darwin ]; then
  # Apple's installer needs human confirmation. Never proceed with half-installed
  # tools, silently accept an Xcode licence, or change the selected Xcode.
  if ! xcode-select -p >/dev/null 2>&1 || ! xcrun --find clang >/dev/null 2>&1; then
    xcode-select --install || true
    echo 'Complete the Command Line Tools installation, then rerun install.sh.' >&2
    echo 'If Xcode is already installed, check xcode-select -p and finish its first-run setup.' >&2
    exit 1
  fi

  # Fresh shells may not yet know either standard Homebrew prefix.
  export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
  if ! command -v brew >/dev/null 2>&1; then
    url='https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh'
    confirm_remote_script Homebrew "$url"
    installer=$(download "$url")
    /bin/bash -c "$installer"
  fi
  brew_env=$(brew shellenv)
  eval "$brew_env"
  export PATH="$BIN_DIR:$PATH"
fi

# The apply hooks and shell config use this fixed path. Reuse a system/package
# manager install via a link rather than installing a second copy.
if [ ! -x "$BIN_DIR/mise" ]; then
  if [ -e "$BIN_DIR/mise" ] || [ -L "$BIN_DIR/mise" ]; then
    echo "error: $BIN_DIR/mise exists but is not executable; repair it before retrying" >&2
    exit 1
  fi
  if mise_bin=$(command -v mise); then
    ln -s "$mise_bin" "$BIN_DIR/mise"
  else
    url='https://mise.run'
    confirm_remote_script mise "$url"
    installer=$(download "$url")
    if [ "$os" = Linux ] && [ "$(uname -m)" = aarch64 ]; then
      MISE_INSTALL_PATH="$BIN_DIR/mise" MISE_INSTALL_ARCH=arm64-musl sh -c "$installer"
    else
      MISE_INSTALL_PATH="$BIN_DIR/mise" sh -c "$installer"
    fi
  fi
fi
"$BIN_DIR/mise" --version
export PATH="$BIN_DIR:${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims:$PATH"

if ! command -v chezmoi >/dev/null 2>&1; then
  installer=$(download 'https://get.chezmoi.io')
  sh -c "$installer" -- -b "$BIN_DIR"
fi

# Chezmoi owns persistent shell configuration and installs the declared tools.
chezmoi init --apply brendanlees
