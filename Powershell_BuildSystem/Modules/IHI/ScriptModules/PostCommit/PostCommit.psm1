#region Module initialize 
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
    # globally-scoped variables are passed into post-commit system
    # (in order to be passed, they must be globally scoped)

    # root temporary folder used for individual post-commit processing;
    # exported application config files are put here, etc.
    [string]$global:RootPostCommitFolder = ""

    # application 'match' information compiled from all application configs
    # found in /trunk/PowerShell3/Main/BuildDeploy/Configs
    # includes application name, file name (and full name), notification emails
    # and source paths from Export-IHIRepositoryContent statements
    [hashtable]$global:AppConfigXmlMatchData = @{}

    # repository version change number
    [int]$global:Version = 0
    # account/domain name of user committing change
    [string]$global:AuthorAccount = $null
    # commit datetime string (from svnlook)
    [string]$global:CommitDateText = $null
    # CommitDateText converted to DateTime object
    $global:CommitDate = $null
    # log message supplied to user during commit
    [string]$global:CommitLog = $null
    # list of files changed during commit
    $global:FilesChanged = $null
    # information from FilesChanged, processed (ChangeType spelled out in a
    # separate field, file name with extra / prefix)
    [System.Collections.Hashtable[]]$global:FilesChangedDetails = $null

    # unique list of directories changed (if multiple files in same folder, 
    # folder only appears once)
    $global:DirsChanged = $null

    # unique list of file extensions of files in commit
    [string[]]$global:FileExtensions = $null

    # list of applications (from AppConfigXmlMatchData) that match committed data
    [string[]]$global:AffectedApplications = $null
    # unique list of email addresses across all AffectedApplications
    [string[]]$global:ChangeNotificationEmails = $null
  }
}
# initialize/reset the module
Initialize
# ensure best practices for variable use, function calling, null property access, etc.
# must be done at module script level, not inside Initialize, or will only be function scoped
Set-StrictMode -Version 2
#endregion


#region Functions: Get-IHIChangeNotificationEmailBodyText

