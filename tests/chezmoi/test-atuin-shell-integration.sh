#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

data='{"personal":true,"work":false,"homelab":false,"headless":false,"ephemeral":false,"chezmoi":{"os":"darwin","username":"test"}}'

chezmoi execute-template --source "$repo_root" --override-data "$data" \
  <"$source_root/dot_config/mise/config.toml.tmpl" >"$tmpdir/mise.toml"
grep -Fxq 'atuin = "latest"' "$tmpdir/mise.toml"

chezmoi execute-template --source "$repo_root" --override-data "$data" \
  --file "$source_root/dot_zshrc.tmpl" >"$tmpdir/zshrc"
fzf_line=$(grep -nF '_cached_eval fzf fzf fzf --zsh' "$tmpdir/zshrc" | cut -d: -f1)
atuin_line=$(grep -nF '_cached_eval atuin atuin atuin init zsh' "$tmpdir/zshrc" | cut -d: -f1)
((atuin_line > fzf_line))

# Exercise the binding order with small fake init commands. fzf claims Ctrl-R
# first; the later Atuin init must replace that widget in vi insert mode.
mkdir -p \
  "$tmpdir/home/.config/zsh" \
  "$tmpdir/home/.local/share/zsh/plugins/zsh-autosuggestions" \
  "$tmpdir/home/.local/share/zsh/plugins/fzf-tab" \
  "$tmpdir/home/.local/share/zsh/plugins/zsh-syntax-highlighting" \
  "$tmpdir/home/.cache"
: >"$tmpdir/home/.config/zsh/aliases.zsh"
: >"$tmpdir/home/.local/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
: >"$tmpdir/home/.local/share/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh"
: >"$tmpdir/home/.local/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
mkdir -p "$tmpdir/bin"

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
  cat <<'ZSH'
_atuin_history_widget() { :; }
zle -N atuin-search-viins _atuin_history_widget
bindkey -M emacs '^R' atuin-search
bindkey -M viins '^R' atuin-search-viins
ZSH
fi
EOF
chmod +x "$tmpdir/bin/fzf" "$tmpdir/bin/atuin"

binding=$(HOME="$tmpdir/home" \
  XDG_CONFIG_HOME="$tmpdir/home/.config" \
  XDG_DATA_HOME="$tmpdir/home/.local/share" \
  XDG_STATE_HOME="$tmpdir/home/.local/state" \
  XDG_CACHE_HOME="$tmpdir/home/.cache" \
  PATH="$tmpdir/bin:/usr/bin:/bin" \
  zsh -dfic 'source "$1"; bindkey -M viins "^R"' zsh "$tmpdir/zshrc")
[[ $binding == *atuin-search-viins* ]]
[[ $binding != *fzf-history-widget* ]]

chezmoi execute-template --source "$repo_root" --override-data "$data" \
  <"$source_root/Documents/PowerShell/profile.ps1.tmpl" >"$tmpdir/profile.ps1"
psfzf_line=$(grep -nF "Set-PsFzfOption -PSReadlineChordProvider" "$tmpdir/profile.ps1" | cut -d: -f1)
atuin_ps_line=$(grep -nF 'atuin init powershell | Out-String | Invoke-Expression' "$tmpdir/profile.ps1" | cut -d: -f1)
((atuin_ps_line > psfzf_line))

echo 'Atuin shell integration and Ctrl-R ownership ok'
