
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


#region Functions: Confirm-IHIValidXmlGeneral

<#
.SYNOPSIS
Validate deploy xml General section
.DESCRIPTION
Validate deploy xml General section
.PARAMETER ApplicationXml
Application xml
.EXAMPLE
Confirm-IHIValidXmlGeneral -ApplicationXml <ApplicationXml>
As long as Extranet.xml is valid, returns $null
#>
function Confirm-IHIValidXmlGeneral {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [System.Xml.XmlDocument]$ApplicationXml
  )
  #endregion
  process {
    # Check if these properties exist and are not-null
    #   Application
    #   Application.General
    #   Application.General.Name
    #   Application.General.NotificationEmails
    if ((Get-Member -InputObject $ApplicationXml -Name Application) -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: application file has invalid XML: missing Application"
      return
    }
    if ((Get-Member -InputObject $ApplicationXml.Application -Name General) -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: application file has invalid XML: missing Application.General"
      return
    }
    if ((Get-Member -InputObject $ApplicationXml.Application.General -Name Name) -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: application file has invalid XML: missing Application.General.Name"
      return
    }
    if ($ApplicationXml.Application.General.Name.Trim() -eq "") {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: application file has invalid XML: Application.General.Name is empty"
      return
    }
    if ((Get-Member -InputObject $ApplicationXml.Application.General -Name NotificationEmails) -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: application file has invalid XML: missing Application.General.NotificationEmails"
      return
    }
    if ((Get-Member -InputObject $ApplicationXml.Application.General.NotificationEmails -Name Email) -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: application file has invalid XML: missing Application.General.NotificationEmails.Email"
      return
    }
  }
}
Export-ModuleMember -Function Confirm-IHIValidXmlGeneral
#endregion
