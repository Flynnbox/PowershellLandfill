
#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
    # out-file settings for history file
    [hashtable]$script:OutFileSettings = @{ Encoding = "ascii"; Force = $true; Append = $true }
    #region Set widths of columns in history file
    [int]$script:ColWidth_Application = 30
    [int]$script:ColWidth_Nickname = 12
    [int]$script:ColWidth_Server = 12
    [int]$script:ColWidth_Version = 8
    [int]$script:ColWidth_User = 14
    [int]$script:ColWidth_Date = 17
    [int]$script:ColWidth_Success = 7
    #endregion
  }
}
# initialize/reset the module
Initialize
# ensure best practices for variable use, function calling, null property access, etc.
# must be done at module script level, not inside Initialize, or will only be function scoped
Set-StrictMode -Version 2
#endregion


#region Functions: Confirm-IHIValidDeployXml

<#
.SYNOPSIS
Validate deploy xml
.DESCRIPTION
Validate deploy xml
.PARAMETER ApplicationXml
Application xml
.EXAMPLE
Confirm-IHIValidDeployXml -ApplicationXml <ApplicationXml>
Validate deploy xml
#>
function Confirm-IHIValidDeployXml {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [System.Xml.XmlDocument]$ApplicationXml
  )
  #endregion
  process {
    $Err = $null
    Confirm-IHIValidXmlGeneral -ApplicationXml $ApplicationXml -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error detected in Xml section General"
      return
    }

    $Err = $null
    Confirm-IHIValidDeployXmlDeploySettings -ApplicationXml $ApplicationXml -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error detected in Xml section DeploySettings"
      return
    }
    # asdf implement XSD validation
  }
}
Export-ModuleMember -Function Confirm-IHIValidDeployXml
#endregion


#region Functions: Confirm-IHIValidDeployXmlDeploySettings

<#
.SYNOPSIS
Validate deploy xml DeploySettings section
.DESCRIPTION
Validate deploy xml DeploySettings section; either the section does
not exist at all (for applications that have no deploy) or all the
individual sections must be found.
.PARAMETER ApplicationXml
Application xml
.EXAMPLE
Confirm-IHIValidDeployXmlDeploySettings -ApplicationXml <ApplicationXml>
Looks for errors or missing sections in ApplicationXml
#>
function Confirm-IHIValidDeployXmlDeploySettings {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [System.Xml.XmlDocument]$ApplicationXml
  )
  #endregion
  process {
    # Check if no deploy section found; if so, silently return
    if ((Get-Member -InputObject $ApplicationXml.Application -Name DeploySettings) -eq $null) {
      return
    }
    # Check if these properties exist and are not-null
    #   Application.DeploySettings.Servers
    #   Application.DeploySettings.DeployTasks
    #   Application.DeploySettings.DeployTasks.TaskProcess
    if ((Get-Member -InputObject $ApplicationXml.Application.DeploySettings -Name Servers) -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: application file has invalid XML: missing Application.DeploySettings.Servers"
      return
    }
    if ((Get-Member -InputObject $ApplicationXml.Application.DeploySettings.Servers -Name Server) -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: application file has invalid XML: missing Application.DeploySettings.Servers.Server"
      return
    }
    # for each server entry, make sure Nickname and Name aren't null or empty
    foreach ($ServerXml in $ApplicationXml.Application.DeploySettings.Servers.Server) {
      if ($ServerXml.Nickname -eq $null -or $ServerXml.Nickname.Trim() -eq "") {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: DeploySettings.Servers.Server.Nickname is null or empty"
        return
      }
      if ($ServerXml.Name -eq $null -or $ServerXml.Name.Trim() -eq "") {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: DeploySettings.Servers.Server.Name is null or empty"
        return
      }
    }
    if ((Get-Member -InputObject $ApplicationXml.Application.DeploySettings -Name DeployTasks) -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: application file has invalid XML: missing Application.DeploySettings.DeployTasks"
      return
    }
    if ((Get-Member -InputObject $ApplicationXml.Application.DeploySettings.DeployTasks -Name TaskProcess) -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: application file has invalid XML: missing Application.DeploySettings.DeployTasks.TaskProcess"
      return
    }
    if ((Get-Member -InputObject $ApplicationXml.Application.DeploySettings.DeployTasks.TaskProcess -Name Tasks) -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: application file has invalid XML: missing Application.DeploySettings.DeployTasks.TaskProcess.Tasks"
      return
    }
    if ((Get-Member -InputObject $ApplicationXml.Application.DeploySettings.DeployTasks.TaskProcess.Tasks -Name Task) -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: application file has invalid XML: missing Application.DeploySettings.DeployTasks.TaskProcess.Tasks.Task"
      return
    }
  }
}
Export-ModuleMember -Function Confirm-IHIValidDeployXmlDeploySettings
#endregion
