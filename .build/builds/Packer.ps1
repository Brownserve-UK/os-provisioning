<#
.SYNOPSIS
    Builds all of our Packer images
.DESCRIPTION
    This build acts as a wrapper for our Packer build pipelines.
    It will take ISO's from a given directory or URL and build any that have a matching configuration in this
    repository.
.NOTES
    - ISO names *must* match their build configurations (e.g. 'macOS_11.iso', 'server2019.iso' etc)
    - When your ISO's are on slow storage (e.g. URL's/fileshare's) set the 'CopyISO' switch to have them copied locally
    - Use the "IncludedOperatingSystems" and "ExcludedOperatingSystems" to limit builds to just those you want 
#>
#Requires -Version 6.0
[CmdletBinding()]
param
(
    # The path to where the ISO's are located, can either be a URL or a local path (including fileshare's)
    [Parameter(Mandatory = $true, Position = 0)]
    [string]
    $ISOPath,

    # Setting this parameter limits builds to only those specified
    [Parameter(Mandatory = $false, Position = 1)]
    [Alias('Include')]
    [array]
    $IncludedOperatingSystems,

    # Any operating systems specified here will be ignored
    [Parameter(Mandatory = $false, Position = 2)]
    [Alias('Exclude')]
    [array]
    $ExcludedOperatingSystems,

    # If specified the completed packer build artifacts are copied to the given directory
    [Parameter(Mandatory = $false, Position = 3)]
    [string]
    $CopyBuildArtifactsTo,

    # If set will copy the ISO's to the local build output directory, handy if your ISO's are on slow storage
    [Parameter(Mandatory = $false)]
    [switch]
    $CopyISO
)
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

# First get packer!
Write-Verbose "Downloading Packer"
try
{
    Get-Packer -DownloadPath $global:RepoBinDirectory
}
catch
{
    
}
# We start off by getting a list of ISO's we are building for
try
{
    $ISOs = Get-ISOInformation -ISOPath $ISOPath
}
catch
{
    throw $_.Exception.Message
}

# Now get our list of build configurations that we run
$OSDirectories = @(
    (Join-Path $Global:RepoRootDirectory 'Linux'),
    (Join-Path $Global:RepoRootDirectory 'macOS'),
    (Join-Path $Global:RepoRootDirectory 'Windows')
)
try
{
    $BuildConfigs = Get-ChildItem $OSDirectories |
        Where-Object { $_.PSIsContainer }
}
catch
{
    throw "Failed to get build configurations.`n$($_.Exception.Message)"
}

# Create the directory where all finished Packer builds end up
try
{
    $global:CompletedPackerBuildsDirectory = New-Item (Join-Path $Global:RepoBuildOutputDirectory 'complete') `
        -ItemType Directory `
        -Force
}
catch
{
    throw $_.Exception.Message
}

foreach ($ISO in $ISOs)
{
    # Work out the name of the OS
    $OSName = ($ISO.ISOPath | Split-Path -Leaf) -replace '.iso', ''
    Write-Verbose "OSName: $OSName"
    # Include/Exclude configurations
    if ($IncludedOperatingSystems)
    {
        if ($OSName -notin $IncludedOperatingSystems)
        {
            Write-Verbose "$OSName will be skipped"
            Continue
        }
    }
    if ($ExcludedOperatingSystems)
    {
        if ($OSName -in $ExcludedOperatingSystems)
        {
            Write-Verbose "$OSName will be skipped"
            Continue
        }
    }
    # Only run builds where an ISO name matches a build config name
    if ($OSName -in $BuildConfigs.Name)
    {
        # Do a build
        try
        {
            if (($OSName -eq 'macOS') -and (!$IsMacOS))
            {
                # Don't fail just skip over it
                Write-Warning "macOS can only be built on Apple hardware, skipping"
                Continue
            }
            # Work out what OS type we have by seeing what parent folder it's in (e.g. macOS/Linux/Windows).
            $OSType = $BuildConfigs | 
                Where-Object { $_.Name -eq $OSName } | 
                    Select-Object -ExpandProperty PSParentPath | 
                        Split-Path -Leaf
            $BuildConfigPath = $BuildConfigs |
                Where-Object { $_.Name -eq $OSName } | 
                    Select-Object -ExpandProperty PSPath |
                        Convert-Path
            $IBParams = @{
                File                   = (Join-Path $global:BuildTasksDirectory 'Packer.ps1')
                Task                   = 'BuildPackerImages'
                OSFamily               = $OSType
                BuildConfigurationPath = $BuildConfigPath
                ISOPath                = $ISO.ISOPath
                ISOChecksum            = $ISO.Shasum
            }
            if ($CopyISO)
            {
                $IBParams.Add('CopyISO', $true)
            }
            if ($CopyBuildArtifactsTo)
            {
                $IBParams.Add('BuildArtifactPath', $CopyBuildArtifactsTo)
            }
            Invoke-Build @IBParams -Verbose:($PSBoundParameters['Verbose'] -eq $true)
                
        }
        catch
        {
            throw "Build failed.`n$($_.Exception.Message)"
        }
    }
    else
    {
        Write-Warning "$OSName does not have a corresponding build configuration and as such will be skipped"
    }
}

Write-Host "Build $($MyInvocation.MyCommand) completed successfully! 🎉" -ForegroundColor Green
Write-Host "You can find your Packer images in:`n$($Global:CompletedPackerBuildsDirectory | Convert-Path)"