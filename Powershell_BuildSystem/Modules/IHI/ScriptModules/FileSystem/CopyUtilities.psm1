
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


#region Functions: Copy-IHIFileRoboCopy

<#
.SYNOPSIS
Copies files and folders using RoboCopy
.DESCRIPTION
Copies files and folders using RoboCopy; type RoboCopy /? for more info.
IMPORTANT NOTE: if you want to copy an individual file, specify
SourceFolderPath as the folder and FilePattern as the file name; do NOT 
specify the full filepath in SourceFolderPath. Also, do NOT specify 
-Recursive when copying just a file.
.PARAMETER SourceFolderPath
Source FOLDER to copy; if you want to copy an individual file, specify
SourceFolderPath as the folder and FilePattern as the file name.  Also, do NOT
specify /E in the additional params if you are copying just a file.
.PARAMETER DestinationPath
Destination to copy to
.PARAMETER FilePattern
File(s) to copy (names/wildcards: default is "*.*")
.PARAMETER Recursive
Copies full and empty subfolders under SourceFolderPath.  Do not specify
if copying a single file.
.PARAMETER LogFile
Log file for logging all files/folders copied and error information, if any.
.PARAMETER AdditionalRCParams
Additional parameters to pass to RoboCopy when running.  Default values
are /NP (don't show progress), /W:30 (if locked, retry for 30 seconds)
and /R:3 (if /W fails, retry 3 times).  If you specify any values for 
AdditionalRCParams, you will need to pass these values in your list
(if you want them).
DO NOT specify /E or /S to copy subfolders; use the -Recursive parameter
.PARAMETER ShowResults
Outputs RoboCopy results to console window
.EXAMPLE
Copy-IHIFileRoboCopy -SourceFolderPath c:\temp -DestinationPath d:\temp
Copies all files (no subfolders) under c:\temp into d:\temp
.EXAMPLE
Copy-IHIFileRoboCopy -SourceFolderPath c:\temp -DestinationPath d:\temp -Recursive -LogFile c:\CopyLog.txt
Copies all files and subfolders under c:\temp into d:\temp and logs it
.EXAMPLE
Copy-IHIFileRoboCopy -SourceFolderPath c:\temp\folder1 -DestinationPath d:\temp\folder1 -Recursive
Copies an individual folder c:\temp\folder1 to d:\temp
NOTE: RoboCopy does not handle copying an individual folder gracefully; it is
only designed to copy the contents of a folder.  This example copies the contents
of source folder1 into a new destination folder named folder1.  It is for this
reason that -Recursive has to be specified or it will only copy the immediate
contents of source folder1.
.EXAMPLE
Copy-IHIFileRoboCopy -SourceFolderPath c:\temp -DestinationPath d:\temp -FilePattern File1.txt
Copies an individual file c:\temp\File1.txt to d:\temp
Make sure you don't specify -Recurse or File1.txt and everything else will be copied.
.EXAMPLE
Copy-IHIFileRoboCopy -SourceFolderPath c:\temp -DestinationPath d:\temp -FilePattern File1.txt -ShowResults
Copies file c:\temp\File1.txt to d:\temp and shows RoboCopy results
.EXAMPLE
Copy-IHIFileRoboCopy -SourceFolderPath c:\temp -DestinationPath d:\temp -FilePattern *.* -Recursive
Copies all files, recursively
.EXAMPLE
Copy-IHIFileRoboCopy -SourceFolderPath c:\temp -DestinationPath d:\temp -FilePattern File1.txt -AdditionalRCParams ("/NP","/R:3","/W:60")
Copies file c:\temp\File1.txt to d:\temp with 60 second wait, 3 times
#>
function Copy-IHIFileRoboCopy {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceFolderPath,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationPath,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$FilePattern,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$Recursive,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$LogFile,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    # /E param is added if recursive specified
    [string[]]$AdditionalRCParams = ("/NP","/R:3","/W:30"),
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$ShowResults
  )
  #endregion
  process {
    #region Parameter validation
    #region Make sure RoboCopy found on machine
    if ($Ihi:Applications.FileSystem.RoboCopy -eq $null -or !(Test-Path -Path $Ihi:Applications.FileSystem.RoboCopy)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path for RoboCopy is null or bad: $($Ihi:Applications.FileSystem.RoboCopy)"
      return
    }
    #endregion

    #region Confirm source path exists and is a folder
    if ($false -eq (Test-Path -Path $SourceFolderPath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: source folder path is null or bad: $SourceFolderPath"
      return
    }
    if (!(Get-Item -Path $SourceFolderPath).PSIsContainer) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: source folder path must be a folder, not a file ($SourceFolderPath); specify file name in parameter FilePattern"
      return
    }
    #endregion
    #endregion

    #region If specify Recursive, add /E (copy subfolders) to $AdditionalRCParams
    if ($Recursive -eq $true) {
      $AdditionalRCParams += "/E"
    }
    #endregion

    #region Report information before processing files
    # rather than use PSBoundParameters, manually output for better formatting
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "SourceFolderPath",$SourceFolderPath)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "DestinationPath",$DestinationPath)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "FilePattern",$FilePattern)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Recursive",$Recursive)
    if ($LogFile -ne "") { Write-Host $("{0,-$DefaultCol1Width} {1}" -f "LogFile",$LogFile) }
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "AdditionalRCParams",$("$AdditionalRCParams"))
    #endregion

    #region Process files
    Write-Host "Processing..."
    #region Initialize counters and log start time
    [datetime]$StartTime = Get-Date
    # record start time in log for easier review
    if ($LogFile -ne "") {
      [hashtable]$Params2 = @{ InputObject = "Start time: $($StartTime)"; FilePath = $LogFile } + $OutFileSettings
      $Err = $null
      Out-File @Params2 -ErrorVariable Err
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
        return
      }
    }
    #endregion
    #region Run RoboCopy

    #region Common RoboCopy parameter information
    # /NP   No Progress - don't display % copied
    # /S    copy Subdirectories, but not empty ones
    # /E    copy subdirectories, including Empty ones
    # /R:n  number of Retries on failed copies: default 1 million
    # /W:n  Wait time between retries: default is 30 seconds
    # type robocopy /? for more information
    #endregion
    [string]$Cmd = $Ihi:Applications.FileSystem.RoboCopy
    [string[]]$Params = $SourceFolderPath,$DestinationPath
    if ($FilePattern.Trim() -ne "") { $Params += $FilePattern }

    # if additional sql parameters, pass them
    if ($AdditionalRCParams -ne $null) { $Params += $AdditionalRCParams }
    $LastExitCode = 0
    # if logging enabled, record command in log file
    if ($LogFile -ne "") {
      [hashtable]$Params2 = @{ InputObject = "& $Cmd $Params"; FilePath = $LogFile } + $OutFileSettings
      $Err = $null
      Out-File @Params2 -ErrorVariable Err
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
        return
      }
    }
    # process the file
    $Results = & $Cmd $Params 2>&1
    # store so not lost later when using
    $ExitCode = $LastExitCode
    #region Robocopy complaints
    # RoboCopy just has to be different; it returns many postitive int values that
    # indicate status but are not errors
    #   Server 2008 exit codes: http://support.microsoft.com/kb/954404
    # it appears that if the exit code is 8 or higher, there's a problem.
    # Also, RoboCopy sucks; if a file is in use (common on production server) and the retry 
    # limit has been exceeded, it knows this is an error (it outputs information 
    # about it) but returns a 0 exit code.  WHY?!?!?! Morons.
    # This is also true for incorrect paths - NO EXIT ERROR CODE!  MORONS! These
    # are the most common errors!  Ugh.
    # So we need to parse Results looking for error text "ERROR: RETRY LIMIT EXCEEDED"
    # or "The filename, directory name, or volume label syntax is incorrect"
    # (I hope there aren't more situations like this)
    #endregion
    if ($ExitCode -ge 8 -or ($Results -match 'ERROR: RETRY LIMIT EXCEEDED') -or
      ($Results -match 'The filename, directory name, or volume label syntax is incorrect')) {
      # if error occurred, display command to console before error message
      Add-IHILogIndentLevel
      Write-Host "& $Cmd $Params"
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error occurred in RoboCopy with parameters: $("$Cmd $Params") :: $("$Results")"
      # write error message to file then to console
      # if logging enabled, record command in log file
      if ($LogFile -ne "") {
        [hashtable]$Params2 = @{ InputObject = $ErrorMessage; FilePath = $LogFile } + $OutFileSettings
        $Err = $null
        Out-File @Params2 -ErrorVariable Err
        if ($? -eq $false) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
          return
        }
      }
      Write-Error -Message $ErrorMessage
      # get rid of indents if need to exit
      Remove-IHILogIndentLevel; Remove-IHILogIndentLevel
      return
    } else {
      # no error occurred
      # reset value of LastExitCode so outside of this function
      # it is considered success in case someone checks LastExitCode
      $global:LastExitCode = 0
      # if user specified LogFile, store results it in
      if ($LogFile -ne "") {
        # log results
        [hashtable]$Params2 = @{ InputObject = $Results; FilePath = $LogFile } + $OutFileSettings
        $Err = $null
        Out-File @Params2 -ErrorVariable Err
        if ($? -eq $false) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
          return
        }
        # log exit code
        [hashtable]$Params2 = @{ InputObject = "Exit code: $ExitCode"; FilePath = $LogFile } + $OutFileSettings
        $Err = $null
        Out-File @Params2 -ErrorVariable Err
        if ($? -eq $false) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
          return
        }
        # log exit code info
        [hashtable]$Params2 = @{ InputObject = "(Non-0 exit codes are not an error, only if 8 or greater)"; FilePath = $LogFile } + $OutFileSettings
        $Err = $null
        Out-File @Params2 -ErrorVariable Err
        if ($? -eq $false) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
          return
        }
      }
      # if user specified ShowResults display in console window
      if ($ShowResults -eq $true -and $Results -ne $null) {
        Add-IHILogIndentLevel
        $Results | Write-Host
        Remove-IHILogIndentLevel
      }
    }
    #endregion

    #region Record end of processing information
    [datetime]$EndTime = Get-Date
    # record end time in log for easier review
    if ($LogFile -ne "") {
      [hashtable]$Params2 = @{ InputObject = "End time: $($EndTime)"; FilePath = $LogFile } + $OutFileSettings
      $Err = $null
      Out-File @Params2 -ErrorVariable Err
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
        return
      }
    }
    Write-Host "Processing complete: $(($EndTime - $StartTime).TotalSeconds) seconds"
    Remove-IHILogIndentLevel
    #endregion
    #endregion
  }
}
Export-ModuleMember -Function Copy-IHIFileRoboCopy
#endregion