<#
.SYNOPSIS
Returns HTML email body text for change notification emails
.DESCRIPTION
Returns HTML email body text for change notification emails.  This
function must be exported as it is used inside the task-based xml.
.PARAMETER Version
Version of repository change
.PARAMETER ApplicationNames
List of application names affected by change; could be empty
.PARAMETER AuthorAccount
Name of user that committed files
.PARAMETER CommitDate
DateTime of commit
.PARAMETER CommitLog
Commit message from user; could be empty
.PARAMETER FilesChangedDetails
Details about files changed (type of change, name, path, etc.)
.EXAMPLE
Get-IHIChangeNotificationEmailBodyText 1111 SPRINGS dward (Get-Date) $FilesChanged
#>
function Get-IHIChangeNotificationEmailBodyText {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [int]$Version,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$ApplicationNames,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$AuthorAccount,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [System.DateTime]$CommitDate,
    [string]$CommitLog,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [System.Collections.Hashtable[]]$FilesChangedDetails
  )
  #endregion
  process {
    [System.Text.StringBuilder]$Body = New-Object System.Text.StringBuilder
    $Body.Append("<HTML>`n") > $null
    $Body.Append("<HEAD>`n") > $null
    $Body.Append("<STYLE>`n") > $null
    $Body.Append("  body {`n") > $null
    $Body.Append("    font-family: Verdana;`n") > $null
    $Body.Append("    font-size: 10pt;`n") > $null
    $Body.Append("  }`n") > $null
    $Body.Append("  table {`n") > $null
    $Body.Append("   width: 750px;`n") > $null
    $Body.Append("  }`n") > $null
    $Body.Append("  table .log {`n") > $null
    $Body.Append("  }`n") > $null
    $Body.Append("  tr {`n") > $null
    $Body.Append("    padding:0px;`n") > $null
    $Body.Append("  }`n") > $null
    $Body.Append("  td {`n") > $null
    $Body.Append("    padding: 5px;`n") > $null
    $Body.Append("    font-size: 10pt;`n") > $null
    $Body.Append("  }`n") > $null
    $Body.Append("  .log td {`n") > $null
    $Body.Append("    padding: 5px;`n") > $null
    $Body.Append("    font-size: 9pt;`n") > $null
    $Body.Append("    border-right:1px solid #000000;`n") > $null
    $Body.Append("    border-bottom:1px solid #000000;`n") > $null
    $Body.Append("  }`n") > $null
    $Body.Append("  th {`n") > $null
    $Body.Append("   border-top:1px solid #000000;`n") > $null
    $Body.Append("   border-right:1px solid #000000;`n") > $null
    $Body.Append("   border-bottom:1px solid #000000;`n") > $null
    $Body.Append("   padding: 5px;`n") > $null
    $Body.Append("   font-size:10pt;`n") > $null
    $Body.Append("   font-weight: bold;`n") > $null
    $Body.Append("   text-align: left;`n") > $null
    $Body.Append("  }`n") > $null
    $Body.Append("  .shaded {`n") > $null
    $Body.Append("   background-color: #cccccc;`n") > $null
    $Body.Append("  }`n") > $null
    $Body.Append("  .first {`n") > $null
    $Body.Append("   border-left:1px solid #000000;`n") > $null
    $Body.Append("   width: 20%;`n") > $null
    $Body.Append("  }`n") > $null
    $Body.Append("  h1 {`n") > $null
    $Body.Append("    font-size: 11pt;`n") > $null
    $Body.Append("    font-weight: bold;`n") > $null
    $Body.Append("    margin:0;`n") > $null
    $Body.Append("  }`n") > $null
    $Body.Append("  .label {`n") > $null
    $Body.Append("    font-weight: bold;`n") > $null
    $Body.Append("    text-align: left;`n") > $null
    $Body.Append("   width: 20%;`n") > $null
    $Body.Append("  }`n") > $null
    $Body.Append("</STYLE>`n") > $null

    $Body.Append("</HEAD>`n") > $null
    $Body.Append("<BODY>`n") > $null

    $Body.Append("<TABLE cellpadding='0' cellspacing='0'>`n") > $null

    $Body.Append("<TR>`n") > $null
    if ($ApplicationNames -ne $null) {
      $Body.Append("  <TD colspan=2 class='shaded'><h1>" + "$ApplicationNames" + " source change on " + $CommitDate.DayOfWeek + " " + $CommitDate.ToString("G") + "</h1></TD>`n") > $null
    } else {
      $Body.Append("  <TD colspan=2 class='shaded'><h1>Source change on " + $CommitDate.DayOfWeek + " " + $CommitDate.ToString("G") + "</h1></TD>`n") > $null
    }
    $Body.Append("</TR>`n") > $null

    $Body.Append("<TR>`n") > $null
    $Body.Append("  <TD class='label'>" + "User:" + "</TD>`n") > $null
    $Body.Append("  <TD>" + $AuthorAccount + "</TD>`n") > $null
    $Body.Append("</TR>`n") > $null

    $Body.Append("<TR>`n") > $null
    $Body.Append("  <TD class='label' valign='top'>" + "Commit Log:" + "</TD>`n") > $null

    # if no commit log, display ugly red text to call out the user
    if ($CommitLog -eq $null -or $CommitLog.Trim() -eq "") {
      $Body.Append("  <TD>" + "<font color='red'>No commit comments! Bad user!</font>" + "</TD>`n") > $null
    } else {
      $Body.Append("  <TD>" + $CommitLog + "</TD>`n") > $null
    }
    $Body.Append("</TR>`n") > $null

    $Body.Append("<TR>`n") > $null
    $Body.Append("  <TD class='label'>" + "Revision:" + "</TD>`n") > $null
    $Body.Append("  <TD>" + $Version + "</TD>`n") > $null
    $Body.Append("</TR>`n") > $null

    $Body.Append("<TR>`n") > $null
    $Body.Append("  <TD class='label'>" + "Repository root:" + "</TD>`n") > $null
    $Body.Append("  <TD>" + $Ihi:BuildDeploy.SvnMain.RepositoryRootUrl + "</TD>`n") > $null
    $Body.Append("</TR>`n") > $null

    $Body.Append("</TABLE>`n") > $null

    $Body.Append("<BR/>`n") > $null

    $Body.Append("<TABLE cellpadding='0' cellspacing='0' class='log'>`n") > $null

    $Body.Append("<TR>`n") > $null
    $Body.Append("  <TH class='first'>" + "Change Type" + "</TH>`n") > $null
    $Body.Append("  <TH>" + "Diff" + "</TH>`n") > $null
    $Body.Append("  <TH>" + "File" + "</TH>`n") > $null
    $Body.Append("</TR>`n") > $null

    $FilesChangedDetails | ForEach-Object {
      $Body.Append("<TR>`n") > $null
      $Body.Append("  <TD class='first'>" + $_.ChangeType + "</TD>`n") > $null
      if ($_.ChangeType.ToUpper() -eq "UPDATED") {
        $Body.Append("  <TD>" + "<a href='IHIDiff:@" + $Ihi:BuildDeploy.SvnMain.RepositoryRootUrl + "/" + $_.FileName + "@" + $Version + "@END'>Diff</a>" + "</TD>`n") > $null
      } else {
        $Body.Append("  <TD>" + "&nbsp;" + "</TD>`n") > $null
      }
      $Body.Append("  <TD>" + $_.FileName + "</TD>`n") > $null
      $Body.Append("</TR>`n") > $null
    }

    $Body.Append("</TABLE>`n") > $null

    $Body.Append("<BR/>`n") > $null
    $Body.Append("Is the Diff link not working for you?  Check out these <a href='http://rnet/departments/engineering/is/IHI%20Build%20Wiki/Email%20Notification%20Diff.aspx'>installation notes</a>.`n") > $null

    $Body.Append("</BODY>`n") > $null
    $Body.Append("</HTML>`n") > $null
    $Body.ToString()
  }
}
Export-ModuleMember -Function Get-IHIChangeNotificationEmailBodyText
#endregion


