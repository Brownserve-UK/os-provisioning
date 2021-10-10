<#
.SYNOPSIS
    This script contains all our build tasks for building macOS images
.DESCRIPTION
    We use Invoke-Build to help run our build pipelines and this script contains all the build tasks 
    that Invoke-Build needs to run.
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
    $ConfigurationDirectory
)
# Get the version number from the directory name
$macOSVersion = Split-Path $ConfigurationDirectory -Leaf

# Set the build output directory
$script:BuildOutputDirectory = Join-Path $Global:RepoBuildOutputDirectory "macOS_$macOSVersion"

# Synopsis: Creates the output directory
task MakeOutputDirectory {
    New-Item $script:BuildOutputDirectory -ItemType Directory -Force | Out-Null
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