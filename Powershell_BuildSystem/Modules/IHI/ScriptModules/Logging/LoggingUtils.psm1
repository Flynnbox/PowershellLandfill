<#
This file contains all the helper logging functionality. 
Only helper functions or output functions that do not need direct access
to the internal variables should be located here.
#>

#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
    [string]$script:IndentStep = "  "
  }
}
# initialize/reset the module
Initialize
# ensure best practices for variable use, function calling, null property access, etc.
# must be done at module script level, not inside Initialize, or will only be function scoped
Set-StrictMode -Version 2
#endregion


#region Functions: Confirm-IHILogSpecialType

<#
.SYNOPSIS
Returns $true if type has special Write-Host processing
.DESCRIPTION
Returns $true if class type requires special Write-Host processing.
Certain complex objects cannot be simply be written with Write-Host or
the object's type will be written and not the object's value.
These types require special Write-Host processing:
 - System.Collections.Hashtable
 - System.Xml.XmlDocument
 - System.Xml.XmlElement
.PARAMETER Object
Object to check
.EXAMPLE
Confirm-IHILogSpecialType -Object <object>
Returns $true if object type has special output function
#>
function Confirm-IHILogSpecialType {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    $Object
  )
  #endregion
  process {
    [bool]$IsSpecial = $false
    if ("System.Collections.Hashtable","System.Xml.XmlDocument","System.Xml.XmlElement","System.Management.Automation.ErrorRecord" -contains $Object.GetType().FullName) {
      $IsSpecial = $true
    }
    $IsSpecial
  }
}
Export-ModuleMember -Function Confirm-IHILogSpecialType


<#
.SYNOPSIS
Calls appropriate Write-IHI...ToHost based on input type
.DESCRIPTION
Calls appropriate Write-IHI...ToHost based on input type
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
Write-IHISpecialTypeToHost <some object>
Writes a special object type to the host
#>
function Write-IHISpecialTypeToHost {
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
    switch ($Object.GetType().FullName) {
      "System.Collections.Hashtable" { Write-IHIHashtableToHost @PSBoundParameters }
      "System.Management.Automation.ErrorRecord" { Write-IHIErrorRecordToHost @PSBoundParameters }
      "System.Xml.XmlDocument" { Write-IHIXmlToHost @PSBoundParameters }
      "System.Xml.XmlElement" { Write-IHIXmlToHost @PSBoundParameters }
      default { Write-Host $("Write-IHISpecialTypeToHost: no special type handling for type: " + $Object.GetType().FullName) }
    }
  }
}
Export-ModuleMember -Function Write-IHISpecialTypeToHost
#endregion


#region Functions: Convert-IHIFlattenHashtable

<#
.SYNOPSIS
Converts hashtable into string, sorted by keys name
.DESCRIPTION
Converts hashtable into string, sorted by keys name.  Does NOT walk 
recursively down hashtables.  This is mostly likely to be used to 
report splatted params for logging.
.PARAMETER HT
Hash table to flatten
.EXAMPLE
Convert-IHIFlattenHashtable -HT <hash table>
Flattens hash table to single string
#>
function Convert-IHIFlattenHashtable {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [hashtable]$HT
  )
  #endregion
  process {
    [string]$Result = ""
    # display keys in order
    $HT.Keys | Sort | ForEach-Object {
      # separate keys/values pairs with semi-colon
      if ($Result -ne "") { $Result += " ; " }
      # $_ is the key
      $Result += $_ + " = " + $HT.$_
    }
    $Result
  }
}
Export-ModuleMember -Function Convert-IHIFlattenHashtable
#endregion


#region Functions: Write-IHIHashtableToHost, Get-IHIHashtableMaxDepth, Get-IHIHashtableMaxKeyLength

