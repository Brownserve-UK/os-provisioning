#!/bin/bash -e -o pipefail
# Creates the vagrant user

sudo dscl . -create /Users/vagrant
sudo dscl . -create /Users/vagrant UserShell /bin/bash
sudo dscl . -create /Users/vagrant RealName "vagrant"
sudo dscl . -create /Users/vagrant PrimaryGroupID 1000
sudo dscl . -create /Users/vagrant NFSHomeDirectory /Local/Users/vagrant
sudo dscl . -passwd /Users/vagrant vagrant
sudo dscl . -append /Groups/admin GroupMembership vagrant