#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

data='{"personal":true,"work":false,"homelab":false,"headless":false,"ephemeral":false,"theme":"guts","chezmoi":{"os":"darwin","username":"test"}}'
linux_data='{"personal":false,"work":false,"homelab":true,"headless":true,"ephemeral":false,"theme":"guts","chezmoi":{"os":"linux","username":"test"}}'

atuin_theme_template="$source_root/dot_config/atuin/themes/chezmoi.toml.tmpl"
chezmoi execute-template --source "$repo_root" --override-data "$data" \
  --file "$atuin_theme_template" >"$tmpdir/atuin-theme.toml"
chezmoi data --source "$repo_root" --format json >"$tmpdir/data.json"
python3 - "$tmpdir/atuin-theme.toml" "$tmpdir/data.json" \
  "$source_root/dot_config/atuin/private_config.toml" <<'PY'
import json
import sys
import tomllib
from pathlib import Path

theme = tomllib.loads(Path(sys.argv[1]).read_text())
data = json.loads(Path(sys.argv[2]).read_text())
config = tomllib.loads(Path(sys.argv[3]).read_text())
palette = data["themes"]["guts"]["palette"]
expected_mapping = {
    "Base": "fg",
    "AlertInfo": "info",
    "AlertWarn": "warn",
    "AlertError": "error",
    "Annotation": "comment",
    "Guidance": "accent",
    "Important": "primary",
    "Title": "primary_alt",
    "Muted": "muted",
    "SyntaxCommand": "primary",
    "SyntaxFlag": "secondary",
    "SyntaxString": "success",
    "SyntaxVariable": "info_alt",
    "SyntaxOperator": "fg",
    "SyntaxComment": "comment",
}
if theme["theme"] != {"name": "chezmoi", "parent": "autumn"}:
    raise SystemExit(f"unexpected Atuin theme inheritance: {theme['theme']!r}")
expected_colors = {key: palette[value] for key, value in expected_mapping.items()}
if theme.get("colors") != expected_colors:
    raise SystemExit(f"Atuin palette mapping mismatch: {theme.get('colors')!r}")
if config.get("tmux", {}).get("enabled") is not False:
    raise SystemExit("Atuin search must stay inline rather than opening a tmux popup")
if config.get("theme") != {"name": "chezmoi"}:
    raise SystemExit(f"Atuin config does not select chezmoi theme: {config.get('theme')!r}")
if "name" in config.get("daemon", {}):
    raise SystemExit("Atuin theme name must not be nested under daemon")
if config.get("daemon", {}).get("socket_path") != "~/.local/share/atuin/atuin.sock":
    raise SystemExit("Atuin needs a fixed per-user daemon socket independent of TMPDIR")
PY

chezmoi execute-template --source "$repo_root" --override-data "$data" \
  <"$source_root/dot_config/mise/config.toml.tmpl" >"$tmpdir/mise.toml"
grep -Fxq 'atuin = "latest"' "$tmpdir/mise.toml"
chezmoi execute-template --source "$repo_root" --override-data "$linux_data" \
  --file "$source_root/dot_config/mise/config.toml.tmpl" >"$tmpdir/mise-linux.toml"
grep -Fxq 'libc = "musl"' "$tmpdir/mise-linux.toml"

chezmoi execute-template --source "$repo_root" --override-data "$data" \
  --file "$source_root/dot_zshrc.tmpl" >"$tmpdir/zshrc"
fzf_line=$(grep -nF '_cached_eval fzf fzf fzf --zsh' "$tmpdir/zshrc" | cut -d: -f1)
atuin_line=$(grep -nF '_cached_eval atuin atuin atuin init zsh' "$tmpdir/zshrc" | cut -d: -f1)
((atuin_line > fzf_line))
if grep -Fq 'XDG_DATA_HOME/zsh/plugins/' "$tmpdir/zshrc"; then
  echo 'Zsh plugins must no longer load from chezmoi-managed directories' >&2
  exit 1
fi
for plugin in 'zsh-users/zsh-completions' 'Aloxaf/fzf-tab' 'zsh-users/zsh-syntax-highlighting' 'Giammarco-Ferranti/deja'; do
  grep -Fq "zinit light $plugin" "$tmpdir/zshrc"
