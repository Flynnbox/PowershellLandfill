#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
    # constant to help identify when params not passed
    [string]$script:NotPassed = "<NOT_PASSED>"
    # help message
    [string]$script:HelpMessage = "`nFor full parameter and usage information type: deploy -Help`n"
    # name of user that started client deploy process
    [string]$script:LaunchUserName = $null
    # name of application to deploy
    [string]$script:ApplicationName = $null
    # name of applications to deploy
    [string[]]$script:ApplicationNames = $null
    # version of application to deploy
    [string]$script:Version = $null
    # nickname of server to deploy to
    [string]$script:EnvironmentNickname = $null
    # name of server to deploy to
    [string]$script:DeployServerName = $null
    # name of application package folder - not full path
    [string]$script:ApplicationPackageFolderName = $null
    # path to application release package folder
    [string]$script:ReleaseFolderApplicationFolder = $null
    # path to application configuration xml file IN THE RELEASE FOLDER PACKAGE
    [string]$script:ReleaseFolderApplicationConfigFile = $null
    # path to root deploy folder on target deploy server
    [string]$script:DeployServerDeployRootFolder = $null
    # path to application folder on target deploy server
    [string]$script:DeployServerApplicationFolder = $null
    # path to application configuration xml file IN THE DEPLOY SERVER DEPLOYS FOLDER
    [string]$script:DeployServerApplicationXmlFile = $null
    # content of application configuration xml file read from RELEASE FOLDER copy
    $script:ApplicationConfigXml = $null
    # user credentials for running remote commands
    [System.Management.Automation.PSCredential]$script:PSCredential = $null
  }
}
# initialize/reset the module
Initialize
# ensure best practices for variable use, function calling, null property access, etc.
# must be done at module script level, not inside Initialize, or will only be function scoped
Set-StrictMode -Version 2
#endregion


#region Functions: Copy-IHIDeployPackageToServer

<#
.SYNOPSIS
Copies deploy package to deploy server
.DESCRIPTION
Copies deploy package to deploy server; returns $true if successful; if error occurs, 
writes errors messages to host (not error stream) and returns $false
.EXAMPLE
Copy-IHIDeployPackageToServer
Copies deploy package to deploy server
#>
function Copy-IHIDeployPackageToServer {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    $Success = $true
    #region Copy description
    # Copy the package from the releases folder to the deploy server.  To do this, we'll use an 
    # intermediate machine that is known to be on the local network.  That is, instead of 
    # running the copy command locally, we'll run the copy command from a server in the 
    # IHI office.  We do this because if instead we ran the copy command from a developer 
    # machine, at home connected to the VPN, deploying to a production machine would require
    # the deploy package to be coped down to their machine (over VPN) then back up to the 
    # destination server, which would take much, MUCH longer.
    #endregion
    #region Dynamic script block code description
    # there are two ways of passing the values of variables into scriptblock to be invoke on a different machine
    # one is to give the script block a params, in the sb use the params then pass in the actual values using the Invoke-Command -ArgumentList parameter
    # the second way is to create a string with the command (the values get evaluated when building the string), convert the string to a script block then pass it
    # I'm doing the second way as there are a number of params and the string is easier to debug
    #endregion
    Write-Host "`nCopying $script:ApplicationName $script:Version package to $DeployServerName"
    try {
      # The PowerShell profile will be loaded for any session with the below pointer, this will point to the
      # Import Modules script which will make sure that the proper Modules and Snap-Ins are loaded
      $ScriptBlockString = "Invoke-Expression $PSHome\Microsoft.PowerShell_profile.ps1 ; Copy-IHIFileRoboCopy -SourceFolderPath $ReleaseFolderApplicationFolder -DestinationPath $DeployServerApplicationFolder -Recursive"
      $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlockString)
      #region Get copy credentials
      # SPRINGS used to be deployed to the production environment as an account that is not in 
      # the IHI domain, so we couldn't use the credentials entered by the user or we will get an error when
      # trying to copy the package to the server.
      # so, instead, we used a domain account that we've used in the past for this type of thing.
      # Changing this as with the hosting change no longer need to worry about the permissions
      # $PW = ConvertTo-SecureString -String "2runT@sks" -AsPlainText -Force
      # $CopyCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "IHI\EngTask",$PW
      #endregion
      # [hashtable]$Params = @{ ComputerName = $($Ihi:BuildDeploy.CopyServer); ScriptBlock = $ScriptBlock; Authentication = "CredSSP"; Credential = $CopyCredentials }
      [hashtable]$Params = @{ ComputerName = $($Ihi:BuildDeploy.CopyServer); ScriptBlock = $ScriptBlock }
      # Assume the deploy to server is Server 2008 and use CredSSP
      $Params.Authentication = "CredSSP"
      $Params.Credential = $PSCredential
      $Err = $null
      Invoke-Command @Params -EV Err 2>$null
      if ($Err -ne $null) {
        $Success = $false
        Write-Host "`nAn error occurred while copying the package." -ForegroundColor Yellow
        # to see if the error appeared to be incorrect password (most likely issue)
        if ($Err[0].Exception.Message.ToUpper().Contains("ACCESS IS DENIED")) {
          Write-Host "`nDid you mistype your password?" -ForegroundColor Yellow
        }
        Write-Host "`nError record:`n"
        $Err | Write-Host
        Write-Host "`nDeploy aborted`n" -ForegroundColor Yellow
      }
    }
    catch {
      $Success = $false
      Write-Host "`nAn exception occurred while copying the package." -ForegroundColor Yellow
      Write-Host "`nException:`n"
      $_ | Write-Host
    }
    $Success
  }
}
#endregion


