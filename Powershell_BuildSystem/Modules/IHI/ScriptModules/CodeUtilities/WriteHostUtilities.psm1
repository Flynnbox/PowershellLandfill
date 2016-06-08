
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


#region Functions: Out-IHIToOrderedColumns

<#
.SYNOPSIS
Writes a list of items in several columns to the host
.DESCRIPTION
Writes a list of strings in several columns to the host.  The strings are displayed 
in the order they are received BUT are displayed down the first column, then second, etc.
in the same order as received to provide a set of lists that is easy to read.
For example, outputting 3 columns this list: A,B,C,D,E,F,G,H,I would produce
A    D    G
B    E    H
C    F    I
By default, if you use Format-Wide, PowerShell nicely outputs all the values in a 
table, but it orders them across the table, not down.
A    B    C
D    E    F
G    H    I
.PARAMETER ListToDisplay
List of strings to display
.PARAMETER Columns
Number of columns to display 2 - 4 only
.EXAMPLE
Out-IHIToOrderedColumns -ListToDisplay A,B,C,D,E,F -Columns 2
Outputs
A                       D
B                       E
C                       F
#>
function Out-IHIToOrderedColumns {
  #region Function parameters 
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ListToDisplay,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateRange(2,6)]
    [int]$Columns
  )
  #endregion
  process {
    # figure out number of rows
    [int]$Rows = [math]::Ceiling($ListToDisplay.Length / $Columns)

    # this function works by reordering the list so that Format-Wide outputs the content correctly
    # unfortunately, Format-Wide doesn't work on simple strings! must be an object with a specific property
    # so create an object with a property Name
    $ObjectListToDisplay = $ListToDisplay | Select @{ n = "Name"; e = { $_ } }

    # this function works by reordering the list so that Format-Wide outputs the content correctly
    # loop through and re-order entries, based on Index = y + (x-1) * NumRows
    # where y = 1 to Rows and x = 1 to Columns
    $NewListToDisplay = $null
    [int]$Index = 0
    for ([int]$x = 1; $x -le $Rows; $x++) {
      for ([int]$y = 1; $y -le $Columns; $y++) {
        $Index = $x + (($y - 1) * $Rows)
        if ($Index -le $ObjectListToDisplay.Length) {
          $NewListToDisplay +=,$ObjectListToDisplay[$Index - 1]
        } else {
          # add a blank entry; bit of a hack
          $BlankEntry = 1 | Select @{ n = "Name"; e = { " " } }
          $NewListToDisplay +=,$BlankEntry
        }
      }
    }
    # now use Format-Wide -column to display them and Out-Host to dump directly to 
    # host (don't return in stream!)
    $NewListToDisplay | Format-Wide -Column $Columns | Out-Host
  }
}
Export-ModuleMember -Function Out-IHIToOrderedColumns
#endregion
