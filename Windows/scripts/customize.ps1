<#
.SYNOPSIS
    This script contains the functions we use to customize Brownserve builds
#>

# Install dotnet sdk, we use it for a bunch of stuff
choco install dotnet-sdk -y

# So doing a sysprep kills the network driver which obviously kills WinRM...
# So we'll run it as the shutdown command in Packer, we'll need to do this as SYSTEM though which requires PSEXEC.
choco install psexec --confirm --ignore-checksums

# Install our Brownserve.PSTools module, as it's a PoSh core module do it in PoSh core!
$ScriptToRun = {Install-Module -Name 'Brownserve.PSTools' -Repository PSGallery -Scope AllUsers -Force -Confirm:$false}
& pwsh -command $ScriptToRun
