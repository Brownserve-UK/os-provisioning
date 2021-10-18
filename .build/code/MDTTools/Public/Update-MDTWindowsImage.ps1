<#
.SYNOPSIS
    Updates a WIM image stored in MDT.
.DESCRIPTION
    Updates a Windows image stored in MDT.
.EXAMPLE
    PS C:\> Update-MDTWindowsImage `
        -SourceWIM "C:\Images\Windows10-pro.wim" `
        -DeploymentSharePath "\\localhost\DeploymentShare"
    
    This would update the 'Windows10-pro' Windows image on the deployment share that's running on the local machine

    PS C:\> Update-MDTWindowsImage `
        -SourceWIM "C:\Images\Windows10-pro.wim" `
        -DeploymentSharePath "\\FS-01\DeploymentShare" `
        -Credential (Get-Credential)
    
    This would update the 'Windows10-pro' Windows image on the deployment share located on the machine 'FS-01'.
    Credentials would be prompted for to connect to this share.
.NOTES
    This script can only be run in PowerShell for Windows Desktop as it requires some .NET libraries that are not present
    in .NET core :(
    It also needs to be run in an elevated prompt.
    The 'DeploymentSharePath' parameter must point to a network share, otherwise the MDT PowerShell module does not function
    correctly.

    TODO: Check file hashes and do a noop on hash match? (unless -force)
#>
#Requires -Module MicrosoftDeploymentToolkit
#Requires -RunAsAdministrator
function Update-MDTWindowsImage
{
    [CmdletBinding()]
    param
    (
        # The WIM to be imported
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipelineByPropertyName = $true,
            ValueFromPipeline = $true
        )]
        [string[]]
        $SourceWIM,

        # The path to the deployment share (must be the network share even for local deployment shares!)
        [Parameter(
            Mandatory = $true,
            Position = 1
        )]
        [string]
        $DeploymentSharePath,
        
        # If you need different credentials to connect to the share specify those here
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential
    )
    
    begin
    {
        if (!(Test-Path $DeploymentSharePath))
        {
            throw "Cannot find path '$DeploymentSharePath'"
        }
        # MDT PowerShell gets sad if the paths are relative not actual -_-
        $DeploymentSharePath = $DeploymentSharePath | Convert-Path
        $Return = @()
    }
    
    process
    {
        $SourceWIM | ForEach-Object {
            # MDT PowerShell gets sad if the paths are relative not actual -_-
            $WIMPath = $_ | Convert-Path
            if ($WIMPath.ToLower() -notmatch '\.wim$')
            {
                throw "WIMPath should be a WIM file"
            }
            if (!(Test-Path $WIMPath))
            {
                throw "Can't find path '$WIMPath'"
            }
            $WIMName = (Split-Path $WIMPath -Leaf)
            $ConnectParams = @{
                Path = $DeploymentSharePath
            }
            if ($Credential)
            {
                $ConnectParams.Add('Credential', $Credential)
            }
            try
            {
                $MDTDrive = Connect-MDTDrive @ConnectParams | Select-Object -ExpandProperty Name
                Write-Verbose "Deployment share connected as '$MDTDrive'"
            }
            catch
            {
                throw $_.Exception.Message 
            }

            try
            {
                $ReturnObject = @{}
                # See if the WIM we're importing already exists in MDT
                $ExistingWIM = Get-MDTWindowsImage `
                    -WIMName $WIMName `
                    -PSDriveName $MDTDrive

                if ($ExistingWIM)
                {
                    $OldGUID = Get-WindowsImageGUID `
                        -WIMName $ExistingWIM `
                        -PSDriveName $MDTDrive
                
                    # Unfortunately we have to remove the old WIM before we can re-import it :(
                    Write-Verbose "Removing old WIM '$ExistingWIM'"
                    Remove-Item -Path "$($MDTDrive):\Operating Systems\$ExistingWIM" -Force -Confirm:$false

                    $ReturnObject.Add('OldGUID', $OldGUID)
                }
                # Import the new WIM
                Write-Verbose "Importing '$WIMPath'"
                Import-MDTOperatingSystem `
                    -Path "$($MDTDrive):\Operating Systems" `
                    -SourceFile $WIMPath  `
                    -DestinationFolder $WIMName | Out-Null

                # Get the new GUID from the WIM we've just imported
                $NewWIM = Get-MDTWindowsImage `
                    -WIMName $WIMName `
                    -PSDriveName $MDTDrive

                $NewGUID = Get-WindowsImageGUID `
                    -WIMName $NewWIM `
                    -PSDriveName $MDTDrive

                $ReturnObject.Add('NewGUID', $NewGUID)

                # Cast the return object to a pscustomobject and add it to our return output
                $Return += [pscustomobject]$ReturnObject
            }
            catch
            {
                if ($OldGUID)
                {
                    Write-Warning "Old WIM '$WIMName' will have been erased, you may need to manually update task sequences that reference the following GUID: $OldGUID"
                }
                throw $_.Exception.Message
            }
            finally
            {
                # Clean up after ourselves
                Write-Verbose "Removing PSDrive '$MDTDrive'"
                Remove-PSDrive -Name $MDTDrive -Force -ErrorAction 'SilentlyContinue'
            }
        }
    }
    
    end
    {
        if ($Return)
        {
            Return $Return
        }
        else
        {
            Return $null
        }
    }
}