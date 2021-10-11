# Linux
Within this directory you will find all the configurations for the flavours of Linux that we currently support.

# Directory structure
Within each configuration directory you'll find various files/folders, below you'll find an overview of what each of these does.

## Autoinstall directory
This directory contains the various flavours of auto-install configurations that Linux distro's can use (e.g preseed, autoinstall, kickstart etc).

## Scripts directory
These directories contain any scripts that are used by Packer during the build either as provisioning steps or as files that get mounted via HTTP/floppy disk etc.  
These scripts get combined with the [common Linux scripts](scripts/) found in this directory during the build process.  
If you have 2 scripts with the same name then the OS specific script will be used (e.g. if you have `./Linux/scripts/users.sh` and `./Linux/Ubuntu2004/scripts/users.sh` then the `Ubuntu2004` version will be used)
  
For details on what a specific script does then please check the script file itself.
