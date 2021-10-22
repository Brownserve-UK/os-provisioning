# Tested with the below version only
packer {
  required_version = ">= 1.7.6"
}

variable "iso_file_checksum" {
  type    = string
  default = "file:images/Ubuntu2004.iso.shasum"
  description = "The checksum for the Ubuntu ISO"
}

variable "iso_url" {
  type    = string
  default = "images/Ubuntu2004.iso"
  description = "The Ubuntu ISO to use for this build"
}

variable "http_directory" {
  type    = string
  default = "files"
  description = "The directory to use as our HTTP server (so we can get to our bootstrap files)"
}

variable "output_directory" {
  type = string
  default = "packer-output"
  description = "The directory to use to store the output from this build"
}

variable "output_filename" {
  type        = string
  default     = "Ubuntu2004"
  description = "The name packer should use for the resulting build output"
}

variable "ssh_password" {
  type    = string
  default = "vagrant"
}

variable "ssh_username" {
  type    = string
  default = "vagrant"
}

# Depending on the host system speed it can be a while before SSH is ready
variable "ssh_timeout" {
  type    = string
  default = "70m"
}

# Again depending on the host system it can take a while before the VM first boots...
# If you find you're not getting to the recovery mode terminal then adjust these timings.
variable "boot_wait_iso" {
  type    = string
  default = "5s"
}

variable "boot_key_interval_iso" {
  type    = string
  default = "150ms"
}

variable "boot_keygroup_interval_iso" {
  type    = string
  default = "2s"
}

variable "memory" {
  type = number
  default = 4096
}

variable "cpus" {
  type = number
  default = 2
}

variable "headless" {
  type        = bool
  default     = true
  description = "If set the VM will boot-up in the background"
}

source "virtualbox-iso" "ubuntu2004" {
  guest_os_type        = "Ubuntu_64"
  guest_additions_mode = "disable"
  headless             = var.headless
  firmware             = "efi"
  disk_size            = "20000"
  gfx_vram_size        = "128"
  memory               = var.memory
  cpus                 = var.cpus
  hard_drive_interface = "sata" # pcie would be better but: https://github.com/hashicorp/packer-plugin-virtualbox/issues/10
  iso_interface        = "sata"
  shutdown_command     = "sudo shutdown -h now"
  vboxmanage = [
    ["storagectl", "{{.Name}}", "--name", "IDE Controller", "--remove"],
  ]
  http_directory         = "${var.http_directory}"
  iso_url                = "${var.iso_url}"
  iso_checksum           = "${var.iso_file_checksum}"
  ssh_username           = "${var.ssh_username}"
  ssh_password           = "${var.ssh_password}"
  boot_wait              = var.boot_wait_iso
  boot_keygroup_interval = var.boot_keygroup_interval_iso
  ssh_timeout            = var.ssh_timeout
  output_directory       = var.output_directory
  output_filename        = var.output_filename
  boot_command = [
    "<esc><wait>",
    "<esc><wait>",
    "linux /casper/vmlinuz --- autoinstall ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/bootstrap/\"<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>"
  ]
}

# This builds a very basic image from a vanilla ISO
build {
  name    = "basic"
  sources = ["sources.virtualbox-iso.ubuntu2004"]
}