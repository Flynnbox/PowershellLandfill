
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


#region Functions: New-IHITaskFromXml

<#
.SYNOPSIS
Creates new Task object from Xml
.DESCRIPTION
Creates new Task object from Xml
.PARAMETER TaskXml
XmlElement that contains Task information
.EXAMPLE
New-IHITaskFromXml -TaskXml <xml>
Creates new Task object from Xml
#>
function New-IHITaskFromXml {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [System.Xml.XmlElement]$TaskXml
  )
  #endregion
  process {
    $Err = $null
    [System.Management.Automation.ScriptBlock]$ScriptBlock = $null
    #get new empty task object
    $Task = New-IHITask

    #region Get IntroMessage
    # IntroMessage is required so if no values exist throw error
    if ((Get-Member -InputObject $TaskXml -Name IntroMessage) -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: IntroMessage is null or empty in TaskXml"
      return
    }
    $Err = $null
    $ScriptBlock = Convert-IHIStringToScriptBlock $TaskXml.IntroMessage -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating task because of bad IntroMessage"
      return
    } else {
      # set scriptblock value of IntroMessage
      $Task.IntroMessage.ScriptBlock = $ScriptBlock
    }
    #endregion

    #region Get Preconditions
    # PreConditions not required; check exist before attempting to process
    if ((Get-Member -InputObject $TaskXml -Name PreConditions) -ne $null) {
      foreach ($Condition in $TaskXml.PreConditions.Condition) {
        $Err = $null
        $ScriptBlock = Convert-IHIStringToScriptBlock $Condition -EV Err
        if ($Err -ne $null) {
          $Err | Write-Host
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating task because of bad PreCondition"
          return
        } else {
          # create new dynamic value
          $DynamicValue = New-IHITaskDynamicValue
          $DynamicValue.ScriptBlock = $ScriptBlock
          # add scriptblock to list of PreConditions.TaskConditions scriptblocks
          $Task.PreConditions.TaskConditions.DynamicValues += $DynamicValue
        }
      }
    }
    #endregion

    #region Get TaskSteps
    # TaskSteps is required so if no values exist throw error
    if ((Get-Member -InputObject $TaskXml -Name TaskSteps) -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: TaskSteps is null or empty in TaskXml"
      return
    }
    foreach ($TaskStep in $TaskXml.TaskSteps.TaskStep) {
      $Err = $null
      $ScriptBlock = Convert-IHIStringToScriptBlock $TaskStep -EV Err
      if ($Err -ne $null) {
        $Err | Write-Host
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating task because of bad TaskStep"
        return
      } else {
        # create new dynamic value
        $DynamicValue = New-IHITaskDynamicValue
        $DynamicValue.ScriptBlock = $ScriptBlock
        # add scriptblock to list of TaskSteps scriptblocks
        $Task.TaskSteps.DynamicValues += $DynamicValue
      }
    }
    #endregion

    #region Get PostConditions
    # PostConditions not required; check exist before attempting to process
    if ((Get-Member -InputObject $TaskXml -Name PostConditions) -ne $null) {
      foreach ($Condition in $TaskXml.PostConditions.Condition) {
        $Err = $null
        $ScriptBlock = Convert-IHIStringToScriptBlock $Condition -EV Err
        if ($Err -ne $null) {
          $Err | Write-Host
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating task because of bad PostCondition"
          return
        } else {
          # create new dynamic value
          $DynamicValue = New-IHITaskDynamicValue
          $DynamicValue.ScriptBlock = $ScriptBlock
          # add scriptblock to list of PostConditions.TaskConditions scriptblocks
          $Task.PostConditions.TaskConditions.DynamicValues += $DynamicValue
        }
      }
    }
    #endregion

    #region Get ExitMessage
    # ExitMessage not required; check exist before attempting to process
    if ((Get-Member -InputObject $TaskXml -Name ExitMessage) -ne $null) {
      $Err = $null
      $ScriptBlock = Convert-IHIStringToScriptBlock $TaskXml.ExitMessage -EV Err
      if ($Err -ne $null) {
        $Err | Write-Host
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating task because of bad ExitMessage"
        return
      } else {
        # set scriptblock value of IntroMessage
        $Task.ExitMessage.ScriptBlock = $ScriptBlock
      }
    }
    #endregion

    #return new object
    $Task
  }
}
Export-ModuleMember -Function New-IHITaskFromXml
#endregion


#region Functions: New-IHITaskListFromXml

<#
.SYNOPSIS
Creates new TaskList object from Xml
.DESCRIPTION
Creates new TaskList object from Xml
.PARAMETER TaskListXml
XmlElement that contains TaskList information
.EXAMPLE
New-IHITaskListFromXml -TaskListXml <xml>
Creates new TaskList object from Xml
#>
function New-IHITaskListFromXml {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [System.Xml.XmlElement]$TaskListXml
  )
  #endregion
  process {
    $Err = $null
    $Task = $null
    #get new empty task list object
    $TaskList = New-IHITaskList

    foreach ($TaskXml in ($TaskListXml.Task)) {
      $Err = $null
      $Task = New-IHITaskFromXml $TaskXml -EV Err
      if ($Err -ne $null) {
        $Err | Write-Host
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating Task"
        return
      }
      # was successful, add to list of tasks
      $TaskList.Tasks +=,$Task
    }
    #return new object
    $TaskList
  }
}
Export-ModuleMember -Function New-IHITaskListFromXml
#endregion


#region Functions: New-IHIVariablePairListFromXml

<#
.SYNOPSIS
Creates new VariablePairList object from Xml
.DESCRIPTION
Creates new VariablePairList object from Xml
.PARAMETER VariablePairs
XmlElement that contains VariablePair information
.EXAMPLE
New-IHIVariablePairListFromXml -VariablePairs <xml element>
Creates variable pair list from xml
#>
function New-IHIVariablePairListFromXml {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [System.Xml.XmlElement]$VariablePairs
  )
  #endregion
  process {
    $Err = $null
    $VariablePairList = @()
    #region For each variable pair, create variable pair object and add to $VariablePairList
    [pscustomobject]$VariablePair = $null
    foreach ($VariablePairXml in $VariablePairs.VariablePair) {
      #region Check for empty variable names
      if ($VariablePairXml.ScriptVariable -eq $null -or $VariablePairXml.ScriptVariable.Trim() -eq "") {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: null or empty value for ScriptVariable"
        return
      }
      if ($VariablePairXml.TaskProcessVariable -eq $null -or $VariablePairXml.TaskProcessVariable.Trim() -eq "") {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: null or empty value for TaskProcessVariable"
        return
      }
      #endregion
      #region Create new VariablePair object
      $VariablePair = New-Object PSCustomObject
      Add-Member -InputObject $VariablePair -MemberType NoteProperty -Name "ScriptVariable" -Value $($VariablePairXml.ScriptVariable)
      Add-Member -InputObject $VariablePair -MemberType NoteProperty -Name "TaskProcessVariable" -Value $($VariablePairXml.TaskProcessVariable)
      #endregion
      $VariablePairList +=,($VariablePair)
    }
    #endregion
    #return new object
    $VariablePairList
  }
}
Export-ModuleMember -Function New-IHIVariablePairListFromXml
#endregion
