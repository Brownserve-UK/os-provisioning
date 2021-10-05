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
        $PackerTemplate
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
        $PackerParams = @('validate', $PackerTemplate)
        try
        {
            Start-SilentProcess `
                -FilePath 'packer' `
                -ArgumentList $PackerParams
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