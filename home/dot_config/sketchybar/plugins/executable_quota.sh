#!/usr/bin/env bash

# Upstream's fetcher needs Homebrew Bash rather than macOS's Bash 3.
if (( BASH_VERSINFO[0] < 4 )); then
    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
    for bash_bin in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        [[ ! -x "$bash_bin" ]] || exec "$bash_bin" "$0" "$@"
    done
    printf 'quota: Homebrew Bash is required\n' >&2
    exit 1
fi

export CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
fetch="$CONFIG_DIR/vendor/showy-quota/bin/showy-quota-fetch"

hide_quota() {
    sketchybar --set '/showy_quota\..*/' popup.drawing=off drawing=off \
        --set showy_quota_bracket drawing=off >/dev/null 2>&1
}

quota_is_active() {
    pgrep -x CodexBar >/dev/null 2>&1 && return 0
    local app
    app=$(aerospace list-windows --focused --format '%{app-name}' 2>/dev/null)
    case "$app" in
        Ghostty|Terminal|iTerm2|Alacritty|WezTerm|kitty|Warp|Termius) return 0 ;;
        *) return 1 ;;
    esac
}

if [[ "${SENDER:-}" == mouse.exited.global ]]; then
    sketchybar --set '/showy_quota\..*\.icon$/' popup.drawing=off
    exit 0
fi

if [[ ! -x "$fetch" ]] || ! quota_is_active; then
    hide_quota
    exit 0
fi

source "$CONFIG_DIR/quota.env"
if [[ "${1:-}" == toggle || "${SENDER:-}" == quota_toggle ]]; then
    python3 "$CONFIG_DIR/plugins/quota_details.py"
    exit $?
elif [[ "${1:-}" == mode ]]; then
    python3 "$CONFIG_DIR/plugins/quota_details.py" mode
    exit $?
fi

# Leave the current layout visible during collection. The fetcher owns cache
# freshness, locking and last-known-good data; only our renderer writes the bar.
"$fetch" >/dev/null 2>&1 || true
if quota_is_active; then
    python3 "$CONFIG_DIR/plugins/quota_details.py" render
    quota_is_active || hide_quota
else
    hide_quota
fi
