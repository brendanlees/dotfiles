#!/bin/bash

# Own the trigger so hidden quotas do not keep fetching in the background.
sketchybar --add event quota_toggle \
    --add event showy_quota_refresh \
    --add event showy_quota_provider_change \
    --add item showy_quota.trigger right \
    --set showy_quota.trigger drawing=off updates=on update_freq=10 \
    script="\"$PLUGIN_DIR/quota.sh\"" \
    --subscribe showy_quota.trigger front_app_switched system_woke \
    showy_quota_refresh quota_toggle mouse.exited.global
