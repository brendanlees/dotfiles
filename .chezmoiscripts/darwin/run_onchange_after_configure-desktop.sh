#!/bin/bash

set -eufo pipefail

current=$(osascript -e 'tell application "System Events" to tell desktop 1 to get picture' 2>/dev/null || true)

# only set wallpaper if current one is a system default (not a user photo)
if [[ "$current" == /System/Library/Desktop\ Pictures/* ]]; then
  osascript -e 'tell application "System Events" to tell every desktop to set picture to "/System/Library/Desktop Pictures/Chroma Blue.madesktop" as POSIX file'
fi
