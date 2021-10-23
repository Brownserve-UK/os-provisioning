# This builds a vagrant box for Ubuntu 20.04

# Tested with the below version only
packer {
  required_version = ">= 1.7.6"
}

variable "input_file" {
  type        = string
  default     = "packer-output/ubuntu2004-basic.ovf"
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
  default     = "ubuntu2004-vagrant"
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

variable "headless" {
  type        = bool
  default     = true
  description = "If set the VM will boot-up in the background"
}

variable "virtualbox_guest_additions_version" {
    type = string
    default = "6.1.28"
    description = "The version of VirtualBox guest additions to be installed"
}

variable "vagrant_output_directory" {
    type = string
    default = "packer-output"
    description = "The directory to store the built Vagrant box in"
}

variable "keep_vm" {
    type = bool
    default = false
    description = "If set to true, will keep the VirtualBox OVF file as well as the resulting vagrant box"
}

source "virtualbox-ovf" "ubuntu2004" {
  source_path      = var.input_file
  checksum         = var.checksum
  headless         = var.headless
  ssh_username     = var.ssh_username
  ssh_password     = var.ssh_password
  output_directory = var.output_directory
  output_filename  = var.output_filename
  shutdown_command = "sudo shutdown -h now"
}

build {
  name    = "vagrant"
  sources = ["sources.virtualbox-ovf.ubuntu2004"]

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; echo '${var.ssh_password}' | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "./files/guest-additions.sh"
    environment_vars = [
      "VIRTUALBOX_GUEST_ADDITIONS_VERSION=${var.virtualbox_guest_additions_version}"
    ]
  }
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; echo '${var.ssh_password}' | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
    scripts = [
      "./files/sshd.sh",
      "./files/clear-machineid.sh",
      "./files/vagrant.sh"
    ]
  }
  post-processor "vagrant"{
      output = "${var.vagrant_output_directory}/{{.BuildName}}_{{.Provider}}.box"
      keep_input_artifact = var.keep_vm
  }
}