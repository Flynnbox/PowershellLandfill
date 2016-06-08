
#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
  }
}
# initialize/reset the module
Initialize
# ensure best practices for variable use, function calling, null property access, etc.
# must be done at module script level, not inside Initialize, or will only be function scoped
Set-StrictMode -Version 2
#endregion


#region Functions: Expand-IHICodeReleasePackage

<#
.SYNOPSIS
Unzip code release package, if it exists
.DESCRIPTION
Unzip code release package, CodeReleasePackage.zip, if it exists
.PARAMETER ApplicationDeployRootFolder
Folder that contains CodeReleasePackage.zip
.EXAMPLE
Expand-IHICodeReleasePackage -ApplicationDeployRootFolder c:\temp
Unzips CodeReleasePackage.zip found in c:\temp
#>
function Expand-IHICodeReleasePackage {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationDeployRootFolder
  )
  #endregion
  process {
    Write-Host ""
    Write-Host "Looking for code release package to unzip"
    [string]$CodeReleasePackagePath = Join-Path -Path $ApplicationDeployRootFolder -ChildPath "CodeReleasePackage.zip"
    if ($true -eq (Test-Path -Path $CodeReleasePackagePath)) {
      Add-IHILogIndentLevel
      Write-Host "Unzipping code release package: $CodeReleasePackagePath"
      $Err = $null
      Expand-IHIArchive -Path $CodeReleasePackagePath -OutputPath $ApplicationDeployRootFolder -EV Err
      Write-Host "Unzip complete"
      Remove-IHILogIndentLevel
      if ($Err -ne $null) {
        $Err | Write-Host
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: Error occurred expanding code release package: $CodeReleasePackagePath"
        Disable-IHILogFile
        return
      }
    } else {
      Write-Host "No code release package zip found for this deploy package"
    }
  }
}
Export-ModuleMember -Function Expand-IHICodeReleasePackage
#endregion


#region Functions: Get-IHIApplicationPackageVersions

<#
.SYNOPSIS
Returns an array of version numbers for an application
.DESCRIPTION
Returns an array of version numbers for an application
.PARAMETER ApplicationName
Name of application
.EXAMPLE
Get-IHIApplicationPackageVersions -ApplicationName Extranet
Returns string array of versions, i.e.
8765
8768
8777
#>
function Get-IHIApplicationPackageVersions {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationName
  )
  #endregion
  process {
    [string[]]$VersionsNumbers = $null
    # get folder names of existing packages:
    #   - get names of folders (packages) in releases folder using Filter
    #   - then filter specifically on ApplicationName_<number> to purge out similarly named projects
    #       (AGILITY vs. AGILITY_CHARTS)
    #   - filter out folder names that contain a period (old application builds from VSS)
    #   - lastly, get the names as an array of strings, not PSObjects
    # first get folder names
    [string[]]$FolderNames = Get-ChildItem -Path $Ihi:BuildDeploy.ReleasesFolder -Filter $($ApplicationName + "*") | Where-Object { $_.Name -imatch ($ApplicationName + "_[0-9]+") } | Where-Object { $_.Name.Contains(".") -eq $false } | ForEach-Object { $_.Name }
    # if packages found, get their versions
    if ($FolderNames -ne $null) {
      # get just package versions, remove prefix <AppName>_ from <AppName>_<Version>
      $VersionsNumbers = $FolderNames | ForEach-Object { $_.Substring($_.LastIndexOf("_") + 1) }
    }
    # right now $VersionsNumbers is an object[] (even though we 'defined' it as a string array;
    # PowerShell is recreating that array over and over with that ForEach-Object loop and it always
    # recreates it as a object[], no matter what the original type is or the object types are)
    # but we want to make sure the result we give back is sorted numerically, not as a string
    # so, let's cast to an int[] (safe because version are numbers only - no other characters)
    # and then sort and return to user
    ([int[]]$VersionsNumbers) | Sort-Object
  }
}
Export-ModuleMember -Function Get-IHIApplicationPackageVersions
#endregion


#region Functions: Get-IHIDeployServerForNicknameFromXml, Get-IHIDeployServersFromXml, Get-IHIDeployServerListing