#region Functions: Deploy-IHIDeployPackageOnServer

<#
.SYNOPSIS
Launches deploy package on deploy server
.DESCRIPTION
Launches deploy package on deploy server; returns $true if successful; if error occurs, 
writes errors messages to host (not error stream) and returns $false
.EXAMPLE
Deploy-IHIDeployPackageOnServer
Launches deploy package on deploy server
#>
function Deploy-IHIDeployPackageOnServer {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    $Success = $true
    #region Dynamic script block code description
    # there are two ways of passing the values of variables into scriptblock to be invoke on a different machine
    # one is to give the script block a params, in the sb use the params then pass in the actual values using the Invoke-Command -ArgumentList parameter
    # the second way is to create a string with the command (the values get evaluated when building the string), convert the string to a script block then pass it
    # I'm doing the second way as there are a number of params and the string is easier to debug
    #endregion
    Write-Host "`nDeploying $script:ApplicationName $script:Version package to $EnvironmentNickname"
    try {
      $ScriptBlockString = "Invoke-Expression $PSHome\Microsoft.PowerShell_profile.ps1 ; Invoke-IHIDeployCode -ApplicationXmlPath $DeployServerApplicationXmlFile -EnvironmentNickname $script:EnvironmentNickname -LaunchUserName $LaunchUserName"
      $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlockString)
      # Need to add an option for generating the PowerShell v2 session
      if ($Script:ApplicationName -eq 'SPRINGS') {
        Write-Host "Attempting to call PowerShell with the right version for SPRINGS deploy.`n"
        # Write-Host "Calling: $ScriptBlockString .`n"
        [hashtable]$Params = @{ ComputerName = $DeployServerName; ConfigurationName = 'SPRINGS'; ScriptBlock = $ScriptBlock }

        Write-Host "DEBUG: In Deploy-IHIDeployPackageOnServer, after set Params for SPRINGS`n"
      } else {
        # Write-Host "This is not a SPRINGS deploy.`n"
        [hashtable]$Params = @{ ComputerName = $DeployServerName; ScriptBlock = $ScriptBlock }
      }
      # Assume the deploy to server is Server 2008 and use CredSSP
      $Params.Authentication = "CredSSP"
      $Params.Credential = $PSCredential
      $Err = $null
      # capture invoke results so not streamed back to caller, but discard the results
      $InvokeResults = Invoke-Command @Params -EV Err
      if ($Err -ne $null) {
        $Success = $false
        Write-Host "`nAn error occurred while deploying the package." -ForegroundColor Yellow
        Write-Host "`nError record:`n"
        $Err | Write-Host
        Write-Host "`nDeploy aborted`n" -ForegroundColor Yellow
      }
    } catch {
      $Success = $false
      Write-Host "`nAn exception occurred while deploying the package." -ForegroundColor Yellow
      Write-Host "`nException:`n"
      $_ | Write-Host
    }
    $Success
  }
}
#endregion


#region Functions: Copy-IHIPSFilesToDestinationOnServer

