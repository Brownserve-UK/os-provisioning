# .SYNOPSIS
#     This script builds the various packages we need to be able to bootstrap macOS deployments.
#     These packages are them copied to the relevant packer directory so they can be picked up during a deployment
[CmdletBinding()]
param (
    # The path to the Python createuserpkg script
    [Parameter(
        Mandatory = $false,
        Position = 0
    )]
    [string]
    $PyCreateUserPkgPath
)
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
    $PackerFilesPath = Join-Path $Global:RepoRoot 'macOS' '11.X', 'packer', 'files'
    $BuiltPackages | ForEach-Object {
        Copy-Item $_ -Destination $PackerFilesPath -Force
    }
}
catch
{
    Write-Error "Failed to copy built packages to packer directory.`n$($_.Exception.Message)"
}

# Create the "packer" user by running pycreateuserpkg, we only do this if we've been given a path to the python script
if ($PyCreateUserPkgPath)
{
    Write-Verbose "Updating packer_user.pkg"
    if (!(Test-Path $PyCreateUserPkgPath))
    {
        throw "Cannot find createuserpkg at $PyCreateUserPkgPath"
    }
    try
    {
        Write-Verbose "Building packer_user.pkg"
        $PackerPackagePath = Join-Path $Global:RepoBuildOutputDirectory 'packer_user.pkg'
        Start-SilentProcess `
            -FilePath $PyCreateUserPkgPath `
            -ArgumentList "-n packer -f packer -p packer -u 525 -V 1 -i com.brownserveuk.packer -a -A -d $PackerPackagePath"
    }
    catch
    {
        Write-Error "Failed to update packer_user.pkg.`n$($_.Exception.Message)"
    }

    # Now copy it over to the relevant place
    try
    {
        Write-Verbose "Copying packer_user.pkg to packer directory"
        Copy-Item $PackerPackagePath -Destination $PackerFilesPath -Force
    }
    catch
    {
        Write-Error "Failed to copy packer_user.pkg.`n$($_.Exception.Message)"
    }
}

Write-Host "Build complete" -ForegroundColor Green