#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
    # when writing name/value pairs, width of first column
    [int]$script:DefaultCol1Width = 20
  }
}
# initialize/reset the module
Initialize
# ensure best practices for variable use, function calling, null property access, etc.
# must be done at module script level, not inside Initialize, or will only be function scoped
Set-StrictMode -Version 2
#endregion


#region Functions: Get-IHIRepositoryFileChangedText

<#
.SYNOPSIS
Converts svnlook 'changed' ID prefix to user-readable text
.DESCRIPTION
Converts the 2 character prefix supplied with the svnlook option 'changed' results
from IDs into human readable values.
.PARAMETER Id
Svnlook 2 character prefix.
.EXAMPLE
Get-IHIRepositoryFileChangedText 'A '
Returns: Added
.EXAMPLE
Get-IHIRepositoryFileChangedText 'D '
Returns: Deleted
.EXAMPLE
Get-IHIRepositoryFileChangedText 'U '
Returns: Updated
.EXAMPLE
Get-IHIRepositoryFileChangedText '_U '
Returns: Properties Changed
.EXAMPLE
Get-IHIRepositoryFileChangedText 'UU'
Returns: Updated and Properties Changed
#>
function Get-IHIRepositoryFileChangedText {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Id
  )
  #endregion
  process {
    #region Parameter validation
    #region Make sure Id is 2 characters long
    if ($Id.Length -ne 2) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Id '$Id' is not 2 characters long"
      return
    }
    #endregion
    #endregion

    #region Convert Id to readable text
    [string]$ReadableText = $null
    switch ($Id) {
      "A " { $ReadableText = "Added" }
      "D " { $ReadableText = "Deleted" }
      "U " { $ReadableText = "Updated" }
      "_U" { $ReadableText = "Properties Changed" }
      "UU" { $ReadableText = "Updated and Properties Changed" }
      default { $ReadableText = "Unknown change token: '$Id'" }
    }
    $ReadableText
    #endregion
  }
}
Export-ModuleMember -Function Get-IHIRepositoryFileChangedText
#endregion


#region Functions: Get-IHIRepositoryHeadVersion

<#
.SYNOPSIS
Returns the version number of the repository head (latest version)
.DESCRIPTION
Returns the version number of the repository head (latest version)
.EXAMPLE
Get-IHIRepositoryHeadVersion
Returns 9876
#>
function Get-IHIRepositoryHeadVersion {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    #region Validate Subversion utility and account information
    if ($Ihi:Applications.Repository.SubversionUtility -eq $null -or (!(Test-Path -Path $Ihi:Applications.Repository.SubversionUtility))) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Subversion client not installed or not found at path: $($Ihi:Applications.Repository.SubversionUtility)"
      return
    }
    if ($Ihi:BuildDeploy.SvnMain.ReadOnlyAccount -eq $null -or $Ihi:BuildDeploy.SvnMain.ReadOnlyAccount.UserName -eq $null -or $Ihi:BuildDeploy.SvnMain.ReadOnlyAccount.Password -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: BuildDeploy.SvnMain.ReadOnlyAccount information not set correctly in Ihi: drive"
      return
    }
    #endregion

    #region Get repository head version
    # get the info on the repository root from the repository, using the read only account
    [string]$Cmd = $Ihi:Applications.Repository.SubversionUtility
    [string[]]$Params = "info","--xml",$Ihi:BuildDeploy.SvnMain.RepositoryRootUrl,"--username",$($Ihi:BuildDeploy.SvnMain.ReadOnlyAccount.UserName),"--password",$($Ihi:BuildDeploy.SvnMain.ReadOnlyAccount.Password),"--no-auth-cache"
    $LastExitCode = 0
    $Results = & $Cmd $Params 2>&1
    # error handling note: svn is weird; doesn't set LastExitCode when error but $? seems to be set
    if ($? -eq $false -or $LastExitCode -ne 0) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred calling svn info on repository head with parameters: $("$Cmd $Params") :: $("$Results")"
      return
    }
    # the head revision number is the info.entry.revision
    ([xml]$Results).info.entry.revision
    #endregion
  }
}
Export-ModuleMember -Function Get-IHIRepositoryHeadVersion
#endregion


