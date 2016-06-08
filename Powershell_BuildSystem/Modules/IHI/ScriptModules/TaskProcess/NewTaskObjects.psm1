
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


#region Functions: Convert-IHIStringToScriptBlock

<#
.SYNOPSIS
Converts a string containing code to a ScriptBlock
.DESCRIPTION
Converts a string whose contents are code, say "5 -lt 10" or "dir c:\windows"
into a PowerShell ScriptBlock object, specifically a object of type
System.Management.Automation.ScriptBlock.  This ScriptBlock can then be 
evaluated
.PARAMETER ScriptBlockText
String to convert to a script block
.EXAMPLE
$SB = Convert-IHIStringToScriptBlock "5 -lt 10"; & $SB
Returns $true
#>
function Convert-IHIStringToScriptBlock {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string]$ScriptBlockText
  )
  #endregion
  process {
    #region Parameter validation
    # trim any whitespace
    $ScriptBlockText = $ScriptBlockText.Trim()
    # make sure there is some actual text there to convert
    if ($ScriptBlockText -eq "") {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: cannot convert empty string to ScriptBlock"
      return
    }
    #endregion
    #region Create scriptblock
    [System.Management.Automation.ScriptBlock]$ScriptBlock = $null
    try {
      # attempt to create ScriptBlock
      $ScriptBlock = [System.Management.Automation.ScriptBlock]::Create($ScriptBlockText)
    }
    catch {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error converting this --> $ScriptBlockText <-- to ScriptBlock :: $("$_")"
      return
    }
    #endregion
    # no errors, return scriptblock
    $ScriptBlock
  }
}
Export-ModuleMember -Function Convert-IHIStringToScriptBlock
#endregion


#region Functions: New-IHIDynamicValueList

<#
.SYNOPSIS
Returns new, empty DynamicValueList object
.DESCRIPTION
Returns new, empty DynamicValueList object
.EXAMPLE
New-IHIDynamicValueList
Returns new, empty DynamicValueList object
#>
function New-IHIDynamicValueList {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    [pscustomobject]$DynamicValueList = New-Object PSCustomObject
    # array of dynamic values (just object array)
    [object[]]$DynamicValues = @()
    Add-Member -InputObject $DynamicValueList -MemberType NoteProperty -Name "DynamicValues" -Value $DynamicValues
    $DynamicValueList
  }
}
Export-ModuleMember -Function New-IHIDynamicValueList
#endregion


#region Functions: New-IHITask

<#
.SYNOPSIS
Returns new, empty Task object
.DESCRIPTION
Returns new, empty Task object
.EXAMPLE
New-IHITask
Returns new, empty Task object
#>
function New-IHITask {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    [pscustomobject]$Task = New-Object PSCustomObject
    [bool]$Error = $false
    [bool]$Processed = $false

    Add-Member -InputObject $Task -MemberType NoteProperty -Name "IntroMessage" -Value (New-IHITaskDynamicValue)
    Add-Member -InputObject $Task -MemberType NoteProperty -Name "PreConditions" -Value (New-IHITaskConditionList)
    Add-Member -InputObject $Task -MemberType NoteProperty -Name "TaskSteps" -Value (New-IHIDynamicValueList)
    Add-Member -InputObject $Task -MemberType NoteProperty -Name "PostConditions" -Value (New-IHITaskConditionList)
    Add-Member -InputObject $Task -MemberType NoteProperty -Name "ExitMessage" -Value (New-IHITaskDynamicValue)
    Add-Member -InputObject $Task -MemberType NoteProperty -Name "Error" -Value $Error
    Add-Member -InputObject $Task -MemberType NoteProperty -Name "Processed" -Value $Processed
    $Task
  }
}
Export-ModuleMember -Function New-IHITask
#endregion


#region Functions: New-IHITaskConditionList

<#
.SYNOPSIS
Returns new, empty TaskConditionList object
.DESCRIPTION
Returns new, empty TaskConditionList object
.EXAMPLE
New-IHITaskConditionList
Returns new, empty TaskConditionList object
#>
function New-IHITaskConditionList {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    [pscustomobject]$TaskConditionsList = New-Object PSCustomObject
    # Conditions is an array of dynamic values
    $TaskConditions = New-IHIDynamicValueList
    # Passed indicates if all conditions evaluated to true; it is true by default which is the case
    # if there are no conditions 
    [bool]$Passed = $true
    Add-Member -InputObject $TaskConditionsList -MemberType NoteProperty -Name "TaskConditions" -Value $TaskConditions
    Add-Member -InputObject $TaskConditionsList -MemberType NoteProperty -Name "Passed" -Value $Passed
    $TaskConditionsList
  }
}
Export-ModuleMember -Function New-IHITaskConditionList
#endregion


#region Functions: New-IHITaskDynamicValue

<#
.SYNOPSIS
Returns new, empty TaskDynamicValue object
.DESCRIPTION
Returns new, empty TaskDynamicValue object
.EXAMPLE
New-IHITaskDynamicValue
Returns new, empty TaskDynamicValue object
#>
function New-IHITaskDynamicValue {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    [pscustomobject]$DynamicValue = New-Object PSCustomObject
    [System.Management.Automation.ScriptBlock]$ScriptBlock = $null
    # no type defined; could be anything (bool, string, array of objects, etc.)
    $ScriptBlockValue = $null
    [bool]$Error = $false
    $ErrorValues = $null
    [bool]$Processed = $false
    Add-Member -InputObject $DynamicValue -MemberType NoteProperty -Name "Error" -Value $Error
    Add-Member -InputObject $DynamicValue -MemberType NoteProperty -Name "ErrorValues" -Value $ErrorValues
    Add-Member -InputObject $DynamicValue -MemberType NoteProperty -Name "Processed" -Value $Processed
    Add-Member -InputObject $DynamicValue -MemberType NoteProperty -Name "ScriptBlock" -Value $ScriptBlock
    Add-Member -InputObject $DynamicValue -MemberType NoteProperty -Name "ScriptBlockValue" -Value $ScriptBlockValue
    $DynamicValue
  }
}
Export-ModuleMember -Function New-IHITaskDynamicValue
#endregion


#region Functions: New-IHITaskList

<#
.SYNOPSIS
Returns new, empty TaskList object
.DESCRIPTION
Returns new, empty TaskList object
.EXAMPLE
New-IHITaskList
Returns new, empty TaskList object
#>
function New-IHITaskList {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    [pscustomobject]$TaskList = New-Object PSCustomObject
    # array of dynamic values (just object array)
    [object[]]$Tasks = @()
    Add-Member -InputObject $TaskList -MemberType NoteProperty -Name "Tasks" -Value $Tasks
    $TaskList
  }
}
Export-ModuleMember -Function New-IHITaskList
#endregion


#region Functions: New-IHITransferVariableList

<#
.SYNOPSIS
Returns new, empty TransferVariableList object
.DESCRIPTION
Returns new, empty TransferVariableList object
.EXAMPLE
New-IHITransferVariableList
Returns new, empty TransferVariableList object
#>
function New-IHITransferVariableList {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    [pscustomobject]$TransferVariableList = New-Object PSCustomObject
    [object[]]$TransferVariables = @()
    Add-Member -InputObject $TransferVariableList -MemberType NoteProperty -Name "TransferVariables" -Value $TransferVariables
    $TransferVariableList
  }
}
Export-ModuleMember -Function New-IHITaskList
#endregion
