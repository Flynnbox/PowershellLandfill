#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
    # constant to help identify when params not passed
    [string]$script:NotPassed = "<NOT_PASSED>"
    # help message
    [string]$script:HelpMessage = "`nFor full parameter and usage information type: version -Help`n"
    # name of applications to check version
    [string[]]$script:ApplicationNames = $null
    # array of xml documents to parse for details
    [xml[]]$script:ApplicationConfigXmls = $null
    # array of array of PSObjects of version info
    [object[]]$script:ApplicationVersions = $null
    # hashtable of server history files; key is server name, value is file contents
    # this is a local cache so this data can be reused and not have to be re-fetched if checking multiple apps on same servers
    [hashtable]$script:ServerDeployHistoryFilesCache = @{}
  }
}
# initialize/reset the module
Initialize
# ensure best practices for variable use, function calling, null property access, etc.
# must be done at module script level, not inside Initialize, or will only be function scoped
Set-StrictMode -Version 2
#endregion


#region Functions: Add-IHIVersionOrderColor, Get-IHINextVersionColor

<#
.SYNOPSIS
Add version order color information to ApplicationVersions data
.DESCRIPTION
Add version order color information to ApplicationVersions data
.EXAMPLE
Add-IHIVersionOrderColor
Add version order color information to ApplicationVersions data
#>
function Add-IHIVersionOrderColor {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    # for each set of application version, loop through each set of application version data...
    $script:ApplicationVersions | ForEach-Object {
      $AppVersionDataSet = $_
      # initialize current version data color info
      [string]$CurrentColor = "None"
      [hashtable]$VersionColors = @{}
      # for each app version entry in a set, check if version has been encountered yet (stored in VersionColors)
      #   if not found
      #     get next color, add to versioncolors and set property on version data
      #   if color has been found
      #      add that color to property
      $AppVersionDataSet | ForEach-Object {
        $AppVersionData = $_
        [string]$CurrentVersion = $AppVersionData.Version
        if ($VersionColors.Keys -notcontains $CurrentVersion) {
          $CurrentColor = Get-IHINextVersionColor -CurrentColor $CurrentColor
          $VersionColors.$CurrentVersion = $CurrentColor
          # add with the new current color
          Add-Member -InputObject $AppVersionData -MemberType NoteProperty -Name "VersionColor" -Value $CurrentColor
        } else {
          # add with the pre-existing color for 
          Add-Member -InputObject $AppVersionData -MemberType NoteProperty -Name "VersionColor" -Value $($VersionColors.$CurrentVersion)
        }
      }
    }
  }
}

<#
.SYNOPSIS
Get next version color given current color
.DESCRIPTION
Get next version color given current color
.EXAMPLE
Get-IHINextVersionColor -CurrentColor Cyan
Returns: Yellow
#>
function Get-IHINextVersionColor {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$CurrentColor
  )
  #endregion
  process {
    # returns next color, loops from DarkCyan back to White
    switch ($CurrentColor) {
      "None" { "White" }
      "White" { "Cyan" }
      "Cyan" { "Yellow" }
      "Yellow" { "Green" }
      "Green" { "Magenta" }
      "Magenta" { "Red" }
      "Red" { "DarkCyan" }
      "DarkCyan" { "White" }
    }
  }
}
#endregion


#region Functions: Confirm-IHIClientMachineOnIhiNetworkForVersion

<#
.SYNOPSIS
Confirms client machine is on IHI network/vpn
.DESCRIPTION
Confirms client machine is on IHI network/vpn
.EXAMPLE
Confirm-IHIClientMachineOnIhiNetworkForVersion
Returns: $true
#>
function Confirm-IHIClientMachineOnIhiNetworkForVersion {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    $Success = $true
    # check if on IHI network by testing if $Ihi:BuildDeploy.CopyServer is available
    if ($false -eq (Test-Connection -ComputerName $($Ihi:BuildDeploy.CopyServer) -Count 1 -Quiet)) {
      Write-Host "`nYou are not on the IHI network - cannot run version`n" -ForegroundColor Yellow
      $Success = $false
    }
    $Success
  }
}
#endregion


#region Functions: Get-IHIServerDeployHistoryFile

