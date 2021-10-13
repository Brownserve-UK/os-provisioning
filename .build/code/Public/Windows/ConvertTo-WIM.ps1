<#
.SYNOPSIS
    Converts a VHD file to a WIM image
.DESCRIPTION
    Long description
    [Compatible with: Windows]
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
function ConvertTo-WIM
{
    [CmdletBinding()]
    param
    (
        # The path to the VHD to convert
        [Parameter(Mandatory = $true, Position = 0)]
        [string[]]
        $VHDPath,

        # The path to store the converted image in
        [Parameter(Mandatory = $false, Position = 1)]
        [string]
        $Destination,

        # The name of the operating system being converted
        [Parameter(Mandatory = $false, Position = 2)]
        [string]
        $OSName = ((Split-Path $VHDPath -Leaf) -replace '(-disk.*)$', '' -replace '\.vhd$', ''),

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
        if (!Test-Administrator)
        {
            throw "This script must be run in an elevated session as it requires the ability to mount WIM images"
        }
        $Return = @()
    }
    
    process
    {
        $VHDPath | ForEach-Object {
            if (!(Test-Path $VHDPath))
            {
                throw "VHD '$VHDPath' not found"
            }
            if ($VHDPath -notmatch '.[vV][hH][dD]$')
            {
                throw "'$VHDPath' does not appear to be a valid VHD file"
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
                $OSNameClean = $OSName -replace ' ', '-'
                $WIMName = "$OSNameClean.wim"
                $WIMOutput = Join-Path $Destination "temp-$WIMName"
                # Currently this fails if the WIM already exists (😬) so we give it a temporary name first
                $TempWIMOutput = Join-Path $Destination "temp-$WIMName"
                $WIMDescription = "$OSName Created $(Get-Date -Format yyyy-MM-dd)"
                Write-Verbose "Creating new WIM image from $MountPath"
                New-WindowsImage `
                    -CapturePath $MountPath `
                    -Name $OSNameClean `
                    -ImagePath $TempWIMOutput `
                    -Description $WIMDescription `
                    -Verify `
                    -ErrorAction Stop | Out-Null
                Move-Item $TempWIMOutput -Destination $WIMOutput -Force -Confirm:$false
                $Return += $WIMOutput
            }
            catch
            {
                throw "Failed to capture WIM '$WIMName'`n$($_.Exception.Message)"
            }
            finally
            {
                Dismount-WindowsImage -Path $MountPath -Discard
                Remove-Item $MountPath -Recurse -Force -Confirm:$false
                Remove-Item $TempWIMOutput -Force -ErrorAction 'SilentlyContinue' # may not exist if everything worked!
            }

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