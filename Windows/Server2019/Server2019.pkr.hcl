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

variable "floppy_directory" {
  type        = string
  default     = "files/"
  description = "The directory to be mounted as a floppy disk"
}

variable "winrm_port" {
  type        = number
  default     = 5986
  description = "The port that Packer can expect to find WinRM on"
}

variable "winrm_use_ssl" {
  type    = bool
  default = true
}

variable "winrm_insecure" {
  type    = bool
  default = true
}

variable "winrm_timeout" {
  type        = string
  default     = "1h"
  description = "The length of time to wait before WinRM is available"
}

variable "winrm_username" {
  type        = string
  default     = "packer"
  description = "The username to use to connect to WinRM"
}

variable "winrm_password" {
  type        = string
  default     = "packer"
  description = "The password to use to connect to WinRM"
}

variable "sysprep_command" {
  type        = string
  default     = "psexec -accepteula -s C:/windows/system32/sysprep/sysprep.exe /generalize /oobe /quiet /shutdown"
  description = "The command that should be used to sysprep the machine"
}

variable "boot_wait" {
  type        = string
  default     = "10m"
  description = "The length of time to wait before trying to connect to WinRM"
}

variable "output_directory" {
  type        = string
  default     = "packer-output"
  description = "The directory packer should use to output build artifacts"
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
  shutdown_command     = "${var.sysprep_command}"
  communicator         = "winrm"
  floppy_dirs          = "${var.floppy_directory}"
  iso_url              = "${var.iso_filename}"
  iso_checksum         = "${var.iso_file_checksum}"
  winrm_port           = var.winrm_port
  winrm_use_ssl        = var.winrm_use_ssl
  winrm_insecure       = var.winrm_insecure
  winrm_timeout        = "${var.winrm_timeout}"
  winrm_username       = "${var.winrm_username}"
  winrm_password       = "${var.winrm_password}"
  boot_wait            = var.boot_wait
  output_directory     = var.output_directory
}

# This builds a very basic image from an ISO
build {
  name    = "basic"
  sources = ["sources.virtualbox-iso.server2019-iso"]
}