<#
.SYNOPSIS
Retrieves server deploy history file or $null if it does not exist
.DESCRIPTION
Retrieves server deploy history file or $null if it does not exist.  Attempts
to retrieve it from local cache, else gets it from server itself
.EXAMPLE
Get-IHIServerDeployHistoryFile -ServerName DEVAPPWEB.IHI.COM
#>
function Get-IHIServerDeployHistoryFile {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ServerName
  )
  #endregion
  process {
    if ($script:ServerDeployHistoryFilesCache.Keys -contains $ServerName) {
      # return back contents of value for that server namea
      $script:ServerDeployHistoryFilesCache.$ServerName
    } else {
      # attempt to fetch server deploy history file; if not found, return $null
      # else fetch, store in cache and return values
      # build path to server history file
      #   format: \\<Server name>\Deploys\DeployHistory.txt
      [string]$ServerDeployHistoryFilePath = "\\" + $ServerName + "\Deploys\DeployHistory.txt"
      # found, so add to cache and return it
      if (Test-Path -Path $ServerDeployHistoryFilePath) {
        $ServerDeployHistoryContent = Get-Content -Path $ServerDeployHistoryFilePath
        $script:ServerDeployHistoryFilesCache.$ServerName = $ServerDeployHistoryContent
        $ServerDeployHistoryContent
      } else {
        # not found, return $null
        $null
      }
    }
  }
}
#endregion 


#region Functions: Get-IHIApplicationVersionInfoForAppConfig

<#
.SYNOPSIS
Retrieves version information for servers in an application config
.DESCRIPTION
Retrieves version information for servers in an application config
.EXAMPLE
Get-IHIApplicationVersionInfoForAppConfig <application xml>
Retrieves version information for servers in an application config
#>
function Get-IHIApplicationVersionInfoForAppConfig {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [xml]$AppConfig
  )
  #endregion
  process {
    # paths to files
    [string]$AppServerVersionFilePath = $null
    # get application name
    [string]$AppName = $AppConfig.Application.General.Name
    # get version file name
    [string]$VersionFileName = Get-IHIApplicationVersionFileName -ApplicationName $AppName
    # get servers
    $Servers = Get-IHIDeployServersFromXml -ApplicationXml $AppConfig
    # if no server data (because no DeploySettings section) then return
    if ($null -eq $Servers) { return }
    $Servers | Where-Object { $_.Name -ne "LOCALHOST" } | ForEach-Object {
      $Server = $_
      # get new object to store data
      $AppServerVersionData = New-IHIApplicationServerVersionData
      # get application name
      $AppServerVersionData.Application = $AppName
      # get server data
      $AppServerVersionData.Nickname = $Server.Nickname
      $AppServerVersionData.Server = $Server.Name
      # build path to application server version file
      #   format: \\<Server name>\Deploys\CurrentVersions\<Server nickname>\<Version filename>
      $AppServerVersionFilePath = "\\" + $AppServerVersionData.Server + "\Deploys\CurrentVersions\" + $AppServerVersionData.Nickname + "\" + $VersionFileName
      # if path doesn't exist (server not set up or application not deploy to 
      # server using new mechanism, then return UNKNOWN
      if (Test-Path -Path $AppServerVersionFilePath) {
        $AppServerVersionData.Version = Get-Content -Path $AppServerVersionFilePath
        # get User, Date, Success and Redeploy info in the server history deploy file
        # if history file not found (server not setup yet), it returns $null
        $ServerDeployHistoryFileContent = Get-IHIServerDeployHistoryFile -ServerName $AppServerVersionData.Server
        if ($ServerDeployHistoryFileContent -ne $null) {
          # start of pattern: match specific application version deployed to a server
          $Pattern = "^" + $AppServerVersionData.Application + " +" + $AppServerVersionData.Nickname + " +" + $AppServerVersionData.Server + " +" + $AppServerVersionData.Version + " +"
          # end of pattern: capture User, Date, and Success
          $Pattern += "(?<User>\w+) +(?<Date>\d\d/\d\d/\d\d\d\d \d\d:\d\d) +(?<Success>[\w]+) +$"
          [string[]]$MatchingLines = $ServerDeployHistoryFileContent -match $Pattern
          if ($MatchingLines.Count -eq 0) {
            # not in deploy history; odd but not necessarily critical error
            # do nothing, User/Date/Success/Redeploy value are empty
          } elseif ($MatchingLines.Count -eq 1) {
            # 1 exact match - the norm
            $MatchingLines[0] -match $Pattern > $null
            $AppServerVersionData.User = $matches.User
            $AppServerVersionData.Date = $matches.Date
            $AppServerVersionData.Success = $matches.Success
          } elseif ($MatchingLines.Count -gt 1) {
            # multiple matches; use latest entry which is last entry
            # and set Redeploy = True
            $MatchingLines[-1] -match $Pattern > $null
            $AppServerVersionData.User = $matches.User
            $AppServerVersionData.Date = $matches.Date
            $AppServerVersionData.Success = $matches.Success
            $AppServerVersionData.Redeploy = "True"
          }
        }
      } else {
        Write-Host "Could not find $($AppServerVersionFilePath)"
        $AppServerVersionData.Version = "UNKNOWN"
        $AppServerVersionData.User = ""
        $AppServerVersionData.Date = ""
        $AppServerVersionData.Success = ""
        $AppServerVersionData.Redeploy = ""
      }
      $AppServerVersionData
    }
  }
}
#endregion


