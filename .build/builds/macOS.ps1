<#
.SYNOPSIS
    Builds our macOS images
#>
[CmdletBinding()]
param
(
    # The path to PyCreateUserPkgPath
    [Parameter(
        Mandatory = $false
    )]
    [string]
    $PyCreateUserPkgPath
)
# Always stop on errors
$ErrorActionPreference = 'Stop'

if (!$IsMacOS)
{
    throw "This build can only currently be run on Apple hardware, sorry!"
}

Write-Host "Starting build $($MyInvocation.MyCommand)"

# We don't dot source the _init script in this build as we run as root and it creates problems with
# our ephemeral paths :(
# We could potentially lock this build behind a CI/CD moniker if we need to, but for now let's just try running
# _init before all our builds :)

if (!$Global:RepoRootDirectory)
{
    throw "Cannot find '`$global:RepoRootDirectory' have you run the _init.ps1 script?"
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

    # Create the "packer" user by running pycreateuserpkg, we only do this if we've been given a path to the python script
    if ($PyCreateUserPkgPath)
    {
        Write-Verbose "Updating packer_user.pkg"
        if (!(Test-Path $PyCreateUserPkgPath))
        {
            throw "Cannot find pycreateuserpkg at $PyCreateUserPkgPath"
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
            Copy-Item $PackerPackagePath -Destination $script:PackerFilesDirectory -Force
        }
        catch
        {
            Write-Error "Failed to copy packer_user.pkg.`n$($_.Exception.Message)"
        }
    }

    # If we've got custom scripts we'll need to copy those over too
    $ScriptsDir = $VersionChildItems | Where-Object { $_.Name -eq 'scripts' } | Select-Object -ExpandProperty PSPath | Convert-Path
    if ($ScriptsDir)
    {
        Write-Verbose "Copying deployment scripts"
        Get-ChildItem $ScriptsDir -Recurse | Copy-Item -Destination $script:PackerFilesDirectory
    }

    # Now we can run the packer build(s)
    Get-ChildItem $VersionChildItems | Where-Object { $_.Name -match ".hcl|.json" } | Select-Object -ExpandProperty PSPath | ForEach-Object {
        Invoke-PackerValidate (Convert-Path $_) -WorkingDirectory $BuildOutputDirectory
        Invoke-PackerBuild (Convert-Path $_) -WorkingDirectory $BuildOutputDirectory
    }
}

Write-Host "Build $($MyInvocation.MyCommand) completed successfully! 🎉" -ForegroundColor Green