done
grep -Fq 'wait"0" lucid depth=1 pick"deja.plugin.zsh"' "$tmpdir/zshrc"
grep -Fq 'zinit ice wait lucid depth=1' "$tmpdir/zshrc"
python3 - "$tmpdir/zshrc" <<'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
assert text.index('zinit light zsh-users/zsh-completions') < text.index('autoload -U compinit')
assert text.index('autoload -U compinit') < text.index('zinit light Aloxaf/fzf-tab')
assert text.rindex('zinit light zsh-users/zsh-syntax-highlighting') > text.index('bindkey \'^X^E\' edit-command-line')
PY

# Exercise the binding order with small fake init commands. fzf claims Ctrl-R
# first; the later Atuin init must replace that widget in vi insert mode.
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
cat >"$tmpdir/bin/deja" <<'DEJA'
#!/bin/sh
exit 0
DEJA
chmod +x "$tmpdir/bin/deja"

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
_atuin_history_widget() { :; }
zle -N atuin-search-viins _atuin_history_widget
bindkey -M emacs '^R' atuin-search
bindkey -M viins '^R' atuin-search-viins
bindkey -M viins '^[[A' atuin-up-search-viins
ZSH
fi
EOF
chmod +x "$tmpdir/bin/fzf" "$tmpdir/bin/atuin"

binding=$(HOME="$tmpdir/home" \
  XDG_CONFIG_HOME="$tmpdir/home/.config" \
  XDG_DATA_HOME="$tmpdir/home/.local/share" \
  XDG_STATE_HOME="$tmpdir/home/.local/state" \
  XDG_CACHE_HOME="$tmpdir/home/.cache" \
  ZINIT_LOG="$tmpdir/zinit.log" \
  PATH="$tmpdir/bin:/usr/bin:/bin" \
  zsh -dfic 'source "$1"; bindkey -M viins "^R"; bindkey -M viins "^[[A"' zsh "$tmpdir/zshrc")
[[ $binding == *atuin-search-viins* ]]
[[ $binding == *atuin-up-search-viins* ]]
[[ $binding != *fzf-history-widget* ]]
grep -Fq '|zsh-users/zsh-completions' "$tmpdir/zinit.log"
grep -Fq '|Aloxaf/fzf-tab' "$tmpdir/zinit.log"
grep -Fq '|Giammarco-Ferranti/deja' "$tmpdir/zinit.log"

rm -f "$tmpdir/home/.cache/zsh/init/atuin.zsh"
failed_binding=$(HOME="$tmpdir/home" \
  XDG_CONFIG_HOME="$tmpdir/home/.config" \
  XDG_DATA_HOME="$tmpdir/home/.local/share" \
  XDG_STATE_HOME="$tmpdir/home/.local/state" \
  XDG_CACHE_HOME="$tmpdir/home/.cache" \
  ZINIT_LOG="$tmpdir/zinit-failure.log" \
  PATH="$tmpdir/bin:/usr/bin:/bin" \
  ATUIN_TEST_FAIL=1 \
  zsh -dfic 'source "$1"; bindkey -M viins "^R"' zsh "$tmpdir/zshrc" 2>"$tmpdir/atuin-failure.stderr")
[[ $failed_binding == *fzf-history-widget* ]]
[[ $failed_binding != *atuin-search* ]]
[[ ! -e "$tmpdir/home/.cache/zsh/init/atuin.zsh" ]]

chezmoi execute-template --source "$repo_root" --override-data "$data" \
  <"$source_root/Documents/PowerShell/profile.ps1.tmpl" >"$tmpdir/profile.ps1"
psfzf_line=$(grep -nF "Set-PsFzfOption -PSReadlineChordProvider" "$tmpdir/profile.ps1" | cut -d: -f1)
atuin_ps_line=$(grep -nF 'atuin init powershell | Out-String | Invoke-Expression' "$tmpdir/profile.ps1" | cut -d: -f1)
((atuin_ps_line > psfzf_line))

echo 'Zinit plugin loading, Deja/Atuin integration, Ctrl-R and Up ownership ok'
