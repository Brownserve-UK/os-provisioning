<#
.SYNOPSIS
    Updates MDT with new Windows images
#>
[CmdletBinding()]
param ()
#Requires -RunAsAdministrator
# Always stop on errors
$ErrorActionPreference = 'Stop'

if (!$IsWindows)
{
    throw "This build must be run on Windows."
}

Write-Host "Starting build $($MyInvocation.MyCommand)"

# dot source the _init.ps1 script
try
{
    Write-Verbose "Initialising repo"
    $initScriptPath = Join-Path $PSScriptRoot -ChildPath '_init.ps1' | Convert-Path
    . $initScriptPath
}
catch
{
    Write-Error "Failed to init repo.`n$($_.Exception.Message)"
}

# Insert your custom build steps here

Write-Host "Build $($MyInvocation.MyCommand) completed successfully! 🎉" -ForegroundColor Green