#region Functions: Export-ApplicationConfigFiles, Analyze-ApplicationConfigFiles
# HL 10/10/2014: Commenting these functions out as they have been created in BuildDeploy\Common.psm1 as
#         Export-IHIApplicationConfigFiles
#         Analyze-IHIApplicationConfigFiles
#      Replacements elsewhere in this file have been made. Keeping them for the moment as a safety net
#<#
#.SYNOPSIS
#Exports application configuration files to local temp folder
#.DESCRIPTION
#Exports application configuration files to local temp folder
##>
#function Export-ApplicationConfigFiles {
#  #region Function parameters
#  [CmdletBinding()]
##  param()
#  #endregion
#  process {
#    #region Export application config files
#    Write-Host "Fetching latest application config files from the repository"
#    Add-IHILogIndentLevel
#    Export-IHIRepositoryContent -Version $Version -UrlPath $Ihi:BuildDeploy.ApplicationConfigsRootUrlPath -LocalPath $RootPostCommitFolder
#    Remove-IHILogIndentLevel
#    #endregion
#  }
#}
#
#<#
#.SYNOPSIS
#Analyzes application configuration files for source paths and notification emails
#.DESCRIPTION
#Analyzes application configuration files for source paths and notification emails
##>
#function Analyze-ApplicationConfigFiles {
#  #region Function parameters
#  [CmdletBinding()]
#  param()
#  #endregion
#  process {
#    #region Parse application config files for SVN path and notification email information
#    Write-Host "Parse application files for SVN path and notification email information"
#    $ConfigFiles = Get-ChildItem -Path $RootPostCommitFolder -Recurse -Filter *.xml
#    $ConfigFiles | ForEach-Object {
#      $FileContent = Get-Content -Path $_.FullName
#      if ($FileContent -match 'Export-IHIRepositoryContent') {
#        [hashtable]$MatchInfo = @{}
#        $MatchInfo.ApplicationName = $_.BaseName.ToUpper()
#        $MatchInfo.FileName = $_.Name
#        $MatchInfo.FileFullName = $_.FullName
#        [string[]]$MatchingPaths = $FileContent | Select-String -Pattern 'Export-IHIRepositoryContent.*' -AllMatches | ForEach-Object {
#          $_.matches | ForEach-Object {
#            $MatchingTextLine = $_.value
#            $MatchingTextLine -match '"(/trunk.*)" ' > $null
#            $matches[1]
#          }
#        }
#        $MatchInfo.MatchingPaths = $MatchingPaths
#        [xml]$ContentXml = [xml]$FileContent
#        $MatchInfo.NotificationEmails = [string[]]($ContentXml.Application.General.NotificationEmails.Email | ForEach-Object { $_ })
#        $global:AppConfigXmlMatchData.$($MatchInfo.ApplicationName) = $MatchInfo
#      }
#    }
#   #endregion
#  }
#}
#endregion


#region Functions: Convert-SvnLookDateTextToDate, Get-SvnLookCommitInformation

