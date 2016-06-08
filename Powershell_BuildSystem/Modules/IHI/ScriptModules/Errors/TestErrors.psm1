
#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {

  }
}
# initialize/reset the module
Initialize
# ensure best practices for variable use, function calling, null property access, etc.
# must be done at module script level, not inside Initialize, or will only be function scoped
Set-StrictMode -Version 2
#endregion


#region Functions: Get-IHIReturnErrorRecord, Get-IHIThrowErrorRecord, Get-IHIWriteErrorRecord

<#
.SYNOPSIS
Test function - returns error record
.DESCRIPTION
Test function - returns error record
.EXAMPLE
Get-IHIReturnErrorRecord
Creates a new ErrorRecord object and returns it
#>
function Get-IHIReturnErrorRecord {
  [CmdletBinding()]
  param()
  process {
    [string]$ErrorMessage = $MyInvocation.MyCommand.Name + " error record"
    New-IHIErrorRecord $ErrorMessage "ErrorRecord"
  }
}
Export-ModuleMember -Function Get-IHIReturnErrorRecord

<#
.SYNOPSIS
Test function - returns thrown error record
.DESCRIPTION
Test function - returns thrown error record
.EXAMPLE
Get-IHIThrowErrorRecord
Creates a new ErrorRecord object and throws it it
#>
function Get-IHIThrowErrorRecord {
  [CmdletBinding()]
  param()
  process {
    [string]$ErrorMessage = $MyInvocation.MyCommand.Name + " error record"
    throw $(New-IHIErrorRecord $ErrorMessage "ErrorRecord")
  }
}
Export-ModuleMember -Function Get-IHIThrowErrorRecord

<#
.SYNOPSIS
Test function - write error record to error stream
.DESCRIPTION
Test function - write error record to error stream
.EXAMPLE
Get-IHIWriteErrorRecord
Creates a new ErrorRecord object and writes it to the error stream
#>
function Get-IHIWriteErrorRecord {
  [CmdletBinding()]
  param()
  process {
    [string]$ErrorMessage = $MyInvocation.MyCommand.Name + " error record"
    Write-Error -ErrorRecord $(New-IHIErrorRecord $ErrorMessage "ErrorRecord")
  }
}
Export-ModuleMember -Function Get-IHIWriteErrorRecord

#endregion
