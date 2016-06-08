
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


#region Functions: Invoke-IHISqlAnalysisServicesDeployFiles

<#
.SYNOPSIS
Runs AnalysisServices utility on files to create cubes, etc.
.DESCRIPTION
Runs Microsoft.AnalysisServices.Deployment.exe utility to process 
database files, typically .asdatabase files, in order to create datacubes
in the database. Runs a file against a particular database server.
Can run an individual file, list of files, all files in a folder, list 
of folders, etc. recursively or not recursively. Optionally logs results 
to a file.
.PARAMETER DatabaseServer
Name of database server
.PARAMETER SqlFilePath
Collection of file path or paths to process.  Can be individual file, 
folder, set of files and/or folders, etc.  By default any folder will be 
searched recursively unless NotRecursive specified
.PARAMETER NotRecursive
If specified, will not search subfolders of any SqlFilePath folders
.PARAMETER LogFile
Log file for logging all files processed and error information, if any
.PARAMETER FileExtensions
List of file extensions of sql files to process, in order of processing
Default list: .asdatabase
.PARAMETER ShowResults
Show full results from utility (by default not displayed to console)
.EXAMPLE
Invoke-IHISqlAnalysisServicesDeployFiles LOCALHOST [path to .asdatabase file]
Runs .asdatabase file targeting database on LOCALHOST server
.EXAMPLE
Invoke-IHISqlAnalysisServicesDeployFiles LOCALHOST [path to folder with .asdatabase files]
Runs all .asdatabase in folder targeting database on LOCALHOST server
.EXAMPLE
Invoke-IHISqlAnalysisServicesDeployFiles LOCALHOST [path to .asdatabase file] -LogFile [logfile]
Runs .asdatabase file targeting database on LOCALHOST server and logs results
.EXAMPLE
dir [path to folder with .asdatabase files] | Select -First 3 | Invoke-IHISqlCmdFiles LOCALHOST
Processes the first 5 .asdatabase files in folder.  Keep in mind that when Invoke-IHISqlCmdFiles
is run this way using the pipeline as input, the function is excuted once for each file.  
A more efficient way to do the same thing would be:
$Files = dir [path to files] | Select -First 3 | % { $_.FullName }
Invoke-IHISqlAnalysisServicesDeployFiles LOCALHOST $Files
#>
function Invoke-IHISqlAnalysisServicesDeployFiles {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseServer,
    [Parameter(Mandatory = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [Alias("FullName")]
    [string[]]$SqlFilePath,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$NotRecursive,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$LogFile,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$FileExtensions = (".asdatabase"),
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [int]$SleepSeconds = 120,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$ShowResults
  )
  #endregion
  process {
    #region Parameter validation

    #region Make sure SqlAnalysisServicesDeploy found on machine
    if ($Ihi:Applications.Database.SqlAnalysisServicesDeploy -eq $null -or !(Test-Path -Path $Ihi:Applications.Database.SqlAnalysisServicesDeploy)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path for Microsoft.AnalysisServices.Deployment.exe is null or bad: $($Ihi:Applications.Database.SqlAnalysisServicesDeploy)"
      return
    }
    #endregion

    #region Make sure server exists/accessible
	# If the Database Server is a SQL Server Instance, it will be of the form SERVER\INSTANCE 
	#	so, let's check for \ and only ping the portion before the \
	$DatabaseServerComponents = $DatabaseServer.split("\")
    # $PingResults = Ping-Host -HostName $DatabaseServerComponents[0] -Count 1 -Quiet
    $PingResults = Test-Connection -ComputerName $DatabaseServerComponents[0] -Count 1 -Quiet
    # if ($PingResults -eq $null -or $PingResults.Received -eq 0) {
    if ($PingResults -eq $null -or $PingResults -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: DatabaseServer not accessible: $DatabaseServer"
      return
    }
    #endregion

    #region Items in path must exist; if specified item does not actually exist, exit
    foreach ($Path in $SqlFilePath) {
      if ($false -eq (Test-Path -Path $Path)) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: item from SqlFilePath not found: $Path"
        return
      }
    }
    #endregion

    #region LogFile parent must exist and LogFile must not be a folder
    # only check if passed
    if ($LogFile -ne "") {
      # make sure parent exists
      if ($false -eq (Test-Path -Path (Split-Path -Path $LogFile -Parent))) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: LogFile parent folder does not exist for LogFile: $LogFile"
        return
      }
      # if exists, make sure logfile is not a folder
      if ((Test-Path -Path $LogFile) -and (Get-Item -Path $LogFile).PSIsContainer) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: LogFile cannot be a folder, must be a filename: $LogFile"
        return
      }
    }
    #endregion

    #endregion

    #region Identify files to process
    # Get files that match extension list and make sure item is not a folder
    # Recurse param for Get-ChildItem call is opposite of current $NotRecursive value
    $FilesToProcess = Get-ChildItem -Path $SqlFilePath -Recurse:$(!$NotRecursive) | Where-Object { $FileExtensions -contains $_.Extension } | Where-Object { !$_.PSIsContainer }
    if ($FilesToProcess -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: no files to process with extension $("$FileExtensions") under: $("$SqlFilePath")"
      return
    }
    #endregion

    #region Report information before processing files
    # rather than use PSBoundParameters, manually output for better formatting
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "DatabaseServer",$DatabaseServer)
    # if multiple source paths, output on separate lines else
    # just write single entry
    if ($SqlFilePath.Count -eq 1) {
      Write-Host $("{0,-$DefaultCol1Width} {1}" -f "SqlFilePath",$SqlFilePath[0])
    } else {
      Write-Host "SqlFilePath"
      Add-IHILogIndentLevel
      $SqlFilePath | ForEach-Object {
        Write-Host "$_"
      }
      Remove-IHILogIndentLevel
    }
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Recursive",$(!$NotRecursive))
    if ($LogFile -ne "") { Write-Host $("{0,-$DefaultCol1Width} {1}" -f "LogFile",$LogFile) }
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "FileExtensions",$("$FileExtensions"))
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "SleepSeconds",$("$SleepSeconds"))
    #endregion

    #region Process files
    Write-Host "Processing..."
    #region Initialize counters and log start time
    [int]$TotalFiles = 0
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
    # get files to process grouped by extension as a hash table for easy usage
    $GroupByExtension = $FilesToProcess | Group-Object -Property Extension -AsHashTable -AsString
    # for each extension, loop through in order of extension in list
    # need to loop by FileExtensions for order, even if particular extension
    # doesn't exist in results
    for ($i = 0; $i -lt $FileExtensions.Count; $i++) {
      [string]$Extension = $FileExtensions[$i]
      # make sure files exist in grouped files for this extension before attempting to process
      if ($GroupByExtension.Keys -contains $Extension) {
        # process each file grouped for this extension
        $TotalFiles += $GroupByExtension.$Extension.Count
        for ($j = 0; $j -lt $GroupByExtension.$Extension.Count; $j++) {
          [string]$FileToProcess = $GroupByExtension.$Extension[$j].FullName
          #region Run Microsoft.AnalysisServices.Deployment for file
          #region Microsoft.AnalysisServices.Deployment parameter information
          # /s  log file
          #endregion
          #region Get Microsoft.AnalysisServices.Deployment temporary log file
          # Microsoft.AnalysisServices.Deployment.exe version 10 does not write it's output 
          # to standard out so we can't simply capture it that way.  It can log the text
          # to a text file but it ONLY overwrites the results - it won't append.  So, we 
          # need to capture the results for each run into a temp file which can then be 
          # analyzed for errors and appended to main file (if specified) and/or output to console.
          [string]$TempFile = Join-Path -Path $Ihi:Folders.TempFolder -ChildPath $(("{0:yyyyMMdd_HHmmss}" -f (Get-Date)) + ".txt")
          # make sure file with same name doesn't already exist
          while (Test-Path -Path $TempFile) {
            $TempFile = Join-Path -Path $Ihi:Folders.TempFolder -ChildPath $(("{0:yyyyMMdd_HHmmss}" -f (Get-Date)) + ".txt")
          }
          #endregion

          [string]$Cmd = $Ihi:Applications.Database.SqlAnalysisServicesDeploy
          [string[]]$Params = $FileToProcess,"/s:$TempFile"
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
          & $Cmd $Params
          # need to pause for previous command to finish writing to file
          Start-Sleep -Seconds $SleepSeconds		
          # get content from temp file; get as array of strings (easier to index results and file is small)
          [string[]]$TempFileContent = [string[]]$(Get-Content $TempFile)
          # if LogFile, store results it in
          if ($LogFile -ne "") {
            [hashtable]$Params2 = @{ InputObject = $TempFileContent; FilePath = $LogFile } + $OutFileSettings
            $Err = $null
            Out-File @Params2 -ErrorVariable Err
            if ($? -eq $false) {
              Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
              return
            }
          }
          # Microsoft.AnalysisServices.Deployment doesn't set LastExitCode, need to parse results
          # if deploy was successful:
          #  - last full line (with text) is "Done"
          #  - second to last line begins with "Deploying the"
          # if doesn't satify both these conditions, error
          if (!($TempFileContent[$TempFileContent.Count - 1] -eq "Done" -and $TempFileContent[$TempFileContent.Count - 2].StartsWith("Deploying the"))) {
            # if error occurred, display command and results to console before error message
            Add-IHILogIndentLevel
            Write-Host "& $Cmd $Params"
            [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error occurred in Microsoft.AnalysisServices.Deployment with parameters: $("$Cmd $Params") :: $("$TempFileContent")"
            # write error message to file then to console
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
            # if user specified ShowResults and there were actual results
            # show command name and results to console window
            if ($ShowResults -eq $true) {
              Add-IHILogIndentLevel
              Write-Host $FileToProcess
              Add-IHILogIndentLevel
              $TempFileContent | ForEach-Object { $_.Replace("`r","`r`n") } | Write-Host
              Remove-IHILogIndentLevel
              Remove-IHILogIndentLevel
            }
          }
          # delete $TempFile, no longer needed
          [hashtable]$Params = @{ Path = $TempFile; Force = $true }
          $Results = Remove-Item @Params 2>&1
          if ($? -eq $false) {
            Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Remove-Item with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Results")"
            return
          }
          #endregion
        }
      }
    }
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
    Write-Host "Processing complete: $TotalFiles files in $(($EndTime - $StartTime).TotalSeconds) seconds"
    Remove-IHILogIndentLevel
    #endregion
    #endregion
  }
}
Export-ModuleMember -Function Invoke-IHISqlAnalysisServicesDeployFiles
#endregion


