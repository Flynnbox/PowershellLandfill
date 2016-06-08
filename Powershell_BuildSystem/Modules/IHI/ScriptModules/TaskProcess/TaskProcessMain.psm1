
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


#region Functions: Initialize-IHITaskProcessModuleFromXml

<#
.SYNOPSIS
Loads task process from Xml into module so can be invoked
.DESCRIPTION
Initializes all internal task process values by reading the process
settings from xml and prepares the module so it can be invoked.
.PARAMETER TaskProcessXml
XmlElement that contains TaskProcess information
.EXAMPLE
Initialize-IHITaskProcessModuleFromXml
Initializes module with task processing xml
#>
function Initialize-IHITaskProcessModuleFromXml {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [System.Xml.XmlElement]$TaskProcessXml
  )
  #endregion
  process {
    #region Parameter validation
    # perform some basic XML structure tests to catch major errors
    # complete XML testing should be done with XSD
    if ((Get-Member -InputObject $TaskProcessXml -Name Tasks) -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: TaskProcess does not contain a Tasks section"
      return
    }
    if ((Get-Member -InputObject $TaskProcessXml.Tasks -Name Task) -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: TaskProcess.Tasks contains no Task sections"
      return
    }
    #endregion

    #region Create ImportVariables list from xml, if present
    # import variables are not required
    if ((Get-Member -InputObject $TaskProcessXml -Name ImportVariables) -ne $null) {
      if ($TaskProcessXml.ImportVariables -ne $null -and
        $TaskProcessXml.ImportVariables.VariablePair -ne $null) {
        $Err = $null
        $script:ImportVariables = New-IHIVariablePairListFromXml $TaskProcessXml.ImportVariables -EV Err
        if ($Err -ne $null) {
          $Err | Write-Host
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating ImportVariable pair list"
          return
        }
      }
    }
    #endregion

    #region Create TaskList from xml
    $Err = $null
    $script:TaskList = New-IHITaskListFromXml $TaskProcessXml.Tasks -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating task list from xml"
      return
    }
    #endregion

    #region Create ExportVariables list from xml, if present
    # import variables are not required
    if ((Get-Member -InputObject $TaskProcessXml -Name ExportVariables) -ne $null) {
      if ($TaskProcessXml.ExportVariables -ne $null -and
        $TaskProcessXml.ExportVariables.VariablePair -ne $null) {
        $Err = $null
        $script:ExportVariables = New-IHIVariablePairListFromXml $TaskProcessXml.ExportVariables -EV Err
        if ($Err -ne $null) {
          $Err | Write-Host
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating ExportVariables pair list"
          return
        }
      }
    }
    #endregion
  }
}
Export-ModuleMember -Function Initialize-IHITaskProcessModuleFromXml
#endregion


#region Functions: Initialize-IHITaskProcessModule

<#
.SYNOPSIS
Initializes task process module using xml values, if passed
.DESCRIPTION
Initializes the task process module.  If an xml element containing task
process information is passed in TaskProcessXml, this information is loaded 
into the module using Initialize-IHITaskProcessModuleFromXml.
.PARAMETER TaskProcessXml
XmlElement that contains TaskProcess information
.EXAMPLE
Initialize-IHITaskProcessModule -TaskProcessXml <xml>
Initializes module with task processing xml
#>
function Initialize-IHITaskProcessModule {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [System.Xml.XmlElement]$TaskProcessXml
  )
  #endregion
  process {
    # reset current reference, if exists
    [System.Management.Automation.PSModuleInfo]$script:TaskProcessDynamicModule = $null
    $Tasks = $null

    #region Initialize private variables
    $script:TaskList = $null
    [object[]]$script:ImportVariables = $null
    [object[]]$script:ExportVariables = $null
    [bool]$script:TaskProcessLoaded = $false
    [int]$script:TaskIndex = 0
    #endregion

    #region Create new dynamic module used for processing all task list scriptblocks
    # initialize dynamic module with Set-StrictMode -Version 2 to make sure
    # that any code processed inside the dynamic module conforms to best 
    # practices - variables defined, etc.
    $script:TaskProcessDynamicModule = New-Module -Name "TaskProcessModule" -ScriptBlock { Set-StrictMode -Version 2 }
    #endregion

    #region If TaskProcessXml passed, process xml and initial module with values
    if ($TaskProcessXml -ne $null) {
      #region Make sure xml is valid
      #region Perform basic xml validation
      if ($false -eq (Test-Xml -InputObject $TaskProcessXml)) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: TaskProcessXml is not valid xml"
        return
      }

      #endregion
      #region Xml XSD validation
      # asdf to be implemented
      #endregion
      #endregion

      $Err = $null
      Initialize-IHITaskProcessModuleFromXml $TaskProcessXml -EV Err
      if ($Err -ne $null) {
        $Err | Write-Host
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred initializing task process data from xml data"
        return
      }
      $script:TaskProcessLoaded = $true
    }
    #endregion
  }
}
Export-ModuleMember -Function Initialize-IHITaskProcessModule
#endregion


