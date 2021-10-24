<#
.SYNOPSIS
    Short description
#>
$ErrorActionPreference = 'Stop'

# Install VirtualBox guest additions
choco install virtualbox-guest-additions-guest.install -y

# Check if we're on Server Core
$regKey = "hklm:/software/microsoft/windows nt/currentversion"
$Core = (Get-ItemProperty $regKey).InstallationType -eq "Server Core"

# Disable UAC (if not on server core)
if (!$Core)
{
    Write-Host "Disabling UAC"
    Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\policies\system' -Name 'EnableLUA' -Value 0
}

# Disable Password complexity
& secedit /export /cfg c:\secpol.cfg
(Get-Content C:\secpol.cfg).replace("PasswordComplexity = 1", "PasswordComplexity = 0") | Out-File C:\secpol.cfg
& secedit /configure /db c:\windows\security\local.sdb /cfg c:\secpol.cfg /areas SECURITYPOLICY
Remove-Item -force c:\secpol.cfg -confirm:$false

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