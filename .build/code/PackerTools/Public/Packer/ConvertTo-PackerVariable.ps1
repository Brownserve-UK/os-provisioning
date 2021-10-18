<#
.SYNOPSIS
    Very simple function for converting some data types to Packer variables
.NOTES
    Doesn't handle every Packer variable type, only those used in this repo
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
                    Write-Verbose "$($PackerVariable.key) is an array, will convert into a list"
                    # Work out what type of list we're working with as both have different logic
                    $ListType = $PackerVariable.Value[0].GetType()
                    switch -regex ($ListType)
                    {
                        '^[iI]nt' 
                        {
                            Write-Verbose "Creating an integer list"
                            $ConvertedValue = "[$($PackerVariable.Value -join ',')]"
                        }
                        '[Ss]tring'
                        {
                            Write-Verbose "Creating a list of strings"
                            # Variables need to be in the format of ["value1","value2"] for strings
                            $ConvertedValue = "[`"$($PackerVariable.Value -join '","')`"]"
                        }
                        Default
                        {
                            throw "Unsupported list type '$ListType'"
                        }
                    }
                    
                }
                'string'
                {
                    Write-Verbose "$($PackerVariable.key) is a string will convert to a string"
                    $ConvertedValue = "`"$($PackerVariable.Value)`""
                }
                'hashtable'
                {
                    Write-Verbose "$($PackerVariable.key) is a hashtable will convert to a map"
                    # Grab the nested hash
                    $NestedHash = $PackerVariable.Value
                    $NestedHashEnum = $NestedHash.GetEnumerator()
                    $ConvertedValue = "{`n"
                    $NestedHashEnum | ForEach-Object {
                        $ConvertedValue = $ConvertedValue + "   `"$($_.Key)`" = `"$($_.Value)`"`n"
                    }
                    $ConvertedValue = $ConvertedValue + "}"

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