<#
.SYNOPSIS
Returns server name for a nickname from application xml
.DESCRIPTION
Returns server name for a nickname from application xml
.PARAMETER ApplicationXml
Application xml
.PARAMETER Nickname
Nickname of environment to deploy to
.EXAMPLE
Get-IHIDeployServerForNicknameFromXml -ApplicationXml <appxml> -Nickname DEV
Returns server name for DEV environment from application xml
#>
function Get-IHIDeployServerForNicknameFromXml {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [xml]$ApplicationXml,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Nickname
  )
  #endregion
  process {
    $ApplicationXml.Application.DeploySettings.Servers.Server | Where { $_.Nickname -eq $Nickname } | Select -ExpandProperty Name
	# Get-PropertyValue Name
  }
}
Export-ModuleMember -Function Get-IHIDeployServerForNicknameFromXml


<#
.SYNOPSIS
Returns array of deploy server objects from application xml
.DESCRIPTION
Returns array of deploy server objects from application xml.  "Server objects" 
are PSObjects with Nickname and Name NoteProperty values.  This assumes the 
xml has been validated, that the section exists and has values, etc.  If the 
entire DeploySettings is missing, return $null
.PARAMETER ApplicationXml
Application xml
.EXAMPLE
Get-IHIDeployServersFromXml -ApplicationXml <app xml>
Returns array of deploy server objects stored in application xml
#>
function Get-IHIDeployServersFromXml {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [xml]$ApplicationXml
  )
  #endregion
  process {
    # Check if no deploy section found; if so, return $null
    if ((Get-Member -InputObject $ApplicationXml.Application -Name DeploySettings) -eq $null) {
      return
    }
    # read server information
    [object[]]$Servers = $null
    [pscustomobject]$Server = $null
    foreach ($ServerXml in $ApplicationXml.Application.DeploySettings.Servers.Server) {
      $Server = New-Object PSCustomObject
      Add-Member -InputObject $Server -MemberType NoteProperty -Name "Nickname" -Value $ServerXml.Nickname
      Add-Member -InputObject $Server -MemberType NoteProperty -Name "Name" -Value $ServerXml.Name
      # add server object to array
      $Servers +=,$Server
    }
    # return servers
    $Servers
  }
}
Export-ModuleMember -Function Get-IHIDeployServersFromXml


<#
.SYNOPSIS
Returns string listing deploy servers from server array
.DESCRIPTION
Returns a string with deploy server nickname/environment information, 
comma-separated.  If the server nickname is the same as the server name,
the value appears only once.  However if the nickname is different, the
server name follow the nickname in parenthesis.
Possible examples:
  DEVAPPWEB, TESTAPPWEB, APP.IHI.ORG
  DEV (DEVSQL), TEST (TESTSQL), PROD (DATAWAREHOUSE)
.PARAMETER Servers
Server information object array
.EXAMPLE
Get-IHIDeployServerListing -Servers <object array of server info>
DEVAPPWEB, TESTAPPWEB, APP.IHI.ORG
#>
function Get-IHIDeployServerListing {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [object[]]$Servers
  )
  #endregion
  process {
    # read server information
    [string]$ServerListing = ""
    for ($i = 0; $i -lt $Servers.Count; $i++) {
      $NickName = $Servers[$i].Nickname
      $Name = $Servers[$i].Name
      if ($NickName.ToUpper() -eq $Name.ToUpper()) {
        $ServerListing += $NickName
      } else {
        $ServerListing += $NickName + " (" + $Name + ")"
      }
      # if not last entry, add comma
      if (($i + 1) -lt $Servers.Count) {
        $ServerListing += ", "
      }
    }
    # return server listing
    $ServerListing
  }
}
Export-ModuleMember -Function Get-IHIDeployServerListing
#endregion


#region Functions: Update-PhoneGapMobileApp

