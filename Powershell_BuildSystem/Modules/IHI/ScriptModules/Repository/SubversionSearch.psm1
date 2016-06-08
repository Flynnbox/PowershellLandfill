
#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
    # constants for search result object property names
    Set-Variable -Name RepositoryPathName -Value "RepositoryPath" -Option ReadOnly -Scope Script
    Set-Variable -Name LocalPathName -Value "LocalPath" -Option ReadOnly -Scope Script
  }
}
# initialize/reset the module
Initialize
# ensure best practices for variable use, function calling, null property access, etc.
# must be done at module script level, not inside Initialize, or will only be function scoped
Set-StrictMode -Version 2
#endregion


#region Functions: Search-IHIRepository

<#
.SYNOPSIS
Search for text in repo, filters and provides highlighting.
.DESCRIPTION
Searches for text in a repository using Search-IHIFishEyeRepository.  It
also provides filtering on the results based on the path of the results
(via PathPattern) and can select either the First x and/or Last y items.
In addition, when LocalPath is specified the file paths will be displayed
as the local paths instead of the repository paths.  When ShowText is
specified the actual matching text inside the files is displayed; by default
2 surrounding lines are shown but this can be modified with the DisplayLines
parameter.

If you are using ShowText and want to redirect the results to a file
(search .... > myresults.txt), by default nothing will go in the file as the 
content is written using Write-Host to display with colors; it is not passed 
through the pipeline.  To get around this, specify NoColors and the content
will be passed to the pipeline so it can be pipe easily into a file.
.PARAMETER SearchTerm
Text to search for
.PARAMETER PathPattern
String array of regular expressions; if search result doesn't match at least
one of the supplied patterns, filter it out
.PARAMETER LocalPath
Show the local file system path, not the repository path, to the file.  The
path is shown regardless of whether or not the file is actually on the 
filesystem.
.PARAMETER First
Filter out everything except first x items.  Can be combined with Last.
.PARAMETER Last
Filter out everything except last y items.  Can be combined with First.
.PARAMETER ShowText
Display text from file that matches search
.PARAMETER DisplayLineRange
Number of surrounding lines to display is Text specified.  Default 2.
.PARAMETER NoColors
Specify this to get ShowText results - without colors - sent through the 
pipeline so they can be redirected to a file.
.EXAMPLE
Search-IHIRepository MaintenanceWindowActive
<returns files using repository path that contain MaintenanceWindowActive>
search -SearchTerm MaintenanceWindowActive -LocalPath
<returns files using local path that contain MaintenanceWindowActive>
.EXAMPLE
Search-IHIRepository MaintenanceWindowActive \Production\web.config
<returns Production web.config files that contain MaintenanceWindowActive>
.EXAMPLE
Search-IHIRepository MaintenanceWindowActive \Production\web.config,Events
<returns Production web.config files plus any file under Events that 
contain MaintenanceWindowActive>
.EXAMPLE
Search-IHIRepository MaintenanceWindowActive -First 3
<returns first 3 files that contain MaintenanceWindowActive>
.EXAMPLE
Search-IHIRepository MaintenanceWindowActive -Last 2
<returns last 2 files that contain MaintenanceWindowActive>
.EXAMPLE
Search-IHIRepository MaintenanceWindowActive -ShowText
<returns files that contain MaintenanceWindowActive and displays
lines containing text with highlighting along with surrounding lines>
.EXAMPLE
Search-IHIRepository MaintenanceWindowActive -ShowText -DisplayLines 0
<returns files that contain MaintenanceWindowActive and displays
lines containing text with highlighting but no surrounding text>
.EXAMPLE
Search-IHIRepository MaintenanceWindowActive -ShowText -NoColors >  c:\temp\SearchResults.txt
<returns files that contain MaintenanceWindowActive and stores 
matching text into text file>
#>
function Search-IHIRepository {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SearchTerm,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$PathPattern = $null,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$LocalPath,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [ValidateRange(0,10000)]
    [int]$First = 0,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [ValidateRange(0,10000)]
    [int]$Last = 0,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$ShowText,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [ValidateRange(0,10000)]
    [int]$DisplayLineRange = 2,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$NoColors
  )
  #endregion
  process {
    #region Get search results
    # get search results from repository
    $SearchResults = Search-IHIFishEyeRepository $SearchTerm
    # if no results, exit function
    if ($SearchResults -eq $null) {
      return
    }
    #endregion

    #region Change search results string array into object with repository and local path
    # for existing results (string array), convert each result into an object with two properties
    #  - RepositoryPath: the path from the search result
    #  - LocalPath: the local location of that file on the user's machine
    $SearchResults = $SearchResults | Select-Object @{ n = $RepositoryPathName; e = { $_ } },@{ n = $LocalPathName; e = { Join-Path -Path $($Ihi:BuildDeploy.SvnMain.LocalRootFolder) -ChildPath $_ } }
    #endregion

    #region Filter out results we know we don't care about
    # filter out these paths (old SPRINGS and Qulturum)
    [string[]]$FilterOutPaths = 'trunk\Springs\Springs_2007','trunk\Springs\Springs_Prototype','Norway','Qulturum','trunk\BuildDeploy','trunk\PowerShell\Development','trunk\PublicSite','trunk\Utility\MCMS'
    # when we filter out results, we will be comparing against the LocalPath value
    # so we need to change any / characters to \
    # AND double-up slashes
    $FilterOutPaths = $FilterOutPaths | ForEach-Object { $_.Replace("/","\").Replace("\","\\") }

    # we know there are multiple entries
    # see section "Filter out results that don't match $PathPatterns" for comments how 
    # what we are doing here (same thing, just for hard-coded paths
    [string]$PatternRegex = ""
    [int]$Count = 0
    $FilterOutPaths | ForEach-Object {
      $PatternRegex = $PatternRegex + $_.Replace("\\","\").Replace("\","\\")
      $Count = $Count + 1
      # add | between NamePatterns, but not at end
      if ($Count -lt $FilterOutPaths.Count) { $PatternRegex = $PatternRegex + "|" }
    }
    # finally, filter the results, keeping only the file paths that match
    $SearchResults = $SearchResults | Where { $($_.$LocalPathName) -inotmatch $PatternRegex }
    # if no results, exit function
    if ($SearchResults -eq $null) {
      return
    }
    #endregion

    #region Filter out results that don't match $PathPatterns
    # if user supplied one or more paths to match, filter results so only
    # those results that match are kept
    if (($PathPattern -ne $null) -and ($PathPattern -ne "")) {
      # when we filter out results, we will be comparing against the LocalPath value
      # so we need to change any / characters to \
      $PathPattern = $PathPattern | ForEach-Object { $_.Replace("/","\") }

      [string]$PatternRegex = ""
      # Instead of taking each $PathPatterns individually and trying to 
      # match against each file separately (O(x*y)), it is faster/more efficient 
      # to combine all the patterns (separated by |) into a single pattern and match that.
      if ($PathPattern.Count -gt 1) {
        [int]$Count = 0
        $PathPattern | ForEach-Object {
          # We need to escape \ as \\ in the regex but must be careful not
          # allow instances of \\\ (if the user already escaped part or all
          # of the path).  Easiest way to do this is to first check if there
          # are any instances of \\ and change to \ (get all instances back to 
          # single \).  Then change all instances of \ to \\.
          $PatternRegex = $PatternRegex + $_.Replace("\\","\").Replace("\","\\")
          $Count = $Count + 1
          # add | between NamePatterns, but not at end
          if ($Count -lt $PathPattern.Count) { $PatternRegex = $PatternRegex + "|" }
        }
      } else {
        # only one PathPattern passed, use that
        # Need to escape \ as \\ - see notes above
        $PatternRegex = $PathPattern[0].Replace("\\","\").Replace("\","\\")
      }
      # finally, filter the results, keeping only the file paths that match
      $SearchResults = $SearchResults | Where { $_.$LocalPathName -imatch $PatternRegex }
    }
    # if no results, exit function
    if ($SearchResults -eq $null) {
      return
    }
    #endregion

    #region Filter out results based on First and Last
    if ($First -gt 0 -and $Last -gt 0) {
      $SearchResults = $SearchResults | Select-Object -First $First -Last $Last
    } else {
      if ($First -gt 0) {
        $SearchResults = $SearchResults | Select-Object -First $First
      } elseif ($Last -gt 0) {
        $SearchResults = $SearchResults | Select-Object -Last $Last
      }
    }
    #endregion

    #region Give results to user
    # if user didn't specify Text option just return search results
    if (!$ShowText) {
      # only return the string value that the user wants, not the whole object with both local and repo path
      # if user specified LocalPath, return just local path
      if ($LocalPath) {
        $SearchResults | ForEach-Object { $_.$LocalPathName }
      } else {
        # just return repo path
        $SearchResults | ForEach-Object { $_.$RepositoryPathName }
      }
    } else {
      # user specified ShowText, need to get content of files and display
      $SearchResults | Show-IHISearchResultsMatchingText -TextToHighlight $SearchTerm -DisplayLineRange $DisplayLineRange -LocalPath:$LocalPath -NoColors:$NoColors
    }
    #endregion
  }
}
Export-ModuleMember -Function Search-IHIRepository
New-Alias -Name "search" -Value Search-IHIRepository
Export-ModuleMember -Alias "search"

#endregion


#region Functions: Search-IHIFishEyeRepository

<#
.SYNOPSIS
Search for text in a FishEye search index of repository
.DESCRIPTION
Search for text in a FishEye search index of repository; searches HEAD version
.PARAMETER SearchTerm
Text to search for
.EXAMPLE
Search-IHIFishEyeRepository asdf
Searches repository for files containing text asdf
#>
function Search-IHIFishEyeRepository {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [string]$SearchTerm
  )
  #endregion
  process {
    #region Get read only user account info endcoded as base 64
    # first get string in correct format
    [string]$UserInfo = $Ihi:BuildDeploy.SvnMain.FishEye.ReadOnlyAccount.UserName + ":" + $Ihi:BuildDeploy.SvnMain.FishEye.ReadOnlyAccount.Password
    # now encode at base 64
    $UserInfoEncoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($UserInfo))
    #endregion

    #region Call FishEye web API to get results
    # load assembly that contains WebClient (used for making call) used to make http call
    Add-Type -AssemblyName System.Web
    # create HTTP web client
    [System.Net.WebClient]$WebClient = New-Object System.Net.WebClient
    # Add authorization HTTP header with user info
    $WebClient.Headers.Add("Authorization","Basic " + $UserInfoEncoded)
    # escape \ - change \ into \\
    # first find any instances of \\ so we don't change to \\\\
    $SearchTerm = $SearchTerm.Replace("\\","\").Replace("\","\\")
    # encode search term
    $SearchTerm = Convert-IHIUrlEncode $SearchTerm
    # get URL for calling FishEye REST API and insert search term
    [string]$SearchUrl = ($Ihi:BuildDeploy.SvnMain.FishEye.SearchRepositoryUrl).Replace("[[ENCODED_SEARCH_TERM]]",$SearchTerm)
    # get search results as string
    $ResultsXmlText = $WebClient.DownloadString($SearchUrl)
    # if an error occurred, just return, error will have been thrown and output to screen
    if ($? -eq $false) { return }
    #endregion

    #region Clean up results and return
    # convert to XML format
    [xml]$ResultsXml = [xml]$ResultsXmlText
    # search results
    [string[]]$Results = $null
    # if nothing found, fileRevisionKeyList will be an empty string
    if ($ResultsXml.fileRevisionKeyList -ne $null -and $ResultsXml.fileRevisionKeyList -ne "") {
      # read the value we are looking for - which is the Url - from XML, store it string array
      $Results = $ResultsXml.fileRevisionKeyList.fileRevisionKey | ForEach-Object { $_.Path } | Sort
    }
    #return results
    $Results
    #endregion
  }
}

#endregion


#region Functions: Show-IHISearchResultsMatchingText

<#
.SYNOPSIS
Displays the matching lines of a search result.
.DESCRIPTION
For a search result (see Search-IHIRepository), displays the matching
line and surrounding text, based on $DisplayLineRange.
.PARAMETER SearchResult
SearchResult object with RepositoryPath and LocalPath properties
.PARAMETER TextToHighlight
Text that was searched for and should not be higlighted
.PARAMETER DisplayLineRange
Number of surrounding lines to display is Text specified.  Default 2.
.PARAMETER LocalPath
Local path to file (not repository path)
.PARAMETER NoColors
Specify this to get ShowText results - without colors - sent through the 
pipeline so they can be redirected to a file.
#>
function Show-IHISearchResultsMatchingText {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    $SearchResult,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$TextToHighlight,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateRange(0,10000)]
    [int]$DisplayLineRange,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$LocalPath,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$NoColors
  )
  #endregion
  process {
    #region Object and tool/settings validation
    if ($SearchResult.$RepositoryPathName -eq $null -or $SearchResult.$LocalPathName -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: invalid SearchResult object; missing $RepositoryPathName or $LocalPathName"
      return
    }
    if ($Ihi:Applications.Repository.SubversionUtility -eq $null -or (!(Test-Path -Path $Ihi:Applications.Repository.SubversionUtility))) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Subversion client not installed or not found at path: $($Ihi:Applications.Repository.SubversionUtility)"
      return
    }
    if ($Ihi:Folders.TempFolder -eq $null -or (!(Test-Path -Path $Ihi:Folders.TempFolder))) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: temp folder not found at path: $($Ihi:Folders.TempFolder)"
      return
    }
    if ($Ihi:BuildDeploy.SvnMain.RepositoryRootUrl -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: BuildDeploy.SvnMain.RepositoryRootUrl not set in Ihi: drive"
      return
    }
    if ($Ihi:BuildDeploy.SvnMain.ReadOnlyAccount -eq $null -or $Ihi:BuildDeploy.SvnMain.ReadOnlyAccount.UserName -eq $null -or $Ihi:BuildDeploy.SvnMain.ReadOnlyAccount.Password -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: BuildDeploy.SvnMain.ReadOnlyAccount information not set correctly in Ihi: drive"
      return
    }
    #endregion

    #region Set temp folder location (create if necessary) and temp file
    # local destination; make sure exists
    [string]$TempFolder = Join-Path -Path $Ihi:Folders.TempFolder -ChildPath "SearchRepo"
    # create folder if doesn't exist
    if ($false -eq (Test-Path -Path $TempFolder)) {
      New-Item -Path $TempFolder -Type Directory 2>&1
    }
    [string]$TempFile = Join-Path -Path $TempFolder -ChildPath "SearchTempFile.txt"
    # remove existing temp file if found
    if (Test-Path -Path $TempFile) {
      [hashtable]$Params = @{ Path = $TempFile; Force = $true }
      $Results = Remove-Item @Params 2>&1
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Remove-Item with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Results")"
        return
      }
    }
    #endregion

    #region Get file to temp location
    # location is root plus item to search for (repo path)
    [string]$RepoUrlOfFile = $Ihi:BuildDeploy.SvnMain.RepositoryRootUrl + "/" + $SearchResult.$RepositoryPathName
    # get the file (export) from the repository, using the read only account
    [string]$Cmd = $Ihi:Applications.Repository.SubversionUtility
    [string[]]$Params = "export",$RepoUrlOfFile,"--username",$($Ihi:BuildDeploy.SvnMain.ReadOnlyAccount.UserName),"--password",$($Ihi:BuildDeploy.SvnMain.ReadOnlyAccount.Password),"--no-auth-cache",$TempFile
    $LastExitCode = 0
    $Results = & $Cmd $Params 2>&1
    # error handling note: svn is weird; doesn't set LastExitCode when error but $? seems to be set
    # in addition, check for existance of $TempFile; it is deleted before operation and if 
    # doesn't exist an error occurred
    if ($? -eq $false -or $LastExitCode -ne 0 -or ($false -eq (Test-Path -Path $TempFile))) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in svn export trying to fetch file contents with parameters: $("$Cmd $Params") :: $("$Results")"
      return
    }
    #endregion

    #region Display file name
    if ($LocalPath) {
      if ($NoColors) { "`nFile: $($SearchResult.$LocalPathName)" }
      else { Write-Host "`nFile: $($SearchResult.$LocalPathName)" -ForegroundColor Green }
    } else {
      if ($NoColors) { "`nFile: $($SearchResult.$RepositoryPathName)" }
      else { Write-Host "`nFile: $($SearchResult.$RepositoryPathName)" -ForegroundColor Green }
    }
    #endregion

    #region Get file content and line numbers that contain text
    $FileContent = Get-Content -Path $TempFile
    # get length of file
    [int]$FileLength = $FileContent.Length

    # get line numbers of lines containing text
    # when searching, do SimpleMatch, not regular expression search
    # more likely that user is search for $ in variablename, rather than end of line
    # plus FishEye doesn't support regex (I think)
    $LineNumbers = $null
    Select-String -Path $TempFile -Pattern $TextToHighlight -SimpleMatch | ForEach-Object {
      $LineNumbers = $LineNumbers +,$_.LineNumber
    }
    #endregion

    #region Determine actual groupings to show and show them
    # it's possible that the search results contain files that don't actually contain the search text
    # this happens at times with special characters, FishEye will match a file but when Select-String
    # is used (section above) no matches are found.  one example is "ihi:applications", FishEye will
    # return matches for "ihi applications".  so to be safe, to attempt to process the file unless
    # results are actually found
    if ($LineNumbers -ne $null) {
      # get the line groups to display, given the line numbers that contain
      # matches and the $DisplayLineRange range
      # $Groupings is an array of hashtables, each hashtable has these keys:
      #   Bottom - first line of range
      #   Top    - last line of range
      #   Rows   - array of line numbers containing matching text
      [System.Object[]]$Groupings = Get-IHILineGroupsForListAndRange -LineNumbers $LineNumbers -Range $DisplayLineRange -EndOfFile $FileLength
      $Groupings | ForEach-Object {
        Show-IHIFileLineRange -FileContent $FileContent -MatchingText $TextToHighlight -FirstLine $_.Bottom -LastLine $_.Top -MatchingLines $_.Rows -NoColors:$NoColors
        # if displaying context (DisplayLineRange>0), put a blank line after each section
        if ($DisplayLineRange -gt 0) {
          ""
        }
      }
    }
    #endregion
  }
}
#endregion


