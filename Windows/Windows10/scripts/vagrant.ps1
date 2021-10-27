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
Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\policies\system' -Name 'EnableLUA' -Value 0

# Create the Vagrant user
Write-Host "Setting up vagrant user"
$VagrantUsername = 'vagrant'
$VagrantPassWord = (ConvertTo-SecureString 'vagrant' -AsPlainText -Force)
New-LocalUser `
    -Name $VagrantUsername `
    -Description 'Well known vagrant account' `
    -Password $VagrantPassWord `
    -AccountNeverExpires `
    -PasswordNeverExpires `
    -UserMayNotChangePassword `
    -Confirm:$false

# Add vagrant to local admins
Add-LocalGroupMember `
    -Group 'Administrators' `
    -Member 'vagrant' `
    -Confirm:$false

# We need to login as the user one time so their profile gets created, we do this by spawning a Powershell session
$Credential = [pscredential]$Credential = New-Object System.Management.Automation.PSCredential ($VagrantUsername, $VagrantPassWord)
try
{
    Start-Process powershell -ErrorAction Stop -Credential $Credential -ArgumentList "exit" -Wait -NoNewWindow
}
catch
{
    throw "Failed to login as supplied user, are you sure the credentials are correct?.`n$($_.Exception.Message)"
}

# Add the well-known vagrant public ssh key
# Make sure that the .ssh directory exists in your server's user account home folder
$AdminSSHPath = 'C:\ProgramData\ssh\'
if (!(Test-Path $AdminSSHPath))
{
    New-Item $AdminSSHPath -ItemType Directory -Force
}

$AuthorizedKeys = Join-Path $AdminSSHPath 'administrators_authorized_keys'
try
{
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub' -OutFile $AuthorizedKeys
}
catch
{
    throw $_.Exception.Message   
}

# Appropriately ACL the authorized_keys file on your server
& icacls.exe $AuthorizedKeys /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"

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