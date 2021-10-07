<#
.SYNOPSIS
    Builds our Windows images
#>
[CmdletBinding()]
param
(
    # The path to where your Windows ISO's are stored.
    [Parameter(Mandatory = $true, Position = 0)]
    [string]
    $ISODirectory
)
# Always stop on errors
$ErrorActionPreference = 'Stop'

try
{
    Write-Host "Starting build $($MyInvocation.MyCommand)"
    $BuildTimer = New-Object -TypeName System.Diagnostics.Stopwatch
    $BuildTimer.Start()
    $Success = $false

    # dot source the _init.ps1 script
    Write-Verbose "Initialising repo"
    $initScriptPath = Join-Path $PSScriptRoot '..' '_init.ps1' | Convert-Path
    . $initScriptPath

    # First get the list of OSes to build
    Get-ChildItem (Join-Path $Global:RepoRootDirectory 'Windows') |
        Where-Object {$_.PSIsContainer} |
            ForEach-Object {
                # Because Windows can have many editions for the same OS (e.g. Server 2019 Standard/Datacenter)
                # We need to check what versions we want to build, we do this by checking what autounattend's we have
                $Autounattends = Get-ChildItem (Join-Path $_ 'autounattend')
                if (!$Autounattends)
                {
                    throw "Could not find any autounattend's for $_"
                }
                $ConfigurationDirectory = $_
                $Autounattends | ForEach-Object {
                    # Do a build!
                    Invoke-Build `
                        -File (Join-Path $global:BuildTasksDirectory 'Windows.ps1') `
                        -Task 'BuildPackerImages' `
                        -ConfigurationDirectory ($ConfigurationDirectory | Convert-Path) `
                        -ISODirectory ($ISODirectory | Convert-Path) `
                        -AutounattendPath ($_ | Convert-Path) `
                        -Verbose:($PSBoundParameters['Verbose'] -eq $true)
                }
            }
    $Success = $true
}
catch
{
    $ErrorMessage = $_.Exception.Message
}
finally
{
    $BuildTimer.Stop()
    $BuildTime = $BuildTimer.Elapsed.Minutes
    if ($Success)
    {
        Write-Host "Build $($MyInvocation.MyCommand) completed successfully in $BuildTime minutes! 🎉" -ForegroundColor Green
    }
    else
    {
        Write-Error "Build $($MyInvocation.MyCommand) failed after $BuildTime minutes, error:`n$ErrorMessage"
    }
}
