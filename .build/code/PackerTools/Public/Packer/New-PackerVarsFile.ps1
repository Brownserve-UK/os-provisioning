<#
.SYNOPSIS
    Creates a Packer variables file
.DESCRIPTION
    Sometimes it can be difficult to pass in variables on the command line due to parsing etc.
    In these instances we use a Packer variables file and this cmdlet assists in the creation of such a file
#>
function New-PackerVarsFile
{
    [CmdletBinding()]
    param
    (
        # The path to the vars file to create
        [Parameter(
            Mandatory = $true,
            Position = 0
        )]
        [string]
        $Path,

        # The values to be set
        [Parameter(
            Mandatory = $true,
            Position = 1
        )]
        [PackerVariable[]]
        $PackerVariables,

        # If set forces overwriting pre-existing files
        [Parameter()]
        [switch]
        $Force
    )
    
    begin
    {
        
    }
    
    process
    {
        $VarsFileContent = ""
        $PackerVariables | ForEach-Object {
            $VarsFileContent += "$($_.VariableName) = $($_.VariableValue)`n"
        }
        Write-Debug "VarsFileContent:`n`n$VarsFileContent"

        $NewItemParams = @{
            Path     = $Path
            ItemType = 'File'
            Value    = $VarsFileContent
        }
        if ($Force)
        {
            $NewItemParams.Add('Force', $true)
        }
        try
        {
            $VarsFile = New-Item @NewItemParams
        }
        catch
        {
            throw "Failed to create packer variable file at $Path.`n$($_.Exception.Message)"
        }
    }
    
    end
    {
        if ($VarsFile)
        {
            Return $VarsFile
        }
    }
}