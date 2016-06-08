#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
    # constant to help identify when params not passed
    [string]$script:NotPassed = "<NOT_PASSED>"
    # help message
    [string]$script:HelpMessage = "`nFor full parameter and usage information type: build -Help`n"
    # name of user that started client build process
    [string]$script:LaunchUserName = $null
    # name of application to build
    [string]$script:ApplicationName = $null
    # name of application to build
    [string[]]$script:ApplicationNames = $null
    # version of application to build
    [string]$script:Version = $null
    # is this a test build or not (TestBuild -eq $true means don't copy to Releases folder
    [bool]$script:TestBuild = $false
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


#region Functions: Build-IHIPackageOnBuildServer

<#
.SYNOPSIS
Launches deploy package on deploy server
.DESCRIPTION
Launches deploy package on deploy server; returns $true if successful; if error occurs, 
writes errors messages to host (not error stream) and returns $false
.EXAMPLE
Build-IHIPackageOnBuildServer
Launches deploy package on deploy server
#>
function Build-IHIPackageOnBuildServer {
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
    Write-Host "`nBuilding $script:ApplicationName $script:Version"
    try {
      $ScriptBlockString = $null
      # if this is a test build, pass that param explicitly
      if ($TestBuild) {
        $ScriptBlockString = "Invoke-Expression $PSHome\Microsoft.PowerShell_profile.ps1 ; Invoke-IHIBuildCode -ApplicationName $ApplicationName -Version $Version -LaunchUserName $LaunchUserName -TestBuild"
      } else {
        $ScriptBlockString = "Invoke-Expression $PSHome\Microsoft.PowerShell_profile.ps1 ; Invoke-IHIBuildCode -ApplicationName $ApplicationName -Version $Version -LaunchUserName $LaunchUserName"
      }
      $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlockString)

      [hashtable]$Params = @{ ComputerName = $($Ihi:BuildDeploy.BuildServer); ScriptBlock = $ScriptBlock }
      # Assume the deploy to server is Server 2008 and use CredSSP
      $Params.Authentication = "CredSSP"
      $Params.Credential = $PSCredential
      $Err = $null
      # capture invoke results so not streamed back to caller, but discard the results
      $InvokeResults = Invoke-Command @Params -EV Err 2>$null
      if ($Err -ne $null) {
        $Success = $false
        Write-Host "`nAn error occurred while building the package." -ForegroundColor Yellow
        Write-Host "`nError record:`n"
        $Err | Write-Host
        Write-Host "`nBuild aborted`n" -ForegroundColor Yellow
      }
    } catch {
      $Success = $false
      Write-Host "`nAn exception occurred while building the package." -ForegroundColor Yellow
      Write-Host "`nException:`n"
      $_ | Write-Host
    }
    $Success
  }
}
#endregion


#region Functions: Out-IHIBuildClientHelp, Out-IHIBuildClientSettings

<#
.SYNOPSIS
Writes build client help to host
.DESCRIPTION
Writes build client help to host
.EXAMPLE
Outputs build help
#>
function Out-IHIBuildClientHelp {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    Write-Host "`nbuild -ApplicationName <APPLICATION> -Version <version>"
    Write-Host "`n  ApplicationName:      name of application to build"
    Write-Host "  Version:              package (repository revision) number to build"
    Write-Host "`n  Examples:"
    Write-Host "    build EXTRANET                 (builds EXTRANET using latest version)"
    Write-Host "    build EXTRANET 1234            (builds EXTRANET version 1234 of repository)"
    Write-Host "`nValid application names:"
    Out-IHIToOrderedColumns -ListToDisplay (Get-IHIApplicationNames) -Columns 4
  }
}
#endregion


#region Functions: Out-IHIReleaseNotesClientHelp

