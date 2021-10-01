# macOS 11.X
This directory contains the OS Provisioning data for macOS 11.  

# Packages
This directory contains the scripts that get converted into `pkg` files to allow us to easily bootstrap the repo.  
They are built using the amazing [Packages](http://s.sudre.free.fr/Software/Packages/about.html) application (`brew install packages --cask`) the [macOSPackages.ps1](../../.build/builds/macOSPackages.ps1) build takes care of updating these.
# Packer

## Files
This directory contains files that are passed into the Packer build via the `http_directory` parameter.  
This is used to bootstrap the build from recovery mode.

## Images
This directory is used to contain the ISO image (and relevant checksum) to build from

# Builds
## Basic
This build takes a raw macOS 11 ISO and performs and install followed by setting up the `packer` user.