<#
.SYNOPSIS
Updates the PhoneGap Mobile Application
.DESCRIPTION
Updates the PhoneGap Mobile Application by uploading the CodeRelease zip to PhoneGap
.PARAMETER PhoneGapBatch
The path to the PhoneGapBatch script that is the runner for the upload
.PARAMETER Archive
The root name of the zip archive, as this script file is used by multiple mobile apps
.PARAMETER Version
The Version of the OpenSchoolMobileApp build that needs to be uploaded to PhoneGap
.PARAMETER AppID
The ID of the PhoneGap Application, this can be found in the URL to the Application in PhoneGap
.PARAMETER ApplicationName
The Name of the application, this is to allow multiple Mobile Apps to use the same scripts
.EXAMPLE
Update-PhoneGapMobileapp -BatchFile phonegap.bat -Version 12345 -AppID 111111
Uploads the CodeRelease zip file from that build to PhoneGap
#>
function Update-PhoneGapMobileApp {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
	[string]$BatchFile,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
  	[string]$Version,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [String]$AppId,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [String]$ArchiveName,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [String]$ApplicationName
  )
  #endregion
  
  #region Report information before processing
  # Previously the Application Name was hardcoded in the batch script, but in order to make
  # this process more generic this is going to be set here, which should make the batch file
  # slightly simpler since it will no longer need to build up the release path in order to
  # find the archive to send to PhoneGap.
  $Application_Location = $ApplicationName + "_" + $Version
  $DefaultCollWidth = 1
  Write-Host "$($MyInvocation.MyCommand.Name) called with:"
  Add-IHILogIndentLevel
  Write-Host $("{0,-$DefaultCollWidth} {1}" -f "PhoneGap Batch Script file",$BatchFile)
  Write-Host $("{0,-$DefaultCollWidth} {1}" -f "Version of the OpenSchool Mobile App",$Version)
  Write-Host $("{0,-$DefaultCollWidth} {1}" -f "ApplicationID of the Mobile App",$AppId)
  Write-Host $("{0,-$DefaultCollWidth} {1}" -f "Archive Name of the Mobile App",$ArchiveName)
  Write-Host $("{0,-$DefaultCollWidth} {1}" -f "Where the Archive can be found in",$Application_Location)
  Remove-IHILogIndentLevel
  #endregion
  
  #region Upload code archive to PhoneGap
  Add-IHILogIndentLevel
  Write-Host "Running upload to PhoneGap by calling Batch to call Curl."
    $Results = & $BatchFile $Application_Location $AppId $ArchiveName
  if ($Results -ge 1){
	  Write-Host "Error running Update-PhoneGapMobileApp with parameters: $BatchFile $Version $AppId $ArchiveName :: $("$Results")"
  }  
  Remove-IHILogIndentLevel
  #endregion
}
Export-ModuleMember -Function Update-PhoneGapMobileApp
#endregion

function Get-AuthorizationHeader {
    [CmdletBinding()] Param (
     [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)]
     [ValidateNotNullOrEmpty()]
     [string]$Username,
     [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)]
     [ValidateNotNullOrEmpty()]
     [string]$Password
    )
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username,$password)))
    return @{Authorization=("Basic {0}" -f $base64AuthInfo)}
}

function Update-PhoneGapBuild {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
  	[string]$Version,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [String]$AppId,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [String]$ArchivePath,
    [Parameter(ValueFromPipeline = $false)]
    [String]$Username = "itsupport@ihi.org",
    [Parameter(ValueFromPipeline = $false)]
    [String]$Password = "Poiuyt321!"
  )
  #endregion
  
  $UrlBuild = "https://build.phonegap.com/api/v1/apps/$AppId"
  $DefaultCollWidth = 1
  Add-IHILogIndentLevel
  Write-Host $("{0,-$DefaultCollWidth} {1}" -f "Version of the OpenSchool Mobile App",$Version)
  Write-Host $("{0,-$DefaultCollWidth} {1}" -f "ApplicationID of the Mobile App",$AppId)
  Write-Host $("{0,-$DefaultCollWidth} {1}" -f "PhoneGap Build URL",$UrlBuild)
  Write-Host $("{0,-$DefaultCollWidth} {1}" -f "Archive Path of the Mobile App",$ArchivePath)
  Remove-IHILogIndentLevel
  #endregion
  
  #region Upload code archive to PhoneGap
  Add-IHILogIndentLevel
  Write-Host "Uploading to PhoneGap"

  $Headers = Get-AuthorizationHeader $Username $Password
  Invoke-RestMethod -uri $UrlBuild -headers $Headers -method put -inFile $ArchivePath

  Remove-IHILogIndentLevel
  #endregion
}
Export-ModuleMember -Function Update-PhoneGapBuild
#endregion

