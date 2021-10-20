[CmdletBinding()]
param
(
    # The VMDK/VHD/WIM to be converted and uploaded to MDT
    [Parameter(Mandatory = $true)]
    [string]
    $InputFile,

    # The MDT deployment share
    [Parameter(Mandatory = $true)]
    [string]
    $DeploymentSharePath,

    # If the deployment share requires credentials, specify those here
    [Parameter(Mandatory = $false)]
    [pscredential]
    $Credential,

    # If set will cleanup at each stage (e.g. VMDK->VHD->WIM->MDT will leave only the MDT image, VMDK->VHD->WIM will leave only the WIM, VMDK->VHD will leave only the VHD image etc)
    [Parameter()]
    [switch]
    $Cleanup
)
if (!($IsWindows))
{
    throw "These build tasks only work on Windows"
}
if (!(Test-Administrator))
{
    throw "These build tasks must be run in an elevated session"
}
if ($InputFile -notmatch '(?:[vV][mM][dD][kK]|[Vv][Hh][Dd]|[Ww][Ii][Mm])$')
{
    throw 'InputFile must be one of: VMDK/VHD/WIM'
}
$Script:CurrentFile = $InputFile | Convert-Path

# Synopsis: Converts the VMDK file into a WIM image
task ConvertVMDKtoVHD -If ($InputFile -match '.[vV][mM][dD][kK]$') {
    $ConvertVMDKParams = @{
        VMDKPath    = $Script:CurrentFile
        Destination = ($global:BuildOutputDirectory | Convert-Path)
    }
    if ($Cleanup)
    {
        $ConvertVMDKParams.add('CleanupVMDK', $true)
    }
    $Script:CurrentFile = ConvertTo-VHD @ConvertVMDKParams
}

# Synopsis: Converts the VHD file into a Windows image file
task ConvertVHDtoWIM -If (($InputFile -match '.[vV][mM][dD][kK]$') -or ($InputFile -match '.[vV][hH][dD]$')) ConvertVMDKtoVHD, {
    $ConvertVHDParams = @{
        VHDPath = $Script:CurrentFile
        Destination = $Global:BuildOutputDirectory
    }
    if ($Cleanup)
    {
        $ConvertVHDParams.add('CleanupVHD', $true)
    }
    $Script:CurrentFile = ConvertTo-WIM @ConvertVHDParams
}

# Synopsis: Updates MDT with the new WIM image
task UpdateMDT ConvertVHDtoWIM, {
    $RepoMDTModulePath = Join-Path $global:RepoCodeDirectory 'MDTTools' 'MDTTools.psm1' | Convert-Path
    $MDTModulePath = 'C:\Program Files\Microsoft Deployment Toolkit\Bin\MicrosoftDeploymentToolkit.psd1' | Convert-Path

    # Unfortunately the MDT PowerShell module only works with PowerShell for Windows Desktop :(
    # Therefore we invoke a new PowerShell process to handle updating the WIM in MDT
    $ScriptToRun = {
        param
        (
            [string]$MDTModulePath,
            [string]$RepoMDTModulePath,
            [string]$SourceWIM,
            [string]$DeploymentSharePath,
            [bool]$Cleanup,
            [pscredential]$Credential
        )
        $ErrorActionPreference = 'Stop'
        try
        {
            Import-Module $MDTModulePath -Force
            Import-Module $RepoMDTModulePath -Force

            # First update the WIM image
            $UpdateWIMParams = @{
                SourceWIM           = $SourceWIM
                DeploymentSharePath = $DeploymentSharePath
            }
            if ($Credential)
            {
                $UpdateWIMParams.Add('Credential', $Credential)
            }
            if ($Cleanup)
            {
                $UpdateWIMParams.Add('CleanupInputWIM', $true)
            }
            $GUIDs = Update-MDTWindowsImage @UpdateWIMParams -Verbose

            # Now update the task sequences but only if we've updated an existing WIM.
            if ($GUIDs.OldGUID)
            {
                $UpdateTSParams = @{
                    OldImageGUID        = $GUIDs.OldGUID
                    NewImageGUID        = $GUIDs.NewGUID
                    DeploymentSharePath = $DeploymentSharePath
                }
                if ($Credential)
                {
                    $UpdateTSParams.Add('Credential', $Credential)
                }
                Update-MDTTaskSequenceImage @UpdateTSParams -Verbose
            }
        }
        catch
        {
            throw "Failed to update MDT image.`n$($_.Exception.Message)"
        }
    }
    $ScriptArgs = @(
        $MDTModulePath,
        $RepoMDTModulePath,
        $Script:CurrentFile,
        $DeploymentSharePath
    )
    if ($Cleanup)
    {
        $ScriptArgs += $true
    }
    if ($Credential)
    {
        $ScriptArgs += $Credential
    }
    Write-Verbose "Attempting to spawn a new PowerShell process"
    & powershell -Noninteractive -Command $ScriptToRun -Args $ScriptArgs
}