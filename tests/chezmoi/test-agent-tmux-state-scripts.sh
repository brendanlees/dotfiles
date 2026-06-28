#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

script="$repo_root/dot_config/sesh/scripts/executable_agent-state.sh.tmpl"
state_dir="$tmpdir/state"
fake_bin="$tmpdir/bin"
mkdir -p "$fake_bin" "$state_dir"

cat > "$fake_bin/tmux" <<'TMUX'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${TMUX_LOG:?}"
case "$1" in
  display-message)
    if [[ "$*" == *'#{pane_id}'* ]]; then
      printf '%%12\t$1\tdotfiles\t@2\t3\tagent-window\t/tmp/project\n'
    fi
    ;;
  list-panes)
    printf '%%12\n'
    ;;
  has-session|switch-client|select-window|select-pane|display-popup)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
TMUX
chmod +x "$fake_bin/tmux"

export PATH="$fake_bin:$PATH"
export TMUX=/tmp/tmux-test
export TMUX_PANE=%12
export TMUX_LOG="$tmpdir/tmux.log"
export AGENT_TMUX_STATE_DIR="$state_dir"

bash -n "$script"

"$script" write-done --harness claude
record="$state_dir/pane-%12.env"
[[ -f "$record" ]]
grep -q "^HARNESS='claude'$" "$record"
grep -q "^STATE='done'$" "$record"
grep -q "^PANE_ID='%12'$" "$record"
grep -q "^SESSION_NAME='dotfiles'$" "$record"

list_output=$("$script" list)
[[ "$list_output" == agent:%12* ]]
[[ "$list_output" == *claude* ]]
[[ "$list_output" == *dotfiles* ]]

preview_output=$("$script" preview 'agent:%12 claude done dotfiles:3 agent-window /tmp/project')
[[ "$preview_output" == *'agent: claude'* ]]
[[ "$preview_output" == *'state: done'* ]]
[[ "$preview_output" == *'pane: %12'* ]]

"$script" target 'agent:%12 claude done dotfiles:3 agent-window /tmp/project'
grep -q 'switch-client -t $1' "$TMUX_LOG"
grep -q 'select-window -t @2' "$TMUX_LOG"
grep -q 'select-pane -t %12' "$TMUX_LOG"