<#
.SYNOPSIS
Writes hashtable contents to host in a nice format
.DESCRIPTION
Displays hashtable contents including nested hashtables in a nice format.
Each nested hashtable is indented while the entire Key column shares a fixed
maximum formatting width.
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
.PARAMETER Indent
Indent level to display item at
.PARAMETER KeyColumnWidthMax
Maximum width of Key column
.EXAMPLE
Write-IHIHashtableToHost <hash table>
Writes hash table to host
#>
function Write-IHIHashtableToHost {
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
    [object]$Separator,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [int]$Indent = 0,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [int]$KeyColumnWidthMax = -1
  )
  #endregion
  process {
    #region Validate parameters
    if ($Object.GetType().FullName -ne "System.Collections.Hashtable") {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: object is not a HashTable"
      return
    }
    #endregion
    # if KeyColumnWidthMax not passed, determine what max should be
    if ($KeyColumnWidthMax -eq -1) {
      # first, determine longest key name in hashtable and nested hashtables
      $MaxKeyNameLength = Get-IHIHashtableMaxKeyLength -HT $Object -Recursive
      # next, determine maximum depth of nested hashtables
      $MaxTableDepth = Get-IHIHashtableMaxDepth -HT $Object
      # assume one level deeper because these hashtables are already down a level
      $MaxTableDepth += 1
      # figure out column1 width
      # - need to know the indent level (which is the max depth)
      # - for this indent level, multiply times $IndentStep.Length (one prefix per indent)
      # - then add the length of the longest entry
      # - then add 2 more as space between the value and the next column
      $KeyColumnWidthMax = $MaxKeyNameLength + (($MaxTableDepth) * ($IndentStep.Length)) + 2
    }
    $Prefix = $IndentStep * $Indent
    $ValueColumnWidth = $KeyColumnWidthMax - $Prefix.Length
    # display keys in order
    $Object.Keys | Sort | ForEach-Object {
      $Key = $_
      # if value is NOT a hashtable, just display it using Write-Host
      if ($Object.$Key -isnot [hashtable]) {
        # use string expansion to get value to display
        $Value = $Object.$Key
        $Value = "$Value"

        #region Modify PSBoundParameters before calling Write-Host
        # In order to call Write-Host with the same 'signature' as Write-IHIHashtableToHost was
        # called with (same parameters and values), we will pass PSBoundParameters to write host.
        # Before we can do that, though, we have to make two changes to PSBoundParameters
        #  - change the value of Object so it's the value we want to display, not the 
        #    entire hashtable itself
        #  - remove any parameters that are not native to Write-Host

        # the content we are writing is a formatted string with our values (prefix, key and value)
        $PSBoundParameters.Object = ("{0}{1,-$ValueColumnWidth}{2}" -f $Prefix,$Key,$Value)
        # remove parameters not supported by Write-Host: Indent and KeyColumnWidthMax
        if ($PSBoundParameters.ContainsKey("Indent")) {
          $PSBoundParameters.Remove("Indent") > $null
        }
        if ($PSBoundParameters.ContainsKey("KeyColumnWidthMax")) {
          $PSBoundParameters.Remove("KeyColumnWidthMax") > $null
        }
        #endregion

        # call Write-Host to output the key/value combo
        Write-Host @PSBoundParameters
      } else {
        # So, we have a nested hashtable; for nested hashtables, we want to display
        # the Key name on a line by itself then the contents of the hashtable with a 
        # larger indent.  We display the nested hashtable by passing it to Display-HashTable

        # first get temporary reference to the hashtable before we write out the 
        # Key name by itself
        $Obj = $Object

        #region Modify PSBoundParameters before calling Write-Host
        # In order to call Write-Host with the same 'signature' as Write-IHIHashtableToHost was
        # called with (same parameters and values), we will pass PSBoundParameters to write host.
        # Before we can do that, though, we have to make two changes to PSBoundParameters
        #  - change the value of Object so it's the value we want to display, not the 
        #    entire hashtable itself
        #  - remove any parameters that are not native to Write-Host

        # the content we are writing is a formatted string with our values (prefix, key and value)

        # call Write-Host with all the same original parameters except $Object
        # which we are replacing with our formatted line
        $PSBoundParameters.Object = ("{0}{1}" -f $Prefix,$Key)
        # remove parameters not supported by Write-Host: Indent and KeyColumnWidthMax
        if ($PSBoundParameters.ContainsKey("Indent")) {
          $PSBoundParameters.Remove("Indent") > $null
        }
        if ($PSBoundParameters.ContainsKey("KeyColumnWidthMax")) {
          $PSBoundParameters.Remove("KeyColumnWidthMax") > $null
        }
        #endregion

        # call Write-Host to output the key
        Write-Host @PSBoundParameters

        # now call Write-IHIHashtableToHost recursively to output the nested hash table
        # with same parameters except the object to process is the nested hash table
        # and the Indent and KeyColumnWidthMax have to be set/incremented

        # the object to display is the nested hashtable
        $PSBoundParameters.Object = $Obj.$Key
        # add the Indent and KeyColumnWidthMax
        if ($PSBoundParameters.ContainsKey("Indent")) {
          # $PSBoundParameters.Indent = $Indent + 1
          $PSBoundParameters.Item("Indent") = $Indent + 1
        } else {
          $PSBoundParameters.Add("Indent",$Indent + 1) > $null
        }
        if ($PSBoundParameters.ContainsKey("KeyColumnWidthMax")) {
          # $PSBoundParameters.KeyColumnWidthMax = $KeyColumnWidthMax
          $PSBoundParameters.Item("KeyColumnWidthMax") = $KeyColumnWidthMax
        } else {
          $PSBoundParameters.Add("KeyColumnWidthMax",$KeyColumnWidthMax) > $null
        }
        Write-IHIHashtableToHost @PSBoundParameters
      }
    }
  }
}
Export-ModuleMember -Function Write-IHIHashtableToHost


