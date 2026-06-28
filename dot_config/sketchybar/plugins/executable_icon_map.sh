#!/bin/bash

# Maps app names to sketchybar-app-font glyphs
# Install: brew install --cask font-sketchybar-app-font
# Reference: https://github.com/kvndrsslr/sketchybar-app-font

case "$1" in
  "Activity Monitor")            icon_result=":activity_monitor:" ;;
  "Arc")                         icon_result=":arc:" ;;
  "Bitwarden")                   icon_result=":bitwarden:" ;;
  "Brave Browser")               icon_result=":brave_browser:" ;;
  "Code" | "Visual Studio Code") icon_result=":code:" ;;
  "Discord")                     icon_result=":discord:" ;;
  "Figma")                       icon_result=":figma:" ;;
  "Finder")                      icon_result=":finder:" ;;
  "Firefox")                     icon_result=":firefox:" ;;
  "Ghostty")                     icon_result=":ghostty:" ;;
  "Google Chrome")               icon_result=":google_chrome:" ;;
  "Mimestream")                  icon_result=":mimestream:" ;;
  "Notion")                      icon_result=":notion:" ;;
  "Obsidian")                    icon_result=":obsidian:" ;;
  "Spotify")                     icon_result=":spotify:" ;;
  "System Preferences" | "System Settings") icon_result=":system_preferences:" ;;
  "Todoist")                     icon_result=":todoist:" ;;
  "Zed")                         icon_result=":zed:" ;;
  "Zen Browser")                 icon_result=":zen_browser:" ;;
  "zoom.us")                     icon_result=":zoom:" ;;
  *)                             icon_result=":default:" ;;
esac

echo "$icon_result"
