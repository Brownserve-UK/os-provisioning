<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
[CmdletBinding()]
param
(
    # The directory that contains the build configuration
    [Parameter(
        Mandatory = $true
    )]
    [string]
    $ConfigurationDirectory,

    # The directory that contains the raw ISO's and their shasum
    [Parameter(
        Mandatory = $true
    )]
    [string]
    $ISODirectory,

    # The path to our autounattend file
    [Parameter(
        Mandatory = $true
    )]
    [string]
    $AutounattendPath
)
task SetVersionInfo {
    # Get the flavour we're building from the directory name (e.g. server2019, 10 etc)
    $script:WindowsVersion = "$(Split-Path $ConfigurationDirectory -Leaf)"
    # The autounattend should be named after the edition we're building
    $script:WindowsEdition = "$(Split-Path $AutounattendPath -Leaf)" -replace '.xml', ''

    # Set the build output directory
    $script:BuildOutputDirectory = Join-Path $Global:RepoBuildOutputDirectory "windows_$($WindowsVersion)_$($WindowsEdition)"

    # Cover cases where we may only have one autounattend
    if ($WindowsEdition -eq 'autounattend')
    {
        $WindowsEdition = $null
        $script:BuildOutputDirectory = Join-Path $Global:RepoBuildOutputDirectory "windows_$($WindowsVersion)"
    }

}

# Synopsis: Creates the output directory
task MakeOutputDirectory SetVersionInfo, {
    New-Item $script:BuildOutputDirectory -ItemType Directory -Force | Out-Null
    # Create the directory for things that get passed into packer builds, either via HTTP or via provisioners
    $script:PackerFilesDirectory = New-Item (Join-Path $BuildOutputDirectory 'files') -ItemType Directory -Force
    # Create the directory for storing the ISO/images
    $script:PackerImagesDirectory = New-Item (Join-Path $BuildOutputDirectory 'images') -ItemType Directory -Force
}

task GetISO {
    $script:ISO = Get-ChildItem $ISODirectory -Recurse | 
        Where-Object { $_.Name -eq "$WindowsVersion.iso" } | 
            Select-Object -ExpandProperty PSPath |
                Convert-Path
    $ISOChecksumFile = Get-ChildItem $ISODirectory -Recurse | 
        Where-Object { $_.Name -eq "$WindowsVersion.iso.shasum" } | 
            Select-Object -ExpandProperty PSPath
    $script:ISOChecksum = Get-Content $ISOChecksumFile -Raw

    if (!$ISO)
    {
        throw "Failed to find ISO '$WindowsEdition.iso' in $ISODirectory"
    }
    if (!$ISOChecksum)
    {
        throw "Failed to find ISO checksum '$WindowsEdition.iso' in $ISODirectory"
    }
}

task CopyFiles MakeOutputDirectory, {
    # Copy the autounattend to the 'files' directory so it can be picked up by the floppy disk
    Copy-Item $AutounattendPath -Destination (Join-Path $script:PackerFilesDirectory 'autounattend.xml') -Force

    $ScriptsDirectory = Join-Path $ConfigurationDirectory 'scripts'
    if ((Test-Path $ScriptsDirectory))
    {
        Write-Verbose "Copying deployment scripts"
        Get-ChildItem $ScriptsDirectory -Recurse | Copy-Item -Destination $script:PackerFilesDirectory
    }
}

task SetPackerVariables GetISO, {
    $script:PackerVariables = @{
        iso_file_checksum = $script:ISOChecksum
        iso_filename      = $script:ISO
        winrm_username    = 'Administrator'
        winrm_password    = 'ItsaSecrettoEverybody1234'
        headless          = 'true'
    }
}

task BuildPackerImages CopyFiles, GetISO, SetPackerVariables, {
    Write-Verbose "Building"
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