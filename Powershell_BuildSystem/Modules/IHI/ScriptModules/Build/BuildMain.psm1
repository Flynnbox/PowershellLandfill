#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
    # defaults for writing version file
    [hashtable]$script:OutFileSettings = @{ Encoding = "ascii"; Force = $true; Append = $true }
    # constant to help identify when params not passed
    [string]$script:NotPassed = "NOT_PASSED"
    # help message
    [string]$script:HelpMessage = "`nFor full parameter and usage information type: build -Help`n"
    # variables with script-level scope are accessible anywhere in this script
    # Get start time of build: used as log file prefix for consistency
    [datetime]$script:StartTime = Get-Date
    [string]$script:StartTimeStamp = "{0:yyyyMMdd_HHmmss}" -f $StartTime
    # application name to build
    [string]$script:ApplicationName = $null
    # name of user that launched the build script, may not be the same as the user the process is running as
    [string]$script:LaunchUserName = $null
    # this is the local root path of the folder (typically c:\temp\Builds\Packages\<datetimestamp>
    [string]$script:BuildDeployConfigsFolder = $null
    # path to application xml file to process
    [string]$script:ApplicationXmlPath = $null
    # xml content of application xml file
    [xml]$script:ApplicationXml = $null
    # this is the path of the local release folder (typically c:\temp\Builds\Packages\<datetimestamp>\<application name>_<version>
    # this release folder is build up then copied to the final releases location
    [string]$script:LocalReleaseFolderPath = $null
    # path to logs folder under local release folder
    [string]$script:LocalReleaseLogsFolderPath = $null
    # list of user email addresses to notify for deploy: success or error
    [string[]]$script:NotificationEmails = $null

    # these values must be global scope; these values are imported into task module process
    # and variables imported in must be global scope

    # application version to build
    [string]$global:Version = $null
    # this is the local root path of the folder (typically c:\temp\Builds\Packages\<datetimestamp>
    [string]$global:ApplicationBuildRootFolderPath = $null
    # prefix to use for all log files - including full folder path
    [string]$global:LogFilePrefix = $null
    # this is the path of the zip folder (typically c:\temp\Builds\Packages\<datetimestamp>\___ZipFolder
    [string]$global:ZipFolderPath = $null
  }
}
# initialize/reset the module
Initialize
# ensure best practices for variable use, function calling, null property access, etc.
# must be done at module script level, not inside Initialize, or will only be function scoped
Set-StrictMode -Version 2
#endregion


#region Functions: Confirm-IHIBuildRootFolder

<#
.SYNOPSIS
Creates a new build root folder
.DESCRIPTION
Creates a new build root folder: $Ihi:Folders.TempFolder\Builds\<datetimestamp>
.EXAMPLE
Confirm-IHIBuildRootFolder
Creates a new build root folder
#>
function Confirm-IHIBuildRootFolder {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    Write-Host "Create temporary build folder"
    # When running the post-commit system, especially during development with the old and new system
    # running simultaneously, there is a great tendency for builds to be started at the same time.
    # The _exact_ same time.  Meaning datetime stamps are not unique, even if you use up to ten
    # thousandths of a second.
    # So, to ensure that we do not have a conflict:
    #  - use the process id in the folder name
    #  - use the process id as the seed value in an Get-Random call with a large max value
    #  - check to see if a folder with that pid and random number exist
    #  - if no folder, then create else loop, generate new random number and try again

    # keep looking until we find a folder that doesn't exist yet
    [string]$FolderToCreateRootName = Join-Path -Path $($Ihi:Folders.TempFolder) -ChildPath $("Builds\{0}" -f $pid)
    [string]$FolderToCreate = $null
    do {
      # add random number to the end to get new $FolderToCreate
      # use the id of the process to set the seed to ensure that multiple instances of this script,
      # launched at the same time, do not share the same 'random' values (because, believe me, they will)
      # also throw on a partial time stamp (just hours, minutes second and milliseconds) so multiple builds
      # done by one post commit (done in serial) have different folder names in case of error
      $FolderToCreate = $FolderToCreateRootName + "_" + (Get-Random -Minimum 1 -Maximum 99999 -SetSeed $pid) + "_" + ("{0:HHmmssfff}" -f (Get-Date))
    } while ($true -eq (Test-Path -Path $FolderToCreate))

    # folder should NOT exist, let's try to create
    if ($false -eq (Test-Path -Path $FolderToCreate)) {
      $Results = New-Item -Path $FolderToCreate -ItemType Directory 2>&1
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating build root folder $FolderToCreate :: $("$Results")"
        return
      } else {
        # worked successfully; store value now
        $global:ApplicationBuildRootFolderPath = $FolderToCreate
      }
    } else {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: a folder for the exact same datetime stamp exists, the odds for this are really slim.  Buy a lottery ticket... or just re-run the build."
      return
    }
  }
}
#endregion


