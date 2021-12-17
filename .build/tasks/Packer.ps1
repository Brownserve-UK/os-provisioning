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
    $OSFamily,

    # The credentials for the local admin user to create
    [Parameter(Mandatory = $false)]
    [pscredential]
    $LocalAdminCredentials,

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
    Write-Verbose 'Checking BuildArtifactPath is valid'
    if (!(Test-Path $BuildArtifactPath))
    {
        throw "'$BuildArtifactPath' does not appear to be a valid directory"
    }
}

# Synopsis: sets some basic build information applicable to everything
task SetBuildInformation {
    $script:OSVersion = "$OSFamily_$($BuildConfigurationPath | Split-Path -Leaf)"
    $script:ConfigSubDirectories = Get-ChildItem $BuildConfigurationPath | 
        Where-Object { $_.PSIsContainer }
    $script:PackerConfigs = Get-ChildItem $BuildConfigurationPath | Where-Object { $_.Name -match '.hcl|.json' }
    $script:ConfigScripts = Get-ChildItem $BuildConfigurationPath | Where-Object { $_.Name -eq 'scripts' }
    $script:CommonOSScripts = Join-Path $BuildConfigurationPath '..' 'scripts'
    Write-Verbose "OSVersion: $OSVersion"
}

# Synopsis: Sets any "secure" variables
task SetSecureVariables {
    # Secure variables is perhaps a bit of a misnomer as these are really just variables that do not get written to a
    # vars file and instead get passed in via the CLI to keep them a bit more secret

    # At the moment we only have the one, but this may change in future
    if ($LocalAdminCredentials)
    {
        $script:SecureVariables = @{
            local_admin_username = $LocalAdminCredentials.UserName
            local_admin_password = ($LocalAdminCredentials.Password | ConvertFrom-SecureString -AsPlainText)
        }
    }
}

