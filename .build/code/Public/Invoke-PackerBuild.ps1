<#
.SYNOPSIS
    Short description
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
function Invoke-PackerBuild
{
    [CmdletBinding()]
    param (
        # The template file to use
        [Parameter(
            Mandatory = $true,
            Position = 0
        )]
        [string]
        $PackerTemplate,

        # Run all builds and post-processors other than these.
        [Parameter(
            Mandatory = $false
        )]
        [array]
        $Except,

        # Build only the specified builds.
        [Parameter(
            Mandatory = $false
        )]
        [array]
        $Only,

        # If the build fails do: clean up (default), abort, ask, or run-cleanup-provisioner.
        [Parameter(
            Mandatory = $false
        )]
        [ValidateSet('cleanup','abort','ask','run-cleanup-provisioner')]
        [string]
        $OnError,

        # Any variables to set
        [Parameter(
            Mandatory = $false
        )]
        [array]
        $TemplateVariables,

        # Add timestamps to stdout
        [Parameter(
            Mandatory = $false
        )]
        [switch]
        $EnableTimestamps,

        # If set will enable color output
        [Parameter(
            Mandatory = $false
        )]
        [Alias('EnableColour')]
        [switch]
        $EnableColor
    )
    
    begin {
        
    }
    
    process {
        
    }
    
    end {
        
    }
}