<#
.SYNOPSIS
Copies PowerShell files to destination server
.DESCRIPTION
Copies PowerShell files to destination server
.EXAMPLE
Copy-IHIPSFilesToDestinationOnServer
Launches deploy package on deploy server
#>
function Copy-IHIPSFilesToDestinationOnServer {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    $Success = $true
    #region Dynamic script block code description
    # there are two ways of passing the values of variables into scriptblock to be invoke on a different machine
    # one is to give the script block a params, in the sb use the params then pass in the actual values using the Invoke-Command -ArgumentList parameter
    # the second way is to create a string with the command (the values get evaluated when building the string), convert the string to a script block then pass it
    # I'm doing the second way as there are a number of params and the string is easier to debug
    #endregion
    Write-Host "`nInvoking copy script $script:ApplicationName $script:Version DeployPowerShellCode.bat on $DeployServerName"
    try {
      # we will launch the copy command on the server WITHOUT invoking the framework profile Microsoft.PowerShell_profile.ps1 !
      # must be lauched as standard PowerShell session without the IHI module framework or copy process will fail!
      # build up xcopy command from source to D:\IHI_Scripts\PowerShell3\Main
      # source is under PowerShell3\Main folder in main deploy folder
      [string]$SourceFolderPath = Join-Path -Path $DeployServerApplicationFolder -ChildPath "PowerShell3_Main"

      # Check if there is a D: drive and set the DestinationFolderPath Accordingly. Use D: if exists, otherwise C:
      if ($true -eq (Test-Path -Path "D:\")) {
        [string]$LocalRootDrive = "D:\"
      } else {
        [string]$LocalRootDrive = "C:\"     
      }
      [string]$DestinationFolderPath = Join-Path -Path $LocalRootDrive -ChildPath "IHI_Scripts\PowerShell3\Main"
      # now build up xcopy command
      [string]$ScriptBlockString = "xcopy $SourceFolderPath $DestinationFolderPath /E /Y"
      Add-IHILogIndentLevel
      Write-Host "Invoke command: $ScriptBlockString"
      Remove-IHILogIndentLevel
      # now run command
      $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlockString)
      [hashtable]$Params = @{ ComputerName = $DeployServerName; ScriptBlock = $ScriptBlock }
      # Assume the deploy to server is Server 2008 and use CredSSP
      $Params.Authentication = "CredSSP"
      $Params.Credential = $PSCredential
      $Err = $null
      # capture invoke results so not streamed back to caller, but discard the results
      $InvokeResults = Invoke-Command @Params -EV Err
      if ($Err -ne $null) {
        $Success = $false
        Write-Host "`nAn error occurred while invoking the PS copy script." -ForegroundColor Yellow
        Write-Host "`nResults:"
        $InvokeResults | Write-Host
        Write-Host "`nError record:`n"
        $Err | Write-Host
        Write-Host "`nCopy aborted`n" -ForegroundColor Yellow
      }
    } catch {
      $Success = $false
      Write-Host "`nAn exception occurred while invoking the PS copy script." -ForegroundColor Yellow
      Write-Host "`nResults:"
      $InvokeResults | Write-Host
      Write-Host "`nException:`n"
      $_ | Write-Host
    }
    $Success
  }
}
#endregion


#region Functions: Out-IHIDeployClientHelp, Out-IHIDeployClientSettings

<#
.SYNOPSIS
Writes deploy client help to host
.DESCRIPTION
Writes deploy client help to host
.EXAMPLE
Out-IHIDeployClientHelp
Outputs deploy client help
#>
function Out-IHIDeployClientHelp {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    Write-Host "`ndeploy -ApplicationName <APPLICATION> -Version <version> -EnvironmentNickName <name>"
    Write-Host "`n  ApplicationName:      name of application to deploy"
    Write-Host "  Version:              package (repository revision) number to deploy"
    Write-Host "  EnvironmentNickName:  name of server/environment to deploy to"
    Write-Host "`n  Examples:"
    Write-Host "    deploy EXTRANET                 (displays existing package versions)"
    Write-Host "    deploy EXTRANET 1234            (displays valid server environments)"
    Write-Host "    deploy EXTRANET 1234 DEVAPPWEB  (deploys EXTRANET 1234 to DEVAPPWEB)"
    Write-Host "`nValid application names:"
    Out-IHIToOrderedColumns -ListToDisplay (Get-IHIApplicationNames) -Columns 4
  }
}


<#
.SYNOPSIS
Writes deploy client current settings to host
.DESCRIPTION
Writes deploy client current settings to host
.EXAMPLE
Out-IHIDeployClientSettings
Outputs client settings
#>
function Out-IHIDeployClientSettings {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    Write-Host "Deploy information"
    Write-Host "  Application name:                   $script:ApplicationName"
    Write-Host "  Version:                            $script:Version"
    Write-Host "  ApplicationPackageFolderName:       $ApplicationPackageFolderName"
    Write-Host "  EnvironmentNickname:                $script:EnvironmentNickname"
    Write-Host "  DeployServerName:                   $DeployServerName"
    Write-Host "  Launch user:                        $LaunchUserName"
    Write-Host "  ReleaseFolderApplicationFolder      $ReleaseFolderApplicationFolder"
    Write-Host "  ReleaseFolderApplicationConfigFile  $ReleaseFolderApplicationConfigFile"
    Write-Host "  DeployServerDeployRootFolder        $DeployServerDeployRootFolder"
    Write-Host "  DeployServerApplicationFolder       $DeployServerApplicationFolder"
    Write-Host "  DeployServerApplicationXmlFile      $DeployServerApplicationXmlFile"
  }
}
#endregion