#region Functions: Invoke-IHIDynamicValue

<#
.SYNOPSIS
Invokes DynamicValues.ScriptBlock, results in ScriptBlockValue
.DESCRIPTION
Invokes the scriptblock stored in DynamicValue.ScriptBlock and stores the results
into DynamicValue.ScriptBlockValue.  If an error occurs, DynamicValue.Error is
set to $true and any errors are stored in DynamicValue.ErrorValues.
.PARAMETER DynamicValue
DynamicValue object to be invoked
.EXAMPLE
Invoke-IHIDynamicValue -DynamicValue <script block>
Invokes DynamicValues.ScriptBlock, results in ScriptBlockValue
#>
function Invoke-IHIDynamicValue {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [pscustomobject]$DynamicValue
  )
  #endregion
  process {
    #region Parameter validation
    #region Make sure ScriptBlock is not null
    if ($DynamicValue.ScriptBlock -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: DynamicValue.ScriptBlock is null but must be a valid scriptblock reference"
      return
    }
    #endregion

    #region Make sure TaskProcessDynamicModule is not null
    if ($script:TaskProcessDynamicModule -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: TaskProcessDynamicModule is null because Initialize-IHITaskProcessModule was not called; make sure Initialize-IHITaskProcessModule is called when initializing a task list."
      return
    }
    #endregion
    #endregion

    $Err = $null
    try {
      # set Processed to true ahead of actual invoke so no need to do it
      # in a finally block (in the case of an exception being thrown)
      $DynamicValue.Processed = $true
      #region Create closure from scriptblock
      # before processing script block we are going to convert it to a closure
      # that is, bind an anonymous method to a module, in this case our module
      # is TaskProcessDynamicModule, the module-level variable
      # by converting the scriptblock to a closure and executing it, the task
      # will run in it's own space, will not affect any script-level variables,
      # will be contained, etc.
      $Closure = $script:TaskProcessDynamicModule.NewBoundScriptBlock($DynamicValue.ScriptBlock)
      #endregion
      $Results = & $Closure 2>&1
      if ($? -eq $false -or ((Select-IHIErrorObjects $Results) -ne $null)) {
        $DynamicValue.ErrorValues = Select-IHIErrorObjects $Results
        $DynamicValue.Error = $true
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred invoking dynamic value --> $($DynamicValue.ScriptBlock) <--"
        $DynamicValue.ErrorValues | Write-Error
        return
      } else {
        # no error, store results if any
        $DynamicValue.ScriptBlockValue = $Results
      }
    } catch {
      $DynamicValue.ErrorValues = $_
      $DynamicValue.Error = $true
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred (catch block) invoking dynamic value $($DynamicValue.ScriptBlock)"
      $DynamicValue.ErrorValues | Write-Error
      return
    }
  }
}
Export-ModuleMember -Function Invoke-IHIDynamicValue
#endregion


#region Functions: Invoke-IHITask

<#
.SYNOPSIS
Processes a Task object and writes results to host
.DESCRIPTION
Invokes all DynamicValue objects on a task and writes results to host.  This includes:
 - invoking and displaying the IntroMessage
 - invoking each PreCondition, if any exist.  If none exist, skip to TaskSteps, if they
   exist all must be $true or processing of this task is terminated WITHOUT ERROR, 
   i.e. this task is 'skipped'.
 - invoking each TaskStep (must be at least one present) and output results
 - invoking each PostCondition, if any exist.  If none exist, skip to ExitMessage, if they
   exist all must $true or the entire task process comes to an end, terminating WITH ERROR.
 - invoking and displaying the ExitMessage, if exists