#region Functions: Confirm-IHILocalReleaseFolder

<#
.SYNOPSIS
Creates a new local release folder <application name>_<version> and logs folder
.DESCRIPTION
Creates a new local release folder <application name>_<version> and logs folder
.EXAMPLE
Confirm-IHILocalReleaseFolder
Creates a new local release folder <application name>_<version> and logs folder
#>
function Confirm-IHILocalReleaseFolder {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    [string]$FolderToCreate = Join-Path -Path $ApplicationBuildRootFolderPath -ChildPath (Get-IHIApplicationPackageFolderName -ApplicationName $ApplicationName -Version $Version)
    $Results = New-Item -Path $FolderToCreate -ItemType Directory 2>&1
    if ($? -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating local release folder $FolderToCreate :: $("$Results")"
      return
    } else {
      # worked successfully; store value now
      $script:LocalReleaseFolderPath = $FolderToCreate
      # now create logs folder
      [string]$FolderToCreate = Join-Path -Path $LocalReleaseFolderPath -ChildPath "_BuildLogs"
      $Results = New-Item -Path $FolderToCreate -ItemType Directory 2>&1
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating local release logs folder $FolderToCreate :: $("$Results")"
        return
      } else {
        # worked successfully; store value now
        $script:LocalReleaseLogsFolderPath = $FolderToCreate
      }
    }
  }
}
#endregion


#region Functions: Confirm-IHIZipFolder

<#
.SYNOPSIS
Creates a new zip folder
.DESCRIPTION
Creates a new zip folder: $Ihi:Folders.TempFolder\Builds\<datetimestamp>\___ZipFolder
.EXAMPLE
Confirm-IHIZipFolder
Creates a new zip folder
#>
function Confirm-IHIZipFolder {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    [string]$FolderToCreate = Join-Path -Path $ApplicationBuildRootFolderPath -ChildPath "___ZipFolder"
    $Results = New-Item -Path $FolderToCreate -ItemType Directory 2>&1
    if ($? -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating zip folder $FolderToCreate :: $("$Results")"
      return
    } else {
      # worked successfully; store value now
      $global:ZipFolderPath = $FolderToCreate
    }
  }
}
#endregion


#region Functions: Get-IHIBuildDeployConfigs

<#
.SYNOPSIS
Gets BuildDeploy script from repository
.DESCRIPTION
Gets BuildDeploy script from repository
.EXAMPLE
Get-IHIBuildDeployConfigs
Gets BuildDeploy script from repository
#>
function Get-IHIBuildDeployConfigs {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    # this path is the parent folder of the configs folder; for now, use this to retrive Configs folder
    # then use actual child value as permanent value
    Write-Host "Get latest application build/deploy configs"
    Add-IHILogIndentLevel
    [string]$FolderToCreate = Join-Path -Path $ApplicationBuildRootFolderPath -ChildPath "___BuildDeployConfigs"
    $Err = $null
    Export-IHIRepositoryContent -UrlPath $IHI:BuildDeploy.ApplicationConfigsRootUrlPath -LocalPath $FolderToCreate -EV Err
    if ($Err -ne $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error attempting to get application build deploy configs :: FolderToCreate = $FolderToCreate :: $("$Err")"
      return
    } else {
      # worked successfully; store child folder value now
      $script:BuildDeployConfigsFolder = Join-Path -Path $FolderToCreate -ChildPath "Configs"
    }
  }
}
#endregion


#region Functions: Set-IHIApplicationName

