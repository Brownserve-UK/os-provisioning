---
Latest tested version: 20.04.3
---

# Packer builds
## Basic
This performs a very basic build to get Ubuntu 20.04 up and running with Packer:
* Bootstraps the install using autoinstall
* Creates a `packer` user
* Gives the `packer` user `sudo` permissions with `NOPASSWD: ALL` set