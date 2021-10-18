# Handy class for managing packer variables
class PackerVariable
{
    # The name of the variable
    [string] $VariableName

    # The value of the variable
    [string] $VariableValue

    # Constructor allowing for creation from 2 values
    PackerVariable([string]$VariableName, [string]$VariableValue)
    {
        $this.VariableName = $VariableName
        $this.VariableValue = $VariableValue
    }

    # Constructor for creation from a hashtable
    PackerVariable([hashtable]$VariableInfo)
    {
        $this.VariableName = $VariableInfo.VariableName
        $this.VariableValue = $VariableInfo.VariableValue
    }

    # Constructor to allow creation from objects
    PackerVariable([PSCustomObject]$VariableInfo)
    {
        $this.VariableName = $VariableInfo.VariableName
        $this.VariableValue = $VariableInfo.VariableValue
    }
}