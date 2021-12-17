#!/usr/local/microsoft/powershell/7/pwsh
#.SYNOPSIS
#  This script will install VirtualBox guest additions on a macOS host.

[CmdletBinding()]
param
()
$ErrorActionPreference = 'Stop'
$DownloadURL = "http://download.virtualbox.org/virtualbox/$env:VIRTUALBOX_GUEST_ADDITIONS_VERSION/VBoxGuestAdditions_$env:VIRTUALBOX_GUEST_ADDITIONS_VERSION.iso"
# Download the required version
$DownloadPath = '/tmp/vbox-guest-additions.iso'
# Download the ISO
Write-Host 'Downloading VirtualBox Guest Additions...'
Invoke-WebRequest -Uri $DownloadURL -OutFile $DownloadPath

# Mount the ISO
Write-Host 'Mounting VirtualBox Guest Additions...'
& hdiutil mount $DownloadPath -quiet

# Find the mounted volume
$MountPath = Get-ChildItem '/Volumes/' | Where-Object { $_.Name -like 'VBox*' }

if (!$MountPath)
{
    Write-Host 'Could not find mounted volume'
    exit 1
}

if ($MountPath.count -gt 1)
{
    Write-Host 'Found multiple mounted volumes'
    exit 1
}

# Find the pkg installer
$InstallerPath = Get-ChildItem $MountPath -Recurse | Where-Object { $_.Name -like 'VBoxDarwinAdditions.pkg' } | Convert-Path
if (!$InstallerPath)
{
    Write-Host 'Could not find installer'
    exit 1
}

# Install the pkg
Write-Host 'Installing VirtualBox Guest Additions...'
& installer -pkg "$InstallerPath" -target /

# unmount the ISO
Write-Host 'Unmounting VirtualBox Guest Additions...'
& hdiutil unmount $MountPath -force -quiet