<#
.SYNOPSIS
Converts $CommitDateText to a DateTime object and stores in $CommitDate
.DESCRIPTION
Converts $CommitDateText to a DateTime object and stores in $CommitDate
#>
function Convert-SvnLookDateTextToDate {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    #region Change commit date text to actual datetime from string and store
    Add-IHILogIndentLevel
    Write-Host "Change commit date text to actual datetime from string"
    # Format of $CommitDateText from SVN look will be in format like: 
    #   2009-10-23 13:00:51 -0400 (Fri, 23 Oct 2009)
    # A datetime value can be easily created by taking the date and time value (everything 
    # before -400, so everything before the second space
    # first get index of first space
    [int]$SpaceIndex = $CommitDateText.IndexOf(" ")
    # now get index of second space
    $SpaceIndex = $CommitDateText.IndexOf(" ",$SpaceIndex + 1)
    # get only text before second space
    $CommitDateText = $CommitDateText.Substring(0,$SpaceIndex)
    # now get as date time
    $global:CommitDate = Get-Date $CommitDateText
    Remove-IHILogIndentLevel
    #endregion
  }
}


<#
.SYNOPSIS
Acquires commit information from Subversion for Version and stores.
.DESCRIPTION
Acquires commit information from Subversion repository and stores the information
in pre-existing variables.  Calls svnlook.exe utility Version number, which retrives
the author, date (text), commit log, file change info and directory change info, and 
stores these in global (module-level) variables.
#>
function Get-SvnLookCommitInformation {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    # To run test builds on a developer machine, comment out the region 
    # below (Get... from Subversion repository) and uncomment the Overrides region.

    #region Get information about version commit from Subversion repository
    Write-Host "Get information about version $Version commit from Subversion repository"
    # get author
    $global:AuthorAccount = & $Ihi:Applications.Repository.SubversionLookUtility "author" $RepositoryPath "--revision" $Version
    $global:CommitDateText = & $Ihi:Applications.Repository.SubversionLookUtility "date" $RepositoryPath "--revision" $Version

    # CommitLog might be a string or an object[], depending if multiple lines were in commmit log.
    # If multiple lines, combine into a string separated with <BR/> so email is pretty
    $CommitLogTemp = & $Ihi:Applications.Repository.SubversionLookUtility "log" $RepositoryPath "--revision" $Version
    if ($CommitLogTemp -isnot [string]) {
      [string]$global:CommitLog = [string]($CommitLogTemp -join "<br />")
    } else {
      [string]$global:CommitLog = $CommitLogTemp
    }

    $global:FilesChanged = & $Ihi:Applications.Repository.SubversionLookUtility "changed" $RepositoryPath "--revision" $Version
    $global:DirsChanged = & $Ihi:Applications.Repository.SubversionLookUtility "dirs-changed" $RepositoryPath "--revision" $Version
    #endregion
    <#
    #region Overrides for development purposes
    # these are the actual svnlook values taken from commit 10669
    # providing these values allows development/maintenance of script on developer 
    # machines without having to develop on the SVN server
    $global:Version        = 10669
    $global:AuthorAccount  = "dward"
    $global:CommitDateText = "2012-01-23 11:00:51 -0500 (Mon, 23 Jan 2012)"
    $global:CommitLog      = "removed DEVWEB01 and DEVGP01 from PowerShell framework; servers are no longer used..."
    $global:FilesChanged   = "U   trunk/PowerShell3/Main/BuildDeploy/Configs/ServerSetup/PowerShell.xml",
                             "U   trunk/PowerShell3/Main/BuildDeploy/Configs/ServerSetup/SVRUtil_ServiceRestart.xml",
                             "U   trunk/PowerShell3/Main/Modules/IHI/ScriptModules/DeveloperTools/Shortcuts.psm1",
                             "U   trunk/PowerShell3/Main/Set-IHIIhiDriveSettings.ps1"
    $global:DirsChanged    = "trunk/PowerShell3/Main/",
                             "trunk/PowerShell3/Main/BuildDeploy/Configs/ServerSetup/",
                             "trunk/PowerShell3/Main/Modules/IHI/ScriptModules/DeveloperTools/"
    #endregion
#>
  }
}
#endregion


#region Functions: Convert-SvnLookFilesChangedToFilesChangedDetails