<#
.SYNOPSIS
Validates and sets value for ApplicationName
.DESCRIPTION
Validates and sets value for ApplicationName; returns $true if successful; if error occurs, 
writes errors messages to host (not error stream) and returns $false
.PARAMETER ApplicationName
Name of application to validate and set
.EXAMPLE
Set-IHIApplicationName -ApplicationName Extranet
Validates and sets value for ApplicationName to Extranet
#>
function Set-IHIApplicationName {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationName
  )
  #endregion
  process {
    $Success = $true
    # make sure application name is all uppercase
    $ApplicationName = $ApplicationName.ToUpper()
    # get list of valid application names from local file listing
    $ValidApplicationNames = Get-IHIApplicationNames -ConfigRootPath $BuildDeployConfigsFolder
    # if no application name specified, ask for one
    if ($ApplicationName -eq $NotPassed) {
      $Success = $false
      Write-Host "`nPlease specify an application name to build." -ForegroundColor Yellow
      # else if invalid application name display error message
    } elseif ($ValidApplicationNames -notcontains $ApplicationName) {
      $Success = $false
      # need to remove 2 indents before writing this; will restore
      Remove-IHILogIndentLevel; Remove-IHILogIndentLevel
      Write-Host "`nSorry, " -ForegroundColor Yellow -NoNewline
      Write-Host $ApplicationName -ForegroundColor Cyan -NoNewline
      Write-Host " is not a valid application name." -ForegroundColor Yellow
      Add-IHILogIndentLevel; Add-IHILogIndentLevel
    }
    # if bad param, display list of valid names and return
    if ($Success -eq $false) {
      Write-Host "`nValid application names:"
      Out-IHIToOrderedColumns -ListToDisplay $ValidApplicationNames -Columns 4
      Write-Host $HelpMessage
    } else {
      # it is valid so store in global context
      $script:ApplicationName = $ApplicationName
    }
    $Success
  }
}
#endregion


#region Functions: Set-IHIBuildApplicationConfigPath

<#
.SYNOPSIS
Validates and sets value for ApplicationXmlPath
.DESCRIPTION
Validates and sets value for ApplicationXmlPath; returns $true 
if successful; if error occurs, writes errors messages to host (not error stream)
and returns $false
.EXAMPLE
Set-IHIBuildApplicationConfigPath
Validates and sets value for ApplicationXmlPath
#>
function Set-IHIBuildApplicationConfigPath {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    # we know config file already exists - validated when application name was validated
    $script:ApplicationXmlPath = (Get-ChildItem -Path $BuildDeployConfigsFolder -Recurse | Where-Object { $_.Name -eq (Get-IHIApplicationConfigFileName -ApplicationName $ApplicationName) }).FullName
  }
}
#endregion


#region Functions: Send-IHIBuildEmailError, Send-IHIBuildEmailSuccess

<#
.SYNOPSIS
Helper function to send Build error emails
.DESCRIPTION
Helper function to send Build error emails
.EXAMPLE
Sends build email with error information
#>
function Send-IHIBuildEmailError {
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
    $LogFiles = Get-ChildItem -Path $ApplicationBuildRootFolderPath -Filter *_log.txt | Select -ExpandProperty FullName
	# Get-PropertyValue FullName
    Send-IHIBuildEmail -Time $StartTime -To $NotificationEmails -ApplicationName $ApplicationName -Version $Version -BuildRunAsUserName $env:UserName -BuildLaunchUserName $LaunchUserName -LogFiles $LogFiles -ErrorOccurred -ErrorMessage $ErrorMessage
  }
}

<#
.SYNOPSIS
Helper function to send Build success emails
.DESCRIPTION
Helper function to send Build success emails
.EXAMPLE
Send-IHIBuildEmailSuccess
Sends build email with information
#>
function Send-IHIBuildEmailSuccess {
  #region Function parameters
  [CmdletBinding()]
  param(
  )
  #endregion
  process {
    # get log files to email
    $LogFiles = Get-ChildItem -Path $ApplicationBuildRootFolderPath -Filter *_log.txt | Select -ExpandProperty FullName
    Send-IHIBuildEmail -Time $StartTime -To $NotificationEmails -ApplicationName $ApplicationName -Version $Version -BuildRunAsUserName $env:UserName -BuildLaunchUserName $LaunchUserName -LogFiles $LogFiles
  }
}
#endregion


#region Functions: Set-IHIApplicationConfigXml

