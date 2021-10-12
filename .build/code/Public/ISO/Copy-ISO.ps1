<#
.SYNOPSIS
    Copies an ISO from one place to another
.DESCRIPTION
    Sometimes when running builds we want to copy an ISO to another place for increased performance
    (e.g from the web to the local drive, or from a HDD to an SDD).
    This cmdlet allows us to do that
.EXAMPLE
    PS C:\> Copy-ISO -ISOPath http://myisos.com/windows10.iso -Destination C:\myISOs
    
    This would copy the 'windows10' ISO from 'http://myisos.com' to 'c:\myISOs\windows10.iso'

    PS ~/ Copy-ISO -ISOPath /opt/ISO/windows10.iso -Destination ~/Documents/ISO
    
    This would copy the 'windows10' ISO from '/opt/ISO/windows10.iso' to '~/Documents/ISO'
#>
function Copy-ISO
{
    [CmdletBinding()]
    param
    (
        # The path to the ISO to copy (either local or URL)
        [Parameter(
            Mandatory = $true,
            Position = 0
        )]
        [string]
        $ISOPath,

        # The destination to copy to
        [Parameter(
            Mandatory = $true,
            Position = 1
        )]
        [string]
        $Destination
    )
    
    begin
    {
        $Return = @()
        try
        {
            $DestinationInfo = Get-Item $Destination
        }
        catch
        {
            throw "'$Destination' does not seem to exist."
        }
        if (!$DestinationInfo.PSIsContainer)
        {
            throw "'Destination' must be a directory"
        }
    }
    
    process
    {
        $ISOName = Split-Path $ISOPath -Leaf
        $DownloadPath = Join-Path $Destination $ISOName
        switch -regex ($ISOPath)
        {
            '^[hH][tT][tT][Pp]|[Ff][Tt][Pp]' 
            {
                Write-Verbose "$ISOPath is a URL"
                # For URL's we need to use Invoke-WebRequest to download the ISO's
                try
                {
                    Invoke-DownloadMethod -DownloadURI $ISOPath -OutFile $DownloadPath
                    $CopiedFile = Get-Item $DownloadPath
                }
                catch
                {
                    throw "Failed to download ISO from $ISOPath to $DownloadPath.`n$($_.Exception.Message)"
                }
            }
            '^(?:\/.*|smb\:.*)$|^(?:(?:[A-Z]:|[a-z]:|\\)\\.*)$'
            {
                Write-Verbose "$ISOPath is local"
                try
                {
                    Copy-Item $ISOPath -Destination $DownloadPath
                    $CopiedFile = Get-Item $DownloadPath
                }
                catch
                {
                    throw "Failed to copy ISO $ISOPath to $DownloadPath.`n$($_.Exception.Message)"
                }
            }
            Default
            {
                throw "Unsupported ISOPath '$ISOPath'"
            }
        }
        $Return += $CopiedFile
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