#region Functions: Copy-IHIBackupFileDestinations

<#
.SYNOPSIS
Copies a single file to multiple locations making simple backup first
.DESCRIPTION
Copies a single source file to multiple destinations, first making a simple backup
of the destination file.  If the destination file doesn't exist, don't bother
backing up (obviously) but don't throw an error - and still do the copy.  
Supports multiple destinations by accepting destinations via pipeline.
Use Copy-IHIFileRoboCopy for making the copy.
This function simplies the SPRINGS deployment process.  Not throwing an error will 
be necessary for first time deploys to a server
.PARAMETER SourceFilePath
Source file path
.PARAMETER DestinationFolderPath
Destination folder path
.PARAMETER BackupFolder
Specify to store backup copy in a _Backup folder located in relative location.
.PARAMETER LogFile
Log to copy results
.EXAMPLE
"c:\temp\D1","c:\temp\D2" | Copy-IHIBackupFileDestinations c:\temp\file1.txt
Backs up c:\temp\D1\file1.txt and c:\temp\D2\file1.txt (if exist) and copies (overwrites) c:\temp\file1.txt into folders D1 and D2
.EXAMPLE
Copy-IHIBackupFileDestinations -SourceFilePath c:\temp\file1.txt -DestinationFolderPath d:\temp -BackupFolder c:\Backups -LogFile c:\LogFiles\f1.txt
Backs up d:\temp\file1.txt (if exist) to c:\Backups and copies (overwrites) c:\temp\file1.txt into d:\temp
#>
function Copy-IHIBackupFileDestinations {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceFilePath,
    [Parameter(Mandatory = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [Alias("FullName")]
    [string]$DestinationFolderPath,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$BackupFolder,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$LogFile
  )
  #endregion
  process {
    #region Parameter validation
    #region Confirm source file path exists
    if ($false -eq (Test-Path -Path $SourceFilePath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: source file path is null or bad: $SourceFilePath"
      return
    }
    #endregion

    #region Confirm destination folder path exists
    if ($false -eq (Test-Path -Path $DestinationFolderPath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: destination folder path is null or bad: $DestinationFolderPath"
      return
    }
    #endregion
    #endregion

    #region Report information before processing files
    # rather than use PSBoundParameters, manually output for better formatting
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "SourceFilePath",$SourceFilePath)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "DestinationFolderPath",$DestinationFolderPath)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "BackupFolder",$BackupFolder)
    if ($LogFile -ne "") {
      Write-Host $("{0,-$DefaultCol1Width} {1}" -f "LogFile",$LogFile)
    }
    Remove-IHILogIndentLevel
    #endregion

    #region Get all source/destination locations
    [string]$SourceFolderPath = Split-Path -Path $SourceFilePath -Parent
    [string]$SourceFileName = Split-Path -Path $SourceFilePath -Leaf
    [string]$DestinationFilePath = Join-Path -Path $DestinationFolderPath -ChildPath $SourceFileName
    #endregion

    #region Backup destination file, if exists
    Write-Host "Backing up destination file, if exists"
    Add-IHILogIndentLevel
    if ($false -eq (Test-Path -Path $DestinationFilePath)) {
      Write-Host "Destination file does not exist; skipping backup: $DestinationFilePath"
    } else {
      Write-Host "Calling backup utility"
      Add-IHILogIndentLevel
      [hashtable]$Params = @{ Path = $DestinationFilePath; BackupFolder = $BackupFolder }
      $Err = $null
      Backup-IHIItemSimple @Params -EV Err
      if ($Err -ne $null) {
        # if error occurred, error would've been written to stream, no need to echo Err in our error
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Backup-IHIItemSimple with parameters: $(Convert-IHIFlattenHashtable $Params)"
        return
      }
      Remove-IHILogIndentLevel
    }
    Remove-IHILogIndentLevel
    #endregion

    #region Copy file to destination path
    Write-Host "Copy file to destination path"
    Add-IHILogIndentLevel
    $Err = $null
    [hashtable]$Params = @{ SourceFolderPath = $SourceFolderPath; DestinationPath = $DestinationFolderPath; FilePattern = $SourceFileName }
    # if log file specified, passed that as well
    if ($LogFile -ne "") {
      $Params.LogFile = $LogFile
    }
    Copy-IHIFileRoboCopy @Params -EV Err
    if ($Err -ne $null) {
      # if error occurred, error would've been written to stream, no need to echo Err in our error
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Copy-IHIFileRoboCopy with parameters: $(Convert-IHIFlattenHashtable $Params)"
      return
    }
    Remove-IHILogIndentLevel
    Write-Host "Backup/copy complete"
    #endregion
  }
}
Export-ModuleMember -Function Copy-IHIBackupFileDestinations
#endregion
