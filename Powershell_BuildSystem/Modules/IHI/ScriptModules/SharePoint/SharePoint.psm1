
#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
    # when writing name/value pairs, width of first column
    [int]$script:DefaultCol1Width = 20
  }
}
# initialize/reset the module
Initialize
# ensure best practices for variable use, function calling, null property access, etc.
# must be done at module script level, not inside Initialize, or will only be function scoped
Set-StrictMode -Version 2
#endregion


#region Functions: Confirm-IHISharePointSnapinLoaded

<#
.SYNOPSIS
Returns $true is SharePoint snapin loaded; if not $false and writes error
.DESCRIPTION
Returns $true is SharePoint snapin loaded; if not $false and writes error
.EXAMPLE
Confirm-IHISharePointSnapinLoaded
Returns $true if SharePoint snapin loaded, $false otherwise and writes error
#>
function Confirm-IHISharePointSnapinLoaded {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    # if snapin found, Success is $true
    $Success = $null -ne (Get-PSSnapin | Where { $_.Name -eq "Microsoft.SharePoint.PowerShell" })
    if ($false -eq $Success) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Microsoft.SharePoint.PowerShell snapin not loaded"
    }
    $Success
  }
}
Export-ModuleMember -Function Confirm-IHISharePointSnapinLoaded
#endregion