#region Functions: Invoke-IHISqlCmdFiles

<#
.SYNOPSIS
Runs SqlCmd on database files to create procedures, etc.
.DESCRIPTION
Runs SqlCmd.exe utility to process database files, typically .udf, .viw,  
.prc and .trg files, in order to create database objects in the database. 
(Actual contents of these files can do anything - be careful!) Runs a file
against a particular database instance on a particular database server using 
integrated security.  Can run an individual file, list of files, all files 
in a folder, list of folders, etc. recursively or not recursively.  
Optionally logs results to a file.
.PARAMETER DatabaseServer
Name of database server
.PARAMETER DatabaseInstance
Name of database instance
.PARAMETER SqlFilePath
Collection of file path or paths to process.  Can be individual file, 
folder, set of files and/or folders, etc.  By default any folder will be 
searched recursively unless NotRecursive specified
.PARAMETER NotRecursive
If specified, will not search subfolders of any SqlFilePath folders
.PARAMETER FileParameters
Hashtable of key/value pairs to pass as parameters to the file via the -v 
option of SqlCmd.exe.
.PARAMETER LogFile
Log file for logging all files processed and error information, if any
.PARAMETER FileExtensions
List of file extensions of sql files to process, in order of processing
Default list: .udf, .viw, .prc, .trg
.PARAMETER AdditionalSqlParams
Additional parameters to pass to SqlCmd.exe when running.  Default values
are -E (use trusted connection) and -b (on error batch abort).
.PARAMETER ShowResults
Show full results from utility (by default not displayed to console)
.EXAMPLE
Invoke-IHISqlCmdFiles LOCALHOST LOCAL_IHIDB [path to folder Workspace]
Runs .udf, .viw, .prc and .trg files under Workspace folder targeting LOCALHOST:LOCAL_IHIDB
.EXAMPLE
Invoke-IHISqlCmdFiles LOCALHOST LOCAL_IHIDB [folder Workspace],[folder Events] -LogFile c:\temp\results.txt
Runs .udf, .viw, .prc and .trg files under Workspace and Events folders targeting 
LOCALHOST:LOCAL_IHIDB, putting results in log file c:\temp\results.txt
.EXAMPLE
Invoke-IHISqlCmdFiles LOCALHOST LOCAL_IHIDB [folder Workspace] -FileExtensions (".sql",".txt")
Runs .sql and .txt files under Workspace folder targeting LOCALHOST:LOCAL_IHIDB
.EXAMPLE
Invoke-IHISqlCmdFiles LOCALHOST LOCAL_IHIDB [folder Workspace] -FileParameters @{ Key1='Value 1'; Key2='Value 2' }
Runs .udf, .viw, .prc and .trg files under Workspace and passes file parameters to each file
.EXAMPLE
dir [path to folder Events] | Select -First 5 | Invoke-IHISqlCmdFiles LOCALHOST LOCAL_IHIDB
Processes the first 5 files in Events folder.  Keep in mind that when Invoke-IHISqlCmdFiles
is run this way using the pipeline as input, the function is excuted once for each file.  
A more efficient way to do the same thing would be:
$Files = dir [path to folder Events] | Select -First 5 | % { $_.FullName }
Invoke-IHISqlCmdFiles LOCALHOST LOCAL_IHIDB $Files
#>
function Invoke-IHISqlCmdFiles {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseServer,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseInstance,
    [Parameter(Mandatory = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [Alias("FullName")]
    [string[]]$SqlFilePath,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$NotRecursive,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [System.Collections.Hashtable]$FileParameters,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$LogFile,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$FileExtensions = (".udf",".viw",".prc",".trg"),
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$AdditionalSqlParams = ("-E","-b"),
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$ShowResults
  )
  #endregion
  process {
    #region Parameter validation

    #region Make sure SqlCmd found on machine
    if ($Ihi:Applications.Database.SqlCmd -eq $null -or !(Test-Path -Path $Ihi:Applications.Database.SqlCmd)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path for SqlCmd.exe is null or bad: $($Ihi:Applications.Database.SqlCmd)"
      return
    }
    #endregion

    #region Make sure server exists/accessible
	  # If the Database Server is a SQL Server Instance, it will be of the form SERVER\INSTANCE 
	  #	so, let's check for \ and only ping the portion before the \
	  $DatabaseServerComponents = $DatabaseServer.split("\")
    # $PingResults = Ping-Host -HostName $DatabaseServerComponents[0] -Count 1 -Quiet
    $PingResults = Test-Connection -ComputerName $DatabaseServerComponents[0] -Count 1 -Quiet
    # if ($PingResults -eq $null -or $PingResults.Received -eq 0) {
    if ($PingResults -eq $null -or $PingResults -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: DatabaseServer not accessible: $DatabaseServer"
      return
    }
    #endregion

    #region Items in path must exist; if specified item does not actually exist, exit
    foreach ($Path in $SqlFilePath) {
      if ($false -eq (Test-Path -Path $Path)) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: item from SqlFilePath not found: $Path"
        return
      }
    }
    #endregion

    #region LogFile parent must exist and LogFile must not be a folder
    # only check if passed
    if ($LogFile -ne "") {
      # make sure parent exists
      if ($false -eq (Test-Path -Path (Split-Path -Path $LogFile -Parent))) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: LogFile parent folder does not exist for LogFile: $LogFile"
        return
      }
      # if exists, make sure logfile is not a folder
      if ((Test-Path -Path $LogFile) -and (Get-Item -Path $LogFile).PSIsContainer) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: LogFile cannot be a folder, must be a filename: $LogFile"
        return
      }
    }
    #endregion

    #endregion

    #region Identify files to process
    # Get files that match extension list and make sure item is not a folder
    # Recurse param for Get-ChildItem call is opposite of current $NotRecursive value
    $FilesToProcess = Get-ChildItem -Path $SqlFilePath -Recurse:$(!$NotRecursive) | Where-Object { $FileExtensions -contains $_.Extension } | Where-Object { !$_.PSIsContainer }
    if ($FilesToProcess -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: no files to process with extension $("$FileExtensions") under: $("$SqlFilePath")"
      return
    }
    #endregion

    #region Report information before processing files
    # rather than use PSBoundParameters, manually output for better formatting
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "DatabaseServer",$DatabaseServer)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "DatabaseInstance",$DatabaseInstance)
    # if multiple source paths, output on separate lines else
    # just write single entry
    if ($SqlFilePath.Count -eq 1) {
      Write-Host $("{0,-$DefaultCol1Width} {1}" -f "SqlFilePath",$SqlFilePath[0])
    } else {
      Write-Host "SqlFilePath"
      Add-IHILogIndentLevel
      $SqlFilePath | ForEach-Object {
        Write-Host "$_"
      }
      Remove-IHILogIndentLevel
    }
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Recursive",$(!$NotRecursive))
    if ($LogFile -ne "") { Write-Host $("{0,-$DefaultCol1Width} {1}" -f "LogFile",$LogFile) }
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "FileExtensions",$("$FileExtensions"))
    if ($FileParameters -ne $null -and $($FileParameters.Keys.Count) -gt 0) {
      $FileParametersInfo = ""
      $FileParameters.Keys | Sort | ForEach-Object { $FileParametersInfo += ($_ + "=" + $FileParameters[$_]) + " " }
      Write-Host $("{0,-$DefaultCol1Width} {1}" -f "FileParameters",$FileParametersInfo)
    }
    #endregion

    #region Process files
    Write-Host "Processing..."
    #region Initialize counters and log start time
    [int]$TotalFiles = 0
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
    # get files to process grouped by extension as a hash table for easy usage
    $GroupByExtension = $FilesToProcess | Group-Object -Property Extension -AsHashTable -AsString
    # for each extension, loop through in order of extension in list
    # need to loop by FileExtensions for order, even if particular extension
    # doesn't exist in results
    for ($i = 0; $i -lt $FileExtensions.Count; $i++) {
      [string]$Extension = $FileExtensions[$i]
      # make sure files exist in grouped files for this extension before attempting to process
      if ($GroupByExtension.Keys -contains $Extension) {
        # process each file grouped for this extension
        $TotalFiles += $GroupByExtension.$Extension.Count
        for ($j = 0; $j -lt $GroupByExtension.$Extension.Count; $j++) {
          [string]$FileToProcess = $GroupByExtension.$Extension[$j].FullName
          #region Run SqlCmd for file
          #region SqlCmd parameter information
          # -S  database server machine
          # -d  database instance
          # -i  path to file to process
          # -E  use trusted connection
          # -b  on error batch abort
          # -v  list of key/value arguments to pass to script
          # type sqlcmd /? for more information
          #endregion
          [string]$Cmd = $Ihi:Applications.Database.SqlCmd
          [string[]]$Params = "-S",$DatabaseServer,"-d",$DatabaseInstance,"-i",$FileToProcess
          # if additional sql parameters, pass them
          if ($AdditionalSqlParams -ne $null) { $Params += $AdditionalSqlParams }
          #region Process FileParameters if passed
          if ($FileParameters -ne $null -and $($FileParameters.Keys.Count) -gt 0) {
            $Params += "-v"
            $FileParameters.Keys | Sort | ForEach-Object { $Params += ($_ + "=" + $FileParameters[$_]) }
          }
          #endregion
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
          if ($? -eq $false -or $LastExitCode -ne 0) {
            # if error occurred, display command to console before error message
            Add-IHILogIndentLevel
            Write-Host "& $Cmd $Params"
            [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error occurred in SqlCmd.exe with parameters: $("$Cmd $Params") :: $("$Results")"
            # write error message to file then to console
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
            # if no error but user specified LogFile, store results it in
            if ($LogFile -ne "") {
              [hashtable]$Params2 = @{ InputObject = $Results; FilePath = $LogFile } + $OutFileSettings
              $Err = $null
              Out-File @Params2 -ErrorVariable Err
              if ($? -eq $false) {
                Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
                return
              }
            }
            # if user specified ShowResults and there were actual results
            # show command name and results to console window
            if ($ShowResults -eq $true -and $Results -ne $null) {
              Add-IHILogIndentLevel
              Write-Host $FileToProcess
              $Results | ForEach-Object { $_.Replace("`r","`r`n") } | Write-Host
              Remove-IHILogIndentLevel
            }
          }
          #endregion
        }
      }
    }
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
    Write-Host "Processing complete: $TotalFiles files in $(($EndTime - $StartTime).TotalSeconds) seconds"
    Remove-IHILogIndentLevel
    #endregion
    #endregion
  }
}
Export-ModuleMember -Function Invoke-IHISqlCmdFiles
#endregion


