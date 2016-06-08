<#
This file contains all the core logging functionality.  All functions
that use or modify any internal variables should be located in this script.
Any helper functions or output functions that do not need direct access
to the internal variables should be located in LoggingUtils.psm1.
#>

#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
    # initialize/reset private variables
    [string]$script:HostScriptName = ""
    [string]$script:HostScriptFolder = ""

    # defaults for log file
    [string]$script:LogFilePath = $null
    [hashtable]$script:OutFileSettings = @{ Encoding = "ascii"; Force = $true; Append = $true }
    [string]$script:DefaultLogFileNameFormatString = "{0}_Log_{1:yyyyMMdd_HHmmss}.txt"

    # time script started, needed for duration
    $script:StartTime = $null

    # two spaces for an index
    [string]$script:IndentStep = "  "
    # start with no indent level
    [int]$script:IndentLevel = 0

    [int]$script:HeaderFooterCol1Width = 18
    [int]$script:HeaderFooterBarLength = 85
    [string]$script:HeaderFooterBarChar = "#"
  }
}

# initialize/reset the module
Initialize
#endregion


#region Functions: Add-IHILogIndentLevel, Remove-IHILogIndentLevel

<#
.SYNOPSIS
Increases the default logging indent level by 1
.DESCRIPTION
Increases the default logging indent level by 1; max is 10
.EXAMPLE
Add-IHILogIndentLevel
Increases indenting level by 1
#>
function Add-IHILogIndentLevel {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    if ($IndentLevel -lt 11) { $script:IndentLevel += 1 }
  }
}
Export-ModuleMember -Function Add-IHILogIndentLevel


<#
.SYNOPSIS
Decreases the default logging indent level by 1
.DESCRIPTION
Decreases the default logging indent level by 1; min is 0
.EXAMPLE
Remove-IHILogIndentLevel
Decreases indenting level by 1
#>
function Remove-IHILogIndentLevel {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    if ($IndentLevel -gt 0) { $script:IndentLevel -= 1 }
  }
}
Export-ModuleMember -Function Remove-IHILogIndentLevel
#endregion


#region Functions: Write-IHILogHeader, Write-IHILogFooter

