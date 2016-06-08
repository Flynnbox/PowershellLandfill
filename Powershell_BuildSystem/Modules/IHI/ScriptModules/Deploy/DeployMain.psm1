
#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
    # variables with script-level scope are accessible anywhere in this script
    # Get start time of deploy: used as log file prefix for consistency
    [datetime]$script:StartTime = Get-Date
    [string]$script:StartTimeStamp = "{0:yyyyMMdd_HHmmss}" -f $StartTime
    # path to application xml file to process
    [string]$script:ApplicationXmlPath = $null
    # xml content of application xml file
    [xml]$script:ApplicationXml = $null
    # name of application to deploy as read from xml - not passed by original user
    [string]$script:ApplicationName = $null
    # list of user email addresses to notify for deploy: success or error
    [string[]]$script:NotificationEmails = $null
    # list of deploy server information as read from xml
    [object[]]$script:DeployServers = $null
    # full local path to verion file
    [string]$script:VersionFilePath = $null
    # name of user that launched the deploy script, may not be the same as the user the process is running as
    [string]$script:LaunchUserName = $null
    # these values must be global scope; these values are imported into task module process
    # and variables imported in must be global scope
    # this is the local root path of the folder (typically <drive>:\Deploys\Packages\<application>_<version>
    [string]$global:ApplicationDeployRootFolder = $null
    # nickname of environment deploying to
    [string]$global:EnvironmentNickname = $null
    # name of server deploying to
    [string]$global:ServerName = $null
    # version of the application to deploy as read from xml - not passed by original user
    [string]$global:Version = $null
    # prefix to use for all log files - including full folder path
    [string]$global:LogFilePrefix = $null
  }
}
# initialize/reset the module
Initialize
# ensure best practices for variable use, function calling, null property access, etc.
# must be done at module script level, not inside Initialize, or will only be function scoped
Set-StrictMode -Version 2
#endregion


#region Functions: Copy-IHILogFilesToArchiveFolder

<#
.SYNOPSIS
Copies all log files for current deploy to archive folder
.DESCRIPTION
Copies all log files for current deploy to archive folder
#>
function Copy-IHILogFilesToArchiveFolder {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    [string]$LogArchiveFolder = Join-Path -Path $Ihi:BuildDeploy.DeployFolders.DeployLogsArchive -ChildPath $($ApplicationName + "_" + $Version)
    $LogFiles = Get-ChildItem -Path $ApplicationDeployRootFolder -Recurse | Where { $_.Name -match $StartTimeStamp }
    if ($LogFiles -eq $null) {
      # write message; this is unlikely to happen but if it does isn't a critical error (don't exit script)
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: no log files found for datetime stamp: $StartTimeStamp"
      Write-Host $ErrorMessage -ForegroundColor Yellow
      Send-IHIDeployEmailError $ErrorMessage
    } else {
      $LogFiles | Copy-Item -Destination $LogArchiveFolder
    }
  }
}
#endregion


#region Functions: Send-IHIDeployEmailError, Send-IHIDeployEmailSuccess

<#
.SYNOPSIS
Helper function to send deploy error emails
.DESCRIPTION
Helper function to send deploy error emails
#>
function Send-IHIDeployEmailError {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ErrorMessage
  )
  #endregion
  process {
    # get log files to email
    $LogFiles = Get-ChildItem -Path $ApplicationDeployRootFolder -Recurse | Where { $_.Name -match $StartTimeStamp } | Select -ExpandProperty FullName
	# Get-PropertyValue FullName
    Send-IHIDeployEmail -Time $StartTime -ApplicationXmlPath $ApplicationXmlPath -To $NotificationEmails -ApplicationName $ApplicationName -Version $Version -EnvironmentNickname $EnvironmentNickname -Server $ServerName -DeployRunAsUserName $env:UserName -DeployLaunchUserName $LaunchUserName -LogFiles $LogFiles -ErrorOccurred -ErrorMessage $ErrorMessage
  }
}

