#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

data='{"personal":true,"work":false,"homelab":false,"headless":false,"ephemeral":false,"chezmoi":{"os":"darwin","username":"test"}}'
linux_data='{"personal":false,"work":false,"homelab":true,"headless":true,"ephemeral":false,"chezmoi":{"os":"linux","arch":"amd64","username":"test"}}'

chezmoi execute-template --source "$repo_root" --override-data "$linux_data" \
  --file "$source_root/dot_config/mise/config.toml.tmpl" >"$tmpdir/mise-linux.toml"
grep -Fq 'asset_pattern = "atuin-x86_64-unknown-linux-musl.tar.gz"' "$tmpdir/mise-linux.toml"
# A global musl setting would also give Node a musl build that glibc hosts cannot run.
if grep -Fxq 'libc = "musl"' "$tmpdir/mise-linux.toml"; then exit 1; fi

chezmoi execute-template --source "$repo_root" --override-data "$data" \
  --file "$source_root/dot_zshrc.tmpl" >"$tmpdir/zshrc"
# Stub initializers so startup and failure handling never touch real history.
mkdir -p "$tmpdir/home/.config/zsh" "$tmpdir/home/.cache" "$tmpdir/bin"
: >"$tmpdir/home/.config/zsh/aliases.zsh"
cat >"$tmpdir/zinit-stub.zsh" <<'ZSH'
typeset -g _zinit_test_ice=''
zinit() {
  if [[ $1 == ice ]]; then
    shift
    _zinit_test_ice="$*"
  elif [[ $1 == light ]]; then
    print -r -- "${_zinit_test_ice}|$2" >>"$ZINIT_LOG"
    _zinit_test_ice=''
  fi
}
ZSH
cat >"$tmpdir/bin/git" <<'GIT'
#!/bin/sh
[ "$1" = clone ] && [ "$2" = --depth ] && [ "$3" = 1 ] &&
  [ "$4" = https://github.com/zdharma-continuum/zinit.git ] || exit 91
printf '%s\n' "$5" >>"$ZINIT_CLONE_LOG"
mkdir -p "$5"
cp "$ZINIT_STUB" "$5/zinit.zsh"
GIT
chmod +x "$tmpdir/bin/git"
chezmoi execute-template --source "$repo_root" --override-data "$linux_data" \
  --file "$source_root/.chezmoiscripts/run_once_before_install-zinit.sh.tmpl" \
  >"$tmpdir/install-zinit.sh"
for _ in 1 2; do
  HOME="$tmpdir/home" XDG_DATA_HOME="$tmpdir/home/.local/share" \
    PATH="$tmpdir/bin:/usr/bin:/bin" ZINIT_STUB="$tmpdir/zinit-stub.zsh" \
    ZINIT_CLONE_LOG="$tmpdir/zinit-clone.log" bash "$tmpdir/install-zinit.sh"
done
[[ $(wc -l <"$tmpdir/zinit-clone.log") -eq 1 ]]
cat >"$tmpdir/bin/fzf" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "--zsh" ]; then
  cat <<'ZSH'
_fzf_history_widget() { :; }
zle -N fzf-history-widget _fzf_history_widget
bindkey -M emacs '^R' fzf-history-widget
bindkey -M viins '^R' fzf-history-widget
ZSH
fi
EOF

cat >"$tmpdir/bin/atuin" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "init" ] && [ "${2:-}" = "zsh" ]; then
  if [ "${ATUIN_TEST_FAIL:-0}" = 1 ]; then
    echo 'simulated atuin failure' >&2
    exit 127
  fi
  cat <<'ZSH'
# Atuin init selects its own strategy even before autosuggestions loads.
ZSH_AUTOSUGGEST_STRATEGY=(atuin)
_atuin_history_widget() { :; }
zle -N atuin-search-viins _atuin_history_widget
bindkey -M emacs '^R' atuin-search
bindkey -M viins '^R' atuin-search-viins
bindkey -M viins '^[[A' atuin-up-search-viins
ZSH
fi
EOF
chmod +x "$tmpdir/bin/fzf" "$tmpdir/bin/atuin"

HOME="$tmpdir/home" \
  XDG_CONFIG_HOME="$tmpdir/home/.config" \
  XDG_DATA_HOME="$tmpdir/home/.local/share" \
  XDG_STATE_HOME="$tmpdir/home/.local/state" \
  XDG_CACHE_HOME="$tmpdir/home/.cache" \
  ZINIT_LOG="$tmpdir/zinit.log" \
  PATH="$tmpdir/bin:/usr/bin:/bin" \
  zsh -dfic 'source "$1"' zsh "$tmpdir/zshrc"
[[ -s "$tmpdir/home/.cache/zsh/init/atuin.zsh" ]]
rm -f "$tmpdir/home/.cache/zsh/init/atuin.zsh"
HOME="$tmpdir/home" \
  XDG_CONFIG_HOME="$tmpdir/home/.config" \
  XDG_DATA_HOME="$tmpdir/home/.local/share" \
  XDG_STATE_HOME="$tmpdir/home/.local/state" \
  XDG_CACHE_HOME="$tmpdir/home/.cache" \
  ZINIT_LOG="$tmpdir/zinit-failure.log" \
  PATH="$tmpdir/bin:/usr/bin:/bin" \
  ATUIN_TEST_FAIL=1 \
  zsh -dfic 'source "$1"' zsh "$tmpdir/zshrc" 2>"$tmpdir/atuin-failure.stderr"
[[ ! -e "$tmpdir/home/.cache/zsh/init/atuin.zsh" ]]

echo 'Zinit bootstrap, Atuin init caching and Linux runtime compatibility ok'