#region Functions: Set-IHIApplicationConfigXml

<#
.SYNOPSIS
Validates and sets value for ApplicationConfigXml
.DESCRIPTION
Validates and sets value for ApplicationConfigXml; returns $true if successful; if 
error occurs, writes errors messages to host (not error stream) and returns $false
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
    $Success = $true
    # Normally would validate XML file with Test-Xml but it can't handle UNC paths, joy
    # so have to do this in a try/catch instead
    [xml]$TempXml = $null
    try {
      $TempXml = [xml](Get-Content -Path $ReleaseFolderApplicationConfigFile)
      # confirm the xml contains the standard, required settings
      $Err = $null
      Confirm-IHIValidDeployXml -ApplicationXml $TempXml -EV Err
      if ($Err -ne $null) {
        Write-Host "`nApplication file does not contain valid application xml: $ReleaseFolderApplicationConfigFile" -ForegroundColor Yellow
        $Err | Write-Host
        $Success = $false
      } else {
        # if made it to this point, xml is valid so store in private variable
        $script:ApplicationConfigXml = $TempXml
      }
    }
    catch {
      Write-Host "`nApplication file does not contain valid xml: $ReleaseFolderApplicationConfigFile `n" -ForegroundColor Yellow
      $_ | Write-Host
      $Success = $false
    }
    $Success
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
Validates and sets value for Extranet
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
    $ValidApplicationNames = Get-IHIApplicationNames
    # if no application name specified, ask for one
    if ($ApplicationName -eq $NotPassed) {
      $Success = $false
      Write-Host "`nPlease specify an application name to deploy." -ForegroundColor Yellow
      # else if invalid application name display error message
    } elseif ($ValidApplicationNames -notcontains $ApplicationName) {
      $Success = $false
      Write-Host "`nSorry, " -ForegroundColor Yellow -NoNewline
      Write-Host $ApplicationName -ForegroundColor Cyan -NoNewline
      Write-Host " is not a valid application name." -ForegroundColor Yellow
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


#region Functions: Set-IHIDeployServerValues

<#
.SYNOPSIS
Validates and sets deploy server values
.DESCRIPTION
Validates and sets deploy server values; returns $true if successful; if error occurs, 
writes errors messages to host (not error stream) and returns $false
.EXAMPLE
Set-IHIDeployServerValues
Validates and sets deploy server values
#>
function Set-IHIDeployServerValues {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    $Success = $true
    # get application/version folder name
    $script:ApplicationPackageFolderName = Get-IHIApplicationPackageFolderName -ApplicationName $script:ApplicationName -Version $script:Version
    # get default deploy share for this server and test it
    $script:DeployServerDeployRootFolder = "\\" + $DeployServerName + "\Deploys"
    #region Confirm deploy share exists
    if ($false -eq (Test-Path -Path $DeployServerDeployRootFolder)) {
      $Success = $false
      Write-Host "`nDeploy infrastructure not set up on server $DeployServerName; contact the administrator`n" -ForegroundColor Yellow
      [string]$Subject = "Deploy infrastructure not set up on server $DeployServerName"
      [string]$Body = $Subject + "<BR/>Application name: $script:ApplicationName<BR/>Version: $script:Version<BR/>Nickname: $script:EnvironmentNickname<BR/>Server: $DeployServerName<BR/>User: $LaunchUserName"
      Send-IHIMailMessage -To $Ihi:BuildDeploy.ErrorNotificationEmails -Subject $Subject -Body $Body
    }
    # set other known values
    $script:DeployServerApplicationFolder = Join-Path -Path $DeployServerDeployRootFolder -ChildPath ("\Packages\" + $ApplicationPackageFolderName)
    $script:DeployServerApplicationXmlFile = Join-Path -Path $DeployServerApplicationFolder -ChildPath (Get-IHIApplicationConfigFileName -ApplicationName $script:ApplicationName)
    $Success
  }
}
#endregion


#region Functions: Set-IHIEnvironmentNicknameAndServer

<#
.SYNOPSIS
Validates and sets values for EnvironmentNickname and DeployServerName
.DESCRIPTION
Validates and sets values for EnvironmentNickname and DeployServerName; returns $true
if successful; if error occurs, writes errors messages to host (not error stream)
and returns $false
.EXAMPLE
Set-IHIEnvironmentNicknameAndServer -EnvironmentNickname DEVAPPWEB
Validates and sets values for EnvironmentNickname and DeployServerName for DEVAPPWEB
#>
function Set-IHIEnvironmentNicknameAndServer {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$EnvironmentNickname
  )
  #endregion
  process {
    $Success = $true
    # make sure environment name is all uppercase
    $EnvironmentNickname = $EnvironmentNickname.ToUpper()
    # get list of valid environment nicknames from app config
    $ValidEnvironmentNicknames = Get-IHIDeployServersFromXml $ApplicationConfigXml | Select -ExpandProperty NickName
	# Get-PropertyValue Nickname
    # if no version specified, ask for one
    if ($EnvironmentNickname -eq $NotPassed) {
      $Success = $false
      Write-Host "`nPlease specify an environment nickname." -ForegroundColor Yellow
      # else if no valid environment nickname for that environment nickname exists
    } elseif ($ValidEnvironmentNicknames -notcontains $EnvironmentNickname) {
      $Success = $false
      Write-Host $("`n" + $EnvironmentNickname) -ForegroundColor Cyan -NoNewline
      Write-Host " is not a valid environment nickname for this package of " -ForegroundColor Yellow -NoNewline
      Write-Host $($script:ApplicationName + "`n") -ForegroundColor Cyan -NoNewline
    }
    # only write version numbers if some type of error
    if ($Success -eq $false) {
      Write-Host "`nEnvironments: $("$ValidEnvironmentNicknames")"
      Write-Host $HelpMessage
    } else {
      # no errors so store values
      # nickname is valid; store in module context
      $script:EnvironmentNickname = $EnvironmentNickname
      # get server name for nickname; store in module context
      $script:DeployServerName = Get-IHIDeployServerForNicknameFromXml -ApplicationXml $ApplicationConfigXml -Nickname $EnvironmentNickname
    }
    $Success
  }
}
#endregion


