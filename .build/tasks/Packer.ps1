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
    $CopyISO = $false,

    # An optional path to copy the completed builds artifacts to
    [Parameter(Mandatory = $false)]
    [string]
    $BuildArtifactPath
)

# Create an empty packer variables hash
$script:PackerVariables = @{
    iso_url           = ($ISOPath | Convert-WindowsPath)
    iso_file_checksum = $ISOChecksum
}
$script:FloppyFiles = @()
$Script:SetHTTPDirectory = $false
$Script:SetFloppyFiles = $false


# Synopsis: checks that our build artifact path is valid
task CheckBuildArtifactPath -If ($BuildArtifactPath) {
    Write-Verbose "Checking BuildArtifactPath is valid"
    if (!(Test-Path $BuildArtifactPath))
    {
        throw "'$BuildArtifactPath' does not appear to be a valid directory"
    }
}

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

    # Create a directory for packer to store the builds in but DO NOT create it, packer takes care of this and gets
    # mad if you try to do it yourself
    $script:PackerOutputDirectory = Join-Path $BuildOutputDirectory 'packer' | Convert-WindowsPath
    # Set the output_directory packer variable
    $script:PackerVariables.add('output_directory', $PackerOutputDirectory)

    # Set the default output filename
    $PackerOutputFilename = $OSVersion
    $script:PackerVariables.add('output_filename', $PackerOutputFilename)

    # Create a subdirectory in the completed build directory so we can better organize our output
    $script:CompletedBuildDirectory = New-Item (Join-Path $global:CompletedPackerBuildsDirectory $OSVersion) -ItemType Directory -Force
}

# Synopsis: Copies the ISO to the build output directory if requested
task CopyISO -If ($CopyISO) PrepareBuildOutputDirectory, {
    # Create a directory for storing the image
    $script:ImagesDirectory = New-Item (Join-Path $script:BuildOutputDirectory 'images') -ItemType Directory -Force | Convert-Path
    # Copy the ISO and change the value of the iso_url Packer variable
    $NewISOPath = Copy-ISO -ISOPath $ISOPath -Destination $script:ImagesDirectory | Convert-Path | Convert-WindowsPath
    if ($script:PackerVariables.iso_url)
    {
        $script:PackerVariables.iso_url = $NewISOPath
    }
    else
    {
        $script:PackerVariables.add('iso_url', $NewISOPath)
    }
}

