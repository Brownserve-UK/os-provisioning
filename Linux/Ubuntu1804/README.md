---
Latest tested version: 18.04.6
---

>⚠️ This only works on the *non-live* ISO's, as the live installers use subiquity which isn't compatible with preseed files. To get non-live installers head to http://cdimage.ubuntu.com/ubuntu/releases/18.04/release/

# Packer builds
## Basic
This performs a very basic build to get Ubuntu 20.04 up and running with Packer:
* Bootstraps the install using preseed
* Copies over a "catchall" netplan file (this is needed due to the variance in network interface names that can be spawned)
* Creates a `packer` user
* Gives the `packer` user `sudo` permissions with `NOPASSWD: ALL` set