.PARAMETER Task
Task object to be processed
.EXAMPLE
Invoke-IHITask -Task <task>
Invokes the task
#>
function Invoke-IHITask {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [pscustomobject]$Task
  )
  #endregion
  process {
    #region Parameter validation
    # Make sure structure of basic Task object is correct and required params found.
    # A Task only required properties are IntroMessage and Tasks, however the basic
    # underlying structure must exist for all the Task properties.  For example, a task
    # may not have any preconditions but it needs to have a valid PreConditions object
    # reference which contains a TaskConditions object has a DynamicValues array which would be 
    # empty, in this case.  This is stuff that would normally be cake to maintain in a 
    # compiled language but this is PowerShell and it's too easy to screw up your objects.
    # We don't need to check if the ScriptBlock property is found on individual DynamicValue
    # objects; this will be checked in Invoke-IHIDynamicValue.
    if ($Task.IntroMessage -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Task IntroMessage reference is null; this task is not structurally correct"
      $Task.Error = $true; return
    }
    if ($Task.PreConditions -eq $null -or $Task.PreConditions.TaskConditions -eq $null -or $Task.PreConditions.TaskConditions.DynamicValues -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Task PreConditions and/or TaskConditions and/or DynamicValues reference is null; this task is not structurally correct"
      $Task.Error = $true; return
    }
    if ($Task.TaskSteps -eq $null -or $Task.TaskSteps.DynamicValues -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Task TaskSteps and/or DynamicValues reference is null; this task is not structurally correct"
      $Task.Error = $true; return
    }
    if ($Task.PostConditions -eq $null -or $Task.PostConditions.TaskConditions -eq $null -or $Task.PostConditions.TaskConditions.DynamicValues -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Task PostConditions and/or TaskConditions and/or DynamicValues reference is null; this task is not structurally correct"
      $Task.Error = $true; return
    }
    if ($Task.ExitMessage -eq $null -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Task ExitMessage reference is null; this task is not structurally correct"
      $Task.Error = $true; return
    }
    # make sure there are actual Tasks to be processed
    if ($Task.TaskSteps.DynamicValues.Count -eq 0) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: This Task has no TaskSteps; this task is not structurally correct"
      $Task.Error = $true; return
    }
    #endregion

    #region Process IntroMessage
    $Err = $null
    Invoke-IHIDynamicValue $Task.IntroMessage -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred invoking dynamic value for IntroMessage"
      $Task.Error = $true; return
    }
    Write-Host "$($Task.IntroMessage.ScriptBlockValue)"
    #endregion

    #region Process each PreCondition
    if ($Task.PreConditions.TaskConditions.DynamicValues.Count -gt 0) {
      Write-Host ""
      Write-Host "PreConditions:"
      Add-IHILogIndentLevel
      foreach ($DynamicValue in $Task.PreConditions.TaskConditions.DynamicValues) {
        $Err = $null
        Invoke-IHIDynamicValue $DynamicValue -EV Err
        Write-Host $("{0,-5} :: {1}" -f ($DynamicValue.ScriptBlockValue,$DynamicValue.ScriptBlock.ToString().Trim()))
        if ($Err -ne $null) {
          $Err | Write-Host
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred invoking dynamic value for PreCondition"
          $Task.PreConditions.Passed = $false
          $Task.Error = $true; Remove-IHILogIndentLevel; return
        }
        # make sure result of the processing is a single boolean (not an int nor an array of booleans nor anything else)
        if ($DynamicValue.ScriptBlockValue -isnot [bool]) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: PreCondition produced a non-boolean result; ScriptBlock is --> $($DynamicValue.ScriptBlock.ToString()) <-- produced value: $($DynamicValue.ScriptBlockValue)"
          $Task.PreConditions.Passed = $false
          $Task.Error = $true; Remove-IHILogIndentLevel; return
        }
        # if a PreCondition failed, this isn't an error but stop processing task
        # and set Passed = $false for the entire PreConditions list
        if ($DynamicValue.ScriptBlockValue -eq $false) {
          $Task.PreConditions.Passed = $false
          Add-IHILogIndentLevel
          Write-Host "PreCondition failed; skipping this task"
          Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
        }
      }
      Remove-IHILogIndentLevel
    }
    #endregion

    #region Process each TaskStep
    Write-Host ""
    Write-Host "TaskSteps:"
    Add-IHILogIndentLevel
    [int]$CurrentTaskStepIndex = 0
    foreach ($DynamicValue in $Task.TaskSteps.DynamicValues) {
      $CurrentTaskStepIndex += 1
      Write-Host ("Step #" + $CurrentTaskStepIndex)
      Add-IHILogIndentLevel
      $Err = $null
      Invoke-IHIDynamicValue $DynamicValue -EV Err
      if ($Err -ne $null) {
        # only show task souce if there was an error
        Write-Host ($DynamicValue.ScriptBlock.ToString().Trim())
        $Err | Write-Host
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred invoking dynamic value for TaskStep"
        $Task.Error = $true; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
      }
      # only output results if there are any captured
      if ($DynamicValue.ScriptBlockValue -ne $null) {
        $DynamicValue.ScriptBlockValue | ForEach-Object { Write-Host $("$_") }
      }
      # if not last taskstep, write newline spacer
      if ($CurrentTaskStepIndex -lt $Task.TaskSteps.DynamicValues.Count) { Write-Host "" }
      Remove-IHILogIndentLevel
    }
    Remove-IHILogIndentLevel
    #endregion

    #region Process each PostConditions
    if ($Task.PostConditions.TaskConditions.DynamicValues.Count -gt 0) {
      Write-Host ""
      Write-Host "PostConditions:"
      Add-IHILogIndentLevel
      foreach ($DynamicValue in $Task.PostConditions.TaskConditions.DynamicValues) {
        $Err = $null
        Invoke-IHIDynamicValue $DynamicValue -EV Err
        Write-Host $("{0,-5} :: {1}" -f ($DynamicValue.ScriptBlockValue,$DynamicValue.ScriptBlock.ToString().Trim()))
        if ($Err -ne $null) {
          $Err | Write-Host
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred invoking dynamic value for PostCondition"
          $Task.PostConditions.Passed = $false
          $Task.Error = $true; Remove-IHILogIndentLevel; return
        }
        # make sure result of the processing is a single boolean (not an int nor an array of booleans nor anything else)
        if ($DynamicValue.ScriptBlockValue -isnot [bool]) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: PostCondition produced a non-boolean result; ScriptBlock is --> $($DynamicValue.ScriptBlock.ToString()) <-- produced value: $($DynamicValue.ScriptBlockValue)"
          $Task.PostConditions.Passed = $false
          $Task.Error = $true; Remove-IHILogIndentLevel; return
        }
        # if a PostCondition failed, this is a major error
        if ($DynamicValue.ScriptBlockValue -eq $false) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: PostCondition failed; ScriptBlock is --> $($DynamicValue.ScriptBlock.ToString()) <--"
          $Task.PostConditions.Passed = $false
          $Task.Error = $true; Remove-IHILogIndentLevel; return
        }
      }
      Remove-IHILogIndentLevel
    }
    #endregion

    #region Process ExitMessage
    if ($Task.ExitMessage.ScriptBlock -ne $null) {
      $Err = $null
      Invoke-IHIDynamicValue $Task.ExitMessage -EV Err
      if ($Err -ne $null) {
        $Err | Write-Host
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred invoking dynamic value for ExitMessage"
        $Task.Error = $true
        Remove-IHILogIndentLevel; return
      }
      Write-Host ""
      Write-Host "$($Task.ExitMessage.ScriptBlockValue)"
    }
    #endregion

    #region Task processing complete
    # no errors; record task as processed completely
    $Task.Processed = $true
    #endregion
  }
}
Export-ModuleMember -Function Invoke-IHITask
#endregion


