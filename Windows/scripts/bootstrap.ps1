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

# So doing a sysprep kills the network driver which obviously kills WinRM...
# So we'll run it as the shutdown command in Packer, we'll need to do this as SYSTEM though which requires PSEXEC.
choco install psexec --confirm --ignore-checksums

### THIS SHOULD ALWAYS BE THE LAST STEP ###
Enable-WinRM
### This is because once WinRM is enabled it signals packer to continue on with provisioning. ###