# Tested with the below version only
packer {
  required_version = ">= 1.7.6"
}

variable "iso_file_checksum" {
  type        = string
  default     = "file:images/Server2019.iso.shasum"
  description = "The checksum for the Server 2019 ISO"
}

variable "iso_filename" {
  type        = string
  default     = "images/Server2019.iso"
  description = "The Server 2019 ISO to use for this build"
}

source "virtualbox-iso" "server2019-iso" {
  guest_os_type        = "Windows2019_64"
  guest_additions_mode = "disable"
  firmware             = "efi"
  disk_size            = "40000"
  gfx_vram_size        = "128"
  memory               = 4096
  cpus                 = 2
  hard_drive_interface = "sata"
  iso_interface        = "sata"
  chipset              = "piix3"
  shutdown_command     = "sudo shutdown -h now"
  communicator         = "winrm"
  floppy_files         = "${var.floppy_files}"
  iso_url              = "${var.iso_filename}"
  iso_checksum         = "${var.iso_file_checksum}"
  winrm_port           = var.winrm_port
  winrm_use_ssl        = var.winrm_use_ssl
  winrm_insecure       = var.winrm_insecure
  winrm_timeout        = var.winrm_timeout
  winrm_username       = "${var.winrm_username}"
  winrm_password       = "${var.winrm_password}"
  boot_wait            = var.boot_wait_iso
  output_directory     = var.output_directory
}