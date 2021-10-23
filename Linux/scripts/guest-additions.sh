#!/bin/bash
# Installs VirtualBox guest additions (required by Vagrant)

apt install linux-headers-$(uname -r) dkms

wget http://download.virtualbox.org/virtualbox/$VIRTUALBOX_GUEST_ADDITIONS_VERSION/VBoxGuestAdditions_$VIRTUALBOX_GUEST_ADDITIONS_VERSION.iso
mkdir /media/VBoxGuestAdditions
mount -o loop,ro VBoxGuestAdditions_$VIRTUALBOX_GUEST_ADDITIONS_VERSION.iso /media/VBoxGuestAdditions
sh /media/VBoxGuestAdditions/VBoxLinuxAdditions.run
rm VBoxGuestAdditions_$VIRTUALBOX_GUEST_ADDITIONS_VERSION.iso
umount /media/VBoxGuestAdditions
rmdir /media/VBoxGuestAdditions