<#
.SYNOPSIS
Writes script header information to Write-Host
.DESCRIPTION
Writes script header informatino to Write-Host including script
name and path, machine name, domain/user name and start time.
Additionally displays any information pass in via hashtable parameter.
Information is surrounded with 'bars' of # marks.
.PARAMETER AdditionalValuesToDisplay
Key/Value pairs to display after the main information.  Keys are sorted
and nested hashtables are displayed in a nested fashion.
.EXAMPLE
Write-IHILogHeader
Writes the log header with information
#>
function Write-IHILogHeader {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [hashtable]$AdditionalValuesToDisplay
  )
  #endregion
  process {
    #region Determine width of column 1
    # if additional values passed, need to determine what the width of column1 should be
    if ($AdditionalValuesToDisplay -ne $null) {
      # to determine width of column1
      #  - get maximum key length
      $MaxKeyLength = Get-IHIHashtableMaxKeyLength $AdditionalValuesToDisplay -Recursive
      #  - next find out deepest depth of nested hashtables
      $MaxTableDepth = Get-IHIHashtableMaxDepth $AdditionalValuesToDisplay
      #  - assume prefix padding is 2 spaces (thus the * 2)
      #  - then add 2 more as space between the value and the next column
      $NewColumn1Width = $MaxKeyLength + (($MaxTableDepth) * 2) + 2
      if ($NewColumn1Width -gt $HeaderFooterCol1Width) {
        $script:HeaderFooterCol1Width = $NewColumn1Width
      }
    }
    #endregion

    #region Write header
    Write-Host ""
    [string]$FormatString = "{0,-$HeaderFooterCol1Width}{1}"
    Write-Host $($HeaderFooterBarChar * $HeaderFooterBarLength)
    # if module being used from a script and Enable-IHILogFile called, host script details will be known
    if ($HostScriptName -ne "") {
      Write-Host $($FormatString -f "Script Name",$HostScriptName)
      Write-Host $($FormatString -f "Location",$HostScriptFolder)
    }
    Write-Host $($FormatString -f "Machine",(Get-IHIFQMachineName))
    Write-Host $($FormatString -f "User",($ENV:USERDOMAIN + "\" + $ENV:USERNAME))

    # set start time for determining duration in footer
    $script:StartTime = Get-Date
    Write-Host $($FormatString -f "Start time",$StartTime)

    #write additional values hashtable
    if ($AdditionalValuesToDisplay -ne $null) {
      Write-IHIHashtableToHost -HT $AdditionalValuesToDisplay -KeyColumnWidthMax $HeaderFooterCol1Width
    }
    Write-Host $($HeaderFooterBarChar * $HeaderFooterBarLength)
    #endregion
  }
}
Export-ModuleMember -Function Write-IHILogHeader


<#
.SYNOPSIS
Writes script footer information to Write-Host
.DESCRIPTION
Writes script footer informatino to Write-Host including script
name and path and end time.
Information is surrounded with 'bars' of # marks.
.EXAMPLE
Write-IHILogFooter
Writes the log footer with information
#>
function Write-IHILogFooter {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    [string]$FormatString = "{0,-$HeaderFooterCol1Width}{1}"
    Write-Host $($HeaderFooterBarChar * $HeaderFooterBarLength)
    # if module being used from a script and Enable-IHILogFile called, host script details will be known
    if ($HostScriptName -ne "") {
      Write-Host $($FormatString -f "Script Name",$HostScriptName)
      Write-Host $($FormatString -f "Location",$HostScriptFolder)
    }

    $EndTime = Get-Date
    Write-Host $($FormatString -f "End time",$EndTime)
    # determine duration and display
    $Duration = $EndTime - $StartTime
    [string]$DurationDisplay = ""
    if ($Duration.Days -gt 0) { $DurationDisplay += $Duration.Days.ToString() + " days, " }
    if ($Duration.Hours -gt 0) { $DurationDisplay += $Duration.Hours.ToString() + " hours, " }
    if ($Duration.Minutes -gt 0) { $DurationDisplay += $Duration.Minutes.ToString() + " minutes, " }
    if ($Duration.Seconds -gt 0) { $DurationDisplay += $Duration.Seconds.ToString() + " seconds" }
    Write-Host $($FormatString -f "Duration",$DurationDisplay)

    Write-Host $($HeaderFooterBarChar * $HeaderFooterBarLength)
    Write-Host ""
  }
}
Export-ModuleMember -Function Write-IHILogFooter
#endregion