#region Functions: New-IHIApplicationServerVersionData
<#
.SYNOPSIS
Creates empty PSObject for application server version data
.DESCRIPTION
Creates empty PSObject for application server version data
.EXAMPLE
New-IHIApplicationServerVersionData
Creates empty PSObject for application server version data
#>
function New-IHIApplicationServerVersionData {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    1 | Select Application,Nickname,Server,Version,User,Date,Success,Redeploy
  }
}
#endregion


#region Functions: Out-IHIVersionHeader, Out-IHIVersionDetails

<#
.SYNOPSIS
Writes version header to host
.DESCRIPTION
Writes version header to host
.EXAMPLE
Out-IHIVersionHeader
Writes version header to host
#>
function Out-IHIVersionHeader {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    $HistoryFileColumnWidths = Get-IHIHistoryFileColumnWidths
    $HeaderLineFormat = "{0,-$($HistoryFileColumnWidths.Application)} {1,-$($HistoryFileColumnWidths.Nickname)} {2,-$($HistoryFileColumnWidths.ServerNoFQDN)} {3,-$($HistoryFileColumnWidths.Version)} {4,-$($HistoryFileColumnWidths.User)} {5,-$($HistoryFileColumnWidths.Date)} {6,-$($HistoryFileColumnWidths.Success)} {7}"
    $HeaderLineContent = $HeaderLineFormat -f "Application","Nickname","Server","Version","User","Date","Success","Redeploy"
    Write-Host $HeaderLineContent
    $HeaderLineContent = $HeaderLineFormat -f "-----------","--------","------","-------","----","----","-------","--------"
    Write-Host $HeaderLineContent
  }
}

<#
.SYNOPSIS
Writes version details to host
.DESCRIPTION
Writes version details to host
.EXAMPLE
Out-IHIVersionDetails
Writes version details to host
#>
function Out-IHIVersionDetails {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    $HistoryFileColumnWidths = Get-IHIHistoryFileColumnWidths
    # format for Application/Nickname/Server
    $EntryLinePart1Format = "{0,-$($HistoryFileColumnWidths.Application)} {1,-$($HistoryFileColumnWidths.Nickname)} {2,-$($HistoryFileColumnWidths.ServerNoFQDN)} "
    # format for Version
    $EntryLinePart2Format = "{0,-$($HistoryFileColumnWidths.Version)} "
    # format for remaining fields
    $EntryLinePart3Format = "{0,-$($HistoryFileColumnWidths.User)} {1,-$($HistoryFileColumnWidths.Date)} {2,-$($HistoryFileColumnWidths.Success)} {3}"
    # loop through each version set, then for each set, loop through each version data object and display
    $script:ApplicationVersions | ForEach-Object {
      $AppVersionDataSet = $_
      $AppVersionDataSet | ForEach-Object {
        $AppVersionData = $_
        # output Application/Nickname/Server
        # when outputting server name, remove FQDN (.IHI.COM) so less display area required
        $EntryLineContent = $EntryLinePart1Format -f $AppVersionData.Application,$AppVersionData.Nickname,$AppVersionData.Server.Replace(".IHI.COM","")
        Write-Host $EntryLineContent -NoNewline
        # output version with color
        $EntryLineContent = $EntryLinePart2Format -f $AppVersionData.Version
        Write-Host $EntryLineContent -ForegroundColor $AppVersionData.VersionColor -NoNewline
        # output remaining fields
        $EntryLineContent = $EntryLinePart3Format -f $AppVersionData.User,$AppVersionData.Date,$AppVersionData.Success,$AppVersionData.Redeploy
        Write-Host $EntryLineContent
      }
    }
  }
}
#endregion