<#
.SYNOPSIS
Validates and sets value for ApplicationConfigXml
.DESCRIPTION
Validates and sets value for ApplicationConfigXml
.EXAMPLE
Set-IHIApplicationConfigXml
Validates and sets value for ApplicationConfigXml
#>
function Set-IHIApplicationConfigXml {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    if ($false -eq (Test-Xml -Path $ApplicationXmlPath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: application file does not contain valid xml: $ApplicationXmlPath"
      return
    }
    # we know the file exists and is xml so no need to wrap this in try/catch
    [xml]$TempXml = [xml](Get-Content -Path $ApplicationXmlPath)
    # confirm the xml contains the standard, required settings
    $Err = $null
    Confirm-IHIValidXmlGeneral -ApplicationXml $TempXml -EV Err
    if ($Err -ne $null) {
      $Err | Write-Error
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error detected in Xml section General: $ApplicationXmlPath"
      Write-Error -Message $ErrorMessage
      $ErrorMessage += $("$Err")
      Send-IHIBuildEmailError -ErrorMessage $ErrorMessage
      return
    }
    # no errors in xml; set value
    $script:ApplicationXml = $TempXml
    # and read the notification emails list
    $script:NotificationEmails = [string[]]$ApplicationXml.Application.General.NotificationEmails.Email
  }
}
#endregion


#region Functions: Invoke-IHIBuildCode

