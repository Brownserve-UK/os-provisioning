<#
.SYNOPSIS
    Builds a macOS DMG/ISO from a given installer package
.DESCRIPTION
    Builds a macOS DMG/ISO from a given installer package
    [Compatible with: macOS]
.EXAMPLE
    PS /scripts/> BuildMacOSImage `
        -MacOSInstallerPath '/Applications/Install macOS Big Sur.app/' `
        -OutputDirectory '~/Images'
        -CreateISO
    
    This would build a macOS DMG and ISO for Big Sur and store the resulting output in ~/Images
.NOTES
    This script must be run as root due to needing permissions to install to the mounted volume.
#>
function Build-MacOSImage
{
    [CmdletBinding()]
    param
    (
        # The path to the macOS installer application
        [Parameter(
            Mandatory = $true,
            Position = 0
        )]
        [string]
        $MacOSInstallerPath,

        # The output directory
        [Parameter(
            Mandatory = $true,
            Position = 1
        )]
        [string]
        $OutputDirectory,

        # If set will create an ISO image alongside a DMG
        [Parameter()]
        [switch]
        $CreateISO,

        # If set will discard the DMG file (can only be set when CreateISO is also set)
        [Parameter()]
        [switch]
        $DiscardDMG
    )
    
    begin
    {
        # Set some default variables
        $MinimumSupportedVersion = [version]'10.2'
        $MaximumSupportedVersion = [version]'11.999.999'
        if (!(Test-Path $OutputDirectory))
        {
            throw "$OutputDirectory does not appear to be valid"
        }
        if ($DiscardDMG -and (-not $CreateISO))
        {
            throw "Cannot set DiscardDMG without specifying CreateISO"
        }
        # Test root access
        if (!(Test-Administrator))
        {
            throw "This script must be run as root"
        }
    }
    
    process
    {
        $DiskImageSize = 8
        $macOS11 = $false
        if (!(Test-Path $MacOSInstallerPath))
        {
            throw "Cannot find the macOS installer application at $MacOSInstallerPath"
        }
        try
        {
            $InstallerDMG = Get-ChildItem (Join-Path $MacOSInstallerPath 'Contents' 'SharedSupport') -Filter '*.dmg'
        }
        catch
        {
            throw $_.Exception.Message
        }
        if (!$InstallerDMG)
        {
            throw "Could not find installer image at $MacOSInstallerPath."
        }
        switch ($InstallerDMG.Name)
        {
            'InstallESD.dmg'
            {
                # No special steps required at the moment
            }
            'SharedSupport.dmg'
            {
                $macOS11 = $true
            }
            Default
            {
                throw "Unrecognised DMG $($InstallerDMG.Name)"
            }
        }

        # Obtain our version number
        if ($macOS11)
        {
            $DiskImageSize = 15
            $hdiutilArgs = @(
                'attach',
                "`"$($InstallerDMG | Convert-Path)`"",
                '-quiet',
                '-noverify',
                '-mountpoint',
                '"/Volumes/macOS11"'

            )
            Write-Verbose "Mounting $(Convert-Path $InstallerDMG)"
            try
            {
                Start-SilentProcess `
                    -FilePath 'hdiutil' `
                    -ArgumentList $hdiutilArgs
            }
            catch
            {
                throw "Failed to mount the dmg.`n$($_.Exception.Message)"
            }
            Write-Verbose "Obtaining installer version"
            # This took a LONG time to work out cos of weird PowerShell string/command interpolation
            # the types of quotations used are important for some reason :shrug:
            # If you need to debug this then the following command may help:
            # & '/usr/libexec/PlistBuddy' '-c' "Print :Assets:0:OSVersion" "/Volumes/macOS11/com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml"
            $PListBuddyArgs = @(
                '-c',
                'Print:Assets:0:OSVersion',
                "/Volumes/macOS11/com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml"
            )
            try
            {
                $InstallerVersion = Start-SilentProcess `
                    -FilePath '/usr/libexec/PlistBuddy' `
                    -ArgumentList $PListBuddyArgs `
                    -PassThru | Select-Object -ExpandProperty OutputContent
            }
            catch
            {
                throw "Failed to obtain installer version.`n$($_.Exception.Message)"
            }
            finally
            {
                Write-Verbose "Detaching macOS installer"
                Start-SilentProcess `
                    -FilePath 'hdiutil' `
                    -ArgumentList 'detach "/Volumes/macOS11" -force -quiet'
            }
        }
        else
        {
            $PListPath = Join-Path $MacOSInstallerPath 'Contents' 'SharedSupport', 'InstallInfo.plist'
            if (!(Test-Path $PListPath))
            {
                throw "Failed to find $PListPath"
            }
            $PListBuddyArgs = @(
                "-c 'Print :System\ Image\ Info:version'",
                $PListPath
            )
            try
            {
                $InstallerVersion = Start-SilentProcess `
                    -FilePath '/usr/libexec/PlistBuddy' `
                    -ArgumentList $PListBuddyArgs `
                    -PassThru | Select-Object -ExpandProperty OutputContent
            }
            catch
            {
                throw "Failed to obtain installer version.`n$($_.Exception.Message)"
            }
        }
        Write-Verbose "Installer version: $InstallerVersion"
        $Return = @{
            InstallerVersion = $InstallerVersion
        }
        [version]$InstallerVersion = $InstallerVersion
        if (($InstallerVersion -lt $MinimumSupportedVersion) -or ($InstallerVersion -gt $MaximumSupportedVersion))
        {
            throw "This version ($($InstallerVersion.ToString())) is not supported.`nMinimum supported version: $($MinimumSupportedVersion.ToString())`nMaximum supported version: $($MaximumSupportedVersion.ToString())"
        }
        $FinalImageName = "macOS_$($InstallerVersion.ToString().Replace('.',''))"

        # Check to make sure we can find the command to create install media
        $InstallCommand = Join-Path $MacOSInstallerPath 'Contents' 'Resources', 'createinstallmedia'
        Write-Verbose "Checking path to createinstallmedia"
        if (!(Test-Path $InstallCommand))
        {
            throw "Cannot find path to createinstallmedia"
        }

        # Create a disk image for us to install to
        $InstallDiskLocation = Join-Path $OutputDirectory $FinalImageName
        $VolumeName = "/Volumes/$FinalImageName"
        Write-Verbose "Creating a disk image to install to"
        $InstallDiskArgs = @(
            'create',
            '-o',
            "$InstallDiskLocation",
            '-size',
            "$($DiskImageSize)g",
            '-layout',
            'SPUD',
            '-fs',
            'HFS+J'
        )
        try
        {
            Start-SilentProcess `
                -FilePath 'hdiutil' `
                -ArgumentList $InstallDiskArgs
        }
        catch
        {
            throw "Failed to create a install disk.`n$($_.Exception.Message)"
        }
        Write-Verbose "Mounting install disk to $VolumeName"
        $MountArgs = @(
            'attach',
            "$InstallDiskLocation.dmg",
            '-noverify',
            '-mountpoint',
            $VolumeName

        )
        try
        {
            Start-SilentProcess `
                -FilePath 'hdiutil' `
                -ArgumentList $MountArgs
        }
        catch
        {
            throw "Failed to attach install disk image.`n$($_.Exception.Message)"
        }

        # Install to our mounted image!
        switch -regex ($InstallerVersion.ToString())
        {
            '10.12|10.13'
            {
                $InstallArgs = @(
                    '--volume',
                    $VolumeName,
                    '--applicationpath',
                    $MacOSInstallerPath,
                    '--nointeraction'
                )
            }
            Default
            {
                $InstallArgs = @(
                    '--volume',
                    $VolumeName,
                    '--nointeraction'
                )
            }
        }
        Write-Verbose "Installing macOS $($InstallerVersion.ToString()) to $VolumeName"
        try
        {
            Start-SilentProcess `
                -FilePath $InstallCommand `
                -ArgumentList $InstallArgs

            # Resolve the path to the DMG file we've just created
            $DMGPath = "$InstallDiskLocation.dmg" | Convert-Path
        }
        catch
        {
            throw "Failed to install macOS $($InstallerVersion.toString()) to install disk.`n$($_.Exception.Message)"
        }
        finally
        {
            # Detach the mounted image(s)
            Write-Verbose "Detaching the mounted installer image(s)"
            # The mounted volume will have changed name now and we may have more than one...
            # Let's try to clean up after ourselves properly
            Get-ChildItem '/Volumes/' | Where-Object { $_.Name -like 'Install*' -or $_.Name -like 'Shared Support' -or $_.Name -like $FinalImageName } | ForEach-Object {
                $AbsolutePath = $_.PSPath | Convert-Path
                # Sometimes the paths unmount themselves... so check before removing each.
                if ((Test-Path $AbsolutePath))
                {
                    $DetachArgs = "detach `"$AbsolutePath`" -force -quiet"
                    Write-Verbose "Detaching mounted volume $AbsolutePath"
                    Start-SilentProcess `
                        -FilePath 'hdiutil' `
                        -ArgumentList $DetachArgs
                }
            }
        }

        # Now we can move the built image to our build output directory
        if ($CreateISO)
        {
            Write-Verbose "Converting $InstallDiskLocation.dmg into an ISO"
            $CDRPath = Join-Path $OutputDirectory "$FinalImageName"
            $ConvertArgs = @(
                'convert',
                "$DMGPath",
                '-format',
                'UDTO',
                '-o',
                $CDRPath

            )
            try
            {
                Start-SilentProcess `
                    -FilePath 'hdiutil' `
                    -ArgumentList $ConvertArgs
                
                # The ISO will actually be a CDR, we'll need to convert it to an ISO
                Rename-Item "$CDRPath.cdr" -NewName "$FinalImageName.iso"
                $ISOPath = Join-Path $OutputDirectory "$FinalImageName.iso" | Convert-Path
                Write-Debug "ISO path = $ISOPath"
                $Return.Add('ISOPath',$ISOPath)
            }
            catch
            {
                throw "Failed to convert $InstallDiskLocation.dmg into an ISO.`n$($_.Exception.Message)"
            }
            try
            {
                Write-Verbose "Generating shasum of $ISOPath"
                $SHASum = Start-SilentProcess `
                    -FilePath 'shasum' `
                    -ArgumentList "-a 256 $ISOPath" `
                    -PassThru | Select-Object -ExpandProperty OutputContent
                $SHASum = $SHASum -replace " $ISOPath",''
                Write-Debug "ISO SHAsum = $SHASum"
                New-Item (Join-Path $OutputDirectory "$FinalImageName.iso.shasum") -Value $SHASum | Out-Null
                $Return.Add('ISOSHASum',$SHASum)
            }
            catch
            {
                throw "Failed to generate ISO shasum.`n$($_.Exception.Message)"
            }
        }
        if ($DiscardDMG)
        {
            Write-Verbose "Removing DMG file"
            try
            {
                Remove-Item $DMGPath -Force -Confirm:$false
            }
            catch
            {
                Write-Error "Failed to remove DMG file $DMGPath"
            }
        }
        else
        {
            Write-Debug "DMG path = $DMGPath"
            $Return.Add('DMGPath', $DMGPath)
        }

    }
    end
    {
        Return [pscustomobject]$Return
    }
}