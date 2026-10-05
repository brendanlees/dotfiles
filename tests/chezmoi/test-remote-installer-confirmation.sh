#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source_root="$repo_root/home"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fake_bin="$tmp/bin"
fake_home="$tmp/home"
mkdir -p "$fake_bin" "$fake_home"

cat > "$fake_bin/curl" <<'CURL'
#!/usr/bin/env bash
set -euo pipefail
echo "curl-called $*" >> "${REMOTE_LOG:?}"
[ "${REMOTE_DOWNLOAD_FAIL:-0}" = 0 ] || exit 22
if [[ "$*" == *herdr.dev/install.sh* ]]; then
  [[ "$3" == -o ]]
  cat >"$4" <<'HERDR'
#!/bin/sh
mkdir -p "$HERDR_INSTALL_DIR"
printf '#!/bin/sh\nexit 0\n' >"$HERDR_INSTALL_DIR/herdr"
chmod +x "$HERDR_INSTALL_DIR/herdr"
HERDR
else
  printf '#!/usr/bin/env sh\necho remote-script-body\n'
fi
CURL
chmod +x "$fake_bin/curl"

cat > "$fake_bin/uname" <<'UNAME'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  -s) printf 'Linux\n' ;;
  -m) printf 'aarch64\n' ;;
  *) exit 1 ;;
esac
UNAME
chmod +x "$fake_bin/uname"

# Simulate another user's mise inherited through PATH. The installer must still
# install into the current HOME when its expected binary is absent.
cat > "$fake_bin/mise" <<'MISE'
#!/usr/bin/env bash
exit 0
MISE
chmod +x "$fake_bin/mise"

cat > "$fake_bin/sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "sh-called $*" >> "${REMOTE_LOG:?}"
echo "mise-install-arch ${MISE_INSTALL_ARCH:-}" >> "${REMOTE_LOG:?}"
if (( $# )); then
  /bin/sh "$@"
else
  cat >/dev/null
fi
SH
chmod +x "$fake_bin/sh"

render_mise="$tmp/mise.sh"
CHEZMOI_ROLE=ephemeral,headless chezmoi execute-template --source "$repo_root" \
  < "$source_root/.chezmoiscripts/run_once_install_mise.sh.tmpl" > "$render_mise"
chmod +x "$render_mise"

no_confirm_log="$tmp/no-confirm.log"
no_confirm_out="$tmp/no-confirm.out"
no_confirm_err="$tmp/no-confirm.err"
: > "$no_confirm_log"
if REMOTE_LOG="$no_confirm_log" PATH="$fake_bin:/usr/bin:/bin" HOME="$fake_home" \
  "$render_mise" >"$no_confirm_out" 2>"$no_confirm_err"; then
  echo "expected mise installer to refuse without confirmation"
  exit 1
fi

if [[ -s "$no_confirm_log" ]]; then
  echo "expected no curl/sh calls without confirmation"
  cat "$no_confirm_log"
  exit 1
fi

grep -Fq "https://mise.run" "$no_confirm_out"
grep -Fq 'curl -fsSL "https://mise.run" | less' "$no_confirm_out"
grep -Fq "Refusing to run mise installer without confirmation" "$no_confirm_err"

allow_log="$tmp/allow.log"
allow_out="$tmp/allow.out"
allow_err="$tmp/allow.err"
: > "$allow_log"
REMOTE_LOG="$allow_log" PATH="$fake_bin:/usr/bin:/bin" HOME="$fake_home" CHEZMOI_ALLOW_REMOTE_SCRIPTS=1 \
  "$render_mise" >"$allow_out" 2>"$allow_err"

grep -Fq "CHEZMOI_ALLOW_REMOTE_SCRIPTS=1 set; allowing mise installer." "$allow_out"
grep -Fq "curl-called https://mise.run" "$allow_log"
grep -Fq "sh-called" "$allow_log"
grep -Fq "mise-install-arch arm64-musl" "$allow_log"

# Herdr uses the same consent boundary, installs once, and precedes its plugins.
herdr_template="$source_root/.chezmoiscripts/darwin/run_after_02-install-herdr.sh.tmpl"
herdr_script="$tmp/herdr.sh"
chezmoi execute-template --source "$repo_root" \
  --override-data '{"personal":true,"chezmoi":{"os":"darwin"}}' \
  <"$herdr_template" >"$herdr_script"
run_herdr_installer() {
  REMOTE_LOG="$tmp/herdr.log" PATH="$fake_bin:/usr/bin:/bin" HOME="$fake_home" \
    bash "$herdr_script" </dev/null
}
: >"$tmp/herdr.log"
if run_herdr_installer >"$tmp/herdr-refused.out" 2>&1; then
  echo 'Herdr must refuse without consent' >&2
  exit 1
fi
[[ ! -s "$tmp/herdr.log" ]]
grep -Fq 'https://herdr.dev/install.sh' "$tmp/herdr-refused.out"
if REMOTE_DOWNLOAD_FAIL=1 CHEZMOI_ALLOW_REMOTE_SCRIPTS=1 run_herdr_installer; then
  echo 'Herdr must fail on download errors' >&2
  exit 1
fi
[[ ! -e "$fake_home/.local/bin/herdr" ]]
CHEZMOI_ALLOW_REMOTE_SCRIPTS=1 run_herdr_installer
[[ -x "$fake_home/.local/bin/herdr" ]]
: >"$tmp/herdr.log"
run_herdr_installer
[[ ! -s "$tmp/herdr.log" ]]
for data in '{"personal":false,"chezmoi":{"os":"darwin"}}' \
  '{"personal":true,"chezmoi":{"os":"linux"}}' \
  '{"personal":true,"chezmoi":{"os":"windows"}}'; do
  [[ -z $(chezmoi execute-template --source "$repo_root" --override-data "$data" <"$herdr_template") ]]
done

# Exercise real chezmoi ordering without downloading or reconciling real plugins.
fixture="$tmp/herdr-source"
mkdir -p "$fixture/.chezmoiscripts"
cp "$herdr_template" "$fixture/.chezmoiscripts/"
cat >"$fixture/.chezmoiscripts/run_onchange_after_install-herdr-plugins.sh" <<'SH'
#!/bin/sh
[ -x "$HOME/.local/bin/herdr" ]
SH
printf '[data]\npersonal=true\n' >"$tmp/herdr-config.toml"
rm "$fake_home/.local/bin/herdr"
REMOTE_LOG="$tmp/herdr.log" PATH="$fake_bin:$PATH" HOME="$fake_home" \
  CHEZMOI_ALLOW_REMOTE_SCRIPTS=1 chezmoi apply --source "$fixture" \
  --destination "$fake_home" --config "$tmp/herdr-config.toml" \
  --persistent-state "$tmp/herdr-state.boltdb" --override-data '{"chezmoi":{"os":"darwin"}}' --no-tty

# The entrypoint must bootstrap macOS prerequisites before chezmoi. Redirect
# fixed system prefixes in a test copy so this never touches the real Homebrew.
bootstrap="$tmp/install.sh"
prefix="$tmp/homebrew"
bootstrap_bin="$tmp/bootstrap-bin"
mkdir -p "$bootstrap_bin"
python3 - "$repo_root/install.sh" "$bootstrap" "$prefix" <<'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
text = text.replace('/opt/homebrew', sys.argv[3]).replace('/usr/local', sys.argv[3] + '-intel')
Path(sys.argv[2]).write_text(text)
PY
cat >"$bootstrap_bin/uname" <<'SH'
#!/bin/sh
case "$1" in
  -s) echo "${FIXTURE_OS:-Darwin}" ;;
  -m) echo aarch64 ;;
