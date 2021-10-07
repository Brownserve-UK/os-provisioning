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

### THIS SHOULD ALWAYS BE THE LAST STEP ###
Enable-WinRM
### This is because once WinRM is enabled it signals packer to continue on with provisioning. ###