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
printf '#!/usr/bin/env sh\necho remote-script-body\n'
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
cat >/dev/null
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

# shellcheck disable=SC2016 # Assert literal template syntax, not shell expansion.
grep -Fq 'MISE_LIBC=musl "$MISE" self-update --yes --no-plugins' \
  "$source_root/.chezmoiscripts/run_after_install_tools.sh.tmpl"
grep -Fxq 'export MISE_USE_VERSIONS_HOST=0' \
  "$source_root/.chezmoiscripts/run_after_install_tools.sh.tmpl"

echo "remote installer confirmation ok"