esac
SH
cat >"$bootstrap_bin/xcode-select" <<'SH'
#!/bin/sh
printf 'xcode-select %s\n' "$*" >>"$BOOTSTRAP_LOG"
[ "$1" = --install ] || [ "${CLT_READY:-1}" = 1 ]
SH
cat >"$bootstrap_bin/xcrun" <<'SH'
#!/bin/sh
[ "${CLT_READY:-1}" = 1 ]
SH
cat >"$bootstrap_bin/curl" <<'SH'
#!/bin/sh
set -eu
for url do :; done
printf 'download %s\n' "$url" >>"$BOOTSTRAP_LOG"
[ "${DOWNLOAD_FAIL:-0}" = 0 ] || exit 22
case "$url" in
  *Homebrew/install*)
    cat <<'BREW_INSTALL'
mkdir -p "$FIXTURE_BREW_PREFIX/bin"
cat >"$FIXTURE_BREW_PREFIX/bin/brew" <<'BREW'
#!/bin/sh
[ "$1" = shellenv ] || exit 91
printf 'export HOMEBREW_PREFIX="%s"; export PATH="%s/bin:$PATH"\n' "$FIXTURE_BREW_PREFIX" "$FIXTURE_BREW_PREFIX"
BREW
chmod +x "$FIXTURE_BREW_PREFIX/bin/brew"
BREW_INSTALL
    ;;
  https://mise.run)
    cat <<'MISE_INSTALL'
printf 'mise-arch %s\n' "${MISE_INSTALL_ARCH:-default}" >>"$BOOTSTRAP_LOG"
printf '#!/bin/sh\nexit 0\n' >"$HOME/.local/bin/mise"
chmod +x "$HOME/.local/bin/mise"
MISE_INSTALL
    ;;
  *get.chezmoi.io*)
    cat <<'CHEZMOI_INSTALL'
