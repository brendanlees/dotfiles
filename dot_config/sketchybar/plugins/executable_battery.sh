#!/bin/bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

BATTERY_INFO="$(pmset -g batt)"
PERCENTAGE="$(printf '%s\n' "$BATTERY_INFO" | grep -Eo '[0-9]+%' | head -n 1 | cut -d% -f1)"
AC_POWER="$(printf '%s\n' "$BATTERY_INFO" | grep 'AC Power' || true)"

if [ -z "$PERCENTAGE" ] || [ -n "$AC_POWER" ]; then
  sketchybar \
    --set "$NAME" drawing=off \
    --set spacer.backup_sync drawing=off
  exit 0
fi

case ${PERCENTAGE} in
  9[0-9]|100) ICON="$ICON_BATTERY_100"; COLOR="$GREEN" ;;
  [6-8][0-9]) ICON="$ICON_BATTERY_75";  COLOR="$GREEN" ;;
  [3-5][0-9]) ICON="$ICON_BATTERY_50";  COLOR="$YELLOW" ;;
  [1-2][0-9]) ICON="$ICON_BATTERY_25";  COLOR="$ORANGE" ;;
  *)          ICON="$ICON_BATTERY_0";    COLOR="$RED" ;;
esac

sketchybar \
  --set "$NAME" \
  drawing=on \
  icon="$ICON" \
  icon.color="$COLOR" \
  label="${PERCENTAGE}%" \
  --set spacer.backup_sync drawing=on
