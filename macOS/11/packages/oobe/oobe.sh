#!/usr/bin/env bash
# This script configures the out of box experience (or whatever the macOS equivalent is called) so that we skip
# things like the "screen time" and "Siri" set-up.

echo "Setting OOBE options"

product_version=$(sw_vers -productVersion)
echo "Product Version: ${product_version}"
build_version=$(sw_vers -buildVersion)
echo "Build: ${build_version}"
user_locale="English"
echo "Will configure the ${user_locale} language"

if [[ -d /System/Library/User\ Template/${user_locale}.lproj/Library/Preferences/ ]]; then
    /usr/bin/defaults write /System/Library/User\ Template/${user_locale}.lproj/Library/Preferences/com.apple.SetupAssistant DidSeeCloudSetup -bool TRUE
    /usr/bin/defaults write /System/Library/User\ Template/${user_locale}.lproj/Library/Preferences/com.apple.SetupAssistant GestureMovieSeen none
    /usr/bin/defaults write /System/Library/User\ Template/${user_locale}.lproj/Library/Preferences/com.apple.SetupAssistant DidSeePrivacy -bool TRUE
    /usr/bin/defaults write /System/Library/User\ Template/${user_locale}.lproj/Library/Preferences/com.apple.SetupAssistant DidSeeTrueTonePrivacy -bool TRUE
    /usr/bin/defaults write /System/Library/User\ Template/${user_locale}.lproj/Library/Preferences/com.apple.SetupAssistant DidSeeTouchIDSetup -bool TRUE
    /usr/bin/defaults write /System/Library/User\ Template/${user_locale}.lproj/Library/Preferences/com.apple.SetupAssistant DidSeeSiriSetup -bool TRUE
    /usr/bin/defaults write /System/Library/User\ Template/${user_locale}.lproj/Library/Preferences/com.apple.SetupAssistant DidSeeActivationLock -bool TRUE
    /usr/bin/defaults write /System/Library/User\ Template/${user_locale}.lproj/Library/Preferences/com.apple.SetupAssistant DidSeeScreenTime -bool TRUE
    /usr/bin/defaults write /System/Library/User\ Template/${user_locale}.lproj/Library/Preferences/com.apple.SetupAssistant LastSeenCloudProductVersion "${product_version}"
    /usr/bin/defaults write /System/Library/User\ Template/${user_locale}.lproj/Library/Preferences/com.apple.SetupAssistant LastSeenBuddyBuildVersion "${build_version}"
else
    echo "Could not find User Templates directory for the '${user_locale}' language"
    exit 1
fi

# Mark set-up as complete
touch /private/var/db/.AppleSetupDone

echo "OOBE should now be complete"
exit 0