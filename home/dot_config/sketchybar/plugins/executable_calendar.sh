#!/bin/bash

sketchybar --set calendar label="$(date '+%d/%m')" \
    --set calendar_time icon="$(date '+%I:%M %p')"