<#
.SYNOPSIS
Returns the greatest depth of nested hashtables
.DESCRIPTION
Returns the greatest depth of nested hashtables.  This is useful when
displaying the contents of a hashtable and formatting the first column
to be the necessary max width (combined with Get-IHIHashtableMaxKeyLength).
.PARAMETER HT
Hash table to analyze
.PARAMETER CurrentDepth
Current search level
.PARAMETER MaxDepth
Current max depth found
.EXAMPLE
Get-IHIHashtableMaxDepth -HT <hash table> -CurrentDepth 3 -MaxDepth 4
Blah
#>
function Get-IHIHashtableMaxDepth {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [hashtable]$HT,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [int]$CurrentDepth = -1,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [int]$MaxDepth = -1
  )
  #endregion
  process {
    $CurrentDepth += 1
    if ($CurrentDepth -gt $MaxDepth) { $MaxDepth = $CurrentDepth }
    # if empty table just exit
    if ($HT.Count -eq 0) { return $CurrentDepth }
    # walk through existing values, looking for nested hashtables
    $HT.Values | ForEach-Object {
      if ($_ -is [hashtable]) {
        # call get max depth recursively
        $NewMaxDepth = Get-IHIHashtableMaxDepth -HT $_ -CurrentDepth $CurrentDepth -MaxDepth $MaxDepth
        if ($NewMaxDepth -gt $MaxDepth) { $MaxDepth = $NewMaxDepth }
      }
    }
    $MaxDepth
  }
}
Export-ModuleMember -Function Get-IHIHashtableMaxDepth