<#
.SYNOPSIS
Builds an application package
.DESCRIPTION
Builds an application package.  If Version is specified, uses that version
of the repository when building.
.PARAMETER ApplicationName
Name of application to build
.PARAMETER Version
Version to build; if not specified, uses HEAD
.PARAMETER LaunchUserName
Name of user that launched build process
.PARAMETER TestBuild
If specified, runs entire build process but doesn't copy package at end to Releases folder.
This is typically used for performing test builds to make sure any new code compiles and builds
correctly.
.EXAMPLE
Invoke-IHIBuildCode -ApplicationName Extranet -Version 9876
Builds Extranet version 9876
#>
function Invoke-IHIBuildCode {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$ApplicationName = $NotPassed,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [int]$Version = 1,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$LaunchUserName = $env:UserName,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$TestBuild
  )
  #endregion
  process {
    # make sure module initialized and set start time
    Initialize

    # make sure names are uppercase
    $ApplicationName = $ApplicationName.ToUpper()
    $LaunchUserName = $LaunchUserName.ToUpper()

    # confirm client machine is on IHI network/vpn
    if ((Confirm-IHIClientMachineOnIhiNetwork) -eq $false) { return }

    #region Write Launching
    Write-Host ""
    if ($Version -eq 1) {
      Write-Host "Launching build of $ApplicationName"
    } else {
      Write-Host "Launching build of $ApplicationName $Version"
    }
    Add-IHILogIndentLevel
    #endregion

    #region Validate/set Version

    #region Validate Version is positive integer
    Write-Host "Validate version"
    if ($Version -notmatch "^\d+$") {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: version $Version is not a valid version"
      return
    }
    #endregion
    # Get HEAD revision number
    Write-Host "Get repository head version"
    $Err = $null
    [int]$HeadVersion = Get-IHIRepositoryHeadVersion -EV Err
    if ($Err -ne $null) {
      $Err | Write-Error
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error attempting to get repository head version"
      Write-Error -Message $ErrorMessage
      $ErrorMessage += $("$Err")
      Send-IHIBuildEmailError -ErrorMessage $ErrorMessage
      return
    }
    #region if no version specified, use HEAD else make sure version is less than or equal to HEAD
    if ($Version -eq 1) {
      $Version = $HeadVersion
    } else {
      if ($Version -gt $HeadVersion) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: version $Version is greater than HEAD version $HeadVersion"
        return
      }
    }
    #endregion
    # set script-level variable
    $global:Version = $Version
    #endregion

    #region Confirm package does not already exist
    # before creating any local files, check to see if already exists
    [string]$FinalReleaseFolder = Join-Path -Path $Ihi:BuildDeploy.ReleasesFolder -ChildPath (Get-IHIApplicationPackageFolderName -ApplicationName $ApplicationName -Version $Version)
    if ($true -eq (Test-Path -Path $FinalReleaseFolder)) {
      Write-Host "`nBuild version $Version of $ApplicationName already exists, no need to rebuild.`n" -ForegroundColor Yellow
      Remove-IHILogIndentLevel; return
    }
    #endregion

    # Ok, we are past the basic user validation-type errors.  For any errors beyond this point, 
    # email about any errors that occur.

    #region Create build root folder
    $Err = $null
    # creates root build folder and sets script-level variable to value
    Confirm-IHIBuildRootFolder -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      Send-IHIBuildEmailError -ErrorMessage $("$Err")
      Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
    }
    #endregion

    #region Get build deploy scripts folder
    $Err = $null
    # gets build deploy scripts folder from repository and sets script-level variable to value
    Get-IHIBuildDeployConfigs -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      Send-IHIBuildEmailError -ErrorMessage $("$Err")
      Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
    }
    #endregion

    #region Validate and set application name and config file
    if ((Set-IHIApplicationName -ApplicationName $ApplicationName) -eq $false) {
      Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
    }
    # validate and set application config file; doesn't generate errors, no need to check
    Set-IHIBuildApplicationConfigPath
    #endregion

    #region Store username of person that launched process
    $script:LaunchUserName = $LaunchUserName
    #endregion

    #region Remove indents from pre-build process
    Remove-IHILogIndentLevel; Remove-IHILogIndentLevel
    #endregion

    #region Create standard log prefix and enable logging
    # Log file prefix is: build root \ Application name + version  i.e.  <root folder>\CSICONSOLE_5787
    # prefix must be global to pass into task module
    $global:LogFilePrefix = Join-Path -Path $ApplicationBuildRootFolderPath -ChildPath (Get-IHIApplicationPackageFolderName -ApplicationName $ApplicationName -Version $Version)
    # Main deploy log file name is prefix + "__Build_log.txt"
    # put in two underscores so it is at the top of the list when viewing in explorer
    [string]$LogFile = $global:LogFilePrefix + "__Build_log.txt"
    # enable logging
    # after this point, if exiting this function (return) because of an error, need to 
    # disable the logging by calling Disable-IHILogFile
    # also, logging needs to be disabled before calling Send-IHIDeployEmailError, which emails
    # a copy of all log files
    Enable-IHILogFile $LogFile
    #endregion

    #region Log basic build information
    [int]$Col1Width = 27
    [string]$FormatString = "  {0,-$Col1Width}{1}"
    Write-Host ""
    Write-Host "Building with these values:"
    Write-Host $($FormatString -f "ApplicationName",$ApplicationName)
    Write-Host $($FormatString -f "Version",$Version)
    Write-Host $($FormatString -f "Launch username",$LaunchUserName)
    #endregion

    #region Validate/set application config xml
    $Err = $null
    Set-IHIApplicationConfigXml -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      Disable-IHILogFile
      Send-IHIBuildEmailError -ErrorMessage $("$Err")
      return
    }
    #endregion

    #region Create zip folder
    $Err = $null
    # creates root build folder and sets script-level variable to value
    Confirm-IHIZipFolder -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      Disable-IHILogFile
      Send-IHIBuildEmailError -ErrorMessage $("$Err")
      return
    }
    #endregion

    #region Create release folder
    $Err = $null
    # creates root build folder and sets script-level variable to value
    Confirm-IHILocalReleaseFolder -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      Disable-IHILogFile
      Send-IHIBuildEmailError -ErrorMessage $("$Err")
      return
    }
    #endregion

    #region Process BuildTasks.TaskProcess steps
    # first initialize task process module with the xml; if the xml is valid and the basic
    # xml properties are found, it will load without error
    Write-Host ""
    Write-Host "Initializing task process module with BuildTasks.TaskProcess..."
    $Err = $null
    Initialize-IHITaskProcessModule $ApplicationXml.Application.BuildSettings.BuildTasks.TaskProcess -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error occurred initializing task process module with xml data"
      Write-Error -Message $ErrorMessage
      Write-Host $ErrorMessage
      Disable-IHILogFile
      Send-IHIBuildEmailError -ErrorMessage $($ErrorMessage + " :: " + "$Err")
      return
    }
    Add-IHILogIndentLevel
    Write-Host "TaskProcess Initialize complete"
    Remove-IHILogIndentLevel

    # now invoke task process
    Write-Host ""
    Write-Host "Invoking BuildTasks.TaskProcess..."
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
      Send-IHIBuildEmailError -ErrorMessage $($ErrorMessage + " :: " + "$Err")
      return
    }
    # remove task indent
    Remove-IHILogIndentLevel
    #endregion

    #region Package up release package
    Write-Host ""
    Write-Host "Task processing complete; running packaging wrap up tasks"
    Add-IHILogIndentLevel

    #region Zip up package if deploy files exist
    Write-Host "Checking for files to package into zip"
    Add-IHILogIndentLevel
    # only call zip if there are files to zip up
    if ($null -ne (Get-ChildItem -Path $ZipFolderPath)) {
      Write-Host "Zipping up files"
      # zip file is written directly into release folder
      $ZipFilePath = Join-Path -Path $LocalReleaseFolderPath -ChildPath "CodeReleasePackage.zip"
      $Err = $null
      Compress-IHICodeReleasePackage -SourceRootFolderPath $ZipFolderPath -ZipFilePath $ZipFilePath -EV Err
      if ($Err -ne $null) {
        $Err | Write-Host
        Remove-IHILogIndentLevel; Remove-IHILogIndentLevel
        Disable-IHILogFile
        Send-IHIBuildEmailError -ErrorMessage $("$Err")
        return
      }
    } else {
      Write-Host "No files to zip"
    }
    Remove-IHILogIndentLevel
    #endregion

    #region Copy application xml file to local release folder
    Write-Host "Copying application xml to local release folder"
    $Results = Copy-Item -Path $ApplicationXmlPath -Destination $LocalReleaseFolderPath
    if ($? -eq $false) {
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error occurred copying application xml from $ApplicationXmlPath to $LocalReleaseFolderPath :: $("$Results")"
      Write-Error -Message $ErrorMessage
      Write-Host $ErrorMessage
      Disable-IHILogFile
      Send-IHIBuildEmailError -ErrorMessage $ErrorMessage
      return
    }
    #endregion

    #region Write version file into local release folder
    Write-Host "Writing version file to Release folder"
    [hashtable]$Params = @{ InputObject = $Version; FilePath = $(Join-Path -Path $LocalReleaseFolderPath -ChildPath (Get-IHIApplicationVersionFileName -ApplicationName $ApplicationName)) } + $OutFileSettings
    $Err = $null
    Out-File @Params -ErrorVariable Err
    if ($? -eq $false) {
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Err")"
      Write-Error -Message $ErrorMessage
      Disable-IHILogFile
      Send-IHIBuildEmailError -ErrorMessage $ErrorMessage
      return
    }
    #endregion

    #region Create Release Notes
    Get-IHIReleaseNotesForBuild -ApplicationName $ApplicationName -BuildVersion $Version -ApplicationConfigsFolder $BuildDeployConfigsFolder -OutputFolderPath $LocalReleaseFolderPath -EV Err
      if ($Err -ne $null) {
        $Err | Write-Host
        #Remove-IHILogIndentLevel; Remove-IHILogIndentLevel
        #Disable-IHILogFile
        #Send-IHIBuildEmailError -ErrorMessage $("$Err")
        #return
      }
    #endregion

    #region Disable logging
    Write-Host "Local package build tasks complete; disable logging`n"
    # disable logging so can copy completed log file to release logs folder
    Remove-IHILogIndentLevel
    Disable-IHILogFile
    #endregion
    #endregion

    #region Post-package steps: copy package to network Releases folder, delete local
    Write-Host "Wrapping up build"
    Add-IHILogIndentLevel

    #region Copy build logs into local release logs folder
    Write-Host "Copy build logs into local release logs folder"
    $Results = (Get-ChildItem -Path $ApplicationBuildRootFolderPath -Filter *_log.txt | Copy-Item -Destination $LocalReleaseLogsFolderPath) 2>&1
    if ($? -eq $false) {
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error copying build logs int release logs folder :: $("$Results")"
      Write-Error -Message $ErrorMessage
      Send-IHIBuildEmailError -ErrorMessage $ErrorMessage
      return
    }
    #endregion

    #region Copy release package to Releases folder
    # if this is a test build, don't copy to server
    if ($TestBuild) {
      Write-Host "Test build - do not copy to Releases folder"
    } else {
      Write-Host "Copy release package to Releases folder"
      $Results = (Copy-Item -Path $LocalReleaseFolderPath -Destination $Ihi:BuildDeploy.ReleasesFolder -Recurse) 2>&1
      if ($? -eq $false) {
        [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error copying release package to Releases folder :: $("$Results")"
        Write-Error -Message $ErrorMessage
        Send-IHIBuildEmailError -ErrorMessage $ErrorMessage
        return
      }
    }
    #endregion

    #region Send successful build email
    # only send build email if not $TestBuild
    if ($false -eq $TestBuild) {
      Send-IHIBuildEmailSuccess
    }
    #endregion

    #region Delete local build folder
    Write-Host "Removing temporary build folder"
    $Results = Remove-Item -Path $ApplicationBuildRootFolderPath -Recurse -Force 2>&1
    if ($? -eq $false) {
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error removing temporary build folder :: $("$Results")"
      Write-Error -Message $ErrorMessage
      Send-IHIBuildEmailError -ErrorMessage $ErrorMessage
      return
    }
    Write-Host "Build completed successfully`n"
    Remove-IHILogIndentLevel
    #endregion
    #endregion

    # only write deploy message if not a test build, and note when to use deploy or deployps
    # Write-Host "Doing a check on the $ApplicationName to see how it matches to POWERSHELL3.`n"
	[string]$deployName = if($ApplicationName -eq "POWERSHELL3") {"deployps"} else {"deploy $ApplicationName"}
    if (!$TestBuild) { Write-Host "Deploy with: $deployName $Version [SERVER]`n" -ForegroundColor Yellow }

    # if this is a build server, do an explicit exit at the end to make sure process completes
    if ("ENGBUILD" -contains $env:COMPUTERNAME) { exit }
  }
}
Export-ModuleMember -Function Invoke-IHIBuildCode
#endregion


