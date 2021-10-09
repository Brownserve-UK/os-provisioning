<#
.SYNOPSIS
    This cmdlet fetches an ISO from a given location.
.DESCRIPTION
    This cmdlet fetches an ISO from a given location, that location can be either a URL or a local path/fileshare.
.EXAMPLE
    PS C:\> Get-PackerISO -ISOPath 'C:\myISOs\Windows10.iso'
    
    This would simply return the the path to 'C:\myISOs\Windows10.iso' and the corresponding shasum, if no shasum exists
    then one will be generated.
.EXAMPLE
    PS C:\> Get-PackerISO -ISOPath 'C:\myISOs\Windows10.iso' -Destination 'C:\Packer\images\Windows10.iso'
    
    This would copy the ISO at 'C:\myISOs\Windows10.iso' to 'C:\Packer\images\Windows10.iso'.
    If a shasum is found alongside the ISO it will be read, if none exists then one will be generated.
.EXAMPLE
    PS C:\> Get-PackerISO -ISOPath 'https://www.isos.com/Windows10.iso' -Destination 'C:\Packer\images\Windows10.iso'
    
    This would download the ISO from 'https://www.isos.com/Windows10.iso' to 'C:\Packer\images\Windows10.iso'.
    A shasum would be generated for this downloaded file
.NOTES
    When using a URL then there is currently no way to verify the shasum of the downloaded file automatically, while 
    unlikely this does technically open up the possibility of downloading a tampered ISO, the same is true if you
    specify a local path to an ISO that does not have a corresponding checksum file.
#>
function Get-PackerISO
{
    [CmdletBinding()]
    param
    (
        # The path to the ISO
        [Parameter(
            Mandatory = $true,
            Position = 0
        )]
        [string]
        $ISOPath,

        # When specifying a URL this is the location the ISO will be downloaded to, when specifying a local ISO
        # this parameter can be left out, but if specified the ISO will be copied to this location
        [Parameter(
            Mandatory = $false,
            Position = 1
        )]
        [string]
        $Destination
    )
    
    begin
    {
        if ($Destination)
        {
            if ($Destination -notmatch '\.iso$')
            {
                throw "Destination must be the full path to an ISO file (eg 'C:\Packer\Images\Windows10.iso')."
            }
        }
    }
    
    process
    {
        # Determine what type of ISO we have, either local or one that requires downloading
        switch -regex ($ISOPath)
        {
            '^[hH][tT][tT][Pp]|[Ff][Tt][Pp]'
            {
                Write-Verbose "$ISOPath appears to be a URL"
                # If we've got a URL then we must have a destination set
                if (!$Destination)
                {
                    throw "'-Destination' must be specified when using URL's"
                }
                # Given we don't have an easy mechanism for obtaining a checksum for a web based ISO at the moment we'll just warn
                # Once we've got our IIS site properly configured we can modify this cmdlet
                Write-Warning "Shasum's cannot be verified for URL's.`nFor your convenience one will be generated but you should verify it matches the original source manually."
                try
                {
                    Invoke-DownloadMethod -DownloadURI $ISOPath -OutFile $Destination
                    $Shasum = Get-FileHash $Destination -Algorithm SHA256
                }
                catch
                {
                    Write-Error "Failed to download ISO from $ISOPath.`n$($_.Exception.Message)"
                }
            }
            '^(?:[\/|smb\:].*).iso$|^(?:(?:[A-Z]:|[a-z]:|\\)\\.*)\.iso$'
            {
                Write-Verbose "$ISOPath appears to local"
                # Check the path is valid
                if (!(Test-Path $ISOPath))
                {
                    Write-Error "No ISO found at $ISOPath."
                }
                # If we've specified the destination parameter we need to copy the ISO
                if ($Destination)
                {
                    try
                    {
                        Copy-Item $ISOPath $Destination -Force
                    }
                    catch
                    {
                        throw "Failed to copy $ISOPath to $Destination.`n$($_.Exception.Message)"
                    }
                }
                else
                {
                    $Destination = $ISOPath
                }
                $ShasumPath = "$ISOPath.shasum"
                if ((Test-Path $ShasumPath))
                {
                    try
                    {
                        $Shasum = Get-Content $ShasumPath -Raw
                    }
                    catch
                    {
                        throw "Failed to get SHASum from $ShasumPath`n$($_.Exception.Message)"
                    }
                }
                else
                {
                    Write-Warning "SHASum not found at $ShasumPath.`nFor convenience one will be generated but you should verify the ISO has not been tampered with."
                    try
                    {
                        $Shasum = Get-FileHash $Destination -Algorithm SHA256
                    }
                    catch
                    {
                        throw "Failed to generate Shasum for $Destination"
                    }
                }
                
            }
            Default
            {
                throw "Unsupported ISOPath '$ISOPath'."
            }
        }
    }
    
    end
    {
        Return [PSCustomObject]@{
            ISOPath = $Destination
            Shasum  = $Shasum
        }
    }
}