#region Functions: Invoke-IHISqlIntegrationServicesFiles


<#
.SYNOPSIS
Runs Integration Services utility on files to deploy packages
.DESCRIPTION
Runs Integration Services dtutil.exe on files to deploy packages.
Processes .dtsx files by default.  
Can run an individual file, list of files, all files in a folder, list 
of folders, etc. recursively or not recursively. Optionally logs results 
to a file.
.PARAMETER SqlFilePath
Collection of file path or paths to process.  Can be individual file, 
folder, set of files and/or folders, etc.  By default any folder will be 
searched recursively unless NotRecursive specified
.PARAMETER DatabaseServer
Name of database server
.PARAMETER CodeSet
CodeSet value used in parameters to help identify the environment
.PARAMETER NotRecursive
If specified, will not search subfolders of any SqlFilePath folders
.PARAMETER LogFile
Log file for logging all files processed and error information, if any
.PARAMETER FileExtensions
List of file extensions of sql files to process, in order of processing
Default list: .dtsx
.PARAMETER ShowResults
Show full results from utility (by default not displayed to console)
.EXAMPLE
Invoke-IHISqlIntegrationServicesFiles [path to .dtsx file] DEVSQL DEV
Runs .dtsx file targeting DEVSQL server DEV codeset
.EXAMPLE
Invoke-IHISqlIntegrationServicesFiles [path to folder with .dtsx files] DEVSQL -ShowResults
Runs all .dtsx in folder targeting DEVSQL server DEV codeset, shows fulls results
.EXAMPLE
Invoke-IHISqlIntegrationServicesFiles [path to .dtsx file] DEVSQL -LogFile [logfile]
Runs .dtsx file targeting DEVSQL server and logs results
#>
function Invoke-IHISqlIntegrationServicesFiles {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [Alias("FullName")]
    [string[]]$SqlFilePath,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseServer,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$CodeSet,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$NotRecursive,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$LogFile,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$FileExtensions = (".dtsx"),
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$ShowResults
  )
  #endregion
  process {
    #region Parameter validation

    #region Make sure SqlIntegrationServicesUtility found on machine
    if ($Ihi:Applications.Database.SqlIntegrationServicesUtility -eq $null -or !(Test-Path -Path $Ihi:Applications.Database.SqlIntegrationServicesUtility)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path for SqlIntegrationServicesUtility dtutil.exe is null or bad: $($Ihi:Applications.Database.SqlIntegrationServicesUtility)"
      return
    }
    #endregion

    #region Make sure server exists/accessible
	# If the Database Server is a SQL Server Instance, it will be of the form SERVER\INSTANCE 
	#	so, let's check for \ and only ping the portion before the \
	$DatabaseServerComponents = $DatabaseServer.split("\")
    # $PingResults = Ping-Host -HostName $DatabaseServerComponents[0] -Count 1 -Quiet
    $PingResults = Test-Connection -ComputerName $DatabaseServerComponents[0] -Count 1 -Quiet
    # if ($PingResults -eq $null -or $PingResults.Received -eq 0) {
    if ($PingResults -eq $null -or $PingResults -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: DatabaseServer not accessible: $DatabaseServer"
      return
    }
    #endregion

    #region Items in path must exist; if specified item does not actually exist, exit
    foreach ($Path in $SqlFilePath) {
      if ($false -eq (Test-Path -Path $Path)) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: item from SqlFilePath not found: $Path"
        return
      }
    }
    #endregion

    #region LogFile parent must exist and LogFile must not be a folder
    # only check if passed
    if ($LogFile -ne "") {
      # make sure parent exists
      if ($false -eq (Test-Path -Path (Split-Path -Path $LogFile -Parent))) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: LogFile parent folder does not exist for LogFile: $LogFile"
        return
      }
      # if exists, make sure logfile is not a folder
      if ((Test-Path -Path $LogFile) -and (Get-Item -Path $LogFile).PSIsContainer) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: LogFile cannot be a folder, must be a filename: $LogFile"
        return
      }
    }
    #endregion

    #endregion

    #region Identify files to process
    # Get files that match extension list and make sure item is not a folder
    # Recurse param for Get-ChildItem call is opposite of current $NotRecursive value
    $FilesToProcess = Get-ChildItem -Path $SqlFilePath -Recurse:$(!$NotRecursive) | Where-Object { $FileExtensions -contains $_.Extension } | Where-Object { !$_.PSIsContainer }
    if ($FilesToProcess -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: no files to process with extension $("$FileExtensions") under: $("$SqlFilePath")"
      return
    }
    #endregion

    #region Report information before processing files
    # rather than use PSBoundParameters, manually output for better formatting
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "DatabaseServer",$DatabaseServer)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "CodeSet",$CodeSet)
    # if multiple source paths, output on separate lines else
    # just write single entry
    if ($SqlFilePath.Count -eq 1) {
      Write-Host $("{0,-$DefaultCol1Width} {1}" -f "SqlFilePath",$SqlFilePath[0])
    } else {
      Write-Host "SqlFilePath"
      Add-IHILogIndentLevel
      $SqlFilePath | ForEach-Object {
        Write-Host "$_"
      }
      Remove-IHILogIndentLevel
    }
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Recursive",$(!$NotRecursive))
    if ($LogFile -ne "") { Write-Host $("{0,-$DefaultCol1Width} {1}" -f "LogFile",$LogFile) }
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "FileExtensions",$("$FileExtensions"))
    #endregion

    #region dtutil.exe parameter information (not all used at same time)
    # /SourceServer  server
    # /DestServer    server
    # /FCreate       action: create 
    # /DELETE        action: delete
    # /SQL           package path
    # /FILE          file spec
    # /ENCRYPT
    #endregion
    [string]$Cmd = $Ihi:Applications.Database.SqlIntegrationServicesUtility

    #region Create root codeset folder if doesn't exist
    [string[]]$Params = "/SourceServer",$DatabaseServer,"/FCreate",$("SQL;/;" + $CodeSet)
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
    if ($? -eq $false) {
      # attempt to create; if already exists, throws error but ok, don't terminate
      Write-Host "Error creating root $CodeSet folder - it probably already exists"
    }
    # if no error but user specified LogFile, store results it in
    if ($LogFile -ne "") {
      [hashtable]$Params2 = @{ InputObject = $Results; FilePath = $LogFile } + $OutFileSettings
      $Err = $null
      Out-File @Params2 -ErrorVariable Err
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
        return
      }
    }
    # if user specified ShowResults and there were actual results
    # show command name and results to console window
    if ($ShowResults -eq $true -and $Results -ne $null) {
      Add-IHILogIndentLevel
      $Results | ForEach-Object { $_.Replace("`r","`r`n") } | Write-Host
      Remove-IHILogIndentLevel
    }
    #endregion

    #region Process files
    Write-Host "Processing..."
    #region Initialize counters and log start time
    [int]$TotalFiles = 0
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
    # get files to process grouped by extension as a hash table for easy usage
    $GroupByExtension = $FilesToProcess | Group-Object -Property Extension -AsHashTable -AsString
    # for each extension, loop through in order of extension in list
    # need to loop by FileExtensions for order, even if particular extension
    # doesn't exist in results
    for ($i = 0; $i -lt $FileExtensions.Count; $i++) {
      [string]$Extension = $FileExtensions[$i]
      # make sure files exist in grouped files for this extension before attempting to process
      if ($GroupByExtension.Keys -contains $Extension) {
        # process each file grouped for this extension
        $TotalFiles += $GroupByExtension.$Extension.Count
        for ($j = 0; $j -lt $GroupByExtension.$Extension.Count; $j++) {
          [string]$FileToProcess = $GroupByExtension.$Extension[$j].FullName
          #region Run SqlIntegrationServicesUtility delete/create for file
          #region Get name of file, no extension
          # first get just file name with extension of DTSX file
          $DtsxNameNoExt = Split-Path $FileToProcess -Leaf
          # now remove extension
          $DtsxNameNoExt = $DtsxNameNoExt.Substring(0,$DtsxNameNoExt.IndexOf("."))
          #endregion

          #region Delete existing package for this file - if it exists
          [string[]]$Params = "/SourceServer",$DatabaseServer,"/SQL",$($CodeSet + "/" + $DtsxNameNoExt),"/DELETE"
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
          if ($? -eq $false) {
            Write-Host "Error deleting $CodeSet \ $DtsxNameNoExt - it probably doesn't exist"
          }
          # if no error but user specified LogFile, store results it in
          if ($LogFile -ne "") {
            [hashtable]$Params2 = @{ InputObject = $Results; FilePath = $LogFile } + $OutFileSettings
            $Err = $null
            Out-File @Params2 -ErrorVariable Err
            if ($? -eq $false) {
              Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
              return
            }
          }
          # if user specified ShowResults and there were actual results
          # show command name and results to console window
          if ($ShowResults -eq $true -and $Results -ne $null) {
            Add-IHILogIndentLevel
            Write-Host $FileToProcess
            $Results | ForEach-Object { $_.Replace("`r","`r`n") } | Write-Host
            Remove-IHILogIndentLevel
          }
          #endregion

          #region Create package
          [string[]]$Params = "/FILE",$FileToProcess,"/DestServer",$DatabaseServer,"/ENCRYPT",$("SQL;/" + $CodeSet + "/" + $DtsxNameNoExt + ";5")
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
          if ($? -eq $false) {
            # if error occurred, display command to console before error message
            Add-IHILogIndentLevel
            Write-Host "& $Cmd $Params"
            [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error occurred in dtutil.exe with parameters: $("$Cmd $Params") :: $("$Results")"
            # write error message to file then to console
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
          }
          # if no error but user specified LogFile, store results it in
          if ($LogFile -ne "") {
            [hashtable]$Params2 = @{ InputObject = $Results; FilePath = $LogFile } + $OutFileSettings
            $Err = $null
            Out-File @Params2 -ErrorVariable Err
            if ($? -eq $false) {
              Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
              return
            }
          }
          # if user specified ShowResults and there were actual results
          # show command name and results to console window
          if ($ShowResults -eq $true -and $Results -ne $null) {
            Add-IHILogIndentLevel
            Write-Host $FileToProcess
            $Results | ForEach-Object { $_.Replace("`r","`r`n") } | Write-Host
            Remove-IHILogIndentLevel
          }
          #endregion
          #endregion
        }
      }
    }
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
    Write-Host "Processing complete: $TotalFiles files in $(($EndTime - $StartTime).TotalSeconds) seconds"
    Remove-IHILogIndentLevel
    #endregion
    #endregion
  }
}
Export-ModuleMember -Function Invoke-IHISqlIntegrationServicesFiles