#region Functions: Set-IHIReleaseFolderApplicationConfigFile, Set-IHIReleaseFolderApplicationFolder

<#
.SYNOPSIS
Validates and sets value for ReleaseFolderApplicationConfigFile
.DESCRIPTION
Validates and sets value for ReleaseFolderApplicationConfigFile; returns $true 
if successful; if error occurs, writes errors messages to host (not error stream)
and returns $false
.EXAMPLE
Set-IHIReleaseFolderApplicationConfigFile
Validates and sets value for ReleaseFolderApplicationConfigFile
#>
function Set-IHIReleaseFolderApplicationConfigFile {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    $Success = $true
    $script:ReleaseFolderApplicationConfigFile = Join-Path -Path $ReleaseFolderApplicationFolder -ChildPath (Get-IHIApplicationConfigFileName -ApplicationName $script:ApplicationName)
    if ($false -eq (Test-Path -Path $ReleaseFolderApplicationConfigFile)) {
      Write-Host "`nNo application configuration file found at: $ReleaseFolderApplicationConfigFile `n" -ForegroundColor Yellow
      $Success = $false
    }
    $Success
  }
}


<#
.SYNOPSIS
Validates and sets value for ReleaseFolderApplicationFolder
.DESCRIPTION
Validates and sets value for ReleaseFolderApplicationFolder; returns $true
if successful; if error occurs, writes errors messages to host (not error stream)
and returns $false
.EXAMPLE
Set-IHIReleaseFolderApplicationFolder
Validates and sets value for ReleaseFolderApplicationFolder
#>
function Set-IHIReleaseFolderApplicationFolder {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    $Success = $true
    # Get-IHIAppVersionReleasePackageFolder only returns the path, does NOT test to make sure it exists
    # so need to check if it exists
    $script:ReleaseFolderApplicationFolder = Get-IHIAppVersionReleasePackageFolder -ApplicationName $script:ApplicationName -Version $script:Version
    if ($false -eq (Test-Path -Path $ReleaseFolderApplicationFolder)) {
      Write-Host "`nSorry, release folder not found: " -ForegroundColor Yellow -NoNewline
      Write-Host $ReleaseFolderApplicationFolder -ForegroundColor Cyan
      Write-Host ""
      $Success = $false
    }
    $Success
  }
}
#endregion


#region Functions: Set-IHIPSCredential

