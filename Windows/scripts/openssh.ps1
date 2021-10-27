<#
.SYNOPSIS
    Installs the latest version of OpenSSH for Windows
.NOTES
    Adapted from https://adamtheautomator.com/openssh-windows/
#>
$ErrorActionPreference = 'Stop'

## Set network connection protocol to TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

## Define the OpenSSH latest release url
$url = 'https://github.com/PowerShell/Win32-OpenSSH/releases/latest/'

## Create a web request to retrieve the latest release download link
 $request = [System.Net.WebRequest]::Create($url)
 $request.AllowAutoRedirect=$false
 $response=$request.GetResponse()
 $source = $([String]$response.GetResponseHeader("Location")).Replace('tag','download') + '/OpenSSH-Win64.zip'

## Download the latest OpenSSH for Windows package to the current working directory
 $webClient = [System.Net.WebClient]::new()
 $webClient.DownloadFile($source, (Get-Location).Path + '\OpenSSH-Win64.zip')

 # Extract the ZIP to a temporary location
 Expand-Archive -Path .\OpenSSH-Win64.zip -DestinationPath ($env:temp) -Force
# Move the extracted ZIP contents from the temporary location to C:\Program Files\OpenSSH\
 Move-Item "$($env:temp)\OpenSSH-Win64" -Destination "C:\Program Files\OpenSSH\" -Force
# Unblock the files in C:\Program Files\OpenSSH\
 Get-ChildItem -Path "C:\Program Files\OpenSSH\" | Unblock-File

 & 'C:\Program Files\OpenSSH\install-sshd.ps1'

 # Start the sshd service
Start-Service sshd

# Set to automatic startup
Set-Service -Name sshd -StartupType 'Automatic'

# Confirm the Firewall rule is configured. It should be created automatically by setup. Run the following to verify
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled))
{
    Write-Host "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
}
else
{
    Write-Host "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists."
}
