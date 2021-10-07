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
  
For details on what a specific script does then please check the script file itself.

## Packer configuration file
You'll find a Packer configuration file in each directory such as `macOS_11.pkr.hcl` or `macOS_10.json`.  
These files contain all the steps that Packer runs through to perform a build along with build variables and configuration options.  
For more information on these check the [Packer documentation](https://www.packer.io/docs/templates)

# Building
## Prerequisites
Along with our [general prerequisites] you'll also need:
* The relevant macOS installer(s) downloaded
* [pycreateuserpkg](https://github.com/gregneagle/pycreateuserpkg) downloaded and available

## Builds
To build macOS images you'll need to run the [build script](../.build/builds/macOS.ps1) this one script will take care of building every supported version of macOS.  
You'll need to provide the path to the `createuserpkg` script we downloaded earlier and you may also wish to enable verbose output to see detailed information on the build
```powershell
./.build/builds/macOS.ps1 -PyCreateUserPkgPath ~/downloads/pycreateuserpkg/createuserpkg -Verbose
```

>Note: the build requires sudo permissions during one phase, depending on your settings you may be asked to enter your password during the build.
  
Artifacts from the build will be stored in `./.build/output/macOS11`