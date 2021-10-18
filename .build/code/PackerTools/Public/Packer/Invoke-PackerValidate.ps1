<#
.SYNOPSIS
    Validates a given Packer template
.DESCRIPTION
    Validates a given Packer template
.EXAMPLE
    PS C:\> Invoke-PackerValidate c:\windows10.pkr.hcl
    
    This would check to ensure the file 'windows10.pkr.hcl' is a valid Packer template
#>
function Invoke-PackerValidate
{
    [CmdletBinding()]
    param
    (
        # The path to the Packer template to be validated
        [Parameter(
            Mandatory = $true,
            Position = 0
        )]
        [string]
        $PackerTemplate,

        # Any variables to set
        [Parameter(
            Mandatory = $false
        )]
        [PackerVariable[]]
        $TemplateVariables,

        # The working directory to use (useful for handling Packer's relative paths)
        [Parameter(
            Mandatory = $false
        )]
        [string]
        $WorkingDirectory,

        # Path to a variable file to use
        # This is often useful to get around weird escaping issues
        [Parameter(
            Mandatory = $false
        )]
        [string]
        $VariableFile
    )
    
    begin
    {
        if (!(Test-Path $PackerTemplate))
        {
            throw "Packer template $PackerTemplate not found."
        }
        if ($PackerTemplate -notmatch '.hcl|.json')
        {
            throw "$PackerTemplate does not appear to be a packer template file"
        }
    }
    process
    {
        Write-Verbose "Validating Packer configuration $PackerTemplate"
        $PackerArgs = @('validate')
        if ($VariableFile)
        {
            if (!(Test-Path $VariableFile))
            {
                throw "$VariableFile does not appear to exist"
            }
            $PackerArgs += @('-var-file', $VariableFile)
        }
        if ($TemplateVariables) 
        {   
            $TemplateVariables | ForEach-Object {
                $PackerArgs += @("--var", "$($_.VariableName)=$($_.VariableValue)")
            }
        }
        $PackerArgs += "$PackerTemplate"
        $StartSilentProcParams = @{
            FilePath     = 'packer'
            ArgumentList = $PackerArgs
        }
        if ($WorkingDirectory)
        {
            if (!(Test-Path $WorkingDirectory))
            {
                throw "Working directory $WorkingDirectory is not valid"
            }
            $StartSilentProcParams.Add('WorkingDirectory', $WorkingDirectory)
        }
        try
        {
            Start-SilentProcess @StartSilentProcParams
        }
        catch
        {
            throw "Packer validation of $PackerTemplate has failed.`n$($_.Exception.Message)"
        }
    }
    
    end
    {
        
    }
}