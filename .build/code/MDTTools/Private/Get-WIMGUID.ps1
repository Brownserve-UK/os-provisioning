<#
.SYNOPSIS
    Gets the GUID for a given MDT WIM image
#>
function Get-WindowsImageGUID
{
    [CmdletBinding()]
    param
    (
        # The name of the WIM to get the GUID for
        [Parameter(
            Mandatory = $true,
            Position = 0
        )]
        [string[]]
        $WIMName,

        # The name of the PS Drive that contains the mounted deployment share
        [Parameter(
            Mandatory = $true,
            Position = 1
        )]
        [string]
        $PSDriveName
    )
    
    begin
    {
        # Try to sanitize the PSDrive name
        $SanitizedDriveName = $PSDriveName -replace '\:\\', ''
        $OperatingSystemsPath = "$($SanitizedDriveName):\Operating Systems"
        $Return = @()
    }
    
    process
    {
        $WIMName | ForEach-Object {
            Write-Verbose "Fetching GUID for $_"
            try
            {
                $ExistingWindowsImageGUID = (Get-ItemProperty "$OperatingSystemsPath\$_").guid
            }
            catch
            {
                throw "Failed to get old WIM GUID for $_.`n$($_.Exception.Message)"
            }
            if (!$ExistingWindowsImageGUID)
            {
                throw "Empty WIM GUID returned for $_"
            }
            $Return += $ExistingWindowsImageGUID
        }
    }
    
    end
    {
        if ($Return)
        {
            Return $Return
        }
    }
}