<#
.SYNOPSIS
Writes releasenotes client help to host
.DESCRIPTION
Writes releasenotes client help to host
.EXAMPLE
Outputs releasenotes help
#>
function Out-IHIReleaseNotesClientHelp {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    Write-Host "`nreleasenotes -ApplicationName <APPLICATION> -Version <version>"
    Write-Host "`n  ApplicationName:      name of application to get notes for"
    Write-Host "  Version:              package (repository revision) number to compare PROD against"
    Write-Host "`n  Examples:"
    Write-Host "    releasenotes SPRINGS 12344                (shows SPRINGS changes from current PROD build to version online)"
    Write-Host "`nValid application names:"
    Out-IHIToOrderedColumns -ListToDisplay (Get-IHIApplicationNames) -Columns 4
    Write-Host "`n This creates a release notes file from the SVN Log using two version numbers as"
    Write-Host "`ndelineators, the versions will typically be the version released to PROD and the"
    Write-Host "`nversion in TEST.  The Release Notes will be placed in the related build directory for the"
    Write-Host "`nversion being checked.  Giving the version in TEST is sufficient as a boundary to check"
    Write-Host "`nagainst, while the Client will check and determine the version in PROD using existing"
    Write-Host "`nfunctions that will run as the User.`n"
    Write-Host "`nErrors may ensue if the User running this function does not have the right permissions"
    Write-Host "`nto check and return the versions deployed for an existing application."
    Write-Host "`n`nNOTE: Exisiting Applications that have multiple versions installed in the PROD environment"
    Write-Host "`nwill be checked against the latest version deployed."
  }
}


