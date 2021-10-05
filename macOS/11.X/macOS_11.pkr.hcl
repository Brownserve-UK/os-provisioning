# Tested with the below version only
packer {
  required_version = ">= 1.7.6"
}

variable "iso_file_checksum" {
  type    = string
  default = "file:images/macOS_11.shasum"
  description = "The checksum for the macOS ISO"
}

variable "iso_filename" {
  type    = string
  default = "images/macOS_11.iso"
  description = "The macOS ISO to use for this build"
}

variable "http_directory" {
  type    = string
  default = "files"
  description = "The directory to use as our HTTP server (so we can get to our bootstrap files)"
}

variable "output_directory" {
  type = string
  default = "output-macOS11"
  description = "The directory to use to store the output from this build"
}

variable "ssh_password" {
  type    = string
  default = "packer"
}

variable "ssh_username" {
  type    = string
  default = "packer"
}

# Depending on the host system speed it can be a while before SSH is ready
variable "ssh_timeout" {
  type    = string
  default = "60m"
}

# Again depending on the host system it can take a while before the VM first boots...
# If you find you're not getting to the recovery mode terminal then adjust these timings.
variable "boot_wait_iso" {
  type    = string
  default = "200s"
}

variable "boot_key_interval_iso" {
  type    = string
  default = "150ms"
}

variable "boot_keygroup_interval_iso" {
  type    = string
  default = "2s"
}

source "virtualbox-iso" "macos11-vanilla" {
  guest_os_type        = "MacOS1013_64"
  guest_additions_mode = "disable"
  firmware             = "efi"
  disk_size            = "60000"
  gfx_vram_size        = "128"
  memory               = 4096
  cpus                 = 2
  hard_drive_interface = "sata" # pcie would be better but: https://github.com/hashicorp/packer-plugin-virtualbox/issues/10
  iso_interface        = "sata"
  audio_controller     = "hda"
  chipset              = "ich9"
  nic_type             = "82545EM"
  shutdown_command     = "sudo shutdown -h now"
  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--hpet", "on"],
    ["modifyvm", "{{.Name}}", "--keyboard", "usb"],
    ["modifyvm", "{{.Name}}", "--mouse", "usbtablet"],
    ["storagectl", "{{.Name}}", "--name", "IDE Controller", "--remove"],
  ]
  http_directory         = "${var.http_directory}"
  iso_url                = "${var.iso_filename}"
  iso_checksum           = "${var.iso_file_checksum}"
  ssh_username           = "${var.ssh_username}"
  ssh_password           = "${var.ssh_password}"
  boot_wait              = var.boot_wait_iso
  boot_keygroup_interval = var.boot_keygroup_interval_iso
  ssh_timeout            = var.ssh_timeout
  output_directory       = var.output_directory
  boot_command = [
    "<enter><wait10s>",
    "<leftSuperon><f5><leftSuperoff>",
    "<leftCtrlon><f2><leftCtrloff>",
    "u<down><down><down>",
    "<enter>",
    "<leftSuperon><f5><leftSuperoff><wait10>",
    "<leftCtrlon><f2><leftCtrloff>",
    "w<down><down>",
    "<enter>",
    "curl -o /var/root/packer_user.pkg http://{{ .HTTPIP }}:{{ .HTTPPort }}/packer_user.pkg<enter>",
    "curl -o /var/root/oobe.pkg http://{{ .HTTPIP }}:{{ .HTTPPort }}/oobe.pkg<enter>",
    "curl -o /var/root/configure_ssh.pkg http://{{ .HTTPIP }}:{{ .HTTPPort }}/configure_ssh.pkg<enter>",
    "curl -o /var/root/bootstrap.sh http://{{ .HTTPIP }}:{{ .HTTPPort }}/bootstrap.sh<enter>",
    "chmod +x /var/root/bootstrap.sh<enter>",
    "/var/root/bootstrap.sh<enter>"
  ]
}

# This builds a very basic image from a vanilla ISO
build {
  name    = "basic"
  sources = ["sources.virtualbox-iso.macos11-vanilla"]
}