#region Functions: Out-IHIVersionHelp

<#
.SYNOPSIS
Writes version help to host
.DESCRIPTION
Writes version help to host
.EXAMPLE
Out-IHIVersionHelp
Writes version help to host
#>
function Out-IHIVersionHelp {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    Write-Host "`nversion -ApplicationName [string[]] -PSObject -GridView"
    Write-Host "`n  ApplicationName:      name of application(s) to check version"
    Write-Host "  PSObject:             return version data as PSObjects for programmatic use"
    Write-Host "  GridView:             returns data in a sortable, filterable grid"
    Write-Host "`n  Examples:"
    Write-Host "    version EXTRANET                (displays deploy version info for Extranet)"
    Write-Host "    version EXTRANET,EVENTS         (displays deploy version info these applications)"
    Write-Host "    version EXTRANET  -PSObject     (returns Extranet version data as PSOBjects)`n"
    Write-Host "    version EXTRANET  -GridView     (display Extranet version data in a grid)`n"
    Write-Host "`nValid application names:"
    $ValidApplicationNames = Get-IHIApplicationNames
    Out-IHIToOrderedColumns -ListToDisplay $ValidApplicationNames -Columns 4
  }
}
#endregion


#region Functions: Out-IHIVersionServerHelp

<#
.SYNOPSIS
Writes application version history help to host
.DESCRIPTION
Writes application version history help to host
.EXAMPLE
Out-IHIVersionServerHelp
Writes application version history help to host
#>
function Out-IHIVersionServerHelp {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    Write-Host "`napphistory -Application [string[]] -Server [string[]]"
    Write-Host "`n  Application:          name of application to check version"
    Write-Host "  Server:               returns application install history from this server"
    Write-Host "`n  Examples:"
    Write-Host "    apphistory EXTRANET  TESTAPPWEB     (returns Extranet install history from TESTAPPWEB)`n"
    Write-Host "`nValid application names:"
    $ValidApplicationNames = Get-IHIApplicationNames
    Out-IHIToOrderedColumns -ListToDisplay $ValidApplicationNames -Columns 4
  }
}
#endregion


#region Functions: Set-IHIApplicationConfigXmls