# Synopsis: Creates the build output directory structure
task PrepareBuildOutputDirectory SetBuildInformation, {
    $script:BuildOutputDirectory = Join-Path $Global:RepoBuildOutputDirectory $script:OSVersion
    New-Item $script:BuildOutputDirectory -ItemType Directory -Force | Out-Null
    $script:PackerFilesDirectory = New-Item (Join-Path $script:BuildOutputDirectory 'files') -ItemType Directory -Force
    Write-Verbose "Build artifacts can be found in $script:BuildOutputDirectory"

    # Create a directory for Packer build artifacts
    $script:PackerOutputDirectory = New-Item (Join-Path $BuildOutputDirectory 'packer') -ItemType Directory -Force

    # Create a directory for VirtualBox to store VM's in
    # this is useful as it allows us to easily clean up the VM's if the build fails and to grab any additional artifacts we need
    # (e.g. NVRAM)
    $script:VBoxOutputDirectory = New-Item (Join-Path $BuildOutputDirectory 'vbox') -ItemType Directory -Force | Convert-Path
    $script:PackerVariables.add('vm_directory', $script:VBoxOutputDirectory)

    # Create a subdirectory in the completed build directory so we can better organize our various output objects
    $script:CompletedBuildDirectory = New-Item (Join-Path $global:CompletedPackerBuildsDirectory $OSFamily $OSVersion) -ItemType Directory -Force
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
task BuildMacOSPackages -If ($OSFamily -eq 'macOS') PrepareBuildOutputDirectory, {
    $PackagesDirectory = $script:ConfigSubDirectories | Where-Object { $_.Name -eq 'packages' }
    try
    {
        $PackagesToBuild = Get-ChildItem $PackagesDirectory `
            -Recurse `
            -Filter '*.pkgproj' | Select-Object -ExpandProperty PSPath
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
        Write-Verbose 'Building vagrant_user.pkg'
        Start-SilentProcess `
            -FilePath $PyCreateUserPkgPath `
            -ArgumentList "-n vagrant -f vagrant -p vagrant -u 525 -V 1 -i com.brownserveuk.vagrant -a -A -d $(Join-Path $script:PackerFilesDirectory 'vagrant_user.pkg')"
    }
    catch
    {
        throw "Failed to update packer_user.pkg.`n$($_.Exception.Message)"
    }
    # We want these files to end up in the HTTP directory
    $Script:SetHTTPDirectory = $true
}

# Synopsis: On Windows we have some funky logic so we set that up here
task PrepareWindows -If ($OSFamily -eq 'Windows') PrepareBuildOutputDirectory, {
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
task CopyWindowsFiles -If ($OSFamily -eq 'Windows') PrepareWindows, {
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
task CopyLinuxFiles -If ($OSFamily -eq 'Linux') PrepareBuildOutputDirectory, {
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
        Write-Verbose 'Copying common scripts'
        Get-ChildItem $script:CommonOSScripts -Recurse | Copy-Item -Destination $script:PackerFilesDirectory -Force
    }
    # Now copy over any scripts specific to this build (don't need to test-path this one due to way we set the variable)
    if ($script:ConfigScripts)
    {
        Write-Verbose 'Copying build specific scripts'
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

# Synopsis: Passes through the 'files' directory to the VM as a HTTP server
task SetHTTPDirectory -If { $Script:SetHTTPDirectory } CopyScripts, BuildMacOSPackages, CopyLinuxFiles, {
    Write-Verbose "Setting HTTP directory to $script:PackerFilesDirectory"
    $script:PackerVariables.add('http_directory', ($script:PackerFilesDirectory | 
                Convert-Path | 
                    Convert-WindowsPath))
}

# Synopsis: creates a vagrantfile to be used to help configure boxes
task TemplateVagrantfile PrepareBuildOutputDirectory, {
    switch ($OSFamily)
    {
        'Windows'
        {
            # We need to create a vagrantfile to set the communicator and extra memory for Windows boxes
            $VagrantFileContent = @'
# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure("2") do |config|
    # config
    config.vm.guest = :windows
    config.vm.communicator = "winrm"
    config.winrm.retry_limit = 5
    config.vm.provider "virtualbox" do |vb|
        vb.memory = "4096"
        vb.cpus = 2
    end
end
'@

            $VagrantfilePath = (Join-Path $script:BuildOutputDirectory 'vagrantfile')
            New-Item `
                -Path  $VagrantfilePath `
                -ItemType File `
                -Value $VagrantFileContent | Out-Null

            # This probably isn't the best place to set this as it'll be present on ALL builds but we'll worry about that later 😇
            $script:PackerVariables.add('vagrantfile_template', ($VagrantfilePath | Convert-WindowsPath))
        }
        Default {}
    }
}

# Synopsis: Builds the Packer images
task InvokePacker SetSecureVariables, CopyWindowsFiles, CopyScripts, SetFloppyFiles, SetHTTPDirectory, BuildMacOSPackages, CopyLinuxFiles, CopyISO, TemplateVagrantfile, {
    switch ($OSFamily)
    {
        # We have special logic for Windows builds as we build multiple versions of the same ISO.
        'Windows'
        {
            Write-Verbose "Building images for $OSVersion"
            # Need to do a build for each autounattend
            $AutoUnattends = Get-ChildItem $script:BuildOutputDirectory -Recurse | 
                Where-Object { $_.Name -eq 'autounattend.xml' } |
                    Select-Object -ExpandProperty PSPath |
                        Convert-Path |
                            ForEach-Object {
                                Convert-WindowsPath $_
                            }

            # Run through our builds for each autounattend
            foreach ($AutoUnattend in $AutoUnattends)
            {
                # Clear out this variable for each autounattend file
                $script:BaseImagePath = $null
                $FilesToMove = @()
                $Subversion = Get-Item $AutoUnattend | Select-Object -ExpandProperty PSParentPath | Split-Path -Leaf

                # Override the default output directory, we need to do this otherwise packer throws a wobbly cos
                # there's files in the output directory -_-
                $SubversionOutputDirectory = Join-Path $BuildOutputDirectory $Subversion
                
                # Update our floppy_files variable to add in the autounattend
                # We first need to capture the current state of the floppy files as if we try to update the PackerVariables.floppy_files
                # each time it will end up with ALL of our autounattends... D:
                # so we "freeze" our floppy files in time and add the extra autounattend in each time
                if (!$script:DefaultFloppyFiles)
                {
                    # Capture our current floppy files as the default
                    $script:DefaultFloppyFiles = $script:PackerVariables.floppy_files
                }
                $script:PackerVariables.floppy_files = @($AutoUnattend) + $script:DefaultFloppyFiles

                $script:PackerConfigs | ForEach-Object {
                    Write-Verbose "Now building $($_.Name) ($Subversion)"
                    # The directory for packer to store the builds in. DO NOT create it, packer takes care of this and gets
                    # mad if you try to do it yourself
                    # We need a separate one per-config to avoid Packer complaining
                    $output_directory = Join-Path $SubversionOutputDirectory "$($_.Name -replace '.pkr.hcl|.json','')" | Convert-WindowsPath
                    # Set the output_directory packer variable
                    if ($script:PackerVariables.output_directory)
                    {
                        $script:PackerVariables.output_directory = $output_directory
                    }
                    else
                    {                
                        $script:PackerVariables.add('output_directory', $output_directory)
                    }

                    # Set the default output filename
                    $output_filename = "$($_.Name -replace '.pkr.hcl|.json','')-$Subversion"
                    if ($script:PackerVariables.output_filename)
                    {
                        $script:PackerVariables.output_filename = $output_filename
                    }
                    else
                    {
                        $script:PackerVariables.add('output_filename', $output_filename)
                    }

                    # We need to set this variable otherwise Packer will store it in a location that we don't expect...
                    if ($_.Name -match '-vagrant')
                    {   
                        # For Windows we build the entire path to the box, due to having multiple versions
                        $BoxPath = Join-Path $script:CompletedBuildDirectory "$($OSVersion)_$($Subversion)_virtualbox.box" | Convert-WindowsPath
                        # Again another one that'll end up persisting across builds
                        if (!$script:PackerVariables.vagrant_output_directory)
                        {
                            $script:PackerVariables.add('vagrant_output_directory', $BoxPath)
                        }
                        else
                        {
                            $script:PackerVariables.vagrant_output_directory = $BoxPath
                        }
                    }

                    # Once we've built our base image then our other builds will need to know the path to it.
                    if ($script:BaseImagePath)
                    {
                        if ($script:PackerVariables.input_file)
                        {
                            $script:PackerVariables.input_file = $script:BaseImagePath
                        }
                        else
                        {
                            $script:PackerVariables.add('input_file', $script:BaseImagePath)
                        }
                    }
                
                    # Convert our packer variables to make sure they are in a format that Packer can understand
                    $ConvertedVariables = $script:PackerVariables | ConvertTo-PackerVariable

                    # Due to issues with escape characters in the command line we use a variables file to be safe
                    $PackerVarsFile = New-PackerVarsFile `
                        -Path (Join-Path $script:BuildOutputDirectory 'variables.pkrvars.hcl') `
                        -PackerVariables $ConvertedVariables `
                        -Force

                    $PackerParams = @{
                        PackerTemplate   = $_
                        WorkingDirectory = $script:BuildOutputDirectory
                        VariableFile     = $PackerVarsFile
                    }
                    # Only the customize builds have the logic for setting local admin users
                    if ($script:SecureVariables -and ($_.Name -match '-customized'))
                    {
                        $ConvertedSecureVariables = $script:SecureVariables | ConvertTo-PackerVariable
                        $PackerParams.add('TemplateVariables', $ConvertedSecureVariables)
                    }

                    # First validate
                    Invoke-PackerValidate @PackerParams

                    # Then build
                    Invoke-PackerBuild @PackerParams

                    # After a successful build of our base image we store the resulting OVF file in a variable for the subsequent builds to use
                    if (!$script:BaseImagePath)
                    {
                        $script:BaseImagePath = Get-ChildItem $output_directory | Where-Object { $_.Name -match '-base(?:.*).ovf$' } | Convert-Path | Convert-WindowsPath
                    }
                    # We can't move the files yet as they may be needed by the next build, so store them for later.
                    $FilesToMove += $output_directory
                }
                # Now we need to move the built subversions into the packer output directory so everything can end up in
                # one place
                $FilesToMove | Get-ChildItem -Recurse | Move-Item -Destination $script:CompletedBuildDirectory -Force
            }
        }
        Default
        {
            Write-Verbose "Building images for $OSVersion"
            $FilesToMove = @()
            $OVFFile = $null
            $NVRAMFile = $null
            $script:PackerConfigs | ForEach-Object {
                Write-Verbose "Now building $($_.Name)"
                # The directory for packer to store the builds in. DO NOT create it, packer takes care of this and gets
                # mad if you try to do it yourself
                # We need a separate one per-config to avoid Packer complaining
                $output_directory = Join-Path $script:PackerOutputDirectory "$($_.Name -replace '.pkr.hcl|.json','')" | Convert-WindowsPath
                # Set the output_directory packer variable
                if ($script:PackerVariables.output_directory)
                {
                    $script:PackerVariables.output_directory = $output_directory
                }
                else
                {                
                    $script:PackerVariables.add('output_directory', $output_directory)
                }

                # Set the default output filename
                $output_filename = "$($_.Name -replace '.pkr.hcl|.json','')"
                if ($script:PackerVariables.output_filename)
                {
                    $script:PackerVariables.output_filename = $output_filename
                }
                else
                {
                    $script:PackerVariables.add('output_filename', $output_filename)
                }

                # Once we've built our base image then our other builds will need to know the path to it.
                if ($script:BaseImagePath)
                {
                    if ($script:PackerVariables.input_file)
                    {
                        $script:PackerVariables.input_file = $script:BaseImagePath
                    }
                    else
                    {
                        $script:PackerVariables.add('input_file', $script:BaseImagePath)
                    }
                }

                # We need to set this variable otherwise Packer will store it in a location that we don't expect...
                if ($_.Name -match '-vagrant')
                {
                    $script:PackerVariables.add('vagrant_output_directory', ($script:CompletedBuildDirectory | Convert-Path | Convert-WindowsPath))
                }
                
                # Convert our packer variables to make sure they are in a format that Packer can understand
                $ConvertedVariables = $script:PackerVariables | ConvertTo-PackerVariable

                # Due to issues with escape characters in the command line we use a variables file to be safe
                $PackerVarsFile = New-PackerVarsFile `
                    -Path (Join-Path $script:BuildOutputDirectory 'variables.pkrvars.hcl') `
                    -PackerVariables $ConvertedVariables `
                    -Force

                $PackerParams = @{
                    PackerTemplate   = $_
                    WorkingDirectory = $script:BuildOutputDirectory
                    VariableFile     = $PackerVarsFile
                }
                # Only the customize builds have the logic for setting local admin users
                if ($script:SecureVariables -and ($_.Name -match '-customized'))
                {
                    $ConvertedSecureVariables = $script:SecureVariables | ConvertTo-PackerVariable
                    $PackerParams.add('TemplateVariables', $ConvertedSecureVariables)
                }

                # First validate
                Invoke-PackerValidate @PackerParams

                # Then build
                Invoke-PackerBuild @PackerParams

                # After a successful build of our base image we store the resulting OVF file in a variable for the subsequent builds to use
                if (!$script:BaseImagePath)
                {
                    $script:BaseImagePath = Get-ChildItem $output_directory | Where-Object { $_.Name -match '-base.ovf$' } | Convert-Path | Convert-WindowsPath
                }
                # Get the last built OVF file (if we've got one)
                $OVFFile = Get-ChildItem $output_directory | Where-Object { $_.Name -match '.ovf$' } | Convert-Path
                # Sometimes we can end up with a NVRAM file (currently only macOS) as it stands these are not handled by Packer/VBox very well (read: at all)
                # So we need to munge the XML a bit to make sure we include the NVRAM file in the OVF, otherwise we'll get dumped at the EFI shell
                # (the other workaround is to use the ISO to boot into recovery and set the boot disk)
                $NVRAMPath = Get-ChildItem $output_directory | Where-Object { $_.Name -match '.nvram$' } | Convert-Path
                if ($NVRAMPath)
                {
                    try
                    {
                        [xml]$OVFContent = Get-Content -Path $OVFFile -Raw
                        if ($OVFContent.Envelope.VirtualSystem.Machine.Hardware.BIOS.NVRAM.path)
                        {
                            $OVFContent.Envelope.VirtualSystem.Machine.Hardware.BIOS.NVRAM.path = $NVRAMPath
                        } else
                        {
                            $NVRAM = $OVFContent.CreateElement('NVRAM','http://schemas.dmtf.org/ovf/envelope/1')
                            $NVRAM.SetAttribute('path', $NVRAMPath)
                            $OVFContent.Envelope.VirtualSystem.Machine.Hardware.BIOS.AppendChild($NVRAM)
                        }
                    }
                    catch
                    {
                        throw $_.Exception.Message
                    }
                }
                # Add our completed Packer build to the list of files to move later on
                $FilesToMove += $output_directory
            }
            # Move the completed builds so they are easy to find!
            $FilesToMove | Get-ChildItem -Recurse | Move-Item -Destination $script:CompletedBuildDirectory -Force
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
