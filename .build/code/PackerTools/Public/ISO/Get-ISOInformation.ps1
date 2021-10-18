<#
.SYNOPSIS
    Obtains a list of ISO's and their SHASums from a given path
.DESCRIPTION
    This cmdlet will return a list of ISO's and their SHASums from a given path, that path can be a local directory,
    a fileshare or a URL.
    The files should have a corresponding shasum placed next to them
    (e.g. 'server2019.iso' should have 'server2019.iso.shasum')
.EXAMPLE
    Get-ISOs -ISOPath 'C:\myISOs'
    
    This would return a list of ISO's and their checksums from 'C:\myISOs'

.EXAMPLE
    Get-ISOs -ISOPath 'https://packer.mycompany.com/isos'

    This would return a list of ISO's and their checksums from 'https://packer.mycompany.com/isos'
.NOTES
    For URL's we are expecting an IIS file directory site like we have set-up on our internal WebFiles01 machine.
#>
function Get-ISOInformation
{
    [CmdletBinding()]
    param
    (
        # The path to where the ISO's are located, can either be local or a URL
        [Parameter(
            Mandatory = $true,
            Position = 0
        )]
        [string]
        $ISOPath
    )
    
    begin
    {
        $Return = @()
    }
    
    process
    {
        switch -regex ($ISOPath)
        {
            '^[hH][tT][tT][Pp]|[Ff][Tt][Pp]' 
            {
                Write-Verbose "$ISOPath is a URL"
                # For URL's we need to use Invoke-WebRequest to unfold the ISO's
                try
                {
                    $BaseURL = Split-Path $ISOPath
                    $Links = Invoke-WebRequest $ISOPath -Verbose:$false | 
                        Select-Object -ExpandProperty Links
                    $ISOs = $Links | 
                        Where-Object { $_.HREF -match '.iso$' }
                    $Shasums = $Links |
                        Where-Object { $_.HREF -match '.shasum$' }
                }
                catch
                {
                    throw "Failed to get a list of ISO's from $ISOPath.`n$($_.Exception.Message)"
                }
                if (!$ISOs)
                {
                    throw "No ISO's found in $ISOPath"
                }

                # Now we need to see if we've got a SHASum for each of our ISO's
                foreach ($ISO in $ISOs)
                {
                    $ISOName = $ISO.HREF | Split-Path -Leaf
                    $SHASumPath = $null
                    $ShasumContent = $null
                    Write-Verbose "Searching for shasum for $ISOName"
                    
                    foreach ($Shasum in $Shasums)
                    {
                        $ShasumName = $Shasum.HREF | Split-Path -Leaf
                        if ($ShasumName -eq "$ISOName.shasum")
                        {
                            $SHASumPath = "$($BaseURL)$($Shasum.HREF)"
                            # Get the shasum information
                            try
                            {
                                $ShasumContent = Invoke-WebRequest $SHASumPath -Verbose:$false | Select-Object -ExpandProperty 'Content'
                            }
                            catch
                            {
                                Write-Verbose "Unable to access SHASum $SHASumPath."
                            }
                        }
                    }
                    if (!$ShasumContent)
                    {
                        # For now we skip any URL ISO's where we don't have a shasum
                        Write-Warning "No SHASum found for $ISOName in $ISOPath.`nThis ISO will be skipped"
                        Continue
                    }
                    $Return += [PSCustomObject]@{
                        ISOPath = "$($BaseURL)$($ISO.HREF)"
                        SHASum  = $ShasumContent
                    }
                }
            }
            '^(?:\/.*|smb\:.*)$|^(?:(?:[A-Z]:|[a-z]:|\\)\\.*)$'
            {
                Write-Verbose "$ISOPath is local"
                try
                {
                    $ISOPathInfo = Get-Item $ISOPath
                }
                catch
                {
                    throw "$ISOPath is not a valid directory.`n$($_.Exception.Message)"
                }
                if (!$ISOPathInfo.PSIsContainer)
                {
                    throw "$ISOPath is not a directory."
                }
                try
                {
                    $Items = Get-ChildItem $ISOPath
                    $ISOs = $Items |
                        Where-Object { $_.Name -match '.iso$' }
                    $Shasums = $Items |
                        Where-Object { $_.Name -match '.shasum$' }
                }
                catch
                {
                    throw "Failed to read ISO's from $ISOPath.`n$($_.Exception.Message)"
                }
                if (!$ISOs)
                {
                    throw "No ISO's found in $ISOPath"
                }
                foreach ($ISO in $ISOs)
                {
                    $ShasumContent = $null
                    # Find the corresponding shasum for this ISO
                    foreach ($Shasum in $Shasums)
                    {
                        if ($Shasum.Name -match "$($ISO.Name).shasum")
                        {
                            try
                            {
                                $ShasumContent = Get-Content $Shasum -Raw
                            }
                            catch
                            {
                                Write-Verbose "Unable to access shasum $($Shasum.PSPath | Convert-Path)"
                            }
                        }
                    }
                    if (!$ShasumContent)
                    {
                        Write-Warning "No SHASum found for $($ISO.PSPath | Convert-Path).`nThis ISO will be skipped"
                        Continue
                    }
                    $Return += [PSCustomObject]@{
                        ISOPath = ($ISO | Convert-Path)
                        Shasum  = $ShasumContent
                    }
                }
            }
            Default
            {
                throw "Unsupported ISOPath '$ISOPath'"
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