<#
.SYNOPSIS
Processes $FilesChanged data, splits up into usable $FilesChangedDetails
.DESCRIPTION
Processes $FilesChanged data, splits up into usable $FilesChangedDetails.  This
includes getting the readable change type text, the file name and the extension
and storing all this in a hash table.
#>
function Convert-SvnLookFilesChangedToReadable {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    #region Convert array of strings FilesChanged to objects with expanded values
    Write-Host "Convert array of strings FilesChanged to objects with expanded values"
    # $FilesChanged contains an array of strings of the format: "U   trunk/BuildDeploy/Scripts/Build-Application.ps1"
    # convert this to array of hashtables .Type="Update",.File="trunk/BuildDeploy/Scripts/Build-Application.ps1"
    [string]$FileTokenAndChangeToken = $null
    $global:FilesChangedDetails = $FilesChanged | ForEach-Object {
      $FileTokenAndChangeToken = $_
      $FileInfo = @{}
      # get changed type text passing first two characters (changed token)
      $FileInfo.ChangeType = Get-IHIRepositoryFileChangedText $FileTokenAndChangeToken.Substring(0,2)
      # when adding file name, put "/" prefix as svn look does not report that initial charcter
      $FileInfo.FileName = "/" + $FileTokenAndChangeToken.Substring(4)

      # now get the file extension and store in Extension
      # get index of last . in path
      $LastDotIndex = $FileInfo.FileName.LastIndexOf(".")
      # get index of last / in path
      $LastSlashIndex = $FileInfo.FileName.LastIndexOf("/")
      # if dot not found or / is greater than . (meaning it was a file without an extension or a folder) then skip
      if (!($LastDotIndex -eq -1 -or $LastSlashIndex -gt $LastDotIndex)) {
        $FileInfo.Extension = $FileInfo.FileName.Substring($LastDotIndex).ToLower()
      } else {
        # if no extension, store null for it
        $FileInfo.Extension = $null
      }
      # now return $FileInfo object to be added to FilesChangedDetails
      $FileInfo
    }
    #endregion
  }
}
#endregion


#region Functions: Write-LogCommitInformation

<#
.SYNOPSIS
Logs parsed commit information
.DESCRIPTION
Logs parsed commit information
#>
function Write-LogCommitInformation {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    #region Output commit information
    Write-Host ""
    Write-Host "Commit information:"
    Add-IHILogIndentLevel
    $ColumnDef = "{0,-21} : {1}"
    Write-Host ($ColumnDef -f "User",$AuthorAccount)
    Write-Host ($ColumnDef -f "Date",$CommitDate.ToString("G"))
    # if commit log contains multiple lines, then $CommitLog will be an
    # array of objects so use string expansion
    Write-Host ($ColumnDef -f "Log",($("$CommitLog")))
    Write-Host "Files changed:"
    $FilesChangedDetails | ForEach-Object {
      Write-Host ("  {0,-19} : {1} : {2}" -f $_.ChangeType,$_.FileName,$_.Extension)
    }
    Write-Host "Directories changed:"
    $DirsChanged | ForEach-Object {
      Write-Host ($ColumnDef -f "",$_)
    }
    Write-Host ($ColumnDef -f "FileExtensions",$("$FileExtensions"))
    Remove-IHILogIndentLevel
    Write-Host ""
    #endregion
  }
}
#endregion


#region Functions: Get-FileExtensionsFromFilesChangedDetails

<#
.SYNOPSIS
Parses FilesChangedDetails to get unique list of file extensions
.DESCRIPTION
Parses FilesChangedDetails to get unique list of file extensions.  This will
make certain post-processing (in tasks) easier by having an array of extensions
for a quick contains comparison.
#>
function Get-FileExtensionsFromFilesChangedDetails {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    #region Get list of unique file extensions
    Write-Host "Get list of unique file extensions"
    # first get all file extensions
    $global:FileExtensions = $FilesChangedDetails | ForEach-Object { $_.Extension }
    # now make sure the values are sorted and unique
    $global:FileExtensions = $FileExtensions | Sort-Object | Select-Object -Unique
    #endregion
  }
}
#endregion


#region Functions: Find-ApplicationMatches, Send-ChangeNotificationEmail, Invoke-TestBuilds

