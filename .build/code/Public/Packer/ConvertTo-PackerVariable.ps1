<#
.SYNOPSIS
    Very simple function for converting some data types to Packer variables
#>
function ConvertTo-PackerVariable
{
    [CmdletBinding(DefaultParameterSetName = 'default')]
    param
    (
        # The name of the packer variable to set
        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'default',
            Position = 0
        )]
        [string]
        $VariableName,

        # The variable to be converted
        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'default',
            Position = 1
        )]
        $VariableValue,

        # Secret parameter for piping in lots of values
        [Parameter(
            DontShow,
            ValueFromPipeline,
            ParameterSetName = 'pipeline'
        )]
        [hashtable]
        $PackerVariables
    )
    
    begin
    {
        $Return = @()
    }
    
    process
    {
        if (!$PackerVariables)
        {
            $PackerVariables = @{
                $VariableName = $VariableValue
            }
        }
        foreach ($PackerVariable in $PackerVariables.GetEnumerator())
        {
            $VariableType = $PackerVariable.Value.GetType()
            switch ($VariableType.Name)
            {
                'Object[]'
                {
                    Write-Verbose "$($PackerVariable.key) is an array"
                    # Variables need to be in the format of ["value1","value2"]
                    $ConvertedValue = "[`"$($PackerVariable.Value -join '","')`"]"
                }
                'string'
                {
                    Write-Verbose "$($PackerVariable.key) is a string"
                    $ConvertedValue = "`"$($PackerVariable.Value)`""
                }
                Default
                {
                    Write-Error "Unhandled variable type '$($VariableType.BaseType)'"
                }
            }
            $Return += [PackerVariable]@{
                VariableName  = $PackerVariable.Key
                VariableValue = $ConvertedValue
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