<#
.SYNOPSIS
Validates and sets value for Credential
.DESCRIPTION
Validates and sets value for Credential; returns $true if successful; if error occurs, 
writes errors messages to host (not error stream) and returns $false
.EXAMPLE
Set-IHIPSCredential -Credential <credential object>
Gets and stores credential object
#>
function Set-IHIPSCredential {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [System.Management.Automation.PSCredential]$Credential = $null
  )
  #endregion
  process {
    $Success = $true
    if ($Credential -eq $null) {
      $Err = $null
      #region Get user credential call
      # if application is SPRINGS, we used to pre-populate a different username based on internal vs. external server
      # no longer doing that
      # get user credential and pre-fill in username; if user doesn't fill in, suppress error
      $Credential = Get-IHICredential -EV Err -ErrorAction SilentlyContinue
      #endregion
      if ($Err -ne $null -or $Credential -eq $null) {
        $Success = $false
        Write-Host "`nYou need to fill in account credentials in order to deploy`n" -ForegroundColor Yellow
      } else {
        # store at module level
        $script:PSCredential = $Credential
      }
    } else {
      # store at module level
      $script:PSCredential = $Credential
    }
    $Success
  }
}
#endregion


#region Functions: Set-IHIVersion

<#
.SYNOPSIS
Validates and sets value for Version
.DESCRIPTION
Validates and sets value for Version; returns $true if successful; if error occurs, 
writes errors messages to host (not error stream) and returns $false
.EXAMPLE
Set-IHIVersion -Version 9876
Validates version
#>
function Set-IHIVersion {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Version
  )
  #endregion
  process {
    $Success = $true
    # get list of valid version for this application
    $ValidApplicationVersions = Get-IHIApplicationPackageVersions -ApplicationName $script:ApplicationName
    # if no version specified, ask for one
    if ($Version -eq $NotPassed) {
      $Success = $false
      Write-Host "`nPlease specify a version number to deploy." -ForegroundColor Yellow
      # else if invalid version display error message
    } elseif ($Version -notmatch "^\d+$") {
      $Success = $false
      Write-Host "`nVersion number " -ForegroundColor Yellow -NoNewline
      Write-Host $Version -ForegroundColor Cyan -NoNewline
      Write-Host " is not a valid number." -ForegroundColor Yellow
      # else if no package for that version number exists
    } elseif ($ValidApplicationVersions -notcontains $Version) {
      $Success = $false
      Write-Host "`nSorry, package/version number " -ForegroundColor Yellow -NoNewline
      Write-Host $Version -ForegroundColor Cyan -NoNewline
      Write-Host " does not exist for application " -ForegroundColor Yellow -NoNewline
      Write-Host $script:ApplicationName -ForegroundColor Cyan
    }
    if ($Success -eq $false) {
      Write-Host "`n$script:ApplicationName versions: $("$ValidApplicationVersions")"
      Write-Host $HelpMessage
    } else {
      # it is valid so store in global context
      $script:Version = $Version
    }
    $Success
  }
}
#endregion


#region Functions: Invoke-IHIDeployCodeClient

