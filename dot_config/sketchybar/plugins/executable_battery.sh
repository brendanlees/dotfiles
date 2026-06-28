#!/bin/bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
CHARGING="$(pmset -g batt | grep 'AC Power')"

if [ "$PERCENTAGE" = "" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

case ${PERCENTAGE} in
  9[0-9]|100) ICON="$ICON_BATTERY_100"; COLOR="$GREEN" ;;
  [6-8][0-9]) ICON="$ICON_BATTERY_75";  COLOR="$GREEN" ;;
  [3-5][0-9]) ICON="$ICON_BATTERY_50";  COLOR="$YELLOW" ;;
  [1-2][0-9]) ICON="$ICON_BATTERY_25";  COLOR="$ORANGE" ;;
  *)          ICON="$ICON_BATTERY_0";    COLOR="$RED" ;;
esac

if [ -n "$CHARGING" ]; then
  ICON="$ICON_BATTERY_CHARGING"
  COLOR="$GREEN"
fi

sketchybar --set "$NAME" \
  drawing=on \
  icon="$ICON" \
  icon.color="$COLOR" \
  label="${PERCENTAGE}%"
