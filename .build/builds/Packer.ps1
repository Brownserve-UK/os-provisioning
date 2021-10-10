<#
.SYNOPSIS
    Builds all of our Packer images
.NOTES
    N/A
#>
[CmdletBinding()]
param
(
    # The path to where the ISO's are located, can either be a URL or a local path (including fileshare's)
    [Parameter(Mandatory = $true, Position = 0)]
    [string]
    $ISOPath,

    # Setting this parameter limits builds to only those specified
    [Parameter(Mandatory = $false, Position = 1)]
    [array]
    $OperatingSystemsToBuild
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
    $ISOs = Get-ISOs -ISOPath $ISOPath
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

foreach ($ISO in $ISOs)
{
    # Work out the name of the OS
    $OSName = ($ISO.ISOPath | Split-Path -Leaf) -replace '.iso', ''
    Write-Verbose "OSName: $OSName"
    if ($OperatingSystemsToBuild)
    {
        if ($OSName -notin $OperatingSystemsToBuild)
        {
            Write-Verbose "$OSName will be skipped"
            Continue
        }
    }
    if ($OSName -in $BuildConfigs.Name)
    {
        # Do a build
        try
        {
            if (($OSName -eq 'macOS') -and (!$IsMacOS))
            {
                Write-Warning "macOS can only be built on Apple hardware, skipping"
                Continue
            }
            # Work out what OS type we have by seeing what parent folder it's in (e.g. macOS).
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
                OSType                 = $OSType
                BuildConfigurationPath = $BuildConfigPath
                ISOPath                = $ISO.ISOPath
                ISOChecksum            = $ISO.Shasum
            }
            if ($CopyISO)
            {
                $IBParams.Add('CopyISO', $true)
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