<#
.SYNOPSIS
    Builds macOS packages using the "packages" application
.DESCRIPTION
    Builds macOS packages using the "packages" application
.EXAMPLE
    PS C:\> Build-MacOSPackages -PackageProjectPath './packages/package.pkgproj' -OutputDirectory './builds'
    Would build the package.pkgproj file and output it into 'builds'
.NOTES
    This cmdlet expects that the pkgproj will output a file with the same name as the pkgproj file for example if you have
    'MyPackage.pkgproj' this script will look for 'MyPackage.pkg' in the output directory
#>
function Build-MacOSPackage
{
    [CmdletBinding()]
    param
    (
        # The path to the pkgproj file(s)
        [Parameter(
            Mandatory = $true,
            Position = 0
        )]
        [string[]]
        $PackageProjectPath,

        # The output directory for built packages
        [Parameter(
            Mandatory = $true,
            Position = 1
        )]
        [string]
        $OutputDirectory
    )
    
    begin
    {
        try
        {
            $AbsoluteOutputPath = Get-Item $OutputDirectory -Force | Convert-Path
        }
        catch
        {
            throw "Output directory $OutputDirectory is not valid.`n$($_.Exception.Message)"
        }
        $ToReturn = @()
    }
    
    process
    {
        foreach ($PackageProject in $PackageProjectPath)
        {
            $PackageProject = Convert-Path $PackageProject
            Write-Verbose "Attempting to build $PackageProject"
            if (!(Test-Path $PackageProject) -or ($PackageProject -notlike "*.pkgproj"))
            {
                Write-Error "$PackageProject does not appear to be a valid packages project"
                break
            }
            # Extract the pkg name from the pkgproj file, we'll need this later
            $PackageName = (Split-Path $PackageProject -Leaf) -replace '.pkgproj', '.pkg'
            try
            {
                Start-SilentProcess `
                    -FilePath 'packagesbuild' `
                    -ArgumentList "$PackageProject --build-folder $AbsoluteOutputPath"
                # Grab the built package so we can return it
                $BuiltPackage = Get-Item (Join-Path $AbsoluteOutputPath $PackageName) -ErrorAction Stop
            }
            catch
            {
                Write-Error "Failed to build $PackageProject.`n$($_.Exception.Message)"
                break
            }
            Write-Verbose "Successfully built $PackageProject"
            $ToReturn += $BuiltPackage
        }
    }
    
    end
    {
        if ($ToReturn)
        {
            Return $ToReturn
        }
        else
        {
            Return $null
        }
    }
}