#endregion


#region Functions: Invoke-IHISqlReportingServicesFiles

<#
.SYNOPSIS
Executes .rss file against the specified Report Server
.DESCRIPTION
Executes .rss file against the specified Report Server
Optionally logs results to a file.
.PARAMETER RssFilePath
Path to .rss file to use.  Must be file ending in .rss
.PARAMETER ReportingServicesUrl
Name of reporting server instance
.PARAMETER Endpoint
Value of SSRS Web Service Endpoint, typically Mgmt2005 or Mgmt2010
.PARAMETER FileParameters
Hashtable of key/value pairs to pass as parameters to the file via the -v 
option of rs.exe.
.PARAMETER LogFile
Log file for logging all files processed and error information, if any
.PARAMETER HideResults
Hide full results from console output (by default always show in console)
.EXAMPLE
Invoke-IHISqlReportingServicesFiles [path to .rss file] http://devsql/reportserver
Runs .rss file targeting reportserver on devsql
.EXAMPLE
Invoke-IHISqlReportingServicesFiles [path to .rss file] http://devsql/reportserver -LogFile c:\temp\results.txt
Runs .rss file targeting reportserver on devsql and logs results to file
.EXAMPLE
Invoke-IHISqlReportingServicesFiles [path to .rss file] http://devsql/reportserver Mgmt2005 -FileParameters @{ Key1='Value 1'; Key2='Value 2' }
Runs .rss file targeting reportserver on devsql passing additional parameters via -v and using an endpoint of Mgmt2005
#>
function Invoke-IHISqlReportingServicesFiles {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string]$RssFilePath,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ReportingServicesUrl,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
	[string]$Endpoint,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [System.Collections.Hashtable]$FileParameters,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$LogFile,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$HideResults
  )
  #endregion
  process {
    #region Parameter validation

    #region Make sure SqlReportingServicesUtility found on machine
    if ($Ihi:Applications.Database.SqlReportingServicesUtility -eq $null -or !(Test-Path -Path $Ihi:Applications.Database.SqlReportingServicesUtility)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path for SqlReportingServicesUtility rs.exe is null or bad: $($Ihi:Applications.Database.SqlReportingServicesUtility)"
      return
    }
    #endregion

    #region RssFilePath must exist, and be a file with extension .rss
    if ($false -eq (Test-Path -Path $RssFilePath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: RssFilePath not found: $RssFilePath"
      return
    }
    $RssFile = Get-Item -Path $RssFilePath
    # make sure not a folder
    if ($true -eq $RssFile.PSIsContainer) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: RssFilePath is a folder, not a file: $RssFilePath"
      return
    }
    # make sure has .rss extension
    if ($RssFile.Extension -ne ".rss") {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: RssFilePath must have an extension of .rss: $RssFilePath"
      return
    }
    #endregion

    #region LogFile parent must exist and LogFile must not be a folder
    # only check if passed
    if ($LogFile -ne "") {
      # make sure parent exists
      if ($false -eq (Test-Path -Path (Split-Path -Path $LogFile -Parent))) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: LogFile parent folder does not exist for LogFile: $LogFile"
        return
      }
      # if exists, make sure logfile is not a folder
      if ((Test-Path -Path $LogFile) -and (Get-Item -Path $LogFile).PSIsContainer) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: LogFile cannot be a folder, must be a filename: $LogFile"
        return
      }
    }
    #endregion

    #endregion

    #region Report information before processing files
    # rather than use PSBoundParameters, manually output for better formatting
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "ReportingServicesUrl",$ReportingServicesUrl)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "RssFilePath",$RssFilePath)
    if ($LogFile -ne "") { Write-Host $("{0,-$DefaultCol1Width} {1}" -f "LogFile",$LogFile) }
    if ($FileParameters -ne $null -and $($FileParameters.Keys.Count) -gt 0) {
      $FileParametersInfo = ""
      $FileParameters.Keys | Sort | ForEach-Object { $FileParametersInfo += ($_ + "=" + $FileParameters[$_]) + " " }
      Write-Host $("{0,-$DefaultCol1Width} {1}" -f "FileParameters",$FileParametersInfo)
    }
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "HideResults",$HideResults)
    #endregion

    #region Process file
    Write-Host "Processing..."
    #region Initialize counters and log start time
    [int]$TotalFiles = 0
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

    #region Run SqlReportingServicesUtility for file
    #region rs.exe parameter information
    # /i  reporting services script
    # /s  reporting services url
    # all additional file parameters passed at end
    #endregion
    [string]$Cmd = $Ihi:Applications.Database.SqlReportingServicesUtility
    [string[]]$Params = "/i",$RssFile,"/s",$ReportingServicesUrl
	#region Process Endpoint if passed
	if ($Endpoint -ne $null){
		$Params += '"-e"',$Endpoint
	}
    #region Process FileParameters if passed
    # add any parameters using format (with quotes):
    #   "-v" $ParamName="$ParamValue"
    # note: each param needs the -v prefix
    if ($FileParameters -ne $null -and $($FileParameters.Keys.Count) -gt 0) {
      $FileParameters.Keys | Sort | ForEach-Object {
        $Params += '"-v"'
        $Params += ($_ + "=" + $FileParameters[$_])
      }
    }
    #endregion
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
    if ($? -eq $false -or $LastExitCode -ne 0 -or ($Results -match 'ERROR:')) {
      # if error occurred, display command to console before error message
      Add-IHILogIndentLevel
      Write-Host "& $Cmd $Params"
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error occurred in rs.exe with parameters: $("$Cmd $Params") :: See the SSRS log file for more information."
      # write error message to file then to console
      if ($LogFile -ne "") {
        $FileContent = $Results | ForEach-Object { $_.ToString() + "`r`n" }
        [hashtable]$Params2 = @{ InputObject = ($ErrorMessage + "`r`n" + $FileContent); FilePath = $LogFile } + $OutFileSettings
        $Err = $null
        Out-File @Params2 -ErrorVariable Err
        if ($? -eq $false) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
          return
        }
      }
      Write-Error -Message $ErrorMessage
      $Results | Write-Host
      # get rid of indents if need to exit
      Remove-IHILogIndentLevel; Remove-IHILogIndentLevel
      return
    } else {
      # if no error but user specified LogFile, store results it in
      if ($LogFile -ne "") {
        $FileContent = $Results | ForEach-Object { $_.ToString() + "`r`n" }
        [hashtable]$Params2 = @{ InputObject = $FileContent; FilePath = $LogFile } + $OutFileSettings
        $Err = $null
        Out-File @Params2 -ErrorVariable Err
        if ($? -eq $false) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
          return
        }
      }
      # if there were actual results and user didn't specify HideResults
      # show command name and results to console window
      if ($HideResults -eq $false -and $Results -ne $null) {
        Add-IHILogIndentLevel
        Write-Host $RssFile
        $Results | ForEach-Object { $_.Replace("`r","`r`n") } | Write-Host
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
    Write-Host "Processing complete: in $(($EndTime - $StartTime).TotalSeconds) seconds"
    Remove-IHILogIndentLevel
    #endregion
    #endregion
  }
}
Export-ModuleMember -Function Invoke-IHISqlReportingServicesFiles
#endregion


