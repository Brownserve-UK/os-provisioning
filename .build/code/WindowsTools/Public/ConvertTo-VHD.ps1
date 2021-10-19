<#
.SYNOPSIS
    Converts a VMDK disk file into a VHD file.
.DESCRIPTION
    This cmdlet takes a VMDK disk file and converts it into a VHD file this can be useful when working with Windows
    images as these can be easily repacked into WIM images
.EXAMPLE
    PS C:\> ConvertTo-VHD -VMDKPath C:\Windows10.vmdk -Destination C:\VHDs\

    This would take the 'Windows10.vmdk' and convert it to a VHD in 'C:\VHDs\'
#>
function ConvertTo-VHD
{
    [CmdletBinding()]
    param
    (
        # The path to the VirtualBox VMDK file
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline)]
        [string[]]
        $VMDKPath,

        # The path to store the converted VHD in
        [Parameter(Mandatory = $false, Position = 1)]
        [string]
        $Destination = $PWD,

        # If set will delete the old VMDK file after a successful conversion
        [Parameter(Mandatory = $false)]
        [switch]
        $CleanupVMDK
    )
    
    begin
    {
        try
        {
            $DestinationInfo = Get-Item $Destination
        }
        catch
        {
            throw "Destination '$Destination' does not appear to exist"
        }
        if (!$DestinationInfo.PSIsContainer)
        {
            throw "Destination must be a container"
        }
        $Return = @()
    }
    
    process
    {
        $VMDKPath | ForEach-Object {
            $VMDKName = ($_ | Split-Path -Leaf) -replace '\.vmdk', ''
            if ($_ -notmatch '\.[vV][mM][dD][kK]$')
            {
                throw "VMDKPath must point to a '.vmdk' file"
            }
            if (!(Test-Path $_))
            {
                throw "VMDKPath '$_' does not exist"
            }
            $VHDPath = Join-Path $Destination "$VMDKName.vhd"
            Write-Verbose "Attempting to convert $_ into a VHD"
            try
            {
                Start-SilentProcess `
                    -File 'VBoxManage' `
                    -ArgumentList "clonehd $_ $VHDPath --format vhd"
                $ConvertedVHD = Get-Item $VHDPath -Force
                $Return += $ConvertedVHD
            }
            catch
            {
                throw "Failed to convert $_ into a VHD.`n$($_.Exception.Message)"
            }
            if ($CleanupVMDK)
            {
                Write-Verbose "Cleaning up $_"
                try
                {
                    Remove-Item $_ -Force -Confirm:$false
                }
                catch
                {
                    Write-Error "Failed to cleanup $_.`n$($_.Exception.Message)"
                }
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