<#
.SYNOPSIS
Helper function to send deploy success emails
.DESCRIPTION
Helper function to send deploy success emails
#>
function Send-IHIDeployEmailSuccess {
  #region Function parameters
  [CmdletBinding()]
  param(
  )
  #endregion
  process {
    # get log files to email
    $LogFiles = Get-ChildItem -Path $ApplicationDeployRootFolder -Recurse | Where { $_.Name -match $StartTimeStamp } | Select -ExpandProperty FullName
	# Get-PropertyValue FullName
    Send-IHIDeployEmail -Time $StartTime -ApplicationXmlPath $ApplicationXmlPath -To $NotificationEmails -ApplicationName $ApplicationName -Version $Version -EnvironmentNickname $EnvironmentNickname -Server $ServerName -DeployRunAsUserName $env:UserName -DeployLaunchUserName $LaunchUserName -LogFiles $LogFiles
  }
}
#endregion


#region Functions: Update-IHIDeployHistoryFileHelper

<#
.SYNOPSIS
Helper function to update history file
.DESCRIPTION
Helper function to update history file.  Returns false if error occurred during update.
#>
function Update-IHIDeployHistoryFileHelper {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [bool]$Success
  )
  #endregion
  process {
    [bool]$UpdateFileSuccess = $true
    $Err = $null
    Update-IHIDeployHistoryFile -Application $ApplicationName -EnvironmentNickname $EnvironmentNickname -Server (Get-IHIFQMachineName) -Version $Version -User $LaunchUserName -Date $StartTime -Success $Success -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error occurred updating deploy history file"
      Write-Error -Message $ErrorMessage
      Write-Host $ErrorMessage
      Disable-IHILogFile
      Send-IHIDeployEmailError ($ErrorMessage + " :: " + "$("$Err")")
      $UpdateFileSuccess = $false
    }
    $UpdateFileSuccess
  }
}
#endregion


#region Functions: Invoke-IHIDeployCode

