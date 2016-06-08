
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


#region Functions: Remove-IHISharePointUser

<#
.SYNOPSIS
Removes user permissions and profile from current farm
.DESCRIPTION
Removes user permissions and profile from all sites on current farm.  This can
only be run against the local farm.  Uses Remove-SPUser and RemoveUserProfile()
on type Microsoft.Office.Server.UserProfiles.UserProfileManager.
.PARAMETER UserId
Id of user; this is either the email address or the full NTName value in the form
of i:0#.f|edefinemembershipprovider|<email>
.EXAMPLE
Remove-IHISharePointUser -UserId ksweeney@ihi.org
Removes user ksweeney@ihi.org from the current farm.
#>
function Remove-IHISharePointUser {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [string]$UserId
  )
  #endregion
  process {
    #region Parameter validation
    #region Make sure UserId is not a GUID
    # can't use [guid]::TryParse, doesn't exist pre-.NET 4.0
    # assume true, if can't create (exception) then false
    [bool]$IsGuid = $true
    try {
      $Result = New-Object System.GUID $UserId
    } catch {
      $IsGuid = $false
    }
    if ($true -eq $IsGuid) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: UserId cannot be a GUID, must be a NTName; see: Get-Help Remove-IHISPUser -Full"
      return
    }
    #endregion

    #region Verify/change UserId format to be i:0#.f|edefinemembershipprovider|<email>
    # check if prefix i:0#.f|edefinemembershipprovider| found
    # if not, add it to email address
    # this does not validate the format of the email address itself
    # first, make sure lower case
    $UserId = $UserId.ToLower()
    # add prefix if not found
    [string]$IhiNTNamePrefix = "i:0#.f|edefinemembershipprovider|"
    if ($false -eq ($UserId.StartsWith($IhiNTNamePrefix))) {
      $UserId = $IhiNTNamePrefix + $UserId
    }
    #endregion
    #endregion

    Write-Host "Looking for UserId: $UserId"
    # loop through each site and Remove-SPUser
    Add-IHILogIndentLevel
    Get-SPSite | ForEach-Object {
      # get reference to current site
      [Microsoft.SharePoint.SPSite]$Site = $_
      Write-Host "Site: $($Site.Url)"
      Add-IHILogIndentLevel

      #region Remove-SPUser to remove user permissions for site
      # make sure user exists before attempting to remove
      # this check is only relevant for Remove-SPUser, it is not application to the user profile
      [Microsoft.SharePoint.SPUser]$SiteUser = Get-SPUser -Identity $UserId -Web $Site.Url -ErrorAction SilentlyContinue
      if ($null -eq $SiteUser) {
        Write-Host "No SPUser account found"
      } else {
        # remove any basic site permissions
        Write-Host "Removing user permissions"
        $Result = Remove-SPUser -Identity $UserId -Web $Site.Url -Confirm:$false
      }
      #endregion
      Remove-IHILogIndentLevel
    }

    #region Remove UserProfile
    #region Get Context and UserProfileManager to remove user profile
    # get first site, it doesn't matter; while the ProfileManager is created from
    # ServiceContext, which is site-specific, the ProfileManger is not site-specific
    [Microsoft.SharePoint.SPSite]$Site = (Get-SPSite)[0]
    [Microsoft.SharePoint.SPServiceContext]$ServiceContext = [Microsoft.SharePoint.SPServiceContext]::GetContext($Site)
    #Get UserProfileManager from the My Site Host Site context
    [Microsoft.Office.Server.UserProfiles.UserProfileManager]$ProfileManager = New-Object Microsoft.Office.Server.UserProfiles.UserProfileManager $ServiceContext
    #endregion

    #region Call ProfileManager.RemoveUserProfile
    # if the account is weird, it's possible that orphaned permissions exist and
    # no profile exists; so try running these steps, if $UserProfile is $null
    # then no profile exists; unfortunately no easy way to do this without throwing
    # an exception
    $UserProfile = $null
    try {
      $UserProfile = $ProfileManager.GetUserProfile($UserId)
    } catch {
      # do nothing; swallow exception
    }
    if ($null -eq $UserProfile) {
      Write-Host "No user profile found"
    } else {
      Write-Host "Removing user profile"
      $Result = $ProfileManager.RemoveUserProfile($UserId)
    }
    $ProfileManager = $null
    $ServiceContext = $null
    $Site.Dispose()
    $Site = $null
    #endregion
    #endregion

    Remove-IHILogIndentLevel
  }
}
Export-ModuleMember -Function Remove-IHISharePointUser
#endregion