<#
.SYNOPSIS
Gathers, validates and stores application config xml files
.DESCRIPTION
Gathers, validates and stores application config xml files; returns $true 
if successful; if error occurs, writes errors messages to host (not error 
stream) and returns $false
.EXAMPLE
Set-IHIApplicationConfigXmls
Gathers, validates and stores application config xml files
#>
function Set-IHIApplicationConfigXmls {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    $Success = $true
    $ConfigFile = $null
    [string]$AppName = $null
    [string]$ConfigFilePath = $null
    [xml]$TempXml = $null
    $script:ApplicationNames | ForEach-Object {
      $AppName = $_.ToString()
      $Err = $null
      # we known file already exists; the list of valid app names was filtered based on the 
      # existence of the file, so no need to check for error
      $ConfigFilePath = (Get-IHIApplicationConfigFile -ApplicationName $_).FullName
      # make sure XML is ok
      if ($false -eq (Test-Xml -Path $ConfigFilePath)) {
        Write-Host "`nApplication file does not contain valid xml: $ConfigFilePath" -ForegroundColor Yellow
        $Success = $false
      } else {
        $TempXml = [xml](Get-Content -Path $ConfigFilePath)
        # confirm the xml contains the standard, required settings
        $Err = $null
        Confirm-IHIValidDeployXml -ApplicationXml $TempXml -EV Err
        if ($Err -ne $null) {
          Write-Host "`nApplication file does not contain valid application xml: $ConfigFilePath" -ForegroundColor Yellow
          $Err | Write-Host
          $Success = $false
        }
      }
      # if made it to this point, xml is valid so store in array of xml configs
      $script:ApplicationConfigXmls +=,([xml](Get-Content -Path $ConfigFilePath))
    }
    # if Success is false, reset any values in ApplicationConfigXmls
    if ($Success -eq $false) {
      $script:ApplicationConfigXmls = $null
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
    # if user specified ALL, retrieve all application names
    if ($ApplicationNames.Count -eq 1 -and $ApplicationNames[0] -eq "ALL") {
      $ApplicationNames = Get-IHIApplicationNames
    }
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


#region Functions: Get-IHIApplicationDeployedVersions

<#
.SYNOPSIS
Gets version information about deployed applications on servers
.DESCRIPTION
Gets version information about deployed applications on servers.  If a value
of ALL is specified for ApplicationNames, all application versions are retrieved.
.PARAMETER ApplicationNames
Name of applications to check version
.PARAMETER PSObject
Return version data as PSObjects, no highlighting or special formatting
.PARAMETER GridView
Return version data in sortable, filterable grid
.PARAMETER Help
Display user-friend (not PowerShell-based) help for this command
.EXAMPLE
Get-IHIApplicationDeployedVersions -ApplicationNames EXTRANET
Outputs version information about EXTRANET
#>
function Get-IHIApplicationDeployedVersions {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$ApplicationNames,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$PSObject,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$GridView,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$Help
  )
  #endregion
  process {
    # if help requested, display and exit
    if ($Help -eq $true) { Out-IHIVersionHelp; return }
    # if no application names passed, show help
    if ($null -eq $ApplicationNames) { Out-IHIVersionHelp; return }

    # initialize the module
    Initialize

    #region Parameter validation and set module/config values
    # confirm client machine is on IHI network/vpn
    if ((Confirm-IHIClientMachineOnIhiNetworkForVersion) -eq $false) { return }
    # validate and set application name(s)
    if ((Set-IHIApplicationNames -ApplicationNames $ApplicationNames) -eq $false) { return }
    # gather, validate and set application config xmls to peruse for version server info
    if ((Set-IHIApplicationConfigXmls) -eq $false) { return }
    #endregion

    # for each application xml, get all version information
    $script:ApplicationConfigXmls | ForEach-Object {
      # get array of PSObjects of application version information
      [object[]]$SingleAppVersionInfo = Get-IHIApplicationVersionInfoForAppConfig -AppConfig $_
      # store array data in another array if not $null
      if ($null -ne $SingleAppVersionInfo) {
        $script:ApplicationVersions +=,($SingleAppVersionInfo)
      }
    }
    # if no data to process, write message and exit
    if ($null -eq $ApplicationVersions) {
      Write-Host "`nNo version data for: $ApplicationNames `n" -ForegroundColor Yellow
      return
    }
    # if user requested GridView, display it
    if ($GridView) {
      # flatten jagged array and pipe objects into Out-GridView
      $script:ApplicationVersions | ForEach-Object { $_ | ForEach-Object { $_ } } | Out-GridView -Title "Version data for: $ApplicationNames"
    } elseif ($PSObject) {
      # if user requested PSObject data return all objects - flatten jagged array 
      $script:ApplicationVersions | ForEach-Object { $_ | ForEach-Object { $_ } }
    } else {
      # will output results with version colors (different color if different version) so
      # need to look through the version data and add a color attribute based on version value
      Add-IHIVersionOrderColor
      # display header
      Write-Host ""
      Out-IHIVersionHeader
      # display version details
      Out-IHIVersionDetails
      Write-Host ""
    }
  }
}
Export-ModuleMember -Function Get-IHIApplicationDeployedVersions
New-Alias -Name "version" -Value Get-IHIApplicationDeployedVersions
Export-ModuleMember -Alias "version"
#endregion

#region Function: Get-IHIApplicationServerInstallHistory

<#
.SYNOPSIS
Displays the install history of an application on a specific server
.DESCRIPTION
Displays the install history of an application on a specific server from the 
Deploy History text file.  If the file is empty, or the Application was not
installed on the server, it will return nothing
.PARAMETER Application
The name of the Application installed on the server
.PARAMETER Server
Name of the Server that is being checked
.EXAMPLE
Get-IHIApplicationServerInstallHistory -Application SPRINGS -SERVER TESTSPRADM
Displays the install history of an application on a specific server
#>

function Get-IHIApplicationServerInstallHistory {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$ApplicationNames,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$Server,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$Help
  )
  #endregion
  process {
    # if help requested, display and exit
    if ($Help -eq $true -or $ApplicationNames -match "help") { Out-IHIVersionServerHelp; return }
    # if no application names passed, show help
    if ($null -eq $ApplicationNames) { Out-IHIVersionServerHelp; return }

    [string]$AppConfigFilePath = $null
    [string]$AppName = $ApplicationNames.ToUpper()

    # initialize the module
    Initialize

    # get path and file name for the config file
    $AppConfigFilePath = (Get-IHIApplicationConfigFile -ApplicationName $AppName).FullName

    #region Parameter validation and set module/config values
    # confirm client machine is on IHI network/vpn
    if ((Confirm-IHIClientMachineOnIhiNetworkForVersion) -eq $false) { return }
    # validate and set application name(s)
    if ((Set-IHIApplicationNames -ApplicationNames $ApplicationNames) -eq $false) { return }
    #endregion

    # Need to get the Server name and Nickname to be able to match the Deploy History file
    # Write-Host "Looking at: $($AppConfigFilePath)"
    $Servers = Get-IHIDeployServersFromXml -ApplicationXml ([xml](Get-Content -Path $AppConfigFilePath))
        
    if ($null -eq $Servers) {
        Write-Host "Nothing matched for $($AppName)"
        return
    }
    $Servers | where-object {$_.Name  -match $Server -or $_.Nickname -eq $Server } | ForEach-Object {
        $ServerName = $_.Name
        $Nickname = $_.Nickname
       
        # build path to application server version file
        $AppServerVersionFilePath = "\\" + $ServerName + "\Deploys\DeployHistory.txt"

        # To do this as a set of values that work perform a regex to pull out the values
        # by doing a capture on the pattern, this will give only the required items from the list
        # add objects to the CustomPSObject created previously
        # start of pattern: match specific application version deployed to a server
        $Pattern = "^" + $AppName + " +" + $Nickname + " +" + $ServerName + " +(?<Version>\d\d\d\d\d) +"
        # end of pattern: capture User, Date, and Success
        $Pattern += "(?<User>\w+) +(?<Date>\d\d/\d\d/\d\d\d\d \d\d:\d\d) +(?<Success>[\w]+) +(?<Redeploy>[\w]?) +$"

        if (Test-Path -Path $AppServerVersionFilePath) {
            # Get all of the Application install history
            $VersionImport = Get-Content $AppServerVersionFilePath
            # Now filtering this according to the application name
            [string[]]$MatchingLines = $VersionImport -match $Pattern
            if ($MatchingLines.Count -eq 0) {
                # Nothing in the deploy history file, not a bad thing if this is a new server
                Write-Host "Nothing matched for $($AppName) on $($Nickname)`n"
                # HL 9/14/2015 - Commenting out the exit here. When we add new servers and haven't deployed to them yet
                #                but still want to get the apphistory, it was exiting and even closing the powershell window. 
                #                We don't want this. I'm leaving it here, commented in case something else needed this as an exit?
                # exit
            } elseif ($MatchingLines.Count -gt 1) {
                # Generate the page structure and format
                # Write-Host 
                $HistoryFileColumnWidths = Get-IHIHistoryFileColumnWidths
                $HeaderLineFormat = "{0,-$($HistoryFileColumnWidths.Application)} {1,-$($HistoryFileColumnWidths.Nickname)} {2,-$($HistoryFileColumnWidths.ServerNoFQDN)} {3,-$($HistoryFileColumnWidths.Version)} {4,-$($HistoryFileColumnWidths.User)} {5,-$($HistoryFileColumnWidths.Date)} {6,-$($HistoryFileColumnWidths.Success)} {7}"    
                $HeaderLineContent = $HeaderLineFormat -f "Application","Nickname","Server","Version","User","Date","Success","Redeploy"
                Write-Host $HeaderLineContent
                $HeaderLineContent = $HeaderLineFormat -f "-----------","--------","------","-------","----","----","-------","--------"
                Write-Host $HeaderLineContent
                # Now to output the matching values
                foreach ($line in $MatchingLines) {
                    # collecting install history for the application
                    $line -match $Pattern > $null
                    $HeaderLineContent = $HeaderLineFormat -f $AppName,$Nickname,$Nickname,$Matches.Version,$Matches.User,$Matches.Date,$Matches.Success,$Matches.Redeploy
                    Write-Host $HeaderLineContent
                }
            }
        } else {
            Write-Host "No Deploy History found...$AppServerVersionFilePath`n"
            exit
        }
     }
  }
}

