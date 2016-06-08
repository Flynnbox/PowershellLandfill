
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


#region Functions: New-IHIErrorRecord

<#
.SYNOPSIS
New-IHIErrorRecord creates a new ErrorRecord object.
.DESCRIPTION
New-IHIErrorRecord creates a new ErrorRecord object - a System.Management.
Automation.ErrorRecord object, the type used by PowerShell when errors are
generated.  The user supplies an $ErrorMessage, an $ErrorId, an optional
$Exception (the original Exception raised) and an optional ErrorRecord 
(the original ErrorRecord raised) and a new ErrorRecord object is
created with this information plus additional details about the calling code.
This function does not exposed the standard error-related variables as it 
would be imposible to use them (if there was an error during the processing
of New-IHIErrorRecord, it would need to call New-IHIErrorRecord).
This function is public.
.PARAMETER ErrorMessage
Text of the error message.
.PARAMETER ErrorId
Id type of the error.
.PARAMETER Exception
Exception raised by client code; this information is embedded in the 
error record.  Optional.
.PARAMETER OriginalErrorRecord
ErrorRecord raised by client code; this information is embedded in the 
error record.  Optional.
.EXAMPLE
New-IHIErrorRecord "Config files does not exist" "MISSING_CONFIG_123"
Generates an ErrorRecord for this information.
.EXAMPLE
New-IHIErrorRecord "Config files does not exist" "MISSING_CONFIG_123" $(New-Object System.Exception "Inner exception")
Generates an ErrorRecord for this information and embeds the exception's information
as well.
#>
function New-IHIErrorRecord {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ErrorMessage,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ErrorId,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [AllowNull()]
    [System.Exception]$Exception,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [AllowNull()]
    [System.Management.Automation.ErrorRecord]$OriginalErrorRecord
  )
  process {
    # Always create a new exception for the error record using $ErrorMessage as the
    # Message value.  However, if an $Exception was also passed, grab it's Message and
    # append it to the Message of the new main exception and then make passed $Exception
    # the inner exception.
    [System.Exception]$ERException = $null

    # text of exception - main error message
    [string]$ErrorText = $ErrorMessage
    # attempt to get information about the calling code to include
    # in the error information
    if (((Get-PSCallStack) -ne $null) -and ((Get-PSCallStack)[1] -ne $null)) {
      $ErrorText += " (source: " + (Get-PSCallStack)[1].Location + " " + (Get-PSCallStack)[1].Command + ")"
    }

    # get error text from original error (Exception or ErrorRecord) if exists
    [string]$OriginalErrorText = ""
    if ($Exception -ne $null) {
      $OriginalErrorText = $Exception.Message + "; "
    }
    if ($OriginalErrorRecord -ne $null) {
      $OriginalErrorText += $OriginalErrorRecord.Exception.Message + " " + $OriginalErrorRecord.InvocationInfo.ScriptName + ":" + $OriginalErrorRecord.InvocationInfo.ScriptLineNumber + " char:" + $OriginalErrorRecord.InvocationInfo.OffsetInLine
    }

    # create Exception to put in ErrorRecord
    if ($OriginalErrorText -eq "") {
      $ERException = New-Object System.Exception $ErrorText
    } else {
      $ERException = New-Object System.Exception (($ErrorText + " :: " + $OriginalErrorText),$Exception)
    }
    # set the ErrorCategory - hard-coded for now
    # PSTODO - pass in option ErrorCategory
    [System.Management.Automation.ErrorCategory]$ErrorCategory = $("NotSpecified")
    # create the ErrorRecord
    [System.Management.Automation.ErrorRecord]$ER = New-Object System.Management.Automation.ErrorRecord ($ERException,$ErrorId,$ErrorCategory,$null)

    # return the ErrorRecord
    $ER
  }
}
Export-ModuleMember -Function New-IHIErrorRecord
#endregion
