<#
.SYNOPSIS
    Builds our macOS images
#>
[CmdletBinding()]
param ()
# Always stop on errors
$ErrorActionPreference = 'Stop'

Write-Host "Starting build $($MyInvocation.MyCommand)"

# dot source the _init.ps1 script
try
{
    Write-Verbose "Initialising repo"
    $initScriptPath = Join-Path $PSScriptRoot '..' '_init.ps1' | Convert-Path
    . $initScriptPath
}
catch
{
    Write-Error "Failed to init repo.`n$($_.Exception.Message)"
}

# First we need to get the list of macOS versions we currently build for
$macOSVersions = Get-ChildItem (Join-Path $Global:RepoRootDirectory 'macOS') | Where-Object { $_.PSIsContainer }

$macOSVersions | ForEach-Object {
    Write-Verbose "Now preparing to build macOS $($_.Name)"

    $BuildOutputDirectory = Join-Path $Global:RepoBuildOutputDirectory "macOS_$($_.Name)"
    New-Item $BuildOutputDirectory -ItemType Directory -Force | Out-Null
    Write-Verbose "Build artifacts will be stored in $BuildOutputDirectory"

    # Create the directory for things that get passed into packer builds, either via HTTP or via provisioners
    $script:PackerFilesDirectory = New-Item (Join-Path $BuildOutputDirectory 'files') -ItemType Directory -Force
    # Create the directory for storing the ISO/images
    $script:PackerImagesDirectory = New-Item (Join-Path $BuildOutputDirectory 'images') -ItemType Directory -Force

    # Build our ISO

    # Find out what items we have in our version directory
    $VersionChildItems = Get-ChildItem $_

    # We need to build any packages that are needed for these builds
    $PackageDir = $VersionChildItems | Where-Object { $_.Name -eq 'packages' } | Select-Object -ExpandProperty PSPath | Convert-Path
    if ($PackageDir)
    {
        Write-Verbose "Building custom packages"
        $PackagesToBuild = Get-ChildItem $PackageDir -Recurse -Filter "*.pkgproj" | Select-Object -ExpandProperty PSPath
        Build-MacOSPackage -PackageProjectPath $PackagesToBuild -OutputDirectory $script:PackerFilesDirectory -Verbose:($PSBoundParameters['Verbose'] -eq $true) | Out-Null
    }

    # If we've got custom scripts we'll need to copy those over too
    $ScriptsDir = $VersionChildItems | Where-Object { $_.Name -eq 'scripts' } | Select-Object -ExpandProperty PSPath | Convert-Path
    if ($ScriptsDir)
    {
        Write-Verbose "Copying deployment scripts"
        Get-ChildItem $ScriptsDir -Recurse | Copy-Item -Destination $script:PackerFilesDirectory
    }

    # Now we can run the packer build(s)
    
}

Write-Host "Build $($MyInvocation.MyCommand) completed successfully! 🎉" -ForegroundColor Green