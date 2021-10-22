# This builds a more customised Ubuntu 18.04 image

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
  default     = "ubuntu2004-customized"
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

variable "local_admin_username" {
  type        = string
  default     = "admin"
  description = "The account to be used as a local admin on the machine, this should be passed in as a variable to keep it secure"
}

variable "local_admin_password" {
  type        = string
  default     = "admin"
  description = "The password for the local administrator account, this should be passed in as a variable to keep it secure"
}

source "virtualbox-ovf" "ubuntu2004" {
  source_path      = var.input_file
  checksum         = var.checksum
  headless         = var.headless
  ssh_username     = var.ssh_username
  ssh_password     = var.ssh_password
  output_directory = var.output_directory
  output_filename  = var.output_filename
  shutdown_command = "sudo su ${var.local_admin_username} -c \"sudo userdel -rf ${var.ssh_username}; sudo rm /etc/sudoers.d/${var.ssh_username}; sudo /sbin/shutdown -hP now\""
}

build {
  name    = "customized"
  sources = ["sources.virtualbox-ovf.ubuntu2004"]

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; echo '${var.ssh_password}' | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "./files/local_admin.sh"
    environment_vars = [
      "LOCAL_ADMIN_USERNAME=${var.local_admin_username}",
      "LOCAL_ADMIN_PASSWORD=${var.local_admin_password}"
    ]
  }
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; echo '${var.ssh_password}' | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
    scripts = [
      "./files/sshd.sh",
      "./files/clear-machineid.sh"
    ]
  }
}