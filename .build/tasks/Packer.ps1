<#
.SYNOPSIS
    Build tasks for building Packer images
.DESCRIPTION
    These build tasks cover the process of building Packer images.
.NOTES
#>
[CmdletBinding()]
param
(
    # The path to the build configuration
    [Parameter(
        Mandatory = $true
    )]
    [string]
    $BuildConfigurationPath,

    # The ISO Path
    [Parameter(Mandatory = $true)]
    [string]
    $ISOPath,

    # The ISO checksum
    [Parameter(Mandatory = $true)]
    [string]
    $ISOChecksum,

    # The OS being built
    [Parameter(
        Mandatory = $true
    )]
    [ValidateSet('Linux', 'macOS', 'Windows')]
    [string]
    $OSType,

    # Whether or not to copy the ISO locally when building
    [Parameter(Mandatory = $false)]
    [bool]
    $CopyISO = $false
)

# Create an empty packer variables hash
$script:PackerVariables = @{
    iso_filename      = $ISOPath
    iso_file_checksum = $ISOChecksum
}
$script:FloppyFiles = @()
$Script:SetHTTPDirectory = $false
$Script:SetFloppyFiles = $false

# Synopsis: sets some basic build information applicable to everything
task SetBuildInformation {
    $script:OSVersion = "$OSType_$($BuildConfigurationPath | Split-Path -Leaf)"
    $script:ConfigSubDirectories = Get-ChildItem $BuildConfigurationPath | 
        Where-Object { $_.PSIsContainer }
    $script:PackerConfigs = Get-ChildItem $BuildConfigurationPath | Where-Object { $_.Name -match '.hcl|.json' } | Convert-Path
    $script:ConfigScripts = Get-ChildItem $BuildConfigurationPath | Where-Object { $_.Name -eq 'scripts' }
    $script:CommonOSScripts = Join-Path $BuildConfigurationPath '..' 'scripts'
    Write-Verbose "OSVersion: $OSVersion"
}

# Synopsis: Creates the build output directory structure
task PrepareBuildOutputDirectory SetBuildInformation, {
    $script:BuildOutputDirectory = Join-Path $Global:RepoBuildOutputDirectory $script:OSVersion
    New-Item $script:BuildOutputDirectory -ItemType Directory -Force | Out-Null
    $script:PackerFilesDirectory = New-Item (Join-Path $script:BuildOutputDirectory 'files') -ItemType Directory -Force
    Write-Verbose "Build artifacts can be found in $script:BuildOutputDirectory"
}

# Synopsis: On Windows we have some funky logic so we set that up here
task PrepareWindows -If ($OSType -eq 'Windows') PrepareBuildOutputDirectory, {
    # For Windows builds we have a list of autounattends that build our various flavours of Windows
    # (e.g. 'Server 2019 - Datacenter', 'Server 2019 - Standard' etc)
    Write-Verbose "Finding a list of Autounattend's"
    $script:AutoUnattends = $script:ConfigSubDirectories | 
        Where-Object { $_.Name -eq 'autounattend' } | 
            Get-ChildItem
    if (!$AutoUnattends)
    {
        throw "No autounattend's found"
    }
    $script:SubVersions = $AutoUnattends | Select-Object -ExpandProperty Name

    # To help keep our build output directory organised we'll create subdirectories for all our sub-versions
    $script:OutputSubDirectories = $script:SubVersions | ForEach-Object {
        New-Item (Join-Path $script:BuildOutputDirectory ($_ -replace '.xml', '')) -ItemType Directory -Force
    }
    # On windows we need to set floppy disk files so we can automate the build
    $Script:SetFloppyFiles = $true
}

# Synopsis: If on Windows this will copy our autounattend's
task CopyWindowsFiles -If ($OSType -eq 'Windows') PrepareWindows, {
    foreach ($OutputSubDirectory in $script:OutputSubDirectories)
    {
        # Copy the relevant autounattend to it's given subdirectory
        $script:AutoUnattends | ForEach-Object {
            if (($_.Name -replace '.xml', '') -eq $OutputSubDirectory.Name)
            {
                Copy-Item $_ -Destination (Join-Path $OutputSubDirectory 'autounattend.xml')
            }
        }
    }
}

