#!/bin/bash

set -eufo pipefail

# appearance
defaults write -g AppleInterfaceStyle -string Dark
defaults write -g AppleShowScrollBars -string WhenScrolling

# text input
defaults write -g ApplePressAndHoldEnabled -int 0
defaults write -g InitialKeyRepeat -int 15
defaults write -g KeyRepeat -int 2
defaults write -g NSAutomaticCapitalizationEnabled -int 0
defaults write -g NSAutomaticDashSubstitutionEnabled -int 0
defaults write -g NSAutomaticInlinePredictionEnabled -int 0
defaults write -g NSAutomaticPeriodSubstitutionEnabled -int 0
defaults write -g NSAutomaticQuoteSubstitutionEnabled -int 0
defaults write -g NSAutomaticSpellingCorrectionEnabled -int 0
defaults write -g NSAutomaticTextCorrectionEnabled -int 0

# window behaviour
defaults write -g AppleEnableSwipeNavigateWithScrolls -int 0
defaults write -g AppleMiniaturizeOnDoubleClick -int 0
defaults write -g AppleShowAllExtensions -int 1

# scrolling
defaults write -g com.apple.swipescrolldirection -bool false

# trackpad
defaults write -g com.apple.trackpad.forceClick -int 0
defaults write com.apple.AppleMultitouchTrackpad Clicking -int 1
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -int 1

# dock
defaults write com.apple.dock autohide -int 1
defaults write com.apple.dock autohide-delay -float 0.2
defaults write com.apple.dock autohide-time-modifier -float 0
defaults write com.apple.dock expose-group-apps -int 1
defaults write com.apple.dock largesize -int 53
defaults write com.apple.dock launchanim -int 0
defaults write com.apple.dock magnification -int 1
defaults write com.apple.dock mineffect -string scale
defaults write com.apple.dock minimize-to-application -int 1
defaults write com.apple.dock mru-spaces -int 0
defaults write com.apple.dock orientation -string bottom
defaults write com.apple.dock show-recents -int 0
defaults write com.apple.dock tilesize -int 31

# finder
defaults write com.apple.finder FXEnableExtensionChangeWarning -int 0
defaults write com.apple.finder FXPreferredViewStyle -string clmv
defaults write com.apple.finder FXRemoveOldTrashItems -int 1
defaults write com.apple.finder _FXSortFoldersFirst -int 1
defaults write com.apple.finder QuitMenuItem -int 1
defaults write com.apple.finder ShowPathbar -int 1
defaults write com.apple.finder ShowStatusBar -int 1

# screenshots
defaults write com.apple.screencapture target -string clipboard
defaults write com.apple.screencapture type -string jpg

# safari
defaults write com.apple.Safari AlwaysPromptForDownloadFolder -int 1
defaults write com.apple.Safari AutoFillCreditCardData -int 0
defaults write com.apple.Safari AutoFillFromAddressBook -int 0
defaults write com.apple.Safari AutoFillMiscellaneousForms -int 0
defaults write com.apple.Safari AutoFillPasswords -int 0
defaults write com.apple.Safari AutoOpenSafeDownloads -int 0

killall Dock Finder SystemUIServer 2>/dev/null || true
