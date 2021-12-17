#!/usr/local/microsoft/powershell/7/pwsh
#.SYNOPSIS
#  This script will install the required PowerShell modules
$ErrorActionPreference = 'Stop'

@('Brownserve.PSTools', 'PuppetPowerShell') | 
    ForEach-Object { Install-Module -Name $_ -Repository PSGallery -Scope AllUsers -Force -Confirm:$false }