#region Functions: Invoke-IHITaskProcess

<#
.SYNOPSIS
Invokes the task process
.DESCRIPTION
Invokes the task process contained in the task process module, assuming the 
module has been properly initialized with a TaskProcess xml.
.EXAMPLE
Invoke-IHITaskProcess
Invokes the task process
#>
function Invoke-IHITaskProcess {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    #region Parameter validation
    # make sure module initialized without errors
    if ($script:TaskProcessLoaded -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: task process module has not been initialized with valid data.  Make sure you first call Initialize-IHITaskProcessModule with a TaskProcess xml section before attempting to invoke the task list."
      return
    }
    # Make sure structure of basic objects are correct.
    # This is stuff that would normally be cake to maintain in a compiled language but 
    # this is PowerShell and it's too easy to screw up your objects.  
    # We don't need to check if the ScriptBlock property is found on individual DynamicValue
    # objects; this will be checked in Invoke-IHIDynamicValue.
    if ($script:TaskList -eq $null -or $script:TaskList.Tasks -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: TaskList and/or Tasks reference is null; TaskModule is not structurally correct"
      $Task.Error = $true; return
    }
    # check to make sure there are actual tasks
    if ($script:TaskList.Tasks.Count -eq 0) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: there are no tasks to process but they are required"
      $Task.Error = $true; return
    }
    #endregion

    #region Import variables from script context into task process context
    if ($script:ImportVariables -ne $null -and $script:ImportVariables.Count -gt 0) {
      Write-Host ""
      Write-Host "Importing variables from script context into task process context"
      Add-IHILogIndentLevel
      foreach ($VariablePair in $script:ImportVariables) {
        # check if variable exists in script context; if doesn't error
        $ScriptVar = Get-Variable -Scope Global | Where { $_.Name -eq $VariablePair.ScriptVariable }
        if ($ScriptVar -eq $null) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: No variable with name $($VariablePair.ScriptVariable) exists in script context to import into task process module context"
          Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
        }
        Write-Host "[script] $($VariablePair.ScriptVariable) -> [task] $($VariablePair.TaskProcessVariable) :: $($ScriptVar.Value)"
        $script:TaskProcessDynamicModule.SessionState.PSVariable.Set($VariablePair.TaskProcessVariable,$ScriptVar.value)
      }
      Remove-IHILogIndentLevel
    }
    #endregion

    #region Process all tasks
    foreach ($Task in $script:TaskList.Tasks) {
      $script:TaskIndex += 1
      Write-Host ""
      Write-Host "Task #$($script:TaskIndex)"
      Add-IHILogIndentLevel
      $Err = $null
      Invoke-IHITask $Task -EV Err
      if ($Err -ne $null) {
        $Err | Write-Host
        $ErrorMsg = "$($MyInvocation.MyCommand.Name):: Error occurred invoking task"
        Write-Error $ErrorMsg
        Write-Host $ErrorMsg
        Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
      }
      Remove-IHILogIndentLevel
    }
    #endregion

    #region Export variables from task process context into script context
    # take any ExportVariables values and set into script context
    if ($script:ExportVariables -ne $null -and $script:ExportVariables.Count -gt 0) {
      Write-Host ""
      Write-Host "Exporting variables from task process context into script context"
      Add-IHILogIndentLevel
      foreach ($VariablePair in $script:ExportVariables) {
        #region Check if variable exists in script context; if doesn't error
        if ($script:TaskProcessDynamicModule.SessionState.PSVariable.Get($VariablePair.TaskProcessVariable) -eq $null) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: No variable with name $($VariablePair.TaskProcessVariable) exists in task process module context to export to script context"
          Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
        }
        #endregion
        # attempt to get reference to variable in Global context
        $ScriptVar = Get-Variable -Scope Global | Where { $_.Name -eq $VariablePair.ScriptVariable }
        # if variable doesn't exist in Global context, create it and get reference
        if ($ScriptVar -eq $null) {
          New-Variable -Name $VariablePair.ScriptVariable -Scope Global
          $ScriptVar = Get-Variable -Scope Global | Where { $_.Name -eq $VariablePair.ScriptVariable }
        }
        Write-Host "[script] $($VariablePair.TaskProcessVariable) -> [task] $($VariablePair.ScriptVariable) :: $($script:TaskProcessDynamicModule.SessionState.PSVariable.Get($VariablePair.TaskProcessVariable).Value)"
        $ScriptVar.value = $script:TaskProcessDynamicModule.SessionState.PSVariable.Get($VariablePair.TaskProcessVariable).value
      }
      Remove-IHILogIndentLevel
    }
    #endregion

    #region Task process complete
    Write-Host ""
    Write-Host "Task process complete"
    #endregion
  }
}
Export-ModuleMember -Function Invoke-IHITaskProcess
#endregion
