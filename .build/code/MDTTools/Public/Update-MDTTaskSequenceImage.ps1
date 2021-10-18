<#
.SYNOPSIS
    Updates the XML in a task sequence to ensure the new value replaces the old.
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Update-MDTTaskSequenceImage
{
    [CmdletBinding()]
    param
    (
        # The GUID of the WIM you want to search for
        [Parameter(Mandatory = $true)]
        [string]
        $OldImageGUID,

        # Parameter help description
        [Parameter(Mandatory = $true)]
        [string]
        $NewImageGUID,

        # The path to the deployment share
        [Parameter(Mandatory = $true)]
        [string]
        $DeploymentSharePath,

        # The parent folder containing the task sequences
        [Parameter(Mandatory = $false)]
        [string]
        $TaskSequenceFolder = 'Control',

        # The credentials to use if required
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
        
        # Connect to the deployment share
        $ConnectParams = @{
            Path = $DeploymentSharePath
            AsFileSystem = $true
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
        $Return = @()
    }
    process
    {
        try
        {
            $TaskSequences = Get-ChildItem -Path "$($MDTDrive):\$TaskSequenceFolder" -Recurse -Filter "ts.xml"
            if (!$TaskSequences)
            {
                throw "No task sequences found in path '$($MDTDrive):\$TaskSequenceFolder'"
            }
            $TaskSequences | ForEach-Object {
                Write-Verbose "Checking $($_.PSPath) for $OldImageGUID"

                $TaskSequenceXML = [xml](Get-Content $_.PSPath)
                if (!$TaskSequenceXML)
                {
                    throw "Task sequence XML is blank"
                }

                $OSGUID = $TaskSequenceXML.sequence.globalVarList.variable | 
                    Where-Object { $_.name -eq "OSGUID" } |
                        Select-Object "#text"
                
                if ($OSGUID."#text" -contains $OldImageGUID)
                {
                    $Return += ($_.PSPath | Convert-Path)
                    Write-Verbose "$_.PSPath contains $OldImageGUID"
                    # Update the variable in the XML that contains the GUID
                    $TaskSequenceXML.sequence.globalVarList.variable | 
                        Where-Object { $_.name -eq "OSGUID" } | 
                            ForEach-Object { $_."#text" = $NewImageGUID }

                    # Update the install media GUID
                    $TaskSequenceXML.sequence.group | 
                        Where-Object { $_.Name -eq "Install" } | 
                            ForEach-Object { $_.step } | 
                                Where-Object { $_.Name -eq "Install Operating System" } | 
                                    ForEach-Object { $_.defaultVarList.variable } | 
                                        Where-Object { $_.name -eq "OSGUID" } | 
                                            ForEach-Object { $_."#text" = $NewImageGUID }
                    # Save the updated XML
                    $TaskSequenceXML.Save(($_.PSPath | Convert-Path))
                    Write-Verbose "Replaced GUID"
                }
            }
        }
        catch
        {
            throw $_.Exception.Message
        }
        finally
        {
             # Clean up after ourselves
             Write-Verbose "Removing PSDrive '$MDTDrive'"
             Remove-PSDrive -Name $MDTDrive -Force -ErrorAction 'SilentlyContinue'
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