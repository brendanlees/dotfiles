#!/bin/bash

set -eufo pipefail

trap 'killall Dock' EXIT

# remove apple defaults
declare -a remove_labels=(
    "App Store"
    Calendar
    Contacts
    FaceTime
    Freeform
    Keynote
    Launchpad
    Mail
    Maps
    Messages
    Music
    Notes
    Numbers
    Pages
    Photos
    Reminders
    Safari
    TV
)

for label in "${remove_labels[@]}"; do
    dockutil --no-restart --remove "${label}" 2>/dev/null || true
done

# remove everything else to start clean
dockutil --no-restart --remove all || true

# system
dockutil --no-restart --add '/System/Applications/System Settings.app'
dockutil --no-restart --add '' --type spacer --section apps

# browser / comms / terminal
dockutil --no-restart --add '/Applications/Mimestream.app'
dockutil --no-restart --add '/Applications/Arc.app'
dockutil --no-restart --add '/Applications/Ghostty.app'
dockutil --no-restart --add '' --type spacer --section apps

# audio
dockutil --no-restart --add '/System/Applications/Utilities/Audio MIDI Setup.app'
dockutil --no-restart --add '/Applications/Ableton Live 12 Suite.app'
dockutil --no-restart --add '/Applications/Spotify.app'
dockutil --no-restart --add '' --type spacer --section apps

# productivity
dockutil --no-restart --add '/Applications/Notion.app'
dockutil --no-restart --add '/Applications/Obsidian.app'
dockutil --no-restart --add '/Applications/Todoist.app'
dockutil --no-restart --add '/System/Applications/Calendar.app'