# Synopsis: Copies any scripts over to the 'files' directory so they are available to provisioners/floppy drives
task CopyScripts PrepareBuildOutputDirectory, {
    # If we've got common scripts then copy them over here
    if ((Test-Path $script:CommonOSScripts))
    {
        Write-Verbose "Copying common scripts"
        Get-ChildItem $script:CommonOSScripts -Recurse | Copy-Item -Destination $script:PackerFilesDirectory -Force
    }
    # Now copy over any scripts specific to this build
    if ((Test-Path $script:ConfigScripts))
    {
        Write-Verbose "Copying build specific scripts"
        Get-ChildItem $script:ConfigScripts -Recurse | Copy-Item -Destination $script:PackerFilesDirectory -Force
    }
}

# Synopsis: This will create a floppy drive with the contents of the 'files' directory
task SetFloppyFiles -If { $script:SetFloppyFiles -eq $true } CopyScripts, {
    Write-Verbose "Setting Floppy files to contents of $script:PackerFilesDirectory"
    $script:FloppyFiles = Get-ChildItem $script:PackerFilesDirectory -Recurse | 
        Where-Object { $_.PSIsContainer -eq $false } |
            Select-Object -ExpandProperty PSPath |
                Convert-Path
    # This is horrible, but we need to escape the quotes with backslashes for the CLI to _actually_ pass them
    # on to Packer 😩
    $FloppyString = "[\`"$($script:FloppyFiles -join '\",\"')\`"]"
    if ($script:PackerVariables.floppy_files)
    {
        $script:PackerVariables.floppy_files = $FloppyString
    }
    else
    {
        $script:PackerVariables.add('floppy_files', $FloppyString)
    }
}

task SetHTTPDirectory -If { $Script:SetHTTPDirectory } CopyScripts, {
    Write-Verbose "Setting HTTP directory to $script:PackerFilesDirectory"
    if ($script:PackerVariables.http_directory)
    {
        $script:PackerVariables.http_directory = ($script:PackerFilesDirectory | Convert-Path)
    }
    else
    {
        $script:PackerVariables.add('http_directory', ($script:PackerFilesDirectory | Convert-Path))
    }
}

# Synopsis: Builds the Packer images
task BuildPackerImages CopyWindowsFiles, CopyScripts, SetFloppyFiles, {
    # We have special logic for Windows builds as we build multiple versions of the same ISO.
    if ($OSType -eq 'Windows')
    {
        # Need to do a build for each autounattend
        $AutoUnattends = Get-ChildItem $script:BuildOutputDirectory -Recurse | 
            Where-Object { $_.Name -eq 'autounattend.xml' } |
                Select-Object -ExpandProperty PSPath |
                    Convert-Path

        foreach ($AutoUnattend in $AutoUnattends)
        {
            $Subversion = Get-Item $AutoUnattend | Select-Object -ExpandProperty PSParentPath | Split-Path -Leaf
            $PackerOutputDirectory = Join-Path $BuildOutputDirectory $Subversion 'packer'
            Write-Verbose "Now building $OSVersion-$Subversion"
            if ($script:PackerVariables.output_directory)
            {
                $script:PackerVariables.output_directory = $PackerOutputDirectory
            }
            else
            {
                $script:PackerVariables.add('output_directory', $PackerOutputDirectory)
            }
            $FloppyString = "[\`"$AutoUnattend\`",\`"$($script:FloppyFiles -join '\",\"')\`"]"
            if ($script:PackerVariables.floppy_files)
            {
                $script:PackerVariables.floppy_files = $FloppyString
            }
            else
            {
                $script:PackerVariables.add('floppy_files', $FloppyString)
            }
            $script:PackerConfigs | ForEach-Object {
                # First validate
                Invoke-PackerValidate `
                    -PackerTemplate $_ `
                    -WorkingDirectory $script:BuildOutputDirectory `
                    -TemplateVariables $script:PackerVariables `
                    -Verbose
                # Then build
                Invoke-PackerBuild `
                    -PackerTemplate $_ `
                    -WorkingDirectory $script:BuildOutputDirectory `
                    -TemplateVariables $script:PackerVariables `
                    -Verbose
            }
        }
    }
}