<#
.SYNOPSIS
Deploys a application package that exists locally on the machine
.DESCRIPTION
Deploys a application package that exists locally on the machine.  This does
NOT copy the package to the server nor launch the processing; it is the actual
function that unzips, copies, run stores procedures, etc.
.PARAMETER ApplicationXmlPath
Full local path to application xml file
.PARAMETER EnvironmentNickname
Nickname of server deploying to
.PARAMETER LaunchUserName
Name of user that initially launched the deploy process, may not be same as user
running the process.
.EXAMPLE
Invoke-IHIDeployCode -ApplicationXmlPath c:\app.xml -EnvironmentNickname DEVAPPWEB
Deploys a application package described in c:\app.xml to DEVAPPWEB
#>
function Invoke-IHIDeployCode {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationXmlPath,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$EnvironmentNickname,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$LaunchUserName = $env:UserName
  )
  #endregion
  process {
    # make sure module initialized and set start time
    Initialize

    # make sure names are uppercase
    $EnvironmentNickname = $EnvironmentNickname.ToUpper()
    $LaunchUserName = $LaunchUserName.ToUpper()

    #region Parameter validation
    # Confirm path to xml file is valid
    if ($false -eq (Test-Path -Path $ApplicationXmlPath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: application xml path not valid: $ApplicationXmlPath"
      return
    }
    # Confirm path is a file, not a folder
    if ($true -eq (Get-Item $ApplicationXmlPath).PSIsContainer) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: application xml path is a folder, not a file: $ApplicationXmlPath"
      return
    }
    # Make sure no prefix or trailing spaces
    $EnvironmentNickname = $EnvironmentNickname.Trim()
    #endregion

    #region Set script-level ApplicationXmlPath and LaunchUserName
    # make sure these are available at script level
    # after this region, if an error email is sent, it will include these details, which are important
    # in case there are errors in the xml - at least we will know these
    $script:ApplicationXmlPath = $ApplicationXmlPath
    $script:LaunchUserName = $LaunchUserName
    #endregion

    #region Read and validate application xml
    #Validate files basic xml format
    if ($false -eq (Test-Xml -Path $ApplicationXmlPath)) {
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: application file does not contain valid xml: $ApplicationXmlPath"
      Write-Error -Message $ErrorMessage
      Send-IHIDeployEmailError $ErrorMessage
      return
    }
    # we know the file exists and is xml so no need to wrap this in try/catch
    [xml]$TempXml = [xml](Get-Content -Path $ApplicationXmlPath)
    # confirm the xml contains the standard, required settings
    $Err = $null
    Confirm-IHIValidDeployXml -ApplicationXml $TempXml -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: invalid Xml"
      Send-IHIDeployEmailError ("$($MyInvocation.MyCommand.Name):: invalid Xml:: " + "$("$Err")")
      return
    }
    # if made it to this point, xml is valid so store in private variable
    $script:ApplicationXml = $TempXml
    #endregion

    #region Get root folder of this deploy (the parent folder of XML file)
    [string]$global:ApplicationDeployRootFolder = Split-Path -Path $ApplicationXmlPath -Parent
    #endregion

    #region Read values from deploy xml
    # Xml has been validated; these properties all exist in the xml so safe to read
    $script:ApplicationName = $ApplicationXml.Application.General.Name
    $script:NotificationEmails = [string[]]$ApplicationXml.Application.General.NotificationEmails.Email
    $script:DeployServers = Get-IHIDeployServersFromXml -ApplicationXml $ApplicationXml
    #endregion

    #region Confirm version file and read/validate value
    # Confirm a version file with the same name exists in same folder
    $script:VersionFilePath = Join-Path -Path $ApplicationDeployRootFolder -ChildPath (Get-IHIApplicationVersionFileName $ApplicationName)
    if ($false -eq (Test-Path -Path $VersionFilePath)) {
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: Version files does not exist at: $VersionFilePath"
      Write-Error -Message $ErrorMessage
      Send-IHIDeployEmailError $ErrorMessage
      return
    }
    # Read content from version file
    $global:Version = Get-Content $VersionFilePath
    # Make sure value read from file is a integer
    if ($Version -notmatch "^\d+$") {
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: Version contained in version file is not a number: $Version"
      Write-Error -Message $ErrorMessage
      Send-IHIDeployEmailError $ErrorMessage
      return
    }
    #endregion

    #region Create standard log prefix and enable logging
    # Log file prefix is: Xml file folder \ Datetime stamp + Application name + version + Environment Nickname
    # For example: # <root folder>\20112808_112815_CSICONSOLE_5787_DEVAPPWEB
    # prefix must be global to pass into task module
    $global:LogFilePrefix = Join-Path -Path $ApplicationDeployRootFolder -ChildPath $StartTimeStamp
    $global:LogFilePrefix += "_" + $ApplicationName + "_" + $Version + "_" + $EnvironmentNickname
    # Main deploy log file name is prefix + "__Deploy_log.txt"
    # put in two underscores so it is at the top of the list when viewing in explorer
    [string]$LogFile = $global:LogFilePrefix + "__Deploy_log.txt"
    # enable logging
    # after this point, if exiting this function (return) because of an error, need to 
    # disable the logging by calling Disable-IHILogFile
    # also, logging needs to be disabled before calling Send-IHIDeployEmailError, which emails
    # a copy of all log files
    Enable-IHILogFile $LogFile
    #endregion

    #region Validate $EnvironmentNickname in DeploySettings.Servers, set environment/server
    # if EnvironmentNickname not found in Nickname
    $DeployServer = $DeployServers | Where-Object { $_.Nickname -eq $EnvironmentNickname }
    if ($DeployServer -eq $null) {
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: deploy target $EnvironmentNickname is not in the official environment list: $($DeployServers | Select -ExpandProperty NickName)"
	  # Get-PropertyValue -propertyName Nickname)"
      Write-Error -Message $ErrorMessage
      Disable-IHILogFile
      Update-IHIDeployHistoryFileHelper -Success $false
      Send-IHIDeployEmailError $ErrorMessage
      return
    }
    # record nickname and server in local variables
    # these variables need to be set global in order for them to be imported into task module
    $global:EnvironmentNickname = $EnvironmentNickname
    $global:ServerName = $DeployServer.Name
    #endregion

    #region Confirm deploy folder structure and files exist for this machine
    #region Create deploy folder structure if doesn't exist
    $Err = $null
    Confirm-IHIDeployRootFolder -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error confirming deploy root folder exists"
      Write-Error -Message $ErrorMessage
      Disable-IHILogFile
      Copy-IHILogFilesToArchiveFolder
      Update-IHIDeployHistoryFileHelper -Success $false
      Send-IHIDeployEmailError ($ErrorMessage + " :: " + "$("$Err")")
      return
    }
    #endregion

    #region Create deploy current version folder if doesn't exist
    $Err = $null
    Confirm-IHIDeployVersionsFolder -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error confirming current versions folder exists"
      Write-Error -Message $ErrorMessage
      Disable-IHILogFile
      Update-IHIDeployHistoryFileHelper -Success $false
      Send-IHIDeployEmailError ($ErrorMessage + " :: " + "$("$Err")")
      return
    }
    #endregion

    #region Create deploy current version \ environment nickname folder if doesn't exist
    $Err = $null
    Confirm-IHIDeployVersionsNicknameFolder $EnvironmentNickname -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error confirming current versions environment nickname folder exists"
      Write-Error -Message $ErrorMessage
      Disable-IHILogFile
      Update-IHIDeployHistoryFileHelper -Success $false
      Send-IHIDeployEmailError ($ErrorMessage + " :: " + "$("$Err")")
      return
    }
    #endregion

    #region Create deploy logs archive folder if doesn't exist
    $Err = $null
    Confirm-IHIDeployLogsArchiveFolder -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error confirming deploy logs archive folder exists"
      Write-Error -Message $ErrorMessage
      Disable-IHILogFile
      Update-IHIDeployHistoryFileHelper -Success $false
      Send-IHIDeployEmailError ($ErrorMessage + " :: " + "$("$Err")")
      return
    }
    #endregion

    #region Create deploy logs archive \ application version folder if doesn't exist
    $Err = $null
    Confirm-IHIDeployLogsArchiveAppVerFolder -ApplicationName $ApplicationName -Version $Version -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error confirming deploy logs archive application version folder exists"
      Write-Error -Message $ErrorMessage
      Disable-IHILogFile
      Update-IHIDeployHistoryFileHelper -Success $false
      Send-IHIDeployEmailError ($ErrorMessage + " :: " + "$("$Err")")
      return
    }
    #endregion

    #region Create deploy packages folder if doesn't exist
    $Err = $null
    Confirm-IHIDeployPackagesFolder -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error confirming deploy packages folder exists"
      Write-Error -Message $ErrorMessage
      Disable-IHILogFile
      Update-IHIDeployHistoryFileHelper -Success $false
      Send-IHIDeployEmailError ($ErrorMessage + " :: " + "$("$Err")")
      return
    }
    #endregion

    #region Create deploy history file if doesn't exist
    $Err = $null
    Confirm-IHIDeployHistoryFileExists -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error confirming deploy history file exists"
      Write-Error -Message $ErrorMessage
      Disable-IHILogFile
      Update-IHIDeployHistoryFileHelper -Success $false
      Send-IHIDeployEmailError ($ErrorMessage + " :: " + "$("$Err")")
      return
    }
    #endregion
    #endregion

    #region Log basic deploy information
    [int]$Col1Width = 27
    [string]$FormatString = "  {0,-$Col1Width}{1}"
    Write-Host "`nDeploying with these values:"
    Write-Host $($FormatString -f "Application name",$ApplicationName)
    Write-Host $($FormatString -f "Version",$Version)
    Write-Host $($FormatString -f "Environment nickname",$EnvironmentNickname)
    Write-Host $($FormatString -f "Launch username",$LaunchUserName)
    Write-Host $($FormatString -f "RunAs username",$env:UserName)
    Write-Host $($FormatString -f "Start time",$StartTime)
    #endregion

    #region Unzip code release package zip file if present
    # unzip code release package zip file if present (may not, for builds with just deploy code steps)
    $Err = $null
    Expand-IHICodeReleasePackage $ApplicationDeployRootFolder -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error expanding code release package"
      Write-Error -Message $ErrorMessage
      Disable-IHILogFile
      Copy-IHILogFilesToArchiveFolder
      Update-IHIDeployHistoryFileHelper -Success $false
      Send-IHIDeployEmailError ($ErrorMessage + " :: " + "$("$Err")")
      return
    }
    #endregion

    #region Process DeployTasks.TaskProcess steps
    # first initialize task process module with the xml; if the xml is valid and the basic
    # xml properties are found, it will load without error
    Write-Host ""
    Write-Host "Initializing task process module with DeployTasks.TaskProcess..."
    $Err = $null
    Initialize-IHITaskProcessModule $ApplicationXml.Application.DeploySettings.DeployTasks.TaskProcess -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error occurred initializing task process module with xml data"
      Write-Error -Message $ErrorMessage
      Write-Host $ErrorMessage
      Disable-IHILogFile
      Copy-IHILogFilesToArchiveFolder
      Update-IHIDeployHistoryFileHelper -Success $false
      Send-IHIDeployEmailError ($ErrorMessage + " :: " + "$("$Err")")
      return
    }
    Add-IHILogIndentLevel
    Write-Host "Initialize complete"
    Remove-IHILogIndentLevel

    # now invoke task process
    Write-Host ""
    Write-Host "Invoking DeployTasks.TaskProcess..."
    # indent for easier reading
    Add-IHILogIndentLevel
    $Err = $null
    Invoke-IHITaskProcess -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error occurred invoking task process "
      Write-Error -Message $ErrorMessage
      Write-Host $ErrorMessage
      Remove-IHILogIndentLevel
      Disable-IHILogFile
      Copy-IHILogFilesToArchiveFolder
      Update-IHIDeployHistoryFileHelper -Success $false
      Send-IHIDeployEmailError ($ErrorMessage + " :: " + "$("$Err")")
      return
    }
    # remove task indent
    Remove-IHILogIndentLevel
    #endregion

    #region Copy version file to CurrentVersion\<EnvironmentNickname> folder
    Write-Host ""
    Write-Host "Copying version file to version folder..."
    $Err = $null
    [string]$DeployVersionFileFolder = Join-Path -Path $Ihi:BuildDeploy.DeployFolders.CurrentVersions -ChildPath $EnvironmentNickname -EV Err
    if ($Err -ne $null) {
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error joining path of version destination folder path :: $("$Err")"
      Write-Error -Message $ErrorMessage
      Write-Host $ErrorMessage
      Disable-IHILogFile
      Copy-IHILogFilesToArchiveFolder
      Update-IHIDeployHistoryFileHelper -Success $false
      Send-IHIDeployEmailError $ErrorMessage
      return
    }
    $Results = Copy-Item -Path $VersionFilePath -Destination $DeployVersionFileFolder -Force 2>&1
    if ($? -eq $false) {
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error occurred updating version file $VersionFilePath in server/environment version folder $DeployVersionFileFolder :: $("$Results")"
      Write-Error -Message $ErrorMessage
      Write-Host $ErrorMessage
      Disable-IHILogFile
      Copy-IHILogFilesToArchiveFolder
      Update-IHIDeployHistoryFileHelper -Success $false
      Send-IHIDeployEmailError $ErrorMessage
      return
    }
    Add-IHILogIndentLevel
    Write-Host "Copy complete"
    Remove-IHILogIndentLevel
    #endregion

    #region Update deploy history file
    Write-Host ""
    Write-Host "Updating deploy history file..."
    if ((Update-IHIDeployHistoryFileHelper -Success $true) -eq $false) { return }
    Add-IHILogIndentLevel
    Write-Host "Update complete"
    Remove-IHILogIndentLevel
    #endregion

    #region Deploy process is complete; disable logging
    Write-Host ""
    Write-Host "Deploy process is complete"
    Write-Host ""
    # Disable logging
    Disable-IHILogFile
    #endregion

    #region Send email when done
    # must be done after logging disabled as it sends a copy of the log file
    Write-Host "Sending deploy success email"
    Add-IHILogIndentLevel
    Send-IHIDeployEmailSuccess
    Remove-IHILogIndentLevel
    #endregion

    #region Copy deploy log files to permanent log archive folder
    # must be done after logging disabled as it copies the files (don't want a file lock)
    Write-Host ""
    Write-Host "Copying deploy log files to permanent log archive folder..."
    Copy-IHILogFilesToArchiveFolder
    Add-IHILogIndentLevel
    Write-Host "Copy complete"
    Remove-IHILogIndentLevel
    #endregion
  }
}
Export-ModuleMember -Function Invoke-IHIDeployCode
#endregion
