#!/bin/bash
# This script assists in bootstrapping the Install process by preparing the system and injecting our special packages
# into the install process.
set -euo pipefail
IFS=$'\n\t'
shopt -s nullglob nocaseglob

echo "Beginning bootstrap process..."

# Erase disk0 (which should be our one and only disk...)
diskutil eraseDisk jhfs+ 11vm disk0

# We _may_ need to change the SUS server address for machines with the T2 chip, see here for more info: https://www.reddit.com/r/MacOSBeta/comments/jsigqs/for_anyone_trying_to_use_the_big_sur_1101_rc2/
nvram IASUCatalogURL=https://swscan.apple.com/content/catalogs/others/index-10.16seed-10.16-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog

# Install macOS and inject our configuration packages
/Volumes/Image\ Volume/Install*.app/Contents/Resources/startosinstall --agreetolicense --rebootdelay 90 --installpackage packer_user.pkg --installpackage oobe.pkg --installpackage configure_ssh.pkg --volume /Volumes/11vm

echo "Bootstrap complete"
exit 0