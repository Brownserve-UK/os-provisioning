---
Latest tested version: 21H1
---

# Windows 10
This directory contains our configuration for building Windows 10

# Packer builds
## Basic
This build performs the bare minimum to a Windows 10 ISO to get it up and running with Packer:
* Bootstraps the install with an `autounattend.xml`
* Configures the Chocolatey package manager
* Installs PSEXEC
* Performs a sysprep generalise