# This builds a vagrant image

# Tested with the below version only
packer {
  required_version = ">= 1.7.6"
}

variable "input_file" {
  type        = string
  default     = "packer-output/windows10-base.ovf"
  description = "This should point to the output of the previous build"
}

variable "checksum" {
  type        = string
  default     = "none"
  description = "The checksum of the .OVF file"
}

variable "output_directory" {
  type        = string
  default     = "packer-output"
  description = "The directory to use to store the output from this build"
}

variable "output_filename" {
  type        = string
  default     = "windows10-vagrant"
  description = "The name packer should use for the resulting build output"
}

variable "vagrant_output_directory" {
    type = string
    default = "packer-output"
    description = "The directory to store the built Vagrant box in"
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
  default     = "Administrator"
  description = "The username to use to connect to WinRM"
}

variable "winrm_password" {
  type        = string
  default     = "ItsaSecrettoEverybody1234"
  description = "The password to use to connect to WinRM"
}

variable "boot_wait" {
  type        = string
  default     = "5m"
  description = "The length of time to wait before trying to connect to WinRM"
}

variable "headless" {
  type        = bool
  default     = true
  description = "If set the VM will boot-up in the background"
}

variable "keep_vm" {
    type = bool
    default = false
    description = "If set to true, will keep the VirtualBox OVF file as well as the resulting vagrant box"
}

variable "vagrantfile_template" {
  type = string
  default = ""
  description = "The path to a vagrantfile template to use"
}

source "virtualbox-ovf" "windows10" {
  source_path          = var.input_file
  checksum             = var.checksum
  headless             = var.headless
  guest_additions_mode = "disable"
  communicator         = "winrm"
  winrm_port           = var.winrm_port
  winrm_use_ssl        = var.winrm_use_ssl
  winrm_insecure       = var.winrm_insecure
  winrm_timeout        = var.winrm_timeout
  winrm_username       = var.winrm_username
  winrm_password       = var.winrm_password
  output_directory     = var.output_directory
  output_filename      = var.output_filename
  disable_shutdown     = true
}

build {
  name    = "vagrant"
  sources = ["sources.virtualbox-ovf.windows10"]

  provisioner "powershell" {
    scripts = [
      "./files/vagrant.ps1"
    ]
  }
  post-processor "vagrant"{
      output = "${var.vagrant_output_directory}"
      keep_input_artifact = var.keep_vm
      vagrantfile_template = var.vagrantfile_template
  }
}