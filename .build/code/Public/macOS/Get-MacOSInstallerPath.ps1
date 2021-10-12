<#
.SYNOPSIS
    Simple cmdlet for checking and returning the path to macOS installers
.DESCRIPTION
    Simple cmdlet for checking and returning the path to macOS installers
    This ensures we can easily get the path to the installer across versions
    [Compatible with: macOS]
.EXAMPLE
    Get-MacOSInstallerPath -macOSVersion '11'
    
    This would get the macOS installer path for macOS 11
#>
function Get-MacOSInstallerPath
{
    [CmdletBinding()]
    param
    (
        # macOS
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $macOSVersion
    )
    if (!$IsMacOS)
    {
        throw "This cmdlet can only be used on macOS"
    }
    switch -regex ($macOSVersion)
    {
        '11|macOS_11|macOS11'
        {
            $InstallerPath = '/Applications/Install macOS Big Sur.app'
        }
        Default
        {
            Write-Error "Unsupported macOS version '$macOSVersion'"
            Return $null
        }
    }
    if (!(Test-Path $InstallerPath))
    {
        Write-Error "Cannot find installer at '$InstallerPath' for macOS '$macOSVersion'"
        Return $null
    }
    else
    {
        Return $InstallerPath
    }
}