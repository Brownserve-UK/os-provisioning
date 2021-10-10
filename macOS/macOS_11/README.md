---
Latest tested version: 11.6
---
# macOS 11.X
This directory contains the OS Provisioning data for macOS 11.  

**Special thanks goes to [trodemaster](https://github.com/trodemaster/packer-macOS-11) for providing the inspiration behind using boot commands to bootstrap the install process**

# Packer builds
## Basic
This build performs the bare minimum to a macOS ISO to get it up and running with Packer:
* Bootstraps the repo by using boot commands to call a terminal and download our `.pkg` files
* Triggers the install process for macOS
* Creates a `packer` user
* Gives the `packer` user `sudo` permissions with `NOPASSWD: ALL` set
* Enables ssh on next boot
* Marks the installation as complete and skips the initial set-up/out of box experience phase.
* Installs the X-Code command line tools
* Installs Homebrew