<#
.SYNOPSIS
    Invokes Packer to perform a build using a given template file
.DESCRIPTION
    This cmdlet will call Packer to perform a build using the specified template file
    (essentially this is just a PowerShell wrapper for Packer).
.EXAMPLE
    PS C:\> Invoke-PackerBuild C:\windows10.pkr.hcl
    
    This would run a build using the template file C:\windows10.pkr.hcl
.NOTES
    Packer looks for paths relative to the current working directory so your templates either need to reference locations
    properly, or you need to set the working directory before calling this cmdlet.
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

        # If the build fails do: clean up (default), abort, or run-cleanup-provisioner.
        # (ask is disabled as we do not connect to StdIn)
        [Parameter(
            Mandatory = $false
        )]
        [ValidateSet('cleanup', 'abort', 'run-cleanup-provisioner')]
        [string]
        $OnError,

        # Any variables to set
        [Parameter(
            Mandatory = $false
        )]
        [hashtable]
        $TemplateVariables,

        # Add timestamps to stdout
        [Parameter(
            Mandatory = $false
        )]
        [switch]
        $EnableTimestamps,

        # If set will enable color output, disabled by default for CI/CD deployments
        [Parameter(
            Mandatory = $false
        )]
        [Alias('EnableColour')]
        [switch]
        $EnableColor,

        # The working directory to use (useful for handling Packer's relative paths)
        [Parameter(
            Mandatory = $false
        )]
        [string]
        $WorkingDirectory
    )
    
    begin
    {
        if ($Only -and $Except)
        {
            throw "Cannot specify both 'Except' and 'Only'"
        }
        if (!(Test-Path $PackerTemplate))
        {
            throw "Packer template $PackerTemplate not found."
        }
        if ($PackerTemplate -notmatch '.hcl|.json')
        {
            throw "$PackerTemplate does not appear to be a packer template file"
        }
    }
    process
    {
        $PackerArgs = @("build")
        if (!$EnableColor)
        {
            $PackerArgs += '--color=false'
        }
        if ($Except)
        {
            $PackerArgs += "--except=$($Except -join ',')"
        }
        if ($Only)
        {
            $PackerArgs += "--only=$($Only -join ',')"
        }
        if ($OnError)
        {
            $PackerArgs += "--on-error=$OnError"
        }
        if ($EnableTimestamps)
        {
            $PackerArgs += "--timestamp-ui"
        }
        if ($TemplateVariables)
        {
            $TemplateVariables.GetEnumerator() | ForEach-Object {
                $PackerArgs += @("--var","$($_.Name)=$($_.Value)")
            }
        }
        $PackerArgs += "$($PackerTemplate | Convert-Path)"
        $SilentProcParams = @{
            FilePath = 'packer'
            ArgumentList = $PackerArgs
        }
        if ($WorkingDirectory)
        {
            if (!(Test-Path $WorkingDirectory))
            {
                throw "Working directory $WorkingDirectory is not valid"
            }
            $SilentProcParams.Add('WorkingDirectory',$WorkingDirectory)
        }
        Write-Verbose "Beginning Packer build for $PackerTemplate"
        try
        {
            Start-SilentProcess @SilentProcParams
        }
        catch
        {
            throw "Failed to build packer template $PackerTemplate.`n$($_.Exception.Message)"
        }
    }
    end
    {

    }
}