#region Functions: Get-IHILineGroupsForListAndRange

<#
.SYNOPSIS
Determines actuals groupings to display based in line numbers and ranges,
preventing overlapping sections
.DESCRIPTION
Determines actuals groupings to display based in line numbers and ranges,
preventing overlapping sections.  Let's say you have matching text on lines
5, 7, 16, 21, 22, and 30 with a range of +/- 2.  You could easily just 
display a section for each match but you'd have overlaps in this case.  For
example, the first match (5) would have lines 3-7, the second (7) would have
5-9, etc.  That's sloppy.  What you really want to do is combine the sections
so there is no overlap.  So the end result would be: 3-9 (contains 5 & 7), 
14-18 (contains 16), 19-24 (contains 21 & 22), etc.
.PARAMETER LineNumbers
Array of line numbers that contain matches
.PARAMETER TextToHighlight
Text that was searched for and should not be higlighted
.PARAMETER Range
Number of surrounding lines to display is Text specified.  Default 2.
.PARAMETER EndOfFile
Number of lines in file
.EXAMPLE
Get-IHILineGroupsForListAndRange
bleh, read description
#>
function Get-IHILineGroupsForListAndRange {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [int[]]$LineNumbers,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [int]$Range,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [int]$EndOfFile
  )
  #endregion
  process {
    [int]$Bottom = 0
    [int]$Top = 0
    $Groups = $null

    $LineNumbers | ForEach-Object {
      if ($Groups -eq $null) {
        # handle first entry
        $Bottom = $_ - $Range
        $Top = $_ + $Range
        # handle boundary conditions
        if ($Bottom -lt 1) { $Bottom = 1 }
        if ($Top -gt $EndOfFile) { $Top = $EndOfFile }
        $Groups =,@{ Bottom = $Bottom; Top = $Top; Rows = $_ }
      } else {
        $Bottom = $_ - $Range
        $Top = $_ + $Range
        if ($Top -gt $EndOfFile) { $Top = $EndOfFile }

        # see if item's range overlaps with previous
        # "Previous top: " + $Groups[$Groups.Count].Top
        if ($Bottom -le $Groups[$Groups.Count - 1].Top) {
          $Groups[$Groups.Count - 1].Top = $Top
          [int[]]$R = $Groups[$Groups.Count - 1].Rows
          $Groups[$Groups.Count - 1].Rows = $R +,$_
          # $Groups[$Groups.Count-1].Rows = $Groups[$Groups.Count-1].Rows + ,$_
        } else {
          $Groups = $Groups +,@{ Bottom = $Bottom; Top = $Top; Rows = $_ }
        }
      }
    }
    # return info
    $Groups
  }
}
#endregion