#region Functions: Out-IHISqlAnalysisServicesXMLAFiles

<#
.SYNOPSIS
Writes XMLS Analysis Services help to host
.DESCRIPTION
Writes XMLS Analysis Services help to host
.EXAMPLE
Outputs build help
#>
function Out-IHISqlAnalysisServicesXMLAFiles {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    Write-Host "`nInvoke-IHISqlAnalysisServicesXMLAFiles -DWDatabaseServer <DATABASESERVER> -DWDatabaseInstance <DATABASEINSTANCE>"
    Write-Host "`n  -JobUserId <USERNAME> -JobPassword <PASSWORD> -DirectoryToScan <DIRECTORYNAME> -IgnorePattern <PATTERNTOIGNORE>"
    Write-Host "`n  -XmlaConnectionFile <CONNECTFILE> -DirectoryScan <BOOLEAN> -XmlaDirectory <XMLAFILELOCATION>"
    Write-Host "`n  DWDatabaseServer:      Database Server to connect to"
    Write-Host "  DWDatabaseInstance:              Name of the database"
    Write-Host "  JobUserId:          Username to connect to Analysis Service as"
    Write-Host "  JobPassword:          Password for the Analysis Service account"
    Write-Host "  DirectoryToScan:          Directory that contains the XMLA files, only scanned when DirectoryScan is set to True"
    Write-Host "  IgnorePattern:          File Name pattern to ignore"
    Write-Host "  XmlaConnectionFile          Name of the XMLA file that contains the connection parameters"
    Write-Host "  DirectoryScan          True or False boolean as to whether or not to scan the Directory, default is True"
    Write-Host "  XmlaDirectory          Directory that contains the XMLA files"
    Write-Host "`n  Examples:"
    Write-Host "    Invoke-IHISqlAnalysisServicesXMLAFiles -DWDatabaseServer DEVDW -DWDatabaseInstance DEV_DWIHI"
    Write-Host "`n  -JobUserId sqlssis -JobPassword PASSWORD -DirectoryToScan O:\GeneralPurpose\Temp\HL_Temp\ -IgnorePattern NoVars"
    Write-Host "`n  -XmlaConnectionFile Products_DWIHI_Connection.xmla -DirectoryScan true -XmlaDirectory O:\GeneralPurpose\Temp\HL_Temp"
  }
}
#endregion