<#
.SYNOPSIS
Look through AppConfigXmlMatchData, compare to commit info to find matches
.DESCRIPTION
Look through AppConfigXmlMatchData, compare to commit info to find matches
#>
function Find-ApplicationMatches {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    #region Find matching applications affected by commit
    Write-Host "Find matching applications affected by commit"
    # loop through each app config
    # for each app, get regex that combines all MatchingPaths
    # for each committed file, see if it matches
    $global:AffectedApplications = $AppConfigXmlMatchData.Keys | ForEach-Object {
      $AppToCheck = $global:AppConfigXmlMatchData.$_
      $ConfigMatchRegex = $AppToCheck.SVNProjectPaths -join "|"
      $MatchFound = $false
      $FilesChangedDetails | ForEach-Object {
        if ($_.FileName -match $ConfigMatchRegex) { $MatchFound = $true }
      }
      if ($MatchFound -eq $true) { $AppToCheck.ApplicationName }
    }
    # if affected application, sort and log
    Add-IHILogIndentLevel
    $ColumnDef = "{0,-21} : {1}"
    if ($null -ne $AffectedApplications -and $AffectedApplications.Count -gt 0) {
      # sort the applications
      $global:AffectedApplications = $AffectedApplications | Sort-Object
      Write-Host ($ColumnDef -f "AffectedApplications",$("$AffectedApplications"))
    } else {
      Write-Host ($ColumnDef -f "AffectedApplications","None")
    }
    Remove-IHILogIndentLevel
    #endregion
  }
}

<#
.SYNOPSIS
Sends notification email to folks affected by commit
.DESCRIPTION
Sends notification email to folks affected by commit
#>
function Send-ChangeNotificationEmail {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    #region Send notification emails
    Write-Host "Send notification emails"
    Add-IHILogIndentLevel
    # if applications have been identified then email the folks associated with those applications
    if ($null -ne $AffectedApplications -and $AffectedApplications.Count -gt 0) {
      # first get all notification emails then sort|unique after
      $global:ChangeNotificationEmails = $AffectedApplications | ForEach-Object { $global:AppConfigXmlMatchData.$_.NotificationEmails }
      $global:ChangeNotificationEmails = $ChangeNotificationEmails | Sort-Object | Select-Object -Unique

      #region Send application change notification email to application owners
      [string]$Body = Get-IHIChangeNotificationEmailBodyText $Version $AffectedApplications $AuthorAccount $CommitDate $CommitLog $FilesChangedDetails
      [string]$Subject = "Repository change $Version by $AuthorAccount affects: $AffectedApplications"
      Add-IHILogIndentLevel
      Write-Host "Notifying: $ChangeNotificationEmails"
      Remove-IHILogIndentLevel
      try {
        Send-IHIMailMessage -To $ChangeNotificationEmails -Subject $Subject -Body $Body -From "RepoChange@ihi.org"
      } catch {
        Write-Host "Error occurred during send email: $_"
      }

      #endregion
    } else {
      # if no application matches, send a generic email to build managers
      #region Send generic change notification email to build managers
      [string]$Body = Get-IHIChangeNotificationEmailBodyText $Version $null $AuthorAccount $CommitDate $CommitLog $FilesChangedDetails
      [string]$Subject = "Repository change $Version by $AuthorAccount - no applications"
      try {
        Send-IHIMailMessage -To $Ihi:BuildDeploy.ErrorNotificationEmails -Subject $Subject -Body $Body -From "RepoChange@ihi.org"
      } catch {
        Write-Host "Error occurred during send email: $_"
      }
      #endregion
    }
    Remove-IHILogIndentLevel
    #endregion
  }
}

<#
.SYNOPSIS
Invoke test builds, if any affected applications
.DESCRIPTION
Invoke test builds, if any affected applications
#>
function Invoke-TestBuilds {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    #region Test builds of applications  
    if ($null -ne $AffectedApplications -and $AffectedApplications.Count -gt 0) {
      Write-Host ""
      Write-Host "Testing builds of applications for errors"
      Add-IHILogIndentLevel
      # test build each application
      $AffectedApplications | ForEach-Object {
        Write-Host "Launch test build of $_ $Version"
        try {
          $ScriptBlockString = "Invoke-Expression $PSHome\Microsoft.PowerShell_profile.ps1 ; Invoke-IHIBuildCode -ApplicationName $_ -Version $Version -LaunchUserName '$AuthorAccount (commit)' -TestBuild"
          $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlockString)
          Start-Job -ScriptBlock $ScriptBlock | Wait-Job | Remove-Job
        } catch {
          Write-Host "`nAn exception occurred while running Start-Job Invoke-IHIBuildCode"
          Write-Host "`nException:`n"
          $_ | Write-Host
        }
        Add-IHILogIndentLevel
        Write-Host "Build complete"
        Remove-IHILogIndentLevel
      }
      Remove-IHILogIndentLevel
    }
    #endregion
  }
}
#endregion