#region Functions: Enable-IHILogFile, Disable-IHILogFile, New-IHILogFilePathInRelativeLocation
<#
.SYNOPSIS
Turns on file logging and writes header
.DESCRIPTION
Enables file logging and writes header.  When enabled, all content
passed to Write-Host will be stored in a log file.  The log file
can be specified in parameter LogPath; if not specified, the log
file will be created in a _Log folder in the same folder at the 
script and the log file name will be the script name plus a date
time stamp.
.PARAMETER LogPath
Path of log file
.PARAMETER NoHeader
Do not write out header information
.PARAMETER LogFileSettings
Hashtable of settings to use when writing to log file.  Hashtable keys must
be valid parameter names on Out-File command.
.EXAMPLE
Enable-IHILogFile
Enables file logging and writes header
.EXAMPLE
Enable-IHILogFile -NoFooter
Enables file logging but does not write header
#>
function Enable-IHILogFile {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    $LogPath = $null,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$NoHeader,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [hashtable]$LogFileSettings
  )
  #endregion
  process {
    #region Get parent script name/path
    # if being called from a script, get script name info - if info exists
    if ($PSCmdlet -ne $null -and $PSCmdlet.MyInvocation -ne $null -and
      $PSCmdlet.MyInvocation.ScriptName -ne $null -and $PSCmdlet.MyInvocation.ScriptName.Trim() -ne "") {
      $script:HostScriptName = Split-Path $PSCmdlet.MyInvocation.ScriptName -Leaf
      $script:HostScriptFolder = Split-Path $PSCmdlet.MyInvocation.ScriptName -Parent
    } else {
      # running interactively; get currently location and set name to console
      $script:HostScriptName = "CONSOLE_INTERACTIVE"
      # but might not be in a file system location, so need to check that, too
      if ((Get-Location).Provider.Name -ne "FileSystem") {
        # no idea where to put it; in temp folder I guess
        $script:HostScriptFolder = $Ihi:Folders.TempFolder
      } else {
        $script:HostScriptFolder = (Get-Location).Path
      }
    }
    #endregion

    #region Set log file path
    if ($LogPath -eq $null -or $LogPath.Trim() -eq "") {
      #region Set log path - parameter value not passed
      # no value passed for log file, use log file in location relative to script
      $script:LogFilePath = New-IHILogFilePathInRelativeLocation
      #endregion
    } else {
      #region Set log path - parameter value passed
      # no value passed for log file
      #   if path exists: check if file; if so, set to that value
      #     else it is a folder so file name is script name no extension + _Log_DateTimeStamp using "{0:yyyyMMdd_HHmmss}"
      if (Test-Path -Path $LogPath) {
        if (!(Get-Item -Path $LogPath).PSIsContainer) {
          $script:LogFilePath = $LogPath
        } else {
          $LogFileName = $script:DefaultLogFileNameFormatString -f $script:HostScriptName,(Get-Date)
          $script:LogFilePath = Join-Path -Path $LogPath -ChildPath $LogFileName
        }
      } else {
        #   if path doesn't exist, assume this is a file path
        #     get parent folder; if doesn't exist, try to create
        #       if create fails, put in local _Logs folder
        #       if parent folder exists, just use path
        $LogFolder = Split-Path -Path $LogPath -Parent
        if ($? -eq $false) {
          # don't Write-Error and return (exit) for this, just report and continue
          Write-Host "Error attempting to get path folder of $LogPath; storing log file in local _log folder instead" -ForegroundColor Red
          $script:LogFilePath = New-IHILogFilePathInRelativeLocation
        } else {
          if (!(Test-Path -Path $LogFolder)) {
            New-Item -Path $LogFolder -Type Directory > $null
            if ($? -eq $false) {
              # don't Write-Error and return (exit) for this, just report and continue
              Write-Host "Error attempting to create log folder $LogFolder; storing log file in local _log folder instead" -ForegroundColor Red
              $script:LogFilePath = New-IHILogFilePathInRelativeLocation
            } else {
              # parent path now exists; use $LogPath
              $script:LogFilePath = $LogPath
            }
          } else {
            # parent path exists; use $LogPath
            $script:LogFilePath = $LogPath
          }
        }
      }
      #endregion
    }
    #endregion

    #region Set out file settings
    #PSTODO: implement parameter check - confirm keys are valid parameters
    #        on Out-File.  See poshcode Get-Parameter for iterating info.
    #        For now, just set.
    if ($LogFileSettings -ne $null) {
      $script:OutFileSettings = $LogFileSettings
    }
    #endregion

    #region Write header
    # write header unless user specified not to
    if (!$NoHeader) {
      Write-IHILogHeader
    }
    #endregion
  }
}
Export-ModuleMember -Function Enable-IHILogFile


<#
.SYNOPSIS
Turns off file logging and writes footer
.DESCRIPTION
Turns off file logging and writes footer
.PARAMETER NoFooter
Do not write out footer information
.EXAMPLE
Disable-IHILogFile
Disables file logging and writes footer
.EXAMPLE
Disable-IHILogFile -NoFooter
Disables file logging but does not write footer
#>
function Disable-IHILogFile {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$NoFooter
  )
  #endregion
  process {
    #region Write footer
    # write header unless user specified not to
    # must be done before Initialize (which resets script name & path)
    if (!$NoFooter) {
      Write-IHILogFooter
    }
    #endregion

    # turn off file logging by setting path to null
    $script:LogFilePath = $null
  }
}
Export-ModuleMember -Function Disable-IHILogFile


