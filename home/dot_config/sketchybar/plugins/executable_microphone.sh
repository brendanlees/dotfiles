#!/bin/bash

# shellcheck source=../colors.sh
source "$CONFIG_DIR/colors.sh"

set_item_state() {
  if [ "$1" = "1" ] || [ "$1" = "active" ]; then
    sketchybar \
      --set "$NAME" \
        drawing=on \
        icon.color="$WHITE" \
        background.color="$MICROPHONE_ACTIVE_COLOR" \
      --set microphone_balance drawing=on
  else
    sketchybar \
      --set "$NAME" drawing=off \
      --set microphone_balance drawing=off
  fi
}

# CoreAudio watcher events carry the new state, so this path performs no query.
if [ "${SENDER:-}" = "microphone_change" ]; then
  set_item_state "${MIC_ACTIVE:-0}"
  exit 0
fi

hide_item() {
  set_item_state 0
  exit 0
}

activity_helper="${MIC_ACTIVITY_HELPER:-}"
rebuilt=0
# Use one macOS-native path regardless of whether the invoking shell exports
# XDG_CACHE_HOME; SketchyBar and interactive shells can have different envs.
cache_dir="$HOME/Library/Caches/sketchybar"
lock_file="$cache_dir/mic_activity.lock"
watcher_log="$cache_dir/mic_activity.log"

if [ -z "$activity_helper" ]; then
  source_file="$CONFIG_DIR/helpers/mic_activity.c"
  activity_helper="$cache_dir/mic_activity"

  if [ ! -x "$activity_helper" ] || [ "$source_file" -nt "$activity_helper" ]; then
    command -v xcrun >/dev/null 2>&1 || hide_item
    mkdir -p "$cache_dir" || hide_item
    temporary_helper="$activity_helper.$$"
    if ! xcrun clang -O2 -Wall -Wextra -framework CoreAudio \
      -framework CoreFoundation "$source_file" -o "$temporary_helper" \
      >/dev/null 2>&1; then
      rm -f "$temporary_helper"
      hide_item
    fi
    mv -f "$temporary_helper" "$activity_helper" || hide_item
    rebuilt=1
  fi
fi

watcher_pid() {
  local pid command_line
  [ -r "$lock_file" ] || return 1
  IFS= read -r pid < "$lock_file" || return 1
  case "$pid" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -0 "$pid" 2>/dev/null || return 1
  command_line="$(ps -p "$pid" -o command= 2>/dev/null)" || return 1
  case "$command_line" in
    "$activity_helper --watch $lock_file "*) printf '%s\n' "$pid" ;;
    *) return 1 ;;
  esac
}

# Replacing the cached binary leaves the old inode running. Sleep/wake can also
# invalidate CoreAudio object IDs, so rebuild all listeners after waking. Stop
# an instance only after verifying the PID belongs to this exact command.
if [ "$rebuilt" = "1" ] || [ "${SENDER:-}" = "system_woke" ]; then
  old_pid="$(watcher_pid || true)"
  if [ -n "$old_pid" ]; then
    kill "$old_pid" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      kill -0 "$old_pid" 2>/dev/null || break
      sleep 0.05
    done
  fi
fi

if [ "${MIC_WATCHER_DISABLE:-0}" != "1" ] && ! watcher_pid >/dev/null; then
  sketchybar_bin="$(command -v sketchybar)" || hide_item
  mkdir -p "$cache_dir" || hide_item
  nohup "$activity_helper" --watch "$lock_file" "$sketchybar_bin" \
    >>"$watcher_log" 2>&1 </dev/null &
fi

# Set an immediate state during bar reload; subsequent changes are pushed by
# the persistent watcher through the microphone_change custom event.
state="$("$activity_helper" 2>/dev/null)" || hide_item
set_item_state "$state"