#region Functions: Show-IHIFileLineRange, Display-NormalLine, Display-LineWithHighLightText

<#
.SYNOPSIS
Displays a range of lines from a file, including highlighting matches
.DESCRIPTION
Displays a range of lines from a file, including highlighting matches.
.PARAMETER FileContent
Content of file in string array
.PARAMETER MatchingText
Text to highlight
.PARAMETER FirstLine
First line number of range to show
.PARAMETER LastLine
Last line number of range to show
.PARAMETER MatchingLines
Array containing line numbers of all matches
.PARAMETER NoColors
Don't display matching text in special color
#>
function Show-IHIFileLineRange {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$FileContent,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$MatchingText,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [int]$FirstLine,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [int]$LastLine,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [int[]]$MatchingLines,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$NoColors
  )
  process {
    for ([int]$Index = $FirstLine; $Index -le $LastLine; $Index++) {
      # if this line does NOT have the matching text (if it's not in the
      # $MatchingLines list) then display normally (no highlighting)
      # also, if $NoColors is true, then display normally (no highlighting)
      if ($MatchingLines -notcontains $Index -or $NoColors) {
        # display line with no highlighting
        Display-NormalLine -Line $FileContent[($Index - 1)] -LineNumber $Index
      } else {
        # display line with highlighting
        Display-LineWithHighLightText -Line $FileContent[$Index - 1] -MatchingText $MatchingText -LineNumber $Index
      }
    }
  }
}