Export-ModuleMember -Function Get-IHIApplicationServerInstallHistory
New-Alias -Name "apphistory" -Value Get-IHIApplicationServerInstallHistory
Export-ModuleMember -Alias "apphistory"
#endregion



#region Function: Get-IHIApplicationLatestPackageVersion

<#
.SYNOPSIS
Displays the latest version of the application that lives in the Releases folder
.DESCRIPTION
Displays the latest version of the application that lives in the Releases folder
.PARAMETER Application
The name of the Application
.EXAMPLE
Get-IHIApplicationLatestPackageVersion -Application SPRINGS
#>

function Get-IHIApplicationLatestPackageVersion {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$ApplicationName,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$Help
  )
  #endregion
  process {
    
    # validate and set application name(s)
    if ((Set-IHIApplicationNames -ApplicationNames $ApplicationName) -eq $false) { return }
    # get package Versions
    $PackageVersions = Get-childitem -Path $ihi:BuildDeploy.ReleasesFolder -Filter $($ApplicationName +"*") | where-object {$_.Name -imatch ($ApplicationName + "_[0-9]+") } | where-object {$_.Name.Contains(".") -eq $false } | where-object {$_.Name.Contains(".")  -eq $false} | forEach-object { $_.Name} | foreach-object {$_.Substring($_.LastIndexOf("_") + 1) } 
    $($PackageVersions | measure -Maximum).Maximum  
  }
}