cat >"$HOME/.local/bin/chezmoi" <<'CHEZMOI'
#!/bin/sh
set -eu
[ -x "$HOME/.local/bin/mise" ]
[ "${FIXTURE_OS:-Darwin}" != Darwin ] || [ "$HOMEBREW_PREFIX" = "$FIXTURE_BREW_PREFIX" ]
[ "$(command -v mise)" = "$HOME/.local/bin/mise" ]
printf 'chezmoi %s\n' "$*" >>"$BOOTSTRAP_LOG"
CHEZMOI
chmod +x "$HOME/.local/bin/chezmoi"
CHEZMOI_INSTALL
    ;;
  *) exit 92 ;;
esac
SH
chmod +x "$bootstrap_bin/"*
export BOOTSTRAP_LOG="$tmp/bootstrap.log" FIXTURE_BREW_PREFIX="$prefix"
run_bootstrap() {
  env -i HOME="$tmp/bootstrap-home" PATH="$bootstrap_bin:/usr/bin:/bin" \
    BOOTSTRAP_LOG="$BOOTSTRAP_LOG" FIXTURE_BREW_PREFIX="$prefix" \
    CLT_READY="${CLT_READY:-1}" DOWNLOAD_FAIL="${DOWNLOAD_FAIL:-0}" \
    CHEZMOI_ALLOW_REMOTE_SCRIPTS="${CHEZMOI_ALLOW_REMOTE_SCRIPTS:-}" \
    FIXTURE_OS="${FIXTURE_OS:-Darwin}" /bin/sh "$bootstrap" </dev/null
}

# Missing developer tools stop before downloads and explain how to resume.
: >"$BOOTSTRAP_LOG"
if CLT_READY=0 run_bootstrap >"$tmp/clt.out" 2>&1; then
  echo 'missing developer tools must stop bootstrap' >&2
  exit 1
fi
grep -Fxq 'xcode-select --install' "$BOOTSTRAP_LOG"
if grep -q '^download ' "$BOOTSTRAP_LOG"; then exit 1; fi
grep -Fq 'rerun' "$tmp/clt.out"

# Remote prerequisites still require explicit consent in automation.
: >"$BOOTSTRAP_LOG"
if run_bootstrap >"$tmp/bootstrap-refused.out" 2>&1; then
  echo 'bootstrap must refuse unapproved remote installers' >&2
  exit 1
fi
if grep -q '^download ' "$BOOTSTRAP_LOG"; then exit 1; fi

# Failed downloads cannot be mistaken for a successful prerequisite install.
if DOWNLOAD_FAIL=1 CHEZMOI_ALLOW_REMOTE_SCRIPTS=1 run_bootstrap; then
  echo 'bootstrap must fail on a download error' >&2
  exit 1
fi
if grep -q '^chezmoi ' "$BOOTSTRAP_LOG"; then exit 1; fi

: >"$BOOTSTRAP_LOG"
CHEZMOI_ALLOW_REMOTE_SCRIPTS=1 run_bootstrap
[[ $(grep -c '^download ' "$BOOTSTRAP_LOG") -eq 3 ]]
grep -Fxq 'chezmoi init --apply brendanlees' "$BOOTSTRAP_LOG"

# Existing Homebrew is discovered outside PATH; reruns do not reinstall tools.
: >"$BOOTSTRAP_LOG"
run_bootstrap
if grep -q '^download ' "$BOOTSTRAP_LOG"; then exit 1; fi
grep -Fxq 'chezmoi init --apply brendanlees' "$BOOTSTRAP_LOG"

# Reuse an existing package-manager mise at the path expected by apply hooks.
rm "$tmp/bootstrap-home/.local/bin/mise"
printf '#!/bin/sh\nexit 0\n' >"$bootstrap_bin/mise"
chmod +x "$bootstrap_bin/mise"
: >"$BOOTSTRAP_LOG"
run_bootstrap
[[ -L "$tmp/bootstrap-home/.local/bin/mise" ]]
[[ $(readlink "$tmp/bootstrap-home/.local/bin/mise") == "$bootstrap_bin/mise" ]]
if grep -q '^download ' "$BOOTSTRAP_LOG"; then exit 1; fi
rm "$bootstrap_bin/mise"

# Linux keeps the portable mise bootstrap, without Homebrew or Apple tools.
rm -rf "$tmp/bootstrap-home"
: >"$BOOTSTRAP_LOG"
FIXTURE_OS=Linux CHEZMOI_ALLOW_REMOTE_SCRIPTS=1 run_bootstrap
if grep -q 'Homebrew\|xcode-select' "$BOOTSTRAP_LOG"; then exit 1; fi
grep -Fxq 'mise-arch arm64-musl' "$BOOTSTRAP_LOG"
grep -Fxq 'chezmoi init --apply brendanlees' "$BOOTSTRAP_LOG"

echo "remote installer consent and first-run prerequisites ok"
