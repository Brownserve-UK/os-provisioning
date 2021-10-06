# os-provisioning
This repo contains all our operating system deployment configuration.
We use [Packer](https://www.packer.io/) to build our 'gold images' for use in things such as CI/CD pipelines, vagrant and VM creation.

# How stuff works
We break down our configurations by operating system release (e.g. Windows 10, macOS 11, Ubuntu 20.04, Server 2019 etc) with each having it's own Packer configuration and tooling.  
Detailed information for each of these can be found in the README's located in their respective directories.

We use PowerShell to run our build pipelines across our CI/CD providers and our builds are stored in the [builds](.build/builds/) directory.  
For more information on a given build check out the script file.

# Contributing
This repo is designed to be used and consumed by our other projects and as such it has been built with some very specific use cases in mind.  
With that said we're absolutely not opposed to taking PR's/feature requests but do bear in mind that we may not be able to accommodate every request.  
You are, of course, most welcome to fork the repository and use it for your own projects - check the LICENSE for more information.