# Windows
Within this directory you will found our build configurations for all of the Windows versions that we build.

# Directory structure
Within each configuration directory you'll find various files/folders, below you'll find an overview of what each of these does.

## Autounattend directory
Windows installs can automatically bootstrap themselves if they detect the presence of an `autounattend.xml` file on an attached floppy drive.  
As each Windows ISO supports several versions of Windows (e.g. `Server 2019 Standard`, `Server 2019 Datacenter` etc) we need to create an autounattend for each version that we want to build for.  
Our build process will copy these over to an attached floppy drive and rename it to `autounattend.xml`

## Scripts directory
These directories contain any scripts that are used by Packer during the build either as provisioning steps or as files that get mounted via HTTP/floppy disk etc.  
These scripts get combined with the [common Windows scripts](scripts/) found in this directory during the build process.  
If you have 2 scripts with the same name then the OS specific script will be used (e.g. if you have `./Windows/scripts/functions.ps1` and `./Windows/Server2019/scripts/functions.ps1` then the `Server2019` version will be used)
  
For details on what a specific script does then please check the script file itself.

## Packer configuration file
You'll find a Packer configuration file in each directory such as `Server2019.pkr.hcl` or `Server2019.json`.  
These files contain all the steps that Packer runs through to perform a build along with build variables and configuration options.  
For more information on these check the [Packer documentation](https://www.packer.io/docs/templates)