#region Functions: Export-IHIRepositoryContent

<#
.SYNOPSIS
Exports content from the Subversion repository
.DESCRIPTION
Exports content from the Subversion repository.
.PARAMETER UrlPath
Relative path of source in repository, i.e. /trunk/Extranet
.PARAMETER LocalPath
Local path to export to
.PARAMETER Version
Version of repository to export; if not provided exports HEAD revision
.EXAMPLE
Export-IHIRepositoryContent -UrlPath /trunk/Extranet -LocalPath c:\temp\ExtranetFiles
Exports latest version of content from /trunk/Extranet to c:\temp\ExtranetFiles\Extranet\...
.EXAMPLE
Export-IHIRepositoryContent -UrlPath /trunk/Extranet -LocalPath c:\temp\ExtranetFiles -Version 5000
Exports version 5000 of content from /trunk/Extranet to c:\temp\ExtranetFiles\Extranet\...
#>
function Export-IHIRepositoryContent {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$UrlPath,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$LocalPath,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [int]$Version = 1
  )
  #endregion
  process {
    #region Parameter validation
    #region Validate Subversion utility and account information
    if ($Ihi:Applications.Repository.SubversionUtility -eq $null -or (!(Test-Path -Path $Ihi:Applications.Repository.SubversionUtility))) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Subversion client not installed or not found at path: $($Ihi:Applications.Repository.SubversionUtility)"
      return
    }
    if ($Ihi:BuildDeploy.SvnMain.ReadOnlyAccount -eq $null -or $Ihi:BuildDeploy.SvnMain.ReadOnlyAccount.UserName -eq $null -or $Ihi:BuildDeploy.SvnMain.ReadOnlyAccount.Password -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: BuildDeploy.SvnMain.ReadOnlyAccount information not set correctly in Ihi: drive"
      return
    }
    #endregion

    #region Validate Version is positive integer
    if ($Version -notmatch "^\d+$") {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: version $Version is not a valid version"
      return
    }
    #endregion

    #region Get head version if not passed
    if ($Version -eq 1) {
      $Version = Get-IHIRepositoryHeadVersion
    }
    #endregion
    #endregion

    #region Report information before processing files
    # rather than use PSBoundParameters, manually output for better formatting
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "UrlPath",$UrlPath)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "LocalPath",$LocalPath)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Version",$Version)
    Remove-IHILogIndentLevel
    #endregion

    #region Confirm LocalPath exists, if not, create
    Add-IHILogIndentLevel
    Write-Host "Checking if LocalPath exists"
    if ($false -eq (Test-Path -Path $LocalPath)) {
      Add-IHILogIndentLevel
      Write-Host "Creating LocalPath: $LocalPath"
      Remove-IHILogIndentLevel
      $Results = New-Item -Path $LocalPath -ItemType Directory 2>&1
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating LocalPath folder $LocalPath :: $("$Results")"
        Remove-IHILogIndentLevel
        return
      }
    }
    #endregion

    #region Export repository content
    # store current shell location so we can return to it after the svn retrieval
    # Push/Pop location don't seem to work...? do it the old fashioned way
    [string]$CurrentLocation = (Get-Location).Path

    #region svn export description
    # When we call svn export, we get a copy of the UrlPath, which is typically a folder,
    # and the copy is put UNDER the LocalPath folder.  For example, if our parameters look like:
    #   UrlPath:    /trunk/Extranet
    #   LocalPath:  c:\temp\export
    # First, we need to create the LocalPath (happens above).  Then we need to change location to 
    # this folder and run the svn export command from that folder.  When svn export
    # runs, it'll create Extranet and everything below.  After that we go back to the original location.
    #endregion

    # So, one more time, when we call svn export, we need to be in folder of $LocalPath
    Set-Location $LocalPath

    # get the info on the repository root from the repository, using the read only account
    Write-Host "Exporting content"
    [string]$Cmd = $Ihi:Applications.Repository.SubversionUtility
    [string[]]$Params = "export",($Ihi:BuildDeploy.SvnMain.RepositoryRootUrl + $UrlPath),"--username",$($Ihi:BuildDeploy.SvnMain.ReadOnlyAccount.UserName),"--password",$($Ihi:BuildDeploy.SvnMain.ReadOnlyAccount.Password),"-r",$Version,"--no-auth-cache"
    $LastExitCode = 0
    $Results = & $Cmd $Params 2>&1
    # error handling note: svn is weird; doesn't set LastExitCode when error but $? seems to be set
    if ($? -eq $false -or $LastExitCode -ne 0) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred calling svn export from repository with parameters: $("$Cmd $Params") :: $("$Results")"
      Remove-IHILogIndentLevel
      return
    }
    #return to previous location
    Set-Location -Path $CurrentLocation
    Add-IHILogIndentLevel
    Write-Host "Export complete"
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    #endregion
  }
}
Export-ModuleMember -Function Export-IHIRepositoryContent
#endregion

