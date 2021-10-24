<#
.SYNOPSIS
    Configures a machine to be ready for Vagrant for Windows 10
#>

# Set the execution policy
# Ignore errors on this one as sometimes we get a false-positive error
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine -Force -Confirm:$false -ErrorAction 'Continue'

$ErrorActionPreference = 'Stop'

# Install VirtualBox guest additions
choco install virtualbox-guest-additions-guest.install -y

# Disable UAC
Write-Host "Disabling UAC"
Set-ItemProperty -path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\policies\system' -Name 'EnableLUA' -value 0

# Create the Vagrant user
Write-Host "Setting up vagrant user"
New-LocalUser `
    -Name 'vagrant' `
    -Description 'Well known vagrant account' `
    -Password (ConvertTo-SecureString 'vagrant' -AsPlainText -Force) `
    -AccountNeverExpires `
    -PasswordNeverExpires `
    -UserMayNotChangePassword `
    -Confirm:$false

# Change the password of the Admin account
Write-Host "Changing Administrator password"
Set-LocalUser `
    -Name 'Administrator' `
    -Password (ConvertTo-SecureString 'vagrant' -AsPlainText -Force) `
    -AccountNeverExpires `
    -PasswordNeverExpires $true `
    -Confirm:$false

# Finally shutdown the machine - we do this here instead of via Packer as we've changed the Administrator password
# meaning Packer will fail to issue the shutdown command itself
Stop-Computer -Confirm:$false