<#
.SYNOPSIS
Generates a log file path in a _Log folder in the same folder to the script
.DESCRIPTION
Creates a unique log file path in a _Log folder in the same folder to the
script.  The _Log folder is created if it does not already exist.  The log
file name is based on the script name plus a datetime stamp and extension 
".txt".  The time stamp format is: "{0}_Log_{1:yyyyMMdd_HHmmss}.txt"
#>
function New-IHILogFilePathInRelativeLocation {
  process {
    # get folder of current script
    # look for _Logs subfolder in that folder, if not, create
    # file name is script name + _Log_DateTimeStamp + .txt using DefaultLogFileNameFormatString
    $LogFolder = Join-Path -Path $script:HostScriptFolder -ChildPath "_Log"
    if ($false -eq (Test-Path -Path $LogFolder)) {
      [hashtable]$Params = @{ Path = $LogFolder; ItemType = "Directory" }
      # New-Item also had a bug where error records will not be caught with 2>&1
      # so use ErrorVariable instead
      $Err = $null
      $Results = New-Item @Params -ErrorVariable Err 2>&1
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in New-Item with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Err")"
        return
      }
    }
    $LogFileName = $script:DefaultLogFileNameFormatString -f $script:HostScriptName,(Get-Date)
    Join-Path -Path $LogFolder -ChildPath $LogFileName
  }
}
#endregion


#region Functions: Write-Host

<#
.SYNOPSIS
Wraps cmdlet Write-Host; also can write content to log file
.DESCRIPTION
Writes content to host similar to Write-Host but also writes content
to a file if file logging is enabled.  In addition, any special 
object types (see help for Confirm-IHILogSpecialType) will be output
in a way that shows the content as opposed to the default which is
simply the name of the type.  This is not a true proxy function 
(with steppable pipeline) as I was not able to get it to selectively
use Write-Host (can't turn off for types that require special
formatting).
.PARAMETER Object
Object to write
.PARAMETER BackgroundColor
Color to use for background when writing
.PARAMETER ForegroundColor
Color to use for foreground (character itself) when writing
.PARAMETER NoNewline
Don't write a new line after writing
.PARAMETER Separator
Text used to separate array of items when writing (default is space)
.EXAMPLE
Write-Host "hey now"
Writes "hey now" to console and logs to file, if enabled
.EXAMPLE
Write-Host @{ A=1; B=2 }
Writes this to console (and log, if enabled)
A    1
B    2
#>
function Write-Host {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $false,Position = 1)]
    $Object,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [ValidateSet("Black","DarkBlue","DarkGreen","DarkCyan","DarkRed","DarkMagenta","DarkYellow","Gray","DarkGray","Blue","Green","Cyan","Red","Magenta","Yellow","White")]
    [string]$BackgroundColor,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [ValidateSet("Black","DarkBlue","DarkGreen","DarkCyan","DarkRed","DarkMagenta","DarkYellow","Gray","DarkGray","Blue","Green","Cyan","Red","Magenta","Yellow","White")]
    [string]$ForegroundColor,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$NoNewline,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [object]$Separator
  )
  #endregion
  process {
    $ObjectToWrite = $null
    if ($_ -ne $null) { $ObjectToWrite = $_; }
    elseif ($Object -ne $null) { $ObjectToWrite = $Object; }
    # if nothing passed, return
    else { return }
    if (Confirm-IHILogSpecialType $ObjectToWrite) {
      Write-IHISpecialTypeToHost @PSBoundParameters
    } else {
      # add space prefix based on indent level
      $ObjectToWrite = ($script:IndentStep * $script:IndentLevel) + $ObjectToWrite.ToString()
      $PSBoundParameters.Object = $ObjectToWrite
      # write to log file in enabled (log file path set to value)
      if ($LogFilePath -ne $null -and $LogFilePath.Trim() -ne "") {
        [hashtable]$Params2 = @{ InputObject = $ObjectToWrite; FilePath = $LogFilePath } + $OutFileSettings
        $Err = $null
        Out-File @Params2 -ErrorVariable Err
        if ($? -eq $false) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
          return
        }
      }
      # write to console window using actual Write-Host cmdlet
      $Cmd = Get-Command -Name "Write-Host" -CommandType Cmdlet
      & $Cmd @PSBoundParameters
    }
  }
}
Export-ModuleMember -Function Write-Host
#endregion
