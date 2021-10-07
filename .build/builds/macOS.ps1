<#
.SYNOPSIS
    Builds our macOS images
#>
[CmdletBinding()]
param
(
    # The path to the createuserpkg python script
    [Parameter(
        Mandatory = $false
    )]
    [string]
    $PyCreateUserPkgPath
)
# Always stop on errors
$ErrorActionPreference = 'Stop'

# We need to be running on macOS hardware
if (!$IsMacOS)
{
    throw "This build can only currently be run on Apple hardware, sorry!"
}

try
{
    Write-Host "Starting build $($MyInvocation.MyCommand)"
    $BuildTimer = New-Object -TypeName System.Diagnostics.Stopwatch
    $BuildTimer.Start()
    $Success = $false

    # dot source the _init.ps1 script
    Write-Verbose "Initialising repo"
    $initScriptPath = Join-Path $PSScriptRoot -ChildPath '_init.ps1' | Convert-Path
    . $initScriptPath

    # First we need to get the list of macOS versions we currently build for
    # We do this by getting the child items of os-provisioning/macOS which should correspond to a macOS version (e.g. '11')
    Get-ChildItem (Join-Path $Global:RepoRootDirectory 'macOS') | 
        Where-Object { $_.PSIsContainer } | 
            ForEach-Object {
                Write-Verbose "Now preparing to build macOS $($_.Name)"

                $IBParams = @{
                    File                   = (Join-Path $global:BuildTasksDirectory 'macOS.ps1')
                    Task                   = 'BuildPackerImages'
                    ConfigurationDirectory = ($_ | Convert-Path)
                }
                if ($PyCreateUserPkgPath)
                {
                    $IBParams.Add('PyCreateUserPkgPath', $PyCreateUserPkgPath)
                }
                Invoke-Build @IBParams -Verbose:($PSBoundParameters['Verbose'] -eq $true)
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
