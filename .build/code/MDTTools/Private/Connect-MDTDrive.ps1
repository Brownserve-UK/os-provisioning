<#
.SYNOPSIS
    Connects to an MDT deployment share as a PS drive
#>
function Connect-MDTDrive
{
    [CmdletBinding()]
    param
    (
        # The path to the deployment share to be mounted
        [Parameter(
            Mandatory = $true,
            Position = 0
        )]
        [string]
        $Path,

        # The name to use for the PS drive
        [Parameter(Mandatory = $false, Position = 1)]
        [string]
        $PSDriveName = 'MDT',

        # Credentials to use (if any)
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential,

        # If set mounts the MDT drive as a file system rather than via the MDT provider
        [Parameter()]
        [switch]
        $AsFileSystem
    )
    Write-Verbose "Connecting to MDT deployment share at $Path"
    # MDT PowerShell simply can't handle local paths so throw if we've got one
    if ($Path -match '^([A-Z|a-z][:]\\)|^\/\/(.*?)(?=\/)')
    {
        throw "Cannot connect to an MDT share via a local path, please ensure you provide the network location to this share."
    }
    else
    {
        if ($AsFilesystem)
        {
            $Provider = 'FileSystem'
        }
        else
        {
            $Provider = 'MDTProvider'
        }
        $PSDriveName = 'MDT'
        $PSDriveParams = @{
            Name        = $PSDriveName
            Root        = $Path
            PSProvider  = $Provider
            ErrorAction = 'Stop'
            Scope       = 'script'
        }
        if ($Credential)
        {
            $PSDriveParams.Add('Credential', $Credential)
        }
        try
        {
            $PSDrive = New-PSDrive @PSDriveParams

            if (!$PSDriveName)
            {
                throw "Cannot find PSDrive '$PSDriveName'"
            }
        }
        catch
        {
            throw "Failed to create PSDrive for the $Path.`n$($_.Exception.Message)"
        }
    }
    if ($PSDrive)
    {
        Return $PSDrive
    }
    else
    {
        Return $null
    }
}