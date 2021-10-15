<#
.SYNOPSIS
    Very simple cmdlet that handles converting windows paths
.DESCRIPTION
    Long description
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
function Convert-WindowsPath
{
    [CmdletBinding()]
    param
    (
        # The path to convert
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias('PSPath')]
        [string]
        $Path
    )
    
    begin
    {
    
    }
    
    process
    {
        if ($IsWindows)
        {
            $SanitizedPath = $Path
            # If on Windows we need to check what type of path we've got and escape it properly
            if ($Path -match '^\\\\')
            {
                Write-Verbose "Converting network path"
                $SanitizedPath = $Path -replace '\\', '\\'
            }
            if ($Path -match '^[a-zA-Z]:\\')
            {
                Write-Verbose "Converting Windows path"
                $SanitizedPath = $Path -replace '\\', '/'
            }
            $Return = $SanitizedPath
        }
        # If we're not on Windows just return whatever was put in to this cmdlet
        else
        {
            $Return = $Path
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