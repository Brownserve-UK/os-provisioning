# macOS
Within this directory you'll find the configurations for all the macOS versions we build.

# Directory structure
Within each configuration directory you'll find various files/folders, below you'll find an overview of what each of these does.
## Packages directory
These directories contain any packages that should be built during the build process, we use the amazing [Packages](http://s.sudre.free.fr/Software/Packages/about.html) application (`brew install packages --cask`) to assist in building them.  
The `.pkgproj` files contain the information needed to build them and the [Build-MacOSPackage](../../.build/code/Public/macOS/Build-MacOSPackage.ps1) PowerShell cmdlet provides a convenient way to build these en masse.  
  
Typically we employ this process to inject scripts into the macOS install and have them run during the install. 
   
For details on what specific scripts do check the script file themselves.

## Scripts directory
These directories contain any scripts that are used by Packer during the build either as provisioning steps or as files that get mounted via HTTP/floppy disk etc.  
These scripts get combined with the [common macOS scripts](scripts/) found in this directory during the build process.  
If you have 2 scripts with the same name then the OS specific script will be used (e.g. if you have `./macOS/scripts/homebrew.sh` and `./macOS/macOS_11/scripts/homebrew.sh` then the `macOS_11` version will be used)
  
For details on what a specific script does then please check the script file itself.

## Packer configuration file
You'll find a Packer configuration file in each directory such as `macOS_11.pkr.hcl` or `macOS_10.json`.  
These files contain all the steps that Packer runs through to perform a build along with build variables and configuration options.  
For more information on these check the [Packer documentation](https://www.packer.io/docs/templates)

# Building
Unfortunately macOS builds can only be built on Apple hardware at present, this is part of Apple's EULA and also our build process requires access to tooling which is only available on macOS software.

## Building macOS ISO's
The [./.build/builds/macOS_images.ps1](.build/builds/macOS_images.ps1) build assists in building ISO's for supported versions of macOS.