# Synopsis: Builds the macOS packages
task BuildMacOSPackages -If ($OSType -eq 'macOS') PrepareBuildOutputDirectory, {
    $PackagesDirectory = $script:ConfigSubDirectories | Where-Object { $_.Name -eq 'packages' }
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
    # Now we need to build our user package for packer to use
    try
    {
        $PyCreateUserPkgPath = Join-Path $global:PaketFilesDirectory 'gregneagle' 'pycreateuserpkg' 'createuserpkg' | Convert-Path
        # This isn't executable on download :(
        & chmod +x $PyCreateUserPkgPath
        Write-Verbose "Building packer_user.pkg"
        Start-SilentProcess `
            -FilePath $PyCreateUserPkgPath `
            -ArgumentList "-n packer -f packer -p packer -u 525 -V 1 -i com.brownserveuk.packer -a -A -d $(Join-Path $script:PackerFilesDirectory 'packer_user.pkg')"
    }
    catch
    {
        throw "Failed to update packer_user.pkg.`n$($_.Exception.Message)"
    }
    # We want these files to end up in the HTTP directory
    $Script:SetHTTPDirectory = $true
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

# Synopsis: Copies the files needed for running Linux builds over
task CopyLinuxFiles -If ($OSType -eq 'Linux') PrepareBuildOutputDirectory, {
    # Copy the bootstrap stuff over
    $script:BootstrapDirectory = Copy-Item (Join-Path $BuildConfigurationPath 'bootstrap') `
        -Destination $script:PackerFilesDirectory `
        -Recurse

    # We need to pass our bootstrap stuff through as a HTTP dir:
    $Script:SetHTTPDirectory = $true
}

# Synopsis: Copies any scripts over to the 'files' directory so they are available to provisioners/floppy drives
task CopyScripts PrepareBuildOutputDirectory, {
    # If we've got common scripts then copy them over here
    if ((Test-Path $script:CommonOSScripts))
    {
        Write-Verbose "Copying common scripts"
        Get-ChildItem $script:CommonOSScripts -Recurse | Copy-Item -Destination $script:PackerFilesDirectory -Force
    }
    # Now copy over any scripts specific to this build (don't need to test-path this one due to way we set the variable)
    if ($script:ConfigScripts)
    {
        Write-Verbose "Copying build specific scripts"
        Get-ChildItem $script:ConfigScripts -Recurse | Copy-Item -Destination $script:PackerFilesDirectory -Force
    }
}

# Synopsis: This will create a floppy drive with the contents of the 'files' directory if requested
task SetFloppyFiles -If { $script:SetFloppyFiles -eq $true } CopyScripts, {
    Write-Verbose "Setting Floppy files to contents of $script:PackerFilesDirectory"
    $script:FloppyFiles = Get-ChildItem $script:PackerFilesDirectory -Recurse | 
        Where-Object { $_.PSIsContainer -eq $false } |
            Select-Object -ExpandProperty PSPath |
                Convert-Path | 
                    ForEach-Object {
                        Convert-WindowsPath $_
                    }

    # Add it to our PackerVariables file
    $script:PackerVariables.add('floppy_files', $script:FloppyFiles)
}

task SetHTTPDirectory -If { $Script:SetHTTPDirectory } CopyScripts, BuildMacOSPackages, CopyLinuxFiles, {
    Write-Verbose "Setting HTTP directory to $script:PackerFilesDirectory"
    $script:PackerVariables.add('http_directory', ($script:PackerFilesDirectory | 
                Convert-Path | 
                    Convert-WindowsPath))
}

# Synopsis: Builds the Packer images
task InvokePacker CopyWindowsFiles, CopyScripts, SetFloppyFiles, SetHTTPDirectory, BuildMacOSPackages, CopyLinuxFiles, CopyISO, {
    switch ($OSType)
    {
        # We have special logic for Windows builds as we build multiple versions of the same ISO.
        'Windows'
        {
            # Need to do a build for each autounattend
            $AutoUnattends = Get-ChildItem $script:BuildOutputDirectory -Recurse | 
                Where-Object { $_.Name -eq 'autounattend.xml' } |
                    Select-Object -ExpandProperty PSPath |
                        Convert-Path |
                            ForEach-Object {
                                Convert-WindowsPath $_
                            }

            foreach ($AutoUnattend in $AutoUnattends)
            {
                $Subversion = Get-Item $AutoUnattend | Select-Object -ExpandProperty PSParentPath | Split-Path -Leaf
                
                Write-Verbose "Now building $OSVersion-$Subversion"

                # Override the default output directory, we need to do this otherwise packer throws a wobbly cos
                # there's files in the output directory -_-
                $SubversionOutputDirectory = Join-Path $BuildOutputDirectory $Subversion 'packer' | Convert-WindowsPath
                # Set the output_directory packer variable
                if ($script:PackerVariables.output_directory)
                {
                    $script:PackerVariables.output_directory = $SubversionOutputDirectory
                }
                else
                {
                    $script:PackerVariables.add('output_directory', $SubversionOutputDirectory)
                }
                
                # Override the default Packer filename
                $PackerOutputFilename = "$OSVersion-$Subversion"
                if ($script:PackerVariables.output_filename)
                {
                    $script:PackerVariables.output_filename = $PackerOutputFilename
                }
                else
                {
                    $script:PackerVariables.add('output_filename', $PackerOutputFilename)
                }
                # Update our floppy_files variable to add in the autounattend
                if ($script:PackerVariables.floppy_files)
                {
                    $FloppyFiles = @($AutoUnattend) + $script:PackerVariables.floppy_files
                    $script:PackerVariables.floppy_files = $FloppyFiles
                }
                else
                {
                    $script:PackerVariables.add('floppy_files', @($AutoUnattend))
                }
                # Convert our variables into something that Packer can parse easily
                $ConvertedVariables = $script:PackerVariables | ConvertTo-PackerVariable
                # Due to issues with escape characters in the command line we use a variables to be safe
                $PackerVarsFile = New-PackerVarsFile `
                    -Path (Join-Path $script:BuildOutputDirectory 'variables.pkrvars.hcl') `
                    -PackerVariables $ConvertedVariables `
                    -Force
                $script:PackerConfigs | ForEach-Object {
                    # First validate
                    Invoke-PackerValidate `
                        -PackerTemplate $_ `
                        -WorkingDirectory $script:BuildOutputDirectory `
                        -VariableFile $PackerVarsFile `
                        -Verbose
                    # Then build
                    Invoke-PackerBuild `
                        -PackerTemplate $_ `
                        -WorkingDirectory $script:BuildOutputDirectory `
                        -VariableFile $PackerVarsFile `
                        -Verbose
                }
                # Now we need to move the built subversions into the packer output directory so everything can end up in
                # one place
                Get-ChildItem $SubversionOutputDirectory -Recurse | Move-Item -Destination $script:CompletedBuildDirectory -Force
            }
        }
        Default
        {
            # Convert our packer variables to make sure they are in a format that Packer can understand
            $ConvertedVariables = $script:PackerVariables | ConvertTo-PackerVariable -Verbose
            # Due to issues with escape characters in the command line we use a variables to be safe
            $PackerVarsFile = New-PackerVarsFile `
                -Path (Join-Path $script:BuildOutputDirectory 'variables.pkrvars.hcl') `
                -PackerVariables $ConvertedVariables `
                -Force
            Write-Verbose "Now building $OSVersion"
            $script:PackerConfigs | ForEach-Object {
                # First validate
                Invoke-PackerValidate `
                    -PackerTemplate $_ `
                    -WorkingDirectory $script:BuildOutputDirectory `
                    -VariableFile $PackerVarsFile `
                    -Verbose
                # Then build
                Invoke-PackerBuild `
                    -PackerTemplate $_ `
                    -WorkingDirectory $script:BuildOutputDirectory `
                    -VariableFile $PackerVarsFile `
                    -Verbose
            }
            # Move the completed builds so they are easy to find!
            Get-ChildItem $script:PackerOutputDirectory -Recurse | Move-Item -Destination $script:CompletedBuildDirectory -Force
        }
    }
}

task CopyBuildArtifacts -If ($CopyBuildArtifactsTo) InvokePacker, {
    Write-Verbose "Copying build artifacts to $BuildArtifactPath"
    Get-ChildItem $global:CompletedPackerBuildsDirectory | 
        Copy-Item -Destination $BuildArtifactPath -Recurse -Force
}

# Synopsis: Wrapper task for all the others
task BuildPackerImages InvokePacker, CopyBuildArtifacts, {}
