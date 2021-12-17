#!/usr/local/microsoft/powershell/7/pwsh
# Ensures the .nvram file gets copied correctly
$ErrorActionPreference = 'Stop'
Start-Sleep 120
try
{
    if (!$env:VM_DIRECTORY)
    {
        throw "Environment variable VM_DIRECTORY is not set"
    }
    if (!$env:OUTPUT_DIRECTORY)
    {
        throw "Environment variable OUTPUT_DIRECTORY is not set"
    }
    Write-Host "Checking $env:VM_DIRECTORY for .nvram files"
    $NVRAMFile = Get-ChildItem -Path $env:VM_DIRECTORY -Recurse -Filter "*.nvram"
    if (!$NVRAMFile)
    {
        Write-Warning "No NVRAM file found"
    }
    Write-Host "Copying $NVRAMFile to $env:OUTPUT_DIRECTORY"
    Copy-Item $NVRAMFile -Destination $env:OUTPUT_DIRECTORY -Force
}
catch
{
    throw $_.Exception.Message
}