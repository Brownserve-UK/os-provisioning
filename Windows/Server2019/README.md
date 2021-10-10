---
Latest tested version: 1809 (LTSC)
---

# Server2019
This directory contains our configuration for building Server2019

# Packer builds
## Basic
This build performs the bare minimum to a Server 2019 ISO to get it up and running with Packer:
* Bootstraps the install with an `autounattend.xml`
* Configures the Chocolatey package manager
* Installs PSEXEC
* Performs a sysprep generalise