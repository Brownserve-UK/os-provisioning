<#
.SYNOPSIS
    Bootstraps our OS deployment
.DESCRIPTION
    Long description
#>

Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force -ErrorAction Ignore
$ErrorActionPreference = 'Stop'

# dot source our functions (should always be in the a:\ drive)
. a:\functions.ps1

# We need chocolatey so we can grab PSExec
Install-Chocolatey

# Install PowerShell core
choco install powershell-core -y

# The NuGet provider is required to be able to install PSWindowsUpdate, we'll also take this time to update/install the PowerShellGet module
$ScriptToRun = {Install-PackageProvider -Name 'NuGet' -Scope AllUsers -Force -Confirm:$false
Install-PackageProvider -Name 'PowerShellGet' -Scope AllUsers -Force -Confirm:$false}

# First do it in PowerShell for Windows Desktop
Invoke-Command $ScriptToRun

# Then do it in PowerShell Core
# See if PowerShell Core is on the Path yet...
$pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
# If not do it the old fashioned way
if (!$pwshPath)
{
    $pwshPath = 'C:\Program Files\PowerShell\7\pwsh.exe'
}

& $pwshPath -command $ScriptToRun

# Install the PSWindowsUpdate module 
Install-Module -Name PSWindowsUpdate -Repository PSGallery -Scope AllUsers -Force -Confirm:$false

# Import the module
Import-Module PSWindowsUpdate -Force

# Install any updates, we ignore reboots as that'll be taken care of by Packer later on.
Install-WindowsUpdate -AcceptAll -IgnoreReboot

# Cleanup after ourselves by disabling our auto logon
$RegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty $RegistryPath 'AutoAdminLogon' -Value "0" -Type String 
Set-ItemProperty $RegistryPath 'DefaultUsername' -Value "" -type String

### THIS SHOULD ALWAYS BE THE LAST STEP ###
Enable-WinRM
### This is because once WinRM is enabled it signals packer to continue on with provisioning. ###