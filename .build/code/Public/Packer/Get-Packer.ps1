<#
.SYNOPSIS
    Downloads Packer for your operating system
.DESCRIPTION
    This cmdlet gets the specified version of packer for your operating system and installs it at the given path.
    An alias for the command 'packer' will be created and pointed at this version for your current session and the
    environment variable 'PackerPath' is created.
.EXAMPLE
    PS C:\> Get-Packer -DownloadPath C:\packer
    Would download packer to C:\packer
#>
function Get-Packer
{
    [CmdletBinding()]
    param
    (
        # The version of Packer to download
        [Parameter(
            Mandatory = $false
        )]
        [string]
        $PackerVersion = "$(if ($Global:RepoPackerVersion){"$Global:RepoPackerVersion"}else{'1.7.6'})",

        # The path to download Packer to
        [Parameter(
            Mandatory = $true
        )]
        [string]
        $DownloadPath
    )
    # Make sure the directory path is good
    try
    {
        $DownloadPathInfo = Get-Item $DownloadPath -Force
        if (!$DownloadPathInfo.PSIsContainer)
        {
            Write-Error "$DownloadPath does not appear to be a directory"
        }
    }
    catch
    {
        throw "Error with DownloadPath.`n$($_.Exception.Message)"
    }

    # Look at our special variable from Brownserve.PSTools
    switch ($Global:OS)
    {
        'Windows'
        {
            $PackerDownloadURI = "https://releases.hashicorp.com/packer/$PackerVersion/packer_$($PackerVersion)_windows_amd64.zip"
            $PackerPath = Join-Path $DownloadPath -ChildPath 'Packer.exe'
        }
        'macOS'
        {
            $PackerDownloadURI = "https://releases.hashicorp.com/packer/$PackerVersion/packer_$($PackerVersion)_darwin_amd64.zip"
            $Chmod = $true
            $PackerPath = Join-Path $DownloadPath -ChildPath 'Packer'
        }
        'Linux'
        {
            $PackerDownloadURI = "https://releases.hashicorp.com/packer/$PackerVersion/packer_$($PackerVersion)_linux_amd64.zip"
            $Chmod = $true
            $PackerPath = Join-Path $DownloadPath -ChildPath 'Packer'
        }
        Default
        {
            Write-Error "Unknown OS: $global:OS"
        }
    }
    # Download and extract Packer
    $PackerZipFile = Join-Path $DownloadPath 'Packer.zip'
    # If the ZIP file already exists it seems it won't trigger another download so let's try removing it first
    if ((Test-Path $PackerZipFile) -eq $true)
    {
        Write-Verbose 'Removing previously downloaded archive'
        try
        {
            Remove-Item $PackerZipFile -Force -Confirm:$false
        }
        catch
        {
            # Ignore it and hope for the best using the old zip...
        }
    }
    Write-Verbose 'Downloading Packer binary...'
    try
    {
        Invoke-DownloadMethod -DownloadURI $PackerDownloadURI -OutFile $PackerZipFile
        Expand-Archive -LiteralPath $PackerZipFile -DestinationPath $DownloadPath -Force # Force for when we're running locally and want to overwrite old files
        if ($Chmod -eq $true)
        {
            $Output = & chmod +x $PackerPath
            if ($LASTEXITCODE -ne 0)
            {
                $Output
                Write-Error 'Failed to make Packer executable'
            }
        }
    }
    catch
    {
        Write-Error $_.Exception.Message
    }
    # Providing everything has completed ok, set the packer path
    $env:PackerPath = $PackerPath
    try
    {
        Set-Alias -Name 'packer' -Value $PackerPath -Scope global
    }
    catch
    {
        Write-Error $_.Exception.Message
    }
}