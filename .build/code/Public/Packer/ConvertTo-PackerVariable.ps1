<#
.SYNOPSIS
    Very simple function for converting some data types to Packer variables
#>
function ConvertTo-PackerVariable
{
    [CmdletBinding()]
    param
    (
        # The name of the packer variable to set
        [Parameter(Mandatory = $true)]
        [string]
        $VariableName,

        # The variable to be converted
        [Parameter(Mandatory = $true)]
        $VariableValue
    )
    
    begin
    {
        
    }
    
    process
    {
        $VariableType = $VariableValue.GetType()
        switch ($VariableType.BaseType)
        {
            'array'
            {
                Write-Verbose "Converting variable"
                # Variables need to be in the format of ["value1","value2"]
                $ConvertedValue = "[`"$($VariableValue -split '","')`"]"
            }
            'string'
            {
                Write-Verbose "$VariableName is a string"
                $ConvertedValue = "`"$VariableValue`""
            }
            Default
            {
                Write-Error "Unhandled variable type '$($VariableType.BaseType)'"
            }
        }
    }
    
    end
    {
        if ($ConvertedValue)
        {
            Return [PackerVariable]@{
                VariableName  = $VariableName
                VariableValue = $ConvertedValue
            }
        }
        else
        {
            Return $null
        }
    }
}