#region Functions: Get-IHIReleaseNotesForBuild

<#
.SYNOPSIS
Creates a ReleaseNotes_ApplicationName_Version.txt file within the Release Package directory. 
.DESCRIPTION
For a given ApplicationName, gathers all SVN Commit Notes between the Minimum Deployed Server Versions and the BuildVersion.
This is called by the Build code.
.PARAMETER ApplicationName
The Application Name that you want Release Notes for
.PARAMETER BuildVersion
The Version of the Build you're creating the Release Notes For
.PARAMETER ApplicationConfigsFolder
The directory where the Build Deploy configs reside
.PARAMETER OutputFolderPath
The directory where the Release Notes File will be placed
.EXAMPLE
Create-HLReleaseNotes -ApplicationName SPRINGS
Outputs Release Notes to the screen for SPRINGS
#>
function Get-IHIReleaseNotesForBuild {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationName,    
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [int]$BuildVersion,   
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationConfigsFolder ,   
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputFolderPath
    )
  #endregion
  process {
  
    #region Analyze Application Configs in order to gather SVNProjectPaths     
    [hashtable]$AppConfigXmlMatchData = Analyze-IHIApplicationConfigFiles -LocalApplicationConfigsPath $ApplicationConfigsFolder
    #endregion

    #region Get Version Information from Deployed Versions
    [string]$MaxVersion = $BuildVersion
    $DeployedVersions = Get-IHIApplicationDeployedVersions -ApplicationName $ApplicationName -PSObject | Where {$_.Version -gt 0}
    #endregion
    #region Get Release Notes only if there are deployed versions available
    if ($DeployedVersions -ne $null) {
        $MinVersion = $($DeployedVersions.Version | measure -Minimum).Minimum
        $MinVersion = $MinVersion + 1
        $VersionRange = [string]$MinVersion + ":" + [string]$MaxVersion
    
    
    
        # Use Write-Output and Out-File to output the Release Notes File
        $LogFile = "ReleaseNotes_" + $ApplicationName + "_" + $BuildVersion + ".txt"
        $LogFile = Join-Path $OutputFolderPath -ChildPath $LogFile
    
        Write-Host "Write SVN Log Entries to $Logfile"

        #region Write Release Notes Header
        [int]$HeaderFooterCol1Width = 18
        [int]$HeaderFooterBarLength = 85
        [string]$HeaderFooterBarChar = "#"

        Write-Output ""| Out-File -FilePath $LogFile -Force
        [string]$FormatString = "{0,-$HeaderFooterCol1Width}{1}"
        Write-Output $($HeaderFooterBarChar * $HeaderFooterBarLength)  | Out-File -FilePath $LogFile -Append
        Write-Output $($FormatString -f "Application:",$ApplicationName) | Out-File -FilePath $LogFile -Append
        Write-Output $($FormatString -f "Version Range:",$VersionRange) | Out-File -FilePath $LogFile -Append
        Write-Output $($FormatString -f "User",($ENV:USERDOMAIN + "\" + $ENV:USERNAME)) | Out-File -FilePath $LogFile -Append
        $StartTime = Get-Date
        Write-Output $($FormatString -f "Start time",$StartTime) | Out-File -FilePath $LogFile -Append
        Write-Output $($HeaderFooterBarChar * $HeaderFooterBarLength) | Out-File -FilePath $LogFile -Append
        Write-Output "" | Out-File -FilePath $LogFile -Append
        #endregion

        #region Gather and output SVN Log info

        foreach ($SVNProjectPath in $AppConfigXmlMatchData.$ApplicationName.SVNProjectPaths)
        {
            Write-Output "$SVNProjectPath" | Out-File -FilePath $LogFile -Append
            [string]$Cmd = $Ihi:Applications.Repository.SubversionUtility
            [string[]]$Params = "log",($Ihi:BuildDeploy.SvnMain.RepositoryRootUrl + $SVNProjectPath),"--username",$($Ihi:BuildDeploy.SvnMain.ReadOnlyAccount.UserName),"--password",$($Ihi:BuildDeploy.SvnMain.ReadOnlyAccount.Password),"-r",$VersionRange,"--no-auth-cache","--xml"
            $LastExitCode = 0
            $Results = & $Cmd $Params 2>&1
            if ($? -eq $false -or $LastExitCode -ne 0) {
              Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred calling svn log from repository with parameters: $("$Cmd $Params") :: $("$Results")"
              return
            }
            [xml]$svnlog = $null
            $svnlog = $Results
            if ($svnlog.log -ne ""){
               $svnlog.log.logentry | Format-Table Revision, Author, @{Label="Date";Expression={(get-date -date $_.date -format d)}},msg -wrap -AutoSize | Out-File -FilePath $LogFile -Append
            }
            Write-Output "" | Out-File -FilePath $LogFile -Append

        }
        #endregion
    
        #region Write Release Notes Footer

        Write-Output "" | Out-File -FilePath $LogFile -Append
        [string]$FormatString = "{0,-$HeaderFooterCol1Width}{1}"
        Write-Output $($HeaderFooterBarChar * $HeaderFooterBarLength)  | Out-File -FilePath $LogFile -Append
        Write-Output ""  | Out-File -FilePath $LogFile -Append
        #endregion
    }
    #endregion
  }
}

Export-ModuleMember -Function Get-IHIReleaseNotesForBuild
#endregion


#region Functions: Get-IHIReleaseNotes

<#
.SYNOPSIS
Creates a ReleaseNotes_ApplicationName_Version.txt file within the current directory. 
.DESCRIPTION
For a given ApplicationName, gathers all SVN Commit Notes between the Minimum Deployed Server Versions 
and the Version passed in. Outputs a release notes file in the current directory, named
ReleaseNotes_<ApplicationName>_<Version>.txt
Note: This requires C:\IHI_Main\Trunk\PowerShell3\Main\BuildDeploy\Configs to exist.
.PARAMETER ApplicationName
The Application Name that you want Release Notes for
.PARAMETER Version
The Version of the Build you're creating the Release Notes For
.EXAMPLE
Get-IHIReleaseNotesForBuild -ApplicationName SPRINGS -Version 20851
Creates a file ReleaseNotes_SPRINGS_20851.txt in the current directory
#>
function Get-IHIReleaseNotes {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationName,    
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [int]$Version
    )
  #endregion
  process {
    #region Validate ApplicationName
    # get list of valid application names from local file listing
    $Success = $true
    $ValidApplicationNames = Get-IHIApplicationNames

    # validate the application name      
    if ($ValidApplicationNames -notcontains $ApplicationName) {
        $Success = $false
        Write-Host "`nSorry, " -ForegroundColor Yellow -NoNewline
        Write-Host $ApplicationName -ForegroundColor Cyan -NoNewline
        Write-Host " is not a valid application name." -ForegroundColor Yellow
    }      

    # if bad application name, display list of valid names and return
    if ($Success -eq $false) {
      Write-Host "`nValid application names:"
      Out-IHIToOrderedColumns -ListToDisplay $ValidApplicationNames -Columns 4
      Write-Host $HelpMessage
      return
    } else {
      # it is valid so store in global context
      $script:ApplicationNames = $ApplicationName
    }
    #endregion
    $OutputFileFolder = $pwd
    Get-IHIReleaseNotesForBuild -ApplicationName $ApplicationName -BuildVersion $Version -ApplicationConfigsFolder $Ihi:BuildDeploy.ApplicationConfigsRootFolder -OutputFolderPath $OutputFileFolder
  }
}
Export-ModuleMember -Function Get-IHIReleaseNotes
New-Alias -Name "releasenotes" -Value Get-IHIReleaseNotes
Export-ModuleMember -Alias "releasenotes"
#endregion