<#
.SYNOPSIS
    Builds macOS ISO images
#>
[CmdletBinding()]
param ()
# Always stop on errors
$ErrorActionPreference = 'Stop'

if (!$IsMacOS)
{
    throw "This build can only be run on Apple hardware, sorry!"
}

Write-Host "Starting build $($MyInvocation.MyCommand)"

# dot source the _init.ps1 script
try
{
    Write-Verbose "Initialising repo"
    $initScriptPath = Join-Path $PSScriptRoot '..' '_init.ps1' | Convert-Path
    . $initScriptPath
}
catch
{
    Write-Error "Failed to init repo.`n$($_.Exception.Message)"
}

Get-ChildItem (Join-Path $Global:RepoRootDirectory 'macOS') | 
    Where-Object { ($_.PSIsContainer) -and ($_.Name -ne 'scripts') } | 
        ForEach-Object {
            Write-Verbose "Now preparing to build image for macOS $($_.Name)"
            $IBParams = @{
                File                   = (Join-Path $global:BuildTasksDirectory 'macOS_images.ps1')
                Task                   = 'BuildISO'
                ConfigurationDirectory = ($_ | Convert-Path)
            }
            try
            {
                Invoke-Build @IBParams -Verbose:($PSBoundParameters['Verbose'] -eq $true)
            }
            catch
            {
                throw "Failed to build ISO for macOS $($_.Name)"
            } 
        }

Write-Host "Build $($MyInvocation.MyCommand) completed successfully! 🎉" -ForegroundColor Green