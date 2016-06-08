
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


#region Functions: Remove-IHIFilesByPattern

<#
.SYNOPSIS
Deletes files and folder that match regular expression pattern(s)
.DESCRIPTION
Deletes files and folder that match regular expression pattern(s) under a 
folder.  Specify one or more regular expressions and all files and folders 
under the path that match will be deleted.  Specify recursive if you want 
to purge recursively.
.PARAMETER Path
Source folder under which to purge
.PARAMETER Recursive
Specify if you want to walk through all subfolders to find matches
.PARAMETER Patterns
List of patterns to match
.PARAMETER LogFile
Path to log file to store files that match before purging
.PARAMETER FileAge
Files older than this many days will be deleted, by default the time is now
.EXAMPLE
Remove-IHIFilesByPattern -Path c:\temp -Patterns .txt$,.cs$
Deletes all .txt and .cs files located immediately under c:\temp folder
.EXAMPLE
Remove-IHIFilesByPattern -Path c:\temp -Patterns .txt$,.cs$ -Recursive
Deletes all .txt and .cs files located anywhere under c:\temp folder or subfolder
.EXAMPLE
Remove-IHIFilesByPattern -Path c:\temp -Patterns \\UIWeb$ -Recursive
Deletes UIWeb folder under c:\temp
.EXAMPLE
Remove-IHIFilesByPattern -Path c:\temp -Patterns MyProject\.csproj$
Deletes MyProject.csproj file
.EXAMPLE
Remove-IHIFilesByPattern -Path c:\temp -Patterns \.svn$ -Recursive
Deletes Subversion folders
#>
function Remove-IHIFilesByPattern {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$Recursive,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Patterns,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$LogFile,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$FileAge
  )
  #endregion
  process {
    #region Parameter validation
    #region Confirm source path exists and is a folder
    if ($false -eq (Test-Path -Path $Path)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: source folder path is null or bad: $Path"
      return
    }
    if (!(Get-Item -Path $Path).PSIsContainer) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: source folder path must be a folder, not a file ($Path); specify file name in parameter Path"
      return
    }
    #endregion

    #region Make sure Patterns are valid regular expressions
    # for each entry in Patterns, create regex to see if invalid expression
    foreach ($Pattern in $Patterns) {
      try { New-Object System.Text.RegularExpressions.Regex $Pattern > $null }
      catch {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: invalid regular expression pattern: $Pattern"
        return
      }
    }
    #endregion
    #endregion

    #region Report information before processing files
    # rather than use PSBoundParameters, manually output for better formatting
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Path",$Path)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Recursive",$Recursive)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Patterns",$("$Patterns"))
    if ($LogFile -ne "") { Write-Host $("{0,-$DefaultCol1Width} {1}" -f "LogFile",$LogFile) }
    Remove-IHILogIndentLevel
    #endregion

    #region Build up complete path regex
    Add-IHILogIndentLevel
    Write-Host "Build up complete path regex"
    # combine all regular expressions into a single pipe separated expression so can run once against each file/folder
    $CompletePatternRegex = ""
    for ($i = 0; $i -lt $Patterns.Count; $i++) {
      $CompletePatternRegex += $Patterns[$i]
      if ($i -lt ($Patterns.Count - 1)) { $CompletePatternRegex += "|" }
    }
    Remove-IHILogIndentLevel
    #endregion

    #region Get files/folders to delete and record
    Add-IHILogIndentLevel
    # get all files and folders under directory (get hidden ones using -force)
    Write-Host "Get matching files"
    Add-IHILogIndentLevel
    if ($FileAge)
    {
      # We only need to delete files older than a specific time
      $MatchingFiles = Get-ChildItem -Path $Path -Force -Recurse:$Recursive | Where-Object { $_.FullName -imatch $CompletePatternRegex } | Where-Object { $_.CreationTime -lt ($(Get-Date).AddDays(-$FileAge)) }
    } else {
      $MatchingFiles = Get-ChildItem -Path $Path -Force -Recurse:$Recursive | Where-Object { $_.FullName -imatch $CompletePatternRegex }
    }
    # if no matching files or folders then done
    if ($null -eq $MatchingFiles) {
      Write-Host "No files or folders match the pattern(s)"
      Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
    }
    # if user specified LogFile, store results in it
    if ($LogFile -ne "") {
      Write-Host "Storing purged files in: $LogFile"
      [hashtable]$Params = @{ InputObject = $MatchingFiles; FilePath = $LogFile } + $OutFileSettings
      $Err = $null
      Out-File @Params -ErrorVariable Err
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Err")"
        return
      }
    }
    #endregion

    #region Delete items
    Write-Host "Deleting items"
    # loop through all items to delete
    foreach ($Item in $MatchingFiles) {
      # make sure object still exists, because folders can be recursively
      # deleted, it is possible that a file or folder could be marked for
      # deletion but a parent directory that contains it is deleted first
      if ($true -eq (Test-Path -Path $Item.FullName)) {
        # item still exists; delete it
        [hashtable]$Params = @{ Path = $Item.FullName; Force = $true; ErrorAction = "Stop" }
        # if folder, make sure recurse
        if ($Item.PSIsContainer -eq $true) {
          $Params.Recurse = $true
        } else {
          # if file, make sure it is read-write, not hidden or system
          $Item.Attributes = [System.IO.FileAttributes]"Normal"
        }
        # now delete
        $Results = Remove-Item @Params 2>&1
        if ($? -eq $false) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Remove-Item with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Results")"
          return
        }
      }
    }
    Add-IHILogIndentLevel
    Write-Host "Items deleted"
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    #endregion
  }
}
Export-ModuleMember -Function Remove-IHIFilesByPattern
#endregion
