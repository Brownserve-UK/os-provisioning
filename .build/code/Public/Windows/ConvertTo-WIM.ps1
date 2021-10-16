<#
.SYNOPSIS
    Converts a VHD file to a WIM image
.DESCRIPTION
    Converts a VHD file to a WIM image
    [Compatible with: Windows]
.EXAMPLE
    PS C:\> ConvertTo-WIM `
        -VHDPath C:\Images\Windows10.VHD `
        -Destination C:\Images

    Would convert the 'C:\Images\Windows10.VHD' into 'C:\Images\Windows10.wim'

.EXAMPLE
    PS C:\> ConvertTo-WIM `
        -VHDPath C:\Images\Windows10.VHD `
        -Destination C:\Images `
        -WIMName 'Windows10-Pro' `
        -CleanupVHD 

    Would convert the 'C:\Images\Windows10.VHD' into a WIM stored in 'C:\Images\Windows10-Pro.wim'.
    After a successful conversion 'C:\Images\Windows10.VHD' would be removed.
#>
function ConvertTo-WIM
{
    [CmdletBinding()]
    param
    (
        # The path to the VHD to convert
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $VHDPath,

        # The path to store the converted image in
        [Parameter(Mandatory = $false, Position = 1)]
        [string]
        $Destination,

        # The name of the operating system being converted
        [Parameter(Mandatory = $false, Position = 2)]
        [string]
        $WIMName,

        # If passed will clean-up the VHD after a successful conversion
        [Parameter(Mandatory = $false)]
        [switch]
        $CleanupVHD
    )
    
    begin
    {
        if (!$IsWindows)
        {
            throw "This can only be used on Windows"
        }
        if (!(Test-Administrator))
        {
            throw "This script must be run in an elevated session as it requires the ability to mount WIM images"
        }
        $Return = @()
    }
    
    process
    {
        if (!(Test-Path $VHDPath))
        {
            throw "VHD '$VHDPath' not found"
        }
        if ($VHDPath -notmatch '.[vV][hH][dD]$')
        {
            throw "'$VHDPath' does not appear to be a valid VHD file"
        }
        # Set our WIMName (if we don't already have one) based off the VHDPath
        if (!$WIMName)
        {
            $WIMName = ((Split-Path $VHDPath -Leaf) -replace '(-disk.*)$', '' -replace '\.vhd$', '')
        }
        try
        {
            # Create a temporary directory to use for mounting the WIM
            $MountPath = New-TempDirectory
            Write-Verbose "Mounting VHD $VHDPath"
            Mount-WindowsImage -ImagePath $VHDPath -Path $MountPath -Index 1 | Out-Null
        }
        catch
        {
            # Try to clean up and not leave mess everywhere
            Remove-Item $MountPath -Force -Recurse -ErrorAction SilentlyContinue
            throw "Failed to mount VHD.$($_.Exception.Message)"
        }
        try
        {
            # Replace any spaces that may be in the OS name
            $WIMNameClean = $WIMName -replace ' ', '-'
            $WIMName = "$WIMNameClean.wim"
            $WIMOutput = Join-Path $Destination "$WIMName"
            # Currently this fails if the WIM already exists (😬) so we give it a temporary name first
            $TempWIMOutput = Join-Path $Destination "temp-$WIMName"
            $WIMDescription = "$WIMName Created $(Get-Date -Format yyyy-MM-dd)"
            Write-Verbose "Creating new WIM image from $MountPath"
            New-WindowsImage `
                -CapturePath $MountPath `
                -Name $WIMNameClean `
                -ImagePath $TempWIMOutput `
                -Description $WIMDescription `
                -ErrorAction Stop | Out-Null
            Move-Item $TempWIMOutput -Destination $WIMOutput -Force -Confirm:$false | Out-Null
            $WIMItem = Get-Item $WIMOutput
            $Return += $WIMItem
        }
        catch
        {
            throw "Failed to capture WIM '$WIMName'`n$($_.Exception.Message)"
        }
        finally
        {
            Dismount-WindowsImage -Path $MountPath -Discard | Out-Null
            Remove-Item $MountPath -Recurse -Force -Confirm:$false |Out-Null
            Remove-Item $TempWIMOutput -Force -ErrorAction 'SilentlyContinue' # may not exist if everything worked!
        }

    }
    
    end
    {
        if ($Return)
        {
            Return $Return
        }
        else
        {
            Return $null
        }
    }
}