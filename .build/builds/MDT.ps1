<#
.SYNOPSIS
    Updates MDT with new Windows images
#>
[CmdletBinding()]
param
(
    # The path to the directory containing the VMDK's/WIM's/VHD's to be imported (can also be a single item)
    [Parameter(
        Mandatory = $true
    )]
    [string]
    $InputPath,

    # The path to the MDT deployment share
    [Parameter(
        Mandatory = $true
    )]
    [string]
    $DeploymentSharePath,

    # If set will cleanup all but the final image (e.g. VMDK->VHD->WIM->MDT will leave only the MDT image, VMDK->VHD->WIM will leave only the WIM, VMDK->VHD will leave only the VHD image etc)
    [Parameter()]
    [switch]
    $Cleanup,

    # If the deployment share requires credentials specify those here
    [Parameter(
        Mandatory = $false
    )]
    [pscredential]
    $Credential
)
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

try
{
    $Global:BuildOutputDirectory = New-Item (Join-Path $Global:RepoBuildDirectory 'MDT')
    $PathCheck = Get-Item $InputPath -Force
    if ($PathCheck.PSIsContainer)
    {
        $Images = Get-ChildItem $PathCheck | Where-Object { $_.Name -match '(?:[vV][mM][dD][kK]|[Vv][Hh][Dd]|[Ww][Ii][Mm])$' }
    }
    else
    {
        if ($PathCheck -match '(?:[vV][mM][dD][kK]|[Vv][Hh][Dd]|[Ww][Ii][Mm])$')
        {
            $Images = $InputPath
        }
        else
        {
            throw "InputPath must be either a directory or path to a VMDK/VHD/WIM file"
        }
    }
}
catch
{
    throw $_.Exception.Message
}

$Images | ForEach-Object {
    $IBParams = @{
        File                = (Join-Path $global:BuildTasksDirectory 'MDT.ps1')
        Task                = 'UpdateMDT'
        InputFile           = $_
        DeploymentSharePath = $DeploymentSharePath
    }
    if ($Cleanup)
    {
        $IBParams.Add('Cleanup', $true)
    }
    if ($Credential)
    {
        $IBParams.Add('Credential', $Credential)
    }
    try
    {
        Invoke-Build @IBParams -Verbose
    }
    catch
    {
        throw $_.Exception.Message
    }
}

Write-Host "Build $($MyInvocation.MyCommand) completed successfully! 🎉" -ForegroundColor Green