<#
.SYNOPSIS
Writes build client current settings to host
.DESCRIPTION
Writes build client current settings to host
.EXAMPLE
Out-IHIBuildClientSettings
Outputs build settings
#>
function Out-IHIBuildClientSettings {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    Write-Host "Build information"
    Write-Host "  Application name:                   $script:ApplicationName"
    Write-Host "  Version:                            $script:Version"
    Write-Host "  Launch user:                        $LaunchUserName"
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
Set-IHIApplicationName Extranet
Sets name of application to build to Extranet
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
      Write-Host "`nPlease specify an application name to build." -ForegroundColor Yellow
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

#region Functions: Set-IHIApplicationNames

<#
.SYNOPSIS
Validates and sets value for ApplicationNames
.DESCRIPTION
Validates and sets value for ApplicationNames; returns $true if successful; if error occurs, 
writes errors messages to host (not error stream) and returns $false.  If user specified ALL
then retrieve all application version data.
.EXAMPLE
Set-IHIApplicationNames -ApplicationNames EXTRANET
Sets names of applications to check versions
#>
function Set-IHIApplicationNames {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ApplicationNames
  )
  #endregion
  process {
    $Success = $true
    # make sure application names are sorted and uppercase and no duplicates
    $ApplicationNames = $ApplicationNames | ForEach-Object { $_.ToUpper() } | Sort-Object | Select-Object -Unique
    # get list of valid application names from local file listing
    $ValidApplicationNames = Get-IHIApplicationNames
    # if no application name specified, ask for one
    if ($ApplicationNames -eq $NotPassed) {
      $Success = $false
      Write-Host "`nPlease specify an application name to check version." -ForegroundColor Yellow
    } else {
      # else validate each application name
      $ApplicationNames | ForEach-Object {
        if ($ValidApplicationNames -notcontains $_) {
          $Success = $false
          Write-Host "`nSorry, " -ForegroundColor Yellow -NoNewline
          Write-Host $_ -ForegroundColor Cyan -NoNewline
          Write-Host " is not a valid application name." -ForegroundColor Yellow
        }
      }
    }
    # if bad param, display list of valid names and return
    if ($Success -eq $false) {
      Write-Host "`nValid application names:"
      Out-IHIToOrderedColumns -ListToDisplay $ValidApplicationNames -Columns 4
      Write-Host $HelpMessage
    } else {
      # it is valid so store in global context
      $script:ApplicationNames = $ApplicationNames
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
Validates and sets value for Version; confirms package does not exist
.DESCRIPTION
Validates and sets value for Version; also confirms package does not exist.
Returns $true if successful; if error occurs, writes errors messages to 
host (not error stream) and returns $false.
.PARAMETER Version
Version to validate and set
.EXAMPLE
Set-IHIVersion 9876
Validates and sets version of 9876
#>
function Set-IHIVersion {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [int]$Version
  )
  #endregion
  process {
    $Success = $true

    # validate Version is positive integer
    if ($Version -notmatch "^\d+$") {
      Write-Host "`nVersion $Version is not a valid version`n" -ForegroundColor Yellow
      $Success = $false
    } else {
      # Get HEAD revision number
      $Err = $null
      [int]$HeadVersion = Get-IHIRepositoryHeadVersion -EV Err
      if ($Err -ne $null) {
        $Err | Write-Error
        [string]$ErrorMessage = "Error attempting to get repository head version"
        Write-Error -Message $ErrorMessage
        $Success = $false
      } else {
        # if no version specified, use HEAD 
        if ($Version -eq 1) {
          $Version = $HeadVersion
        }
        # build up path of where final package should exist to see if already built
        [string]$FinalReleaseFolder = Join-Path -Path $Ihi:BuildDeploy.ReleasesFolder -ChildPath (Get-IHIApplicationPackageFolderName -ApplicationName $ApplicationName -Version $Version)

        # at this point, version is a valid number
        # but make sure version is less than or equal to HEAD
        if ($Version -gt $HeadVersion) {
          Write-Host "`nVersion $Version is greater than HEAD version $HeadVersion`n" -ForegroundColor Yellow
          $Success = $false
          # and make sure this version hasn't already been built
        } elseif ($true -eq (Test-Path -Path $FinalReleaseFolder)) {
          Write-Host "`nBuild version $Version of $ApplicationName already exists, no need to rebuild.`n" -ForegroundColor Yellow
          $Success = $false
        } else {
          # it's valid and not already built so set the script-level variable
          $script:Version = $Version
        }
      }
    }
    $Success
  }
}
#endregion


#region Functions: Invoke-IHIBuildCodeClient

<#
.SYNOPSIS
Builds an application package version on the build server
.DESCRIPTION
Builds an application package (or packages) version on the build server.
.PARAMETER ApplicationName
Name of application to build. Can be multiple names separated by commas
.PARAMETER Version
Version of application package to build
.PARAMETER TestBuild
If specified, runs entire build process but doesn't copy package at end to Releases folder.
This is typically used for performing test builds to make sure any new code compiles and builds
correctly.
.PARAMETER Help
Displays help about this command
.EXAMPLE
Invoke-IHIBuildCodeClient SURVEYCENTER
Builds latest version of SURVEYCENTER
.EXAMPLE
Invoke-IHIBuildCodeClient SURVEYCENTER 5678
Builds version 5678 of SURVEYCENTER
.EXAMPLE
Invoke-IHIBuildCodeClient SURVEYCENTER, CSICONSOLE 
Builds latest version of SURVEYCENTER and CSICONSOLE
.EXAMPLE
Invoke-IHIBuildCodeClient SURVEYCENTER, CSICONSOLE 5678
Builds version 5678 of SURVEYCENTER and CSICONSOLE
#>
function Invoke-IHIBuildCodeClient {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$ApplicationNames = $NotPassed,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [int]$Version = 1,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$TestBuild,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [System.Management.Automation.PSCredential]$UserCredential = $null,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$Help
  )
  #endregion
  process {
    # if help requested, display and exit
    if ($Help -eq $true) { Out-IHIBuildClientHelp; return }

    # initialize the module
    Initialize
    


    # validate and set application name(s)
    if ((Set-IHIApplicationNames -ApplicationNames $ApplicationNames) -eq $false) { return }

   $script:ApplicationNames | ForEach-Object {
        # make sure name is uppercase
        $ApplicationName = $_.ToUpper()

        #region Parameter validation and set module values
        # confirm client machine is on IHI network/vpn
        if ((Confirm-IHIClientMachineOnIhiNetwork) -eq $false) { return }
        # validate and set application name
        if ((Set-IHIApplicationName -ApplicationName $ApplicationName) -eq $false) { return }
        # validate and set application version; exit if fails
        if ((Set-IHIVersion -Version $Version) -eq $false) { return }
        # store username of person that launched process
        [string]$User = $env:UserName
        # in the event that $env:UserName is blank (SVN post-commit hook) set to hard-coded value
        if ($User -eq $null -or $User.Trim() -eq "") { $User = "Commit_Compile" }
        $script:LaunchUserName = $User
        # if not running on the build server, get credentials
        if ((Get-IHIFQMachineName) -ne $Ihi:BuildDeploy.SvnMain.Server) {
          if ((Set-IHIPSCredential -Credential $UserCredential) -eq $false) { return }
       }
        #endregion

        # set module value of TestBuild
        $script:TestBuild = $TestBuild

        # display settings info; uncomment for debug purposes only
        # Out-IHIBuildClientSettings

        # build the package
        $Results = Build-IHIPackageOnBuildServer
        # don't bother with error or success message - the server build process will output it's own
    }
  }
}
Export-ModuleMember -Function Invoke-IHIBuildCodeClient
New-Alias -Name "build" -Value Invoke-IHIBuildCodeClient
Export-ModuleMember -Alias "build"
#endregion


