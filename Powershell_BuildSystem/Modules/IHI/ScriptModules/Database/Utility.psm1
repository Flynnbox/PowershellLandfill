
#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
    # when writing name/value pairs, width of first column
    [int]$script:DefaultCol1Width = 20
    # when writing external logfile (not main), use these default settings
    [hashtable]$script:OutFileSettings = @{ Encoding = "ascii"; Force = $true; Append = $true }
  }
}
# initialize/reset the module
Initialize
# ensure best practices for variable use, function calling, null property access, etc.
# must be done at module script level, not inside Initialize, or will only be function scoped
Set-StrictMode -Version 2
#endregion


#region Functions: Test-IHIStoredProcedureStructure

<#
.SYNOPSIS
Returns $true if stored procedure has basic correct stucture
.DESCRIPTION
Returns $true if stored procedure has basic correct stucture, that is:
  - has "create procedure" or "alter procedure", followed by
  - "as" ... "go", followed by
  - "grant execute" followed by "go"
  - and the stored procedure name in the create/alter must match the grant execute
.PARAMETER Path
Path to file
.EXAMPLE
Test-IHIStoredProcedureStructure -Path c:\TestFile.prc
True
#>
function Test-IHIStoredProcedureStructure {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [Alias("FullName")]
    [string]$Path
  )
  #endregion
  process {
    #region Parameter validation
    #region Items in path must exist; if specified item does not actually exist, exit
    if ($false -eq (Test-Path -Path $Path)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: file not found: $Path"
      return
    }
    #endregion
    #region Make sure path correctly set
    $Path = (Resolve-Path -Path $Path).Path
    #endregion
    #endregion

    #region Rough description of regex:
    <#
    The 'sxi' values are some settings that specify case insensitive, compare across new 
    line characters, etc.  Look at the regex itself for an exact understanding of the 
    rules; I won't type up every detail about whitespace, etc., but basically:
     - look for 'create' or 'alter' followed by 'procedure'
     - ignore any store proc prefix like dbo. or [dbo]. or [dbo].[ or....
     - capture store proc name
     - ignore ] following proc name, if found
     - the word 'as' should follow
     - ignore all content after 'as' until the word 'go' (which should complete the store proc body)
     - next look for 'grant' 'execute' or 'exec' 'on' and ignore any store proc prefix
     - make sure the stored proc name matches the original captured name
     - make sure the name is followed by 'to' 'public' and 'go' (to complete that statement)
    #>
    #endregion
    $StructureRegEx = [regex]'(?sxi)\s+(?:create|alter)\s+procedure\s+(?:dbo\.|\[dbo\]\.)?\[?(?<procname>[\w]+)\]?.*\s+as\s+.*\s+go\s+.*\s+grant\s+(?:exec|execute)\s+on\s+(?:dbo\.|\[dbo\]\.)?\[?\k<procname>\]?\s+to\s+(?:public|\[public\])\s*;?\s+.*\s+go'
    # get content as a single large string so 
    [string]$Content = [System.IO.File]::ReadAllText($Path)
    $Content -match $StructureRegEx
  }
}
Export-ModuleMember -Function Test-IHIStoredProcedureStructure
#endregion
