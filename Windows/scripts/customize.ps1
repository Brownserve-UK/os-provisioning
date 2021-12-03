<#
.SYNOPSIS
    This script contains the functions we use to customize Brownserve builds
#>

# Install dotnet sdk, we use it for a bunch of stuff
choco install dotnet-sdk -y

# So doing a sysprep kills the network driver which obviously kills WinRM...
# So we'll run it as the shutdown command in Packer, we'll need to do this as SYSTEM though which requires PSEXEC.
choco install psexec --confirm --ignore-checksums

# Install our Brownserve.PSTools and Puppet-PowerShell modules
# We need to do this via pwsh as they are not compatible with PowerShell Desktop
$ScriptToRun = {
    $ErrorActionPreference = 'Stop'
    @('Brownserve.PSTools', 'PuppetPowerShell') | 
        ForEach-Object { Install-Module -Name $_ -Repository PSGallery -Scope AllUsers -Force -Confirm:$false }
}
& pwsh -Command $ScriptToRun