#region Functions: Set-IHIRepoPassword

<#
.SYNOPSIS
Opens Internet Explorer to CollabNet edit user page
.DESCRIPTION
Opens Internet Explorer to CollabNet edit user page
.EXAMPLE
Set-IHIRepoPassword
<Opens IE to the ...:3343/csvn/user/showSelf page>
#>
function Set-IHIRepoPassword {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    $Path = "http://" + $Ihi:BuildDeploy.BuildServer + ":3343/csvn/user/showSelf"
    Open-IHIInternetExplorer $Path
  }
}
Export-ModuleMember -Function Set-IHIRepoPassword
New-Alias -Name "changepw" -Value Set-IHIRepoPassword
Export-ModuleMember -Alias "changepw"
#endregion


#region Functions: Switch-IHINewRepository

<#
.SYNOPSIS
Switches users main repository working copy to new repository url
.DESCRIPTION
Switches users main repository working copy to new repository url
.EXAMPLE
Switch-IHINewRepository
Switches to the new repository
#>
function Switch-IHINewRepository {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    #region Make sure any dev apps (that might use a SVN password) are closed
    if ($null -ne ((Get-Process | Where-Object { $_.Name -eq 'devenv' }))) {
      Write-Host "Please close Visual Studio and re-run switchrepo"
      return
    }
    if ($null -ne ((Get-Process | Where-Object { $_.Name -eq 'tortoiseproc' }))) {
      Write-Host "Please close any TortoiseSvn windows (check for modifications, repo browser, etc.) that you have open and re-run switchrepo"
      return
    }
    #endregion

    #region Confirm exactly one copy of svn.exe found in path
    $SvnCmd = Get-Command -Name svn.exe
    # if null, no instances, write error and exit
    if ($null -eq $SvnCmd) {
      Write-Host "svn.exe not found on this machine; contact Dan"
      return
    } elseif ($SvnCmd -is [object[]]) {
      # multiple instances, write error and exit
      Write-Host "Multiple instances of svn.exe found on this machine; contact Dan"
      return
    }
    # ok, only one instance found, good; continue on
    #endregion

    #region Delete old cached credentials
    # path to Subversion cached credential files folder is:
    # C:\Users\dward\AppData\Roaming\Subversion\auth\svn.simple
    # If this path exists and has files inside, we'll just delete them
    $AuthFolderPath = Join-Path -Path $env:APPDATA -ChildPath "Subversion\auth\svn.simple"
    if ($false -eq (Test-Path -Path $AuthFolderPath)) {
      Write-Host "No Subversion cached authentication files to delete"
    } else {
      Write-Host "Deleting all Subversion cached credential files"
      Get-ChildItem -Path $AuthFolderPath | Remove-Item -Confirm:$false -Force
    }
    #endregion

    #region Get old and new paths for repository
    # dev values
    # get repository local root folder
    # $RepositoryRoot = "C:\temp\NewRepo\TEST1"
    # $CurrentRepoPath = "http://engbuild.ihi.com/svn/TEST1"
    # $NewRepoPath  = "http://engbuild.ihi.com/svn/Test2"
    # $CurrentRepoPath = "http://engbuild.ihi.com/svn/Test2"
    # $NewRepoPath  = "http://engbuild.ihi.com/svn/TEST1"

    # production values
    # get repository local root folder
    $RepositoryRoot = $Ihi:BuildDeploy.SvnMain.LocalRootFolder
    $CurrentRepoPath = "http://engvss/svn/ihi_main"
    $NewRepoPath = "http://engbuild.ihi.com/svn/IHI_MAIN"
    #endregion

    #region Output settings and confirm with user before continuing
    Write-Host "`nChanging your local working copy:"
    Write-Host "  Local root:   $RepositoryRoot"
    Write-Host "  Current repo: $CurrentRepoPath"
    Write-Host "  New repo:     $NewRepoPath"
    Write-Host ""
    $Input = Read-Host -Prompt "Are you sure you want to continue? Enter Y"
    if ($Input -ne "Y") {
      Write-Host "`nCancelling local working copy switch operation`n"
      return
    }
    #endregion

    #region Run the switch command
    # store current path location
    Push-Location
    # change to repository root directory
    Set-Location -Path $RepositoryRoot

    #region svn.exe command notes
    <#
      Normally we would run the command use this structure:
        $Results = & $Cmd $Params 2>&1
      where $Cmd is the full path to the command.  But this only works 
      if you are certain the command won't be interactive. In this case,
      for the svn switch, we need to run the command in a way that will
      allow user input (password, if prompted) if necessary but the 
      command must be in the path as, for the svn command, we need to
      be in the working copy root folder.
    #>
    #endregion
    Write-Host "Switching local working copy repository path"
    svn switch --relocate $CurrentRepoPath $NewRepoPath --username $env:USERNAME --password 12345 --no-auth-cache
    # error handling note: svn is weird; doesn't set LastExitCode when error but $? seems to be set
    if ($? -eq $false -or $LastExitCode -ne 0) {
      Write-Host "`n`nError occurred - contact MichaelF but DO NOT close this window!`n`n" -ForegroundColor Red
      Send-IHIMailMessage -To "hlattanzio@ihi.org" -From "SvnSwitch@ihi.org" -Subject "Switch-IHINewRepository error $env:COMPUTERNAME $env:USERNAME" -Body "Switch-IHINewRepository error $env:COMPUTERNAME $env:USERNAME" -HighPriority
      # go back to original path location
      Pop-Location
      return
    }
    #endregion

    #region Switch was successful; email Dan
    Write-Host "Switch complete; emailing administrator"
    Add-IHILogIndentLevel
    Send-IHIMailMessage -To "hlattanzio@ihi.org" -From "SvnSwitch@ihi.org" -Subject "Switch-IHINewRepository success $env:COMPUTERNAME $env:USERNAME" -Body "Switch-IHINewRepository success"
    Remove-IHILogIndentLevel
    # go back to original path location
    Pop-Location
    #endregion

    #region User should change password
    Write-Host "`n`nGreat work!"
    Write-Host "`nNow, please repeat these steps (close tools, reopen PowerShell) on any"
    Write-Host "other developer machines or VMs (for SPRINGS folks) that you have."
    Write-Host "`nOnce you've updated all your developer machines then run"
    Write-Host "changepw" -ForegroundColor Magenta -NoNewline
    Write-Host " to open a browser window to change your password."
    Write-Host "`nIf you haven't changed your password yet it's: " -NoNewline
    Write-Host "12345" -ForegroundColor Magenta
    Write-Host "Log in with your account name - but no IHI\ prefix!"
    Write-Host "Click Edit then Change Password`n"
    Start-Sleep -Seconds 8

    #endregion
  }
}
Export-ModuleMember -Function Switch-IHINewRepository
New-Alias -Name "switchrepo" -Value Switch-IHINewRepository
Export-ModuleMember -Alias "switchrepo"

#endregion
