<#
.SYNOPSIS
    Checks for the presence of a WIM image in MDT
#>
function Get-MDTWindowsImage
{
    [CmdletBinding()]
    param
    (
        # The name of the WIM to get the GUID from
        [Parameter(
            Mandatory = $true
        )]
        [string[]]
        $WIMName,

        # The name of the PS Drive that contains the mounted deployment share
        [Parameter(
            Mandatory = $true
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
            Write-Verbose "Checking for $_ in existing WIM's"
            $SearchString = $_
            $ExistingWIM = Get-ChildItem -Path $OperatingSystemsPath | 
                Where-Object { $_.Name -like "*$SearchString*" } |
                    Select-Object -ExpandProperty 'Name'

            if ($ExistingWIM.count -gt 1)
            {
                throw "Too many WIM images returned for $($_):`n$ExistingWim"
            }
            if ($ExistingWIM)
            {
                Write-Debug "Found:`n$($ExistingWIM)"
                $Return += $ExistingWIM
            }
        }
    }

    end
    {
        If ($Return)
        {
            Return $Return
        }
        else
        {
            Return $null
        }
    }
}