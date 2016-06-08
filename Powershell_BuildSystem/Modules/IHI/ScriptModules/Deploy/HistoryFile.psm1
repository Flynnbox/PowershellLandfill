#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
    # out-file settings for history file
    [hashtable]$script:OutFileSettings = @{ Encoding = "ascii"; Force = $true; Append = $true }
    #region Set widths of columns in history file
    [hashtable]$script:HistoryFileColumnWidths = @{}
    $script:HistoryFileColumnWidths.Application = 22
    $script:HistoryFileColumnWidths.Nickname = 15
    $script:HistoryFileColumnWidths.Server = 27
    $script:HistoryFileColumnWidths.ServerNoFQDN = 15
    $script:HistoryFileColumnWidths.Version = 8
    $script:HistoryFileColumnWidths.User = 14
    $script:HistoryFileColumnWidths.Date = 17
    $script:HistoryFileColumnWidths.Success = 7
    #endregion
  }
}
# initialize/reset the module
Initialize
# ensure best practices for variable use, function calling, null property access, etc.
# must be done at module script level, not inside Initialize, or will only be function scoped
Set-StrictMode -Version 2
#endregion


#region Functions: Confirm-IHIDeployHistoryFileExists

<#
.SYNOPSIS
Creates a new deploy history file if doesn't exist
.DESCRIPTION
If DeployHistory.txt does not exist at path identified in global path
$Ihi:BuildDeploy.DeployFolders.DeployHistoryFile, creates file and populates
with default headings.
.EXAMPLE
Confirm-IHIDeployHistoryFileExists
Creates a new deploy history file if doesn't exist
#>
function Confirm-IHIDeployHistoryFileExists {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    # if file doesn't exist, create file and insert basic header
    if ($false -eq (Test-Path -Path $Ihi:BuildDeploy.DeployFolders.DeployHistoryFile)) {
      $HeaderLineFormat = "{0,-$($script:HistoryFileColumnWidths.Application)} {1,-$($script:HistoryFileColumnWidths.Nickname)} {2,-$($script:HistoryFileColumnWidths.Server)} {3,-$($script:HistoryFileColumnWidths.Version)} {4,-$($script:HistoryFileColumnWidths.User)} {5,-$($script:HistoryFileColumnWidths.Date)} {6,-$($script:HistoryFileColumnWidths.Success)}"
      $HeaderLineContent = $HeaderLineFormat -f "Application","Nickname","Server","Version","User","Date","Success"
      [hashtable]$Params2 = @{ InputObject = $HeaderLineContent; FilePath = $($Ihi:BuildDeploy.DeployFolders.DeployHistoryFile) } + $OutFileSettings
      $Err = $null
      Out-File @Params2 -ErrorVariable Err
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
        return
      }

      $HeaderLineContent = $HeaderLineFormat -f "-----------","--------","------","-------","----","----","-------"
      [hashtable]$Params2 = @{ InputObject = $HeaderLineContent; FilePath = $($Ihi:BuildDeploy.DeployFolders.DeployHistoryFile) } + $OutFileSettings
      $Err = $null
      Out-File @Params2 -ErrorVariable Err
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
        return
      }
    }
  }
}
Export-ModuleMember -Function Confirm-IHIDeployHistoryFileExists
#endregion


#region Functions: Get-IHIHistoryFileColumnWidths

<#
.SYNOPSIS
Returns hash table with deploy history file columns widths
.DESCRIPTION
Returns hash table with deploy history file columns widths.  Useful
for code outside of direct deploy process that needs to output deploy
version data (i.e. the version utility)
.EXAMPLE
Get-IHIHistoryFileColumnWidths
Returns hash table with deploy history file columns widths
#>
function Get-IHIHistoryFileColumnWidths {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    $script:HistoryFileColumnWidths
  }
}
Export-ModuleMember -Function Get-IHIHistoryFileColumnWidths
#endregion


#region Functions: Update-IHIDeployHistoryFile

<#
.SYNOPSIS
Updates history file with information about deployment
.DESCRIPTION
Updates history file with information about deployment
.PARAMETER Application
Name of application
.PARAMETER EnvironmentNickname
Environment nickname
.PARAMETER Server
Server name
.PARAMETER Version
Version of application
.PARAMETER Username
Name of user doing deploy (actual launch user, not credential user)
.PARAMETER Date
Date of deploy
.PARAMETER Success
Was deploy successful or not
.EXAMPLE
Update-IHIDeployHistoryFile -Application Extranet -EnvironmentNickname DEVAPPWEB -Server DEVAPPWEB.IHI.COM -Version 9876 -Username dward -Date (Get-Date) -Success $true
Updates the history file with the information provided
#>
function Update-IHIDeployHistoryFile {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Application,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$EnvironmentNickname,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Server,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Version,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Username,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [datetime]$Date,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [bool]$Success
  )
  #endregion
  process {
    # NOTE: this format/layout is slightly different than the one used to create the header rows ($HeaderLineFormat)
    # there are two spaces after the date display to make sure all columns have two spaces for easier reading
    $EntryLineFormat = "{0,-$($script:HistoryFileColumnWidths.Application)} {1,-$($script:HistoryFileColumnWidths.Nickname)} {2,-$($script:HistoryFileColumnWidths.Server)} {3,-$($script:HistoryFileColumnWidths.Version)} {4,-$($script:HistoryFileColumnWidths.User)} {5:MM/dd/yyyy HH:mm}  {6,-$($script:HistoryFileColumnWidths.Success)}"
    $EntryLineContent = $EntryLineFormat -f $Application,$EnvironmentNickname,$Server,$Version,$Username,$Date,$Success
    [hashtable]$Params2 = @{ InputObject = $EntryLineContent; FilePath = $($Ihi:BuildDeploy.DeployFolders.DeployHistoryFile) } + $OutFileSettings
    $Err = $null
    Out-File @Params2 -ErrorVariable Err
    if ($? -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
      return
    }
  }
}
Export-ModuleMember -Function Update-IHIDeployHistoryFile
#endregion
