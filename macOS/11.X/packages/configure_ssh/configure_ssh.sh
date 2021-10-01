#!/usr/bin/env bash
# This script enables SSH so packer can get in and do what it needs to
echo "Beginning SSH configuration phase"

# Add the 'packer' user we created earlier to the sudoers list and make it so they don't need a password to sudo.
echo 'packer     ALL=(ALL)       NOPASSWD: ALL' >/private/etc/sudoers.d/packer

# Copy the system ssh.plist to the shared Library space and enable SSH for the next boot
cp /System/Library/LaunchDaemons/ssh.plist /Library/LaunchDaemons/ssh.plist
/usr/libexec/PlistBuddy -c "set Disabled FALSE" /Library/LaunchDaemons/ssh.plist

echo "SSH configuration complete"
exit 0