
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


#region Functions: Confirm-IHIDeployVersionsFolder

<#
.SYNOPSIS
Creates a new deploy CurrentVersions folder if doesn't exist
.DESCRIPTION
Creates a new deploy CurrentVersions folder if doesn't exist; folder defined in
$Ihi:BuildDeploy.DeployFolders.CurrentVersions
.EXAMPLE
Confirm-IHIDeployVersionsFolder
Creates deploy folder, if necessary
#>
function Confirm-IHIDeployVersionsFolder {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    [string]$FolderToCreate = $Ihi:BuildDeploy.DeployFolders.CurrentVersions
    if ($false -eq (Test-Path -Path $FolderToCreate)) {
      $Results = New-Item -Path $FolderToCreate -ItemType Directory 2>&1
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating deploy CurrentVersions folder $FolderToCreate :: $("$Results")"
        return
      }
    }
  }
}
Export-ModuleMember -Function Confirm-IHIDeployVersionsFolder
#endregion


#region Functions: Confirm-IHIDeployVersionsNicknameFolder

<#
.SYNOPSIS
Creates a new deploy CurrentVersions EnvironmentNickname folder if doesn't exist
.DESCRIPTION
Creates a new deploy CurrentVersions EnvironmentNickname folder if doesn't exist;
folder defined in $Ihi:BuildDeploy.DeployFolders.CurrentVersions \ EnvironmentNickname
.PARAMETER EnvironmentNickname
Environment nickname
.EXAMPLE
Confirm-IHIDeployVersionsNicknameFolder -EnvironmentNickname DEVAPPWEB
Creates deploy versions nickname folder, if necessary
#>
function Confirm-IHIDeployVersionsNicknameFolder {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$EnvironmentNickname
  )
  #endregion
  process {
    [string]$FolderToCreate = Join-Path -Path $($Ihi:BuildDeploy.DeployFolders.CurrentVersions) -ChildPath $EnvironmentNickname
    if ($false -eq (Test-Path -Path $FolderToCreate)) {
      $Results = New-Item -Path $FolderToCreate -ItemType Directory 2>&1
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating deploy CurrentVersions\EnvironmentNickname folder $FolderToCreate :: $("$Results")"
        return
      }
    }
  }
}
Export-ModuleMember -Function Confirm-IHIDeployVersionsNicknameFolder
#endregion


#region Functions: Confirm-IHIDeployLogsArchiveFolder

<#
.SYNOPSIS
Creates a new deploy DeployLogsArchive folder if doesn't exist
.DESCRIPTION
Creates a new deploy DeployLogsArchive folder if doesn't exist; folder defined in
$Ihi:BuildDeploy.DeployFolders.DeployLogsArchive
.EXAMPLE
Confirm-IHIDeployLogsArchiveFolder
Creates deploy logs archive folder, if necessary
#>
function Confirm-IHIDeployLogsArchiveFolder {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    [string]$FolderToCreate = $Ihi:BuildDeploy.DeployFolders.CurrentVersions
    if ($false -eq (Test-Path -Path $FolderToCreate)) {
      $Results = New-Item -Path $FolderToCreate -ItemType Directory 2>&1
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating deploy DeployLogsArchive folder $FolderToCreate :: $("$Results")"
        return
      }
    }
  }
}
Export-ModuleMember -Function Confirm-IHIDeployLogsArchiveFolder
#endregion


#region Functions: Confirm-IHIDeployLogsArchiveAppVerFolder

<#
.SYNOPSIS
Creates DeployLogsArchive AppName_Version if doesn't exist
.DESCRIPTION
Creates a new deploy DeployLogsArchive ApplicationName_Version folder if doesn't exist;
folder is created under $Ihi:BuildDeploy.DeployFolders.DeployLogsArchive
.PARAMETER ApplicationName
Name of application to deploy
.PARAMETER Version
Version of applicatin package to deploy
.EXAMPLE
Confirm-IHIDeployLogsArchiveAppVerFolder -ApplicationName Extranet -Version 9876
Creates DeployLogsArchive AppName_Version if doesn't exist
#>
function Confirm-IHIDeployLogsArchiveAppVerFolder {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationName,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Version
  )
  #endregion
  process {
    [string]$FolderToCreate = Join-Path -Path $($Ihi:BuildDeploy.DeployFolders.DeployLogsArchive) -ChildPath $(Get-IHIApplicationPackageFolderName -ApplicationName $ApplicationName -Version $Version)
    if ($false -eq (Test-Path -Path $FolderToCreate)) {
      $Results = New-Item -Path $FolderToCreate -ItemType Directory 2>&1
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating deploy DeployLogsArchive ApplicationName_Version folder $FolderToCreate :: $("$Results")"
        return
      }
    }
  }
}
Export-ModuleMember -Function Confirm-IHIDeployLogsArchiveAppVerFolder
#endregion


#region Functions: Confirm-IHIDeployPackagesFolder

<#
.SYNOPSIS
Creates a new deploy Packages folder if doesn't exist
.DESCRIPTION
Creates a new deploy Packages folder if doesn't exist; folder defined in
$Ihi:BuildDeploy.DeployFolders.Packages
.EXAMPLE
Confirm-IHIDeployPackagesFolder
Creates a new deploy Packages folder if doesn't exist
#>
function Confirm-IHIDeployPackagesFolder {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    [string]$FolderToCreate = $Ihi:BuildDeploy.DeployFolders.Packages
    if ($false -eq (Test-Path -Path $FolderToCreate)) {
      $Results = New-Item -Path $FolderToCreate -ItemType Directory 2>&1
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating deploy Packages folder $FolderToCreate :: $("$Results")"
        return
      }
    }
  }
}
Export-ModuleMember -Function Confirm-IHIDeployPackagesFolder
#endregion


#region Functions: Confirm-IHIDeployRootFolder

<#
.SYNOPSIS
Creates a new deploy root folder if doesn't exist
.DESCRIPTION
Creates a new deploy root folder if doesn't exist; folder defined in
$Ihi:BuildDeploy.DeployFolders.DeployRootFolder
.EXAMPLE
Confirm-IHIDeployRootFolder
Creates a new deploy root folder if doesn't exist
#>
function Confirm-IHIDeployRootFolder {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    [string]$FolderToCreate = $Ihi:BuildDeploy.DeployFolders.DeployRootFolder
    if ($false -eq (Test-Path -Path $FolderToCreate)) {
      $Results = New-Item -Path $FolderToCreate -ItemType Directory 2>&1
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating root Deploys folder $FolderToCreate :: $("$Results")"
        return
      }
    }
  }
}
Export-ModuleMember -Function Confirm-IHIDeployRootFolder
#endregion