<#
.SYNOPSIS
Deploys an application package version to a server
.DESCRIPTION
Deploys a application package(s) version to a server. Copies the package
to the server and runs the local deploy process for the package.
User must specify application name, version and environment nickname;
if any value is missing or invalid, correct values are shown.
During the deployment, the user will be asked for credentials (username
and password).  These must be supplied; these credentials are used in
copying and deploying.  If the credentials supplied do not have access
the copy and/or deploy will fail.  One note: a user can pass a preloaded 
PSCredential object with the parameters; this is handy if deploying
multiple applications at the same time (not prompted for credentials each
time).
.PARAMETER ApplicationName
Name of application(s) to deploy.
.PARAMETER Version
Version of application package to deploy
.PARAMETER EnvironmentNickname
Environment nickname (typically the server name) to deploy to
.PARAMETER UserCredential
Credentials to use when deploying
.PARAMETER Help
Displays help about this command
.PARAMETER DeployPSFramework
Specify if you are deploying the PS framework to a server.  This should only be added
by the deployps function to ensure the two-step process required by the framework 
deployment is done correctly.
.EXAMPLE
Invoke-IHIDeployCodeClient
Displays a list of valid application names
.EXAMPLE
Invoke-IHIDeployCodeClient SurveyCenter
Displays a list of valid SurveyCenter versions
.EXAMPLE
Invoke-IHIDeployCodeClient SurveyCenter 1111
Displays a list of valid environment nicknames to deploy to (assuming 1111 is valid)
.EXAMPLE
Invoke-IHIDeployCodeClient SurveyCenter 1111 DEVAPPWEB
Deploys SurveyCenter 1111 to DEVAPPWEB
.EXAMPLE
$Cred = Get-Credential; Invoke-IHIDeployCodeClient SurveyCenter 1111 DEVAPPWEB -UserCredential $Cred
Deploys SurveyCenter 1111 to DEVAPPWEB using the credentials acquired in the
Get-Credential pop-up
.EXAMPLE
Invoke-IHIDeployCodeClient SurveyCenter,CERTIFICATECENTER 1111 DEVAPPWEB
Deploys SurveyCenter 1111 as well as CERTIFICATECENTER 1111 to DEVAPPWEB
#>
function Invoke-IHIDeployCodeClient {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$ApplicationNames = $NotPassed,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$Version = $NotPassed,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$EnvironmentNickname = $NotPassed,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [System.Management.Automation.PSCredential]$UserCredential = $null,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$Help,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$DeployPSFramework
  )
  #endregion
  process {
    # if help requested, display and exit
    if ($Help -eq $true) { Out-IHIDeployClientHelp; return }

    # initialize the module
    Initialize
   $script:ApplicationNames = $ApplicationNames
   $script:ApplicationNames | ForEach-Object {
        # make sure name is uppercase
        $ApplicationName = $_.ToUpper()

        # make sure names are uppercase
        $ApplicationName = $ApplicationName.ToUpper()
        $EnvironmentNickname = $EnvironmentNickname.ToUpper()

        #region If PowerShell3 deploy, make sure launched by deployps
        # if this is a PowerShell3 framework deployment, $DeployPSFramework must be specified to ensure
        # deploy is being done by deployps (could check call stack, this is simpler)
        if ($ApplicationName -eq "POWERSHELL3" -and $DeployPSFramework -eq $false) {
          Write-Host "`nPackage POWERSHELL3 can only be deployed by using the " -NoNewline
          Write-Host "deployps" -ForegroundColor Yellow -NoNewline
          Write-Host " command.`n"
          return
        }
        #endregion

        #region Parameter validation and set module values
        # confirm client machine is on IHI network/vpn
        if ((Confirm-IHIClientMachineOnIhiNetwork) -eq $false) { return }
        # validate and set application name
        if ((Set-IHIApplicationName -ApplicationName $ApplicationName) -eq $false) { return }
        # validate and set application version; exit if fails
        if ((Set-IHIVersion -Version $Version) -eq $false) { return }
        # validate and set location for application/version release folder; exit if fails
        if ((Set-IHIReleaseFolderApplicationFolder) -eq $false) { return }
        # validate and set application config; exit if fails
        if ((Set-IHIReleaseFolderApplicationConfigFile) -eq $false) { return }
        # read, validate and set application config xml; exit if fails
        if ((Set-IHIApplicationConfigXml) -eq $false) { return }
        # validate and set environment nickname and server; exit if fails
        if ((Set-IHIEnvironmentNicknameAndServer -EnvironmentNickname $EnvironmentNickname) -eq $false) { return }
        # store username of person that launched process
        $script:LaunchUserName = $env:UserName
        # validate and set remaining deploy server-related values; exit if fails
        if ((Set-IHIDeployServerValues) -eq $false) { return }
        # get user credentials to use for copy and deploy processes
        if ((Set-IHIPSCredential -Credential $UserCredential) -eq $false) { return }
        #endregion

        # display settings info; uncomment for debug purposes only
        # Out-IHIDeployClientSettings

        # copy package from releases folder to target server
        if ((Copy-IHIDeployPackageToServer) -eq $false) { return }

        # deploy the package on the server
        $Results = Deploy-IHIDeployPackageOnServer
        if ($Results -eq $true) {
          Write-Host "`nSuccessfully deployed $script:ApplicationName $script:Version to $script:EnvironmentNickname `n"
        } else {
          Write-Host "`nDeploy FAILED for $script:ApplicationName $script:Version to $script:EnvironmentNickname `n" -ForegroundColor Yellow
          # if this was the PowerShell application, explicitly write an error so calling function
          # will know an error occurred
          if ($ApplicationName -eq "POWERSHELL3") {
            Write-Error -Message "Error deploying POWERSHELL3 client"
          }
        }
    }
  }
}
Export-ModuleMember -Function Invoke-IHIDeployCodeClient
New-Alias -Name "deploy" -Value Invoke-IHIDeployCodeClient
Export-ModuleMember -Alias "deploy"
#endregion


#region Functions: Invoke-IHIDeployPSCodeClient