<#
.SYNOPSIS
Returns the length of the longest key name in a hashtable
.DESCRIPTION
Returns the length of the longest key name in a hashtable; optionally
'walking' recursively down nested hashtables.  Useful when outputting the
contents of a hash table in a 'pretty' format - use the length as the
column width.  Does NOT detect circular references so watch out!
.PARAMETER HT
Hash table to analyze
.PARAMETER Recursive
If the hash table contains nested hash tables, check all recursively.
.EXAMPLE
Get-IHIHashtableMaxKeyLength -HT <hash table> -Recursive
Returns the length of the longest key name in the hashtable
#>
function Get-IHIHashtableMaxKeyLength {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [hashtable]$HT,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$Recursive
  )
  #endregion
  process {
    $MaxLength = 0
    # if empty table just exit
    if ($HT.Count -eq 0) { return }
    # get maximum length of current keys
    $Length = ($HT.Keys | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    if ($Length -gt $MaxLength) { $MaxLength = $Length }
    # if Recursive specified and hashtable contains other hashtables, walk down nested hashtables
    if ($Recursive) {
      $HT.Values | ForEach-Object {
        if ($_ -is [hashtable]) {
          # call get max lengh recursively
          $Length = Get-IHIHashtableMaxKeyLength -HT $_ -Recursive
          if ($Length -gt $MaxLength) { $MaxLength = $Length }
        }
      }
    }
    $MaxLength
  }
}
Export-ModuleMember -Function Get-IHIHashtableMaxKeyLength
#endregion


#region Functions: Write-IHIErrorRecordToHost

<#
.SYNOPSIS
Writes ErrorRecord to host in a nice format
.DESCRIPTION
Writes System.Management.Automation.ErrorRecord contents to host in a 
nice format
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
Write-IHIErrorRecordToHost -Object <error record>
Writes error record to host
#>
function Write-IHIErrorRecordToHost {
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
    #region Validate parameters
    if ($Object.GetType().FullName -ne "System.Management.Automation.ErrorRecord") {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: object is not an ErrorRecord"
      return
    }
    #endregion

    # get basic exception info
    [string]$ErrorMsg = ""
    # add invocation info, if exists
    if ($Object.InvocationInfo -ne $null -and $Object.InvocationInfo.MyCommand -ne $null) {
      $ErrorMsg += $Object.InvocationInfo.MyCommand.ToString() + " : "
    }
    # add exception
    $ErrorMsg += $Object.Exception.ToString()
    # add on any nested exception info
    $Exception = $Object.Exception
    while ($Exception.InnerException -ne $null) {
      $ErrorMsg += " :: " + $Exception.InnerException.ToString()
      $Exception = $Exception.InnerException
    }
    # add invocation location information
    if ($Object.InvocationInfo -ne $null -and $Object.InvocationInfo.PositionMessage -ne $null) {
      $ErrorMsg += $Object.InvocationInfo.PositionMessage
    }

    # we need to remove $Object as that is the original object and we are passing in 
    # our own object via the pipeline
    $PSBoundParameters.Remove("Object") > $null
    # write errorrecord info
    $ErrorMsg | Write-Host @PSBoundParameters
  }
}
Export-ModuleMember -Function Write-IHIErrorRecordToHost
#endregion


#region Functions: Write-IHIXmlToHost

<#
.SYNOPSIS
Writes xml contents to host in a nice format
.DESCRIPTION
Writes xml contents to host in a nice format using Format-Xml
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
Write-IHIXmlToHost <xml>
Writes xml to host
#>
function Write-IHIXmlToHost {
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
    #region Validate parameters
    if (!($Object.GetType().FullName -eq "System.Xml.XmlDocument" -or $Object.GetType().FullName -eq "System.Xml.XmlElement")) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: object is not an XmlDocument nor an XmlElement"
      return
    }
    #endregion
    # Use PSCX Format-XML to format the xml nicely; Format-Xml returns a single 
    # string; we need to split into string array so indenting is correct.
    # Also, we need to pass PSBoundParameters to Write-Host so the necessary params are
    # included in the call to Write-Host, however, we need to remove $Object as that is 
    # coming in via the pipeline
    $PSBoundParameters.Remove("Object") > $null
    (Format-Xml -InputObject $Object -IndentString "  ").Replace("`r","").Split("`n") | Write-Host @PSBoundParameters
  }
}
Export-ModuleMember -Function Write-IHIXmlToHost
#endregion
