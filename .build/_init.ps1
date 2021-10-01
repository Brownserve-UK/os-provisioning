[CmdletBinding()]
param ()
$ErrorActionPreference = 'Stop'
Write-Host "Initializing repository, please wait..."
$Global:RepoBuildDirectory = Get-Item $PSScriptRoot -Force | Convert-Path # Force is needed for dot-dirs on *nix
$Global:RepoRoot = Get-Item (Join-Path $PSScriptRoot "..") -Force | Convert-Path

# Ephemeral directories
$EphemeralDirectories = @(
    ($RepoBuildOutputDirectory = Join-Path $Global:RepoBuildDirectory 'output'),
    ($RepoLogDirectory = Join-Path $Global:RepoBuildDirectory '.log')
)

try
{
    Write-Verbose "Recreating ephemeral directories"
    $EphemeralDirectories | ForEach-Object {
        if ((Test-Path $_))
        {
            Write-Verbose "Removing $_"
            Remove-Item $_ -Force -Recurse -Confirm:$false | Out-Null
        }
        New-Item $_ -ItemType Directory -Force | Out-Null
    }
}
catch
{
    Write-Error "Failed to set-up ephemeral directories.`n$($_.Exception.Message)"
}

# Now the paths should definitely exist and we can store them in global variables.
# As we're storing them globally we convert their paths to make sure they are super compatible with things
$Global:RepoLogDirectory = $RepoLogDirectory | Convert-Path
$Global:RepoBuildOutputDirectory = $RepoBuildOutputDirectory | Convert-Path

# Import the PowerShell module
Write-Verbose "Importing repo module"
try
{
    Import-Module (Join-Path $Global:RepoBuildDirectory 'module' 'os-provisioning.psm1') -Force
}
catch
{
    Write-Error "Failed to import the repo's PowerShell module.`n$($_.Exception.Message)"
}