---
Latest tested version: 11.6
---
# macOS 11.X
This directory contains the OS Provisioning data for macOS 11.  

# Builds
## Basic
This build performs the bare minimum to a macOS ISO to get it up and running with Packer:
* Creates a `packer` user
* Gives the `packer` user `sudo` permissions with `NOPASSWD: ALL` set
* Enables ssh on next boot
* Marks the installation as complete and skips the initial set-up/out of box experience phase.
# Packages
This directory contains the scripts that get converted into `pkg` files to allow us to easily bootstrap the deployment.  
They are built using the amazing [Packages](http://s.sudre.free.fr/Software/Packages/about.html) application (`brew install packages --cask`) the `.pkgproj` files contain the information needed to build them and the [Build-MacOSPackage](../../.build/code/Public/macOS/Build-MacOSPackage.ps1) PowerShell cmdlet provides a convenient way to build these en masse.

For details on what specific scripts do check the script file themselves.

# Scripts
This directory contains all the scripts that are used during packer deployments. 