<#
.SYNOPSIS
Displays a single line of text with a prefix including the line number
.DESCRIPTION
Displays a single line of text with a prefix including the line number
.PARAMETER Line
Line to display
.PARAMETER LineNumber
Line number of line - used in prefix
#>
function Display-NormalLine {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$Line,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [int]$LineNumber
  )
  #endregion
  process {
    # trim spaces before doing anything
    $Line = $Line.Trim()
    # put prefix in front of line
    [string]$Prefix = $LineNumber.ToString().PadRight(4) + ": "
    $Prefix + $Line
  }
}

<#
.SYNOPSIS
xxxx
.DESCRIPTION
xxxx
.PARAMETER xxxx
xxxx
.PARAMETER xxxx
xxxx
.PARAMETER Range
xxxx
#>
function Display-LineWithHighLightText {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Line,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$MatchingText,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [int]$LineNumber
  )
  process {
    # trim spaces before doing anything
    $Line = $Line.Trim()

    # write line prefix
    [string]$Prefix = $LineNumber.ToString().PadRight(4) + ": "
    Write-Host $Prefix -NoNewline
    # [string]$DebugInfo = "`n"

    # use lower case when comparing text (or won't match)
    [string]$LineLower = $Line.ToLower()
    [string]$MatchingTextLower = $MatchingText.ToLower()
    # also, unescape double \
    $MatchingTextLower = $MatchingTextLower.Replace("\\","\")

    [int]$MatchingTextLength = $MatchingTextLower.Length
    [int]$DisplayIndex = 0
    [int]$IndexOfMatch = $LineLower.IndexOf($MatchingTextLower,$DisplayIndex)
    while ($IndexOfMatch -gt -1) {
      # $DebugInfo = $DebugInfo + "DisplayIndex1: $DisplayIndex `n"
      # $DebugInfo = $DebugInfo + "IndexOfMatch1: $IndexOfMatch `n"

      # write text that appears before the match, if any
      if ($DisplayIndex -lt $IndexOfMatch) {
        Write-Host $Line.Substring($DisplayIndex,$IndexOfMatch - $DisplayIndex) -NoNewline
      }
      # update the display index
      $DisplayIndex = $IndexOfMatch
      # $DebugInfo = $DebugInfo + "DisplayIndex2: $DisplayIndex `n"

      # now display the matching text
      Write-Host $Line.Substring($DisplayIndex,$MatchingTextLength) -NoNewline -ForegroundColor Yellow

      # update the display index
      $DisplayIndex = $DisplayIndex + $MatchingTextLength
      # $DebugInfo = $DebugInfo + "DisplayIndex3: $DisplayIndex `n"

      # update search index
      $IndexOfMatch = $LineLower.IndexOf($MatchingTextLower,$DisplayIndex)
      # $DebugInfo = $DebugInfo + "IndexOfMatch2: $IndexOfMatch `n`n"
    }

    # if there's more text after the last match to display, do it
    if ($DisplayIndex -lt $Line.Length) {
      Write-Host $Line.Substring($DisplayIndex) -NoNewline
    }
    # last but not least, write a new line character
    Write-Host ""
    # Write-Host "`n" + $DebugInfo
  }
}

#endregion
