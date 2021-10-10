# os-provisioning
This repo contains all our operating system deployment configuration.
We use [Packer](https://www.packer.io/) to build our gold/template images for use in things such as CI/CD pipelines, vagrant and VM creation.

# Configuration
We break down our configurations by operating system release (e.g. Windows 10, macOS 11, Ubuntu 20.04, Server 2019 etc) with each having it's own Packer configuration and tooling.  
Detailed information for each of these can be found in the README's located in their respective directories:
[Linux](Linux/README.md)
[macOS](macOS/README.md)
[Windows](Windows/README.md)
# Building
We use PowerShell to run our build pipelines across our CI/CD providers and our builds are stored in the [builds](.build/builds/) directory.  
We use [Invoke-Build](https://github.com/nightroman/Invoke-Build) to help break down our builds into simple to manage tasks, which are all found in the [./.build/tasks](.build/tasks/) directory.  
  
For more information on a given build/tasks check out the relevant script file.

## Prerequisites
Before being able to run any of the builds in the builds directory, you'll need the following:
* PowerShell Core available and on your path
* NuGet installed and available on your path
* The relevant virtualisation host (currently we only use VirtualBox but this may change in the future)
* The VirtualBox [extension pack](https://www.virtualbox.org/wiki/Downloads) (about halfway down the page)
* The relevant ISO's for the OS you want to build

## Building an OS
The [./.build/builds/Packer.ps1](.build/builds/Packer.ps1) build deals with building all of our operating system images, you'll need to pass in a directory or URL that contains all of your ISO's that you want to build and they **must** be named after their corresponding configuration directory. (e.g. if you wan't to build `Windows Server 2019` images the ISO should be named `Server2019.iso` to match the [./Windows/Server2019](Windows/Server2019/) configuration directory).  
This is done so our build logic looks to match these up to work out the relevant build process for each operating system.  
You will also need to have a corresponding `.shasum` of the ISO in the same directory (e.g for `Server2019.iso` you would need `Server2019.iso.shasum`)

By default the `Packer.ps1` build will build images for all the ISO's it has been presented with, however you can limit this to only certain operating systems by passing the `-OperatingSystemsToBuild` parameter and listing the name(s) of the operating system's that you want to build.  
For example to build only `macOS 11` and `Windows 10` you would pass `-OperatingSystemsToBuild @('macOS_11','Windows10')`
# Contributing
This repo is designed to be used and consumed by our other projects and as such it has been built with some very specific use cases in mind.  
With that said we're absolutely not opposed to taking PR's/feature requests but do bear in mind that we may not be able to accommodate every request.  
You are, of course, most welcome to fork the repository and use it for your own projects - check the LICENSE for more information.