#region Functions: Invoke-PostCommitTaskList

<#
.SYNOPSIS
Loads and invokes post-commit task list
.DESCRIPTION
Loads and invokes post-commit task list stored in hooks folder
#>
function Invoke-PostCommitTaskList {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    #region Load and run post-commit task processing
    # post commit task xml file is located in the hooks folder; get root path from ihidrive
    $script:TaskFile = Join-Path -Path $($Ihi:BuildDeploy.SvnMain.RepositoryRootFolder) -ChildPath "hooks\PostCommit-TaskList.xml"
    Write-Host ""
    Write-Host "Load and run post-commit task processing"
    Add-IHILogIndentLevel
    Write-Host "Read xml from task file: $TaskFile"
    [xml]$TaskXml = [xml](Get-Content -Path $TaskFile)
    Write-Host "Initialize-IHITaskProcessModule with content"
    Initialize-IHITaskProcessModule -TaskProcessXml $TaskXml.PostCommitTasks.TaskProcess
    Write-Host "Invoke-IHITaskProcess"
    Invoke-IHITaskProcess
    Remove-IHILogIndentLevel
    #endregion
  }
}
#endregion


#region Functions: Invoke-IHIRepositoryPostCommitHandling

<#
.SYNOPSIS
Runs repository post-commit handling for a specific commit
.DESCRIPTION
Runs repository post-commit handling for a specific commit to the repository.
This may include sending notification emails and runs test builds and may include
task steps in a post-commit xml file.  The process looks through all application
configuration files located in /trunk/PowerShell3/Main/BuildDeploy/Configs to
see if any of the source paths (exported from the repository) match this 
particular commit.  If so, individuals listed in the notification emails are
emailed with a change email and a test build of the build is run.  In addition,
the post-commit task xml file is loaded and processed, which may contain 
additional processing/validation steps.
.PARAMETER RepositoryPath
Name of database server
.PARAMETER Version
Name of database instance
.EXAMPLE
Invoke-IHIRepositoryPostCommitHandling D:\SourceControl\SVN\ihi_main 10709
Runs post-commit handling for change version 10709.  Sends out change 
notification emails and runs test builds, if necessary, along with task steps
in post-commit xml file.
#>
function Invoke-IHIRepositoryPostCommitHandling {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryPath,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [int]$Version
  )
  #endregion
  process {
    # make sure module global variables are initialized
    Initialize
    # make sure loggging enabled from very beginning; use default framework logfile location
    
    if ($false -eq (Test-Path -Path $Ihi:Folders.LogfilesFolder)){
        $LogfilesFolderResults = New-Item -Path $Ihi:Folders.LogfilesFolder -ItemType Directory 2>&1
        if ($? -eq $false) {
          Write-Host "$($MyInvocation.MyCommand.Name):: error occurred creating $Ihi:Folders.LogfilesFolder :: $("$LogfilesFolderResults")"
          return
        }
    }
    Enable-IHILogFile -LogPath $Ihi:Folders.LogfilesFolder

    #region Parameter validation
    #region Make sure SVN look utility found on machine (build/Subversion server)
    if ($Ihi:Applications.Repository.SubversionLookUtility -eq $null -or !(Test-Path -Path $Ihi:Applications.Repository.SubversionLookUtility)) {
      [string]$ErrorMsg = "$($MyInvocation.MyCommand.Name):: path for svnlook.exe is null or bad; this function should only be run on the build server: $($Ihi:Applications.Repository.SubversionLookUtility)"
      # write to both so logged to help debug error
      Write-Error -Message $ErrorMsg
      Write-Host $ErrorMsg
      Disable-IHILogFile
      return
    }
    #endregion

    #region Make sure RepositoryPath found on machine
    if ($false -eq (Test-Path -Path $RepositoryPath)) {
      [string]$ErrorMsg = "$($MyInvocation.MyCommand.Name):: RepositoryPath not found on machine; this function should only be run on the build server: $RepositoryPath"
      # write to both so logged to help debug error
      Write-Error -Message $ErrorMsg
      Write-Host $ErrorMsg
      Disable-IHILogFile
      return
    }
    #endregion
    #endregion

    # make sure version is stored in global context
    $global:Version = $Version

    #region Write basic into to log
    Write-Host ""
    Write-Host "Invoke-IHIRepositoryPostCommitHandling called with:"
    Write-Host "  RepositoryPath: $RepositoryPath"
    Write-Host "  Version:        $Version"
    #endregion

    #region Create temporary folder used for single commit processing
    #region Temporary folder name description
    # When running the post-commit system, especially during development with the old and new system
    # running simultaneously, there is a great tendency for builds to be started at the same time.
    # The _exact_ same time - meaning datetime stamps are not unique, even if you use up to ten
    # thousandths of a second.
    # So, to ensure that we do not have a conflict:
    #  - use the process id in the folder name
    #  - use the process id as the seed value in an Get-Random call with a large max value
    #  - check to see if a folder with that pid and random number exist
    #  - if no folder, then create else loop, generate new random number and try again
    #  - BUT... if try 20 times and still can't find a new folder name, exit the script with error.
    #endregion
    Write-Host "Create temporary folder for post-commit processing/temporary files"
    [string]$RootPostCommitFolderPrefix = Join-Path -Path $($Ihi:Folders.TempFolder) -ChildPath $("PostCommit\{0}" -f $pid)
    Write-Host "RootPostCommitFolderPrefix = $RootPostCommitFolderPrefix"
    [int]$loopCounter = 0
    do {
      if ($loopCounter -le 20) {
      $loopCounter++
      Write-Host "Temp Folder Loop: $loopCounter"
      $global:RootPostCommitFolder = $RootPostCommitFolderPrefix + "_" + (Get-Random -Minimum 1 -Maximum 99999 -SetSeed $pid)
      Write-Host "Testing Folder Existance: $global:RootPostCommitFolder"
      }
      else  {
      Write-Host "$($MyInvocation.MyCommand.Name):: exceeded 20 tries to create post-commit root folder."
      Disable-IHILogFile; return
      }
    } while ($true -eq (Test-Path -Path $global:RootPostCommitFolder))
    # create new root folder
    Add-IHILogIndentLevel
    Write-Host "Folder: $global:RootPostCommitFolder"
    Remove-IHILogIndentLevel
    $Results = New-Item -Path $global:RootPostCommitFolder -ItemType Directory 2>&1
    if ($? -eq $false) {
      Write-Host "$($MyInvocation.MyCommand.Name):: error occurred creating post-commit root folder $RootPostCommitFolder :: $("$Results")"
      Disable-IHILogFile; return
    }
    #endregion

    #region Export application config files and analyze
    Export-IHIApplicationConfigFiles -LocalExportPath $global:RootPostCommitFolder
    $global:AppConfigXmlMatchData = Analyze-IHIApplicationConfigFiles -LocalApplicationConfigsPath $global:RootPostCommitFolder
    #endregion 

    #region Acquire and process commit information
    # get information from repository (also contains override for local development)
    Get-SvnLookCommitInformation
    # convert weird date text to date object
    Convert-SvnLookDateTextToDate
    # convert array of single strings to hashtables with broken out fields of information
    Convert-SvnLookFilesChangedToReadable
    # get unique list of file extensions affected by commit
    Get-FileExtensionsFromFilesChangedDetails
    # write information to log
    Write-LogCommitInformation
    #endregion

    #region Find applications affected by commit, email and test build
    # find applications that match commit information
    Find-ApplicationMatches
    # send emails to folks affected by change
    Send-ChangeNotificationEmail
    # invoke test builds, if any
    Invoke-TestBuilds
    #endregion

    #region Load and run post-commit task processing
    Invoke-PostCommitTaskList
    #endregion

    #region Remove temporary folder
    Write-Host "Remove temp folder"
    $Results = Remove-Item -Path $RootPostCommitFolder -Recurse -Force 2>&1
    if ($? -eq $false) {
      Write-Host "$($MyInvocation.MyCommand.Name):: error removing temporary build folder :: $("$Results")"
      # don't exit or return, that's next step anyway after disable logging...
    }
    #endregion

    #disable logging, we're outta here!
    Disable-IHILogFile
  }
}
Export-ModuleMember -Function Invoke-IHIRepositoryPostCommitHandling
#endregion