#region Functions: Invoke-IHISqlAnalysisServicesXMLAFiles

<#
.SYNOPSIS
Run and install the SSAS database deployment files, this utilizes the SQL Command Line Tools after scanning for XMLA type files
.DESCRIPTION
Runs the XMLA files to reconstruct the database schema's on the necessary target server
.PARAMETER -DWDatabaseServer
Data Warehouse Server to connect to
.PARAMETER -DWDatabaseInstance
Data Instance to connect to
.PARAMETER -JobUserId
Username for the Job Account
.PARAMETER -JobPassword
Password for the Job Account
.PARAMETER -DirectoryToScan
Directory through which to scan for the XMLA files
.PARAMETER -IgnorePattern
File Name pattern to ignore when scanning the directory
.PARAMETER -XmlaConnectionFile
File that contains the XMLA connection parameters
.PARAMETER -DirectoryScan
True or False parameter that will determine whether or not to scan a directory for files, defaults to True
.PARAMETER -XmlaDirectory
Directory to scan for XMLA files
.EXAMPLE
Invoke-IHISqlAnalysisServicesXMLAFiles -Server DEVSQLSERVER -Directory \Database\DataWarehouse\SSISPackages\ConfigFiles\DEVSQLSERVER
.EXAMPLE
Invoke-IHISqlAnalysisServicesXMLAFiles DEVSQLSERVER \Database\DataWarehouse\SSISPackages\ConfigFiles\DEVSQLSERVER
#>
function Invoke-IHISqlAnalysisServicesXMLAFiles {
  #region Function parameters
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
    [string]$DWDatabaseServer,
    [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
    [string]$DWDatabaseInstance,
    [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
    [string]$DirectoryToScan,
    [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
    [string]$ignorePattern,
    [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
    [string]$JobPassword,
    [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
    [string]$JobUserId,
    [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
    [string]$XmlaConnectionFile,
    [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
    [string]$DirectoryScan,
    [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
    [string]$XmlaDirectory,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$Help
  )
  #endregion
  
  process {
    # if help requested, display and exit
    if ($Help -eq $true) { Out-IHISqlAnalysisServicesXMLAFiles; return }
    
    #region Validate parameters
    # Checking parameters to make sure the optional ones are set
    if ($XmlaPatternRegex -eq $null) {
      $XmlaPatternRegex = "xmla"
    }
    if ($DirectoryScan -eq $null) {
      $DirectoryScan = $true
    }
    if ($ignorePattern -eq $null) {
      $ignorePattern = "NoVars"
    }
    #endregion
    
    #region Verify that everything is in place
    # Check and see if the SQLAS cmdlet is installed
    if(-not(Get-Module -Name "SQLPS")) {
      Write-Host "SQLPS is not loaded, which should happen when the PowerShell shell starts.  There are problems.`n"
      exit
    }
    #endregion
    
    #region Read all the XMLA files within the specified directory or only the file
    if ($DirectoryScan -eq $true) {
      if ( ($DirectoryScan -eq $true) -and ($DirectoryToScan -ne $null)) {
        # Read the directory to obtain the list of files and select only those that have the XMLA extension
        $XmlaFileList = Get-ChildItem -Path $DirectoryToScan -Force -Recurse:$Recursive | Where-Object { $_.FullName -imatch $XmlaPatternRegex } | Where-Object { $_.FullName -inotmatch $ignorePattern }
        Write-Host "Looking at $XmlaFileList`n"
      } else {
        Write-Host "There was a problem either with $DirectoryScan or $DirectoryToScan.`n"
      }
    } else {
      Write-Host "Only reading the Connection xmla file from the Cubes location.`n"
      $XMLAFile = Join-Path -Path $XmlaDirectory -ChildPath $XmlaConnectionFile
    }
    #endregion

    #region Install the XMLA files using the command line tool
    # XMLA connection string
    $XMLAVars = "DWIHIServer=$DWDatabaseServer","DWIHIDatabase=$DWDatabaseInstance","UserName=$JobUserId","Password=$JobPassword"
    if ($DirectoryScan -eq $true) {
      foreach ($Item in $XmlaFileList) {
        # make sure object exists
        if ($true -eq (Test-Path -Path $Item.FullName)) {
    	    Write-Host "Looking at $Item`n"
          $XMLAFile = Join-Path -Path $DirectoryToScan -ChildPath $Item
          [hashtable]$Params = @{ inputFile = $XMLAFile; server = $DWDatabaseServer; variables = $XMLAVars }
          $Err = $null
          Write-Host "Invoke-ASCmd $(Convert-IHIFlattenHashtable $Params)"
          Invoke-ASCmd @Params -EV Err -outvariable MyOut
          if ($Err -ne $null -or $? -eq $false ) {
            Write-Host $MyOut
            # if error occurred, error would've been written to stream, no need to echo Err in our error
            Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Invoke-ASCmd with parameters: $(Convert-IHIFlattenHashtable $Params)"
            return
          } else {
            $MyOut | Select-string "exception" -quiet -outvariable MyOut
            if ($MyOut -ne "") {           
              # if error occurred, error would've been written to stream, no need to echo Err in our error
              Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Invoke-ASCmd with parameters: $(Convert-IHIFlattenHashtable $Params)"
              return
            }
          }
        }
      }
    } else {
      [hashtable]$Params = @{ inputFile = $XMLAFile; server = $DWDatabaseServer; variables = $XMLAVars }
      $Err = $null
      Write-Host "Invoke-ASCmd $(Convert-IHIFlattenHashtable $Params)"
      Invoke-ASCmd @Params -EV Err -outvariable MyOut
      if ($Err -ne $null -or $? -eq $false ) {
        Write-Host $MyOut
        # if error occurred, error would've been written to stream, no need to echo Err in our error
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Invoke-ASCmd with parameters: $(Convert-IHIFlattenHashtable $Params)"
        return
      } else {
        $MyOut | Select-string "exception" -quiet -outvariable MyOut
        if ($MyOut -ne "") {           
          # if error occurred, error would've been written to stream, no need to echo Err in our error
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Invoke-ASCmd with parameters: $(Convert-IHIFlattenHashtable $Params)"
          return
        }
      }
    }
    #endregion
  }
}
Export-ModuleMember -Function Invoke-IHISqlAnalysisServicesXMLAFiles
#endregion