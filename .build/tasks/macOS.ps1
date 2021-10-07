<#
.SYNOPSIS
    This script contains all our build tasks for macOS.
.DESCRIPTION
    We use Invoke-Build to help run our build pipelines and this script contains all the build tasks 
    that Invoke-Build needs to run.
.EXAMPLE
    Invoke-Build `
        -File ./.build/tasks/macOS.ps1 `
        -Task BuildPackerImages `
        -ConfigurationDirectory (Convert-Path ./macOS/11/) `
        -PyCreateUserPkgPath ~/Documents/Repos/Personal/pycreateuserpkg/createuserpkg 

    This would run the "BuildPackagerImages" task.
.NOTES
    N/A
#>
[CmdletBinding()]
param
(
    # The path to the macOS build configuration
    [Parameter(
        Mandatory = $true
    )]
    [string]
    $ConfigurationDirectory,

    # The path to PyCreateUserPkgPath
    [Parameter(
        Mandatory = $false
    )]
    [string]
    $PyCreateUserPkgPath
)
# Get the version number from the directory name
$macOSVersion = Split-Path $ConfigurationDirectory -Leaf

# Set the build output directory
$script:BuildOutputDirectory = Join-Path $Global:RepoBuildOutputDirectory "macOS_$macOSVersion"

# Synopsis: Creates the output directory
task MakeOutputDirectory {
    New-Item $script:BuildOutputDirectory -ItemType Directory -Force | Out-Null
    # Create the directory for things that get passed into packer builds, either via HTTP or via provisioners
    $script:PackerFilesDirectory = New-Item (Join-Path $BuildOutputDirectory 'files') -ItemType Directory -Force
    # Create the directory for storing the ISO/images
    $script:PackerImagesDirectory = New-Item (Join-Path $BuildOutputDirectory 'images') -ItemType Directory -Force
}

# Synopsis: Builds a macOS ISO
task BuildISO MakeOutputDirectory, {
    # Find the path to our installer
    $InstallerPath = Get-MacOSInstallerPath $macOSVersion

    <# 
        Unfortunately we need to build the ISO as root and PowerShell doesn't have a super neat way of sudo'ing
        while retaining the current environment 😞
        So we create a script block and invoke a new process using sudo to call PowerShell and pass in our scriptblock.
        The cool thing is that PowerShell returns output exactly as it is meaning we can get objects returned.
        This means we can easily consume those back in our calling process!! 🎉
    #>
    $ScriptToRun = { param($InstallerPath, $PackerImagesDirectory)
        try
        {
            # We want to avoid our usual spam as it pollutes the return object
            $Global:BrownserveCmdlets = @{
                CompatibleCmdlets   = @()
                IncompatibleCmdlets = @()
            }
            Import-Module ./packages/Brownserve.PSTools/tools/Brownserve.PSTools.psd1 -Force
            Import-Module ./.build/code/os-provisioning.psm1 -Force

            Build-MacOSImage `
                -MacOSInstallerPath $InstallerPath `
                -OutputDirectory $PackerImagesDirectory `
                -CreateISO `
                -DiscardDMG `
                -Verbose
        }
        catch
        {
            throw \"Failed to build ISO.`n$($_.Exception.Message)\"
        }
    }

    # Build the ISO
    Write-Host "macOS ISO creation requires SUDO permissions.`nDepending on your settings you may now be prompted for your password."
    $macOSImage = sudo pwsh -Noninteractive -Command $ScriptToRun -Args @($InstallerPath, $script:PackerImagesDirectory) -WorkingDirectory $global:RepoRootDirectory

    $script:PackerVariables = @{
        iso_filename      = $macOSImage.ISOPath
        iso_file_checksum = $macOSImage.ISOSHASum
    }
}

# Synopsis: Builds any macOS packages that are required for this build
task BuildPackages MakeOutputDirectory, {
    $PackagesDirectory = Join-Path $ConfigurationDirectory 'packages'
    try
    {
        $PackagesToBuild = Get-ChildItem $PackagesDirectory `
            -Recurse `
            -Filter "*.pkgproj" | Select-Object -ExpandProperty PSPath
    }
    catch
    {
        # Don't error - we probably don't have any packages?
    }
    if ($PackagesToBuild)
    {
        Build-MacOSPackage `
            -PackageProjectPath $PackagesToBuild `
            -OutputDirectory $script:PackerFilesDirectory `
            -Verbose:($PSBoundParameters['Verbose'] -eq $true) | Out-Null
    }

    # Create the "packer" user by running pycreateuserpkg
    # we only do this if we've been given a path to the python script
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
    
}

# Synopsis: copies over any custom scripts required for the build
task CopyScripts MakeOutputDirectory, {
    $ScriptsDirectory = Join-Path $ConfigurationDirectory 'scripts'
    if ((Test-Path $ScriptsDirectory))
    {
        Write-Verbose "Copying deployment scripts"
        Get-ChildItem $ScriptsDirectory -Recurse | Copy-Item -Destination $script:PackerFilesDirectory
    }
}

task BuildPackerImages CopyScripts, BuildPackages, BuildISO, MakeOutputDirectory, {
    $PackerBuilds = Get-ChildItem $ConfigurationDirectory | 
        Where-Object { $_.Name -match ".hcl|.json" } | 
            Select-Object -ExpandProperty PSPath
    if (!$PackerBuilds)
    {
        throw "No Packer builds found for $ConfigurationDirectory"
    }
    $PackerBuilds | ForEach-Object {
        # First validate the config
        Invoke-PackerValidate `
            -PackerTemplate (Convert-Path $_) `
            -WorkingDirectory $script:BuildOutputDirectory `
            -TemplateVariables $script:PackerVariables `
            -Verbose:($PSBoundParameters['Verbose'] -eq $true)
        # Then build
        Invoke-PackerBuild `
            -PackerTemplate (Convert-Path $_) `
            -WorkingDirectory $script:BuildOutputDirectory `
            -TemplateVariables $script:PackerVariables `
            -Verbose:($PSBoundParameters['Verbose'] -eq $true)
    }
}