<#
.SYNOPSIS
  A collection of scripts for aiding in the builds on this repo
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$PublicCmdlets = @()
$CompatibleCmdlets = @()
$IncompatibleCmdlets = @()

Join-Path $PSScriptRoot -ChildPath 'Public' |
  Resolve-Path |
    Get-ChildItem -Filter *.ps1 -Recurse |
      ForEach-Object {
        . $_.FullName
        $PublicCmdlets += Get-Help $_.BaseName
      }

$PublicCmdlets | ForEach-Object { 
  if (($_.Description -match 'Windows Only') -and ($IsMacOS -or $IsLinux))
  {
    $IncompatibleCmdlets += $_
  }
  else
  {
    $CompatibleCmdlets += $_
    # Only export compatible cmdlets
    Export-ModuleMember -Function $_.Name
  }
}


if ($Global:Repocmdlets)
{
  $Global:Repocmdlets.CompatibleCmdlets += $CompatibleCmdlets
  $Global:Repocmdlets.IncompatibleCmdlets += $IncompatibleCmdlets
}
else
{
  Write-Host "The following cmdlets from $($MyInvocation.MyCommand) are now available for use:" -ForegroundColor White
  $CompatibleCmdlets | ForEach-Object {
    Write-Host "    $($_.Name) " -ForegroundColor Magenta -NoNewline; Write-Host "|  $($_.Synopsis)" -ForegroundColor Blue 
  }
  if ($IncompatibleCmdlets)
  {
    Write-Warning "The following cmdlets are NOT compatible with your OS and have been disabled:"
    $IncompatibleCmdlets | ForEach-Object {
      Write-Host "  $($_.Name)" -ForegroundColor Yellow
    }
  }
}