<#
.SYNOPSIS
Deploys a PowerShell framework package version to a server
.DESCRIPTION
Deploys a PowerShell package version to a server; this calls the standard
deploy client function then follows up with another call to deploy the
code to destination.  Because PowerShell module DLLs are in-use when 
the framework is normally loaded, they can't be replaced in a standard
deploy process because the deploy process is a PowerShell session which
locks the DLLs.  So this function calls the standard deploy, which, for
the PowerShell package, simply unzips the package.  Then this function
invokes a xcopy command to do the copying but without loading the PowerShell
module framework, so the DLL files can be overwritten.  
This script also checks to make sure no open PowerShell sessions exist on 
the target server before running the .bat copy file.
.PARAMETER Version
Version of application package to deploy
.PARAMETER EnvironmentNickname
Environment nickname (typically the server name) to deploy to
.PARAMETER UserCredential
Credentials to use when deploying
.EXAMPLE
Invoke-IHIDeployPSCodeClient 5555 DEVAPPWEB
Deploys POWERSHELL3 5555 to DEVAPPWEB
#>
function Invoke-IHIDeployPSCodeClient {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$Version = $NotPassed,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$EnvironmentNickname = $NotPassed,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [System.Management.Automation.PSCredential]$UserCredential = $null
  )
  #endregion
  process {
    # initialize the module
    Initialize

    # this function is only used for deploying POWERSHELL3 builds, setting it here
    $ApplicationName = "POWERSHELL3"

    #region Parameter validation and set module values
    # perform most (not all) of the validatation done by Invoke-IHIDeployCodeClient so can 
    # safely use $DeployServerName in process check
    # confirm client machine is on IHI network/vpn
    if ((Confirm-IHIClientMachineOnIhiNetwork) -eq $false) { return }
    # validate and set application name
    if ((Set-IHIApplicationName -ApplicationName $ApplicationName) -eq $false) { return }
    # validate and set application version; exit if fails
    if ((Set-IHIVersion -Version $Version) -eq $false) { return }
    # validate and set location for application/version release folder; exit if fails
    if ((Set-IHIReleaseFolderApplicationFolder) -eq $false) { return }
    # validate and set application config; exit if fails
    if ((Set-IHIReleaseFolderApplicationConfigFile) -eq $false) { return }
    # read, validate and set application config xml; exit if fails
    if ((Set-IHIApplicationConfigXml) -eq $false) { return }
    # validate and set environment nickname and server; exit if fails
    if ((Set-IHIEnvironmentNicknameAndServer -EnvironmentNickname $EnvironmentNickname) -eq $false) { return }
    # store username of person that launched process
    $script:LaunchUserName = $env:UserName
    # validate and set remaining deploy server-related values; exit if fails
    if ((Set-IHIDeployServerValues) -eq $false) { return }
    # get user credentials to use for copy and deploy processes
    if ((Set-IHIPSCredential -Credential $UserCredential) -eq $false) { return }
    #endregion

    #region Check if any PowerShell sessions presently open on that server before package copy
    $Error.Clear()
    if ($null -ne (Get-Process -Name PowerShell -ComputerName $DeployServerName -ErrorAction SilentlyContinue)) {
      Write-Host "`nThere are open PowerShell sessions on $DeployServerName; close them and re-run deployps`n" -ForegroundColor Yellow
      Get-IHITerminalSessions -Servers $DeployServerName
      return
    }
    $Error.Clear()
    #endregion

    # copy package from releases folder to target serverCopy-IHIDeployPackageToServer
    if ((Copy-IHIDeployPackageToServer) -eq $false) { return }

    # deploy the package on the server
    $Results = Deploy-IHIDeployPackageOnServer
    if ($Results -eq $true) {
      Write-Host "`nSuccessfully deployed $script:ApplicationName $script:Version to $script:EnvironmentNickname `n"
    } else {
      Write-Host "`nDeploy FAILED for $script:ApplicationName $script:Version to $script:EnvironmentNickname `n" -ForegroundColor Yellow
      # if this was the PowerShell application, explicitly write an error so calling function
      # will know an error occurred
      if ($ApplicationName -eq "POWERSHELL3") {
        Write-Error -Message "Error deploying POWERSHELL3 client"
      }
    }

    # wait 5 seconds in case files in use
    Start-Sleep -Seconds 5

    #region Check if any PowerShell sessions presently open on that server before launching local copy command
    $Error.Clear()
    if ($null -ne (Get-Process -Name PowerShell -ComputerName $DeployServerName -ErrorAction SilentlyContinue)) {
      Write-Host "`nThere are open PowerShell sessions on $DeployServerName; close them and re-run deployps`n" -ForegroundColor Yellow
      Get-IHITerminalSessions -Servers $DeployServerName
      return
    }
    $Error.Clear()
    #endregion

    # invoke PowerShell copy script
    if ((Copy-IHIPSFilesToDestinationOnServer) -eq $false) { return }

    Write-Host "`nSuccessfully deployed POWERSHELL3 Module Framework $Version to $DeployServerName`n"
  }
}
Export-ModuleMember -Function Invoke-IHIDeployPSCodeClient
New-Alias -Name "deployps" -Value Invoke-IHIDeployPSCodeClient
Export-ModuleMember -Alias "deployps"
#endregion
