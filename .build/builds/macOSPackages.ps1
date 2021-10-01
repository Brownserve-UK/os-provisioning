# .SYNOPSIS
#     This script builds the various packages we need to be able to bootstrap macOS deployments.
#     These packages are them copied to the relevant packer directory so they can be picked up during a deployment
[CmdletBinding()]
param ()
$ErrorActionPreference = 'Stop'

# Initialize the repository
try
{
    . (Join-Path $PSScriptRoot '..' '_init.ps1')
}
catch
{
    Write-Error "Failed to initialize the repository"
}

# Find any packages we want to build
# TODO: Param this? Could potentiall use it across multiple builds for different versions of macOS
Write-Verbose "Finding package projects to build"
try
{
    $PackagesToBuild = Get-ChildItem (Join-Path $Global:RepoRoot 'macOS' '11.X', 'packages') -Recurse -Filter "*.pkgproj" | Select-Object -ExpandProperty PSPath
}
catch
{
    Write-Error "Failed to get packages to build.`n$($_.Exception.Message)"
}
if (!$PackagesToBuild)
{
    Write-Error "Couldn't find any packages to build.`nDid you specify the right directory?"
}

# Build them!
Write-Verbose "Building packages"
try
{
    $BuiltPackages = Build-MacOSPackage $PackagesToBuild -OutputDirectory $Global:RepoBuildOutputDirectory
}
catch
{
    Write-Error $_.Exception.Message
}

# Now copy them to the packer directory so they can be used in packer builds!
Write-Verbose "Copying packages to packer directory"
try
{
    $BuiltPackages | ForEach-Object {
        Copy-Item $_ -Destination (Join-Path $Global:RepoRoot 'macOS' '11.X', 'packer', 'files') -Force
    }
}
catch
{
    Write-Error "Failed to copy built packages to packer directory.`n$($_.Exception.Message)"
}

Write-Host "Build complete" -ForegroundColor Green