Export-ModuleMember -Function Get-IHIApplicationLatestPackageVersion
New-Alias -Name "VersionLatestPackage" -Value Get-IHIApplicationLatestPackageVersion
Export-ModuleMember -Alias "VersionLatestPackage"
#endregion



#region Function: Get-IHIApplicationVersionByServerNickname

<#
.SYNOPSIS
Displays the latest version of the application that lives in the Releases folder
.DESCRIPTION
Displays the latest version of the application that lives in the Releases folder
.PARAMETER Application
The name of the Application
.EXAMPLE
Get-IHIApplicationVersionByServerNickname -Application SPRINGS
#>

function Get-IHIApplicationVersionByServer {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$ApplicationName,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$Nickname,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$Help
  )
  #endregion
  process {
      # validate and set application name(s)
    if ((Set-IHIApplicationNames -ApplicationNames $ApplicationName) -eq $false) { return }
    # gather, validate and set application config xmls to peruse for version server info
    if ((Set-IHIApplicationConfigXmls) -eq $false) { return }
    #validate Nickname    
    $script:ApplicationConfigXmls | ForEach-Object {
        $ApplicationNicknames = (Get-IHIDeployServerForNicknameFromXml -ApplicationXml $_ -Nickname $Nickname) 
        if ((Get-IHIDeployServerForNicknameFromXml -ApplicationXml $_ -Nickname $Nickname) -eq $null) { return }
    }
    If ($ApplicationNicknames -eq $null) { return }
    # Get version based on $Nickname.  
    $(Get-IHIApplicationDeployedVersions $ApplicationName -PSObject | where {$_.Nickname -eq $Nickname}).Version
  }
}

Export-ModuleMember -Function Get-IHIApplicationVersionByServer
New-Alias -Name "VersionByServer" -Value Get-IHIApplicationVersionByServer
Export-ModuleMember -Alias "VersionByServer"
#endregion