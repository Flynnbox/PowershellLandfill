
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


#region Functions: Get-IHIWmiServiceResultDescription

<#
.SYNOPSIS
Gets WMI service return code description
.DESCRIPTION
Gets WMI service return code description.  For more information see:
http://msdn.microsoft.com/en-us/library/aa384901(v=vs.85).aspx
.PARAMETER ReturnCode
Return code from WMI
.EXAMPLE
Get-IHIWmiServiceResultDescription -ReturnCode 3
Returns: Dependent Services Running
#>
function Get-IHIWmiServiceResultDescription {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [int]$ReturnCode = 0
  )
  #endregion
  process {
    switch ($ReturnCode) {
      0 { "Success" }
      1 { "Not Supported" }
      2 { "Access Denied" }
      3 { "Dependent Services Running" }
      4 { "Invalid Service Control" }
      5 { "Service Cannot Accept Control" }
      6 { "Service Not Active" }
      7 { "Service Request Timeout" }
      8 { "Unknown Failure" }
      9 { "Path Not Found" }
      10 { "Service Already Running" }
      11 { "Service Database Locked" }
      12 { "Service Dependency Deleted" }
      13 { "Service Dependency Failure" }
      14 { "Service Disabled" }
      15 { "Service Logon Failure" }
      16 { "Service Marked For Deletion" }
      17 { "Service No Thread" }
      18 { "Status Circular Dependency" }
      19 { "Status Duplicate Name" }
      20 { "Status Invalid Name" }
      21 { "Status Invalid Parameter" }
      22 { "Status Invalid Service Account" }
      23 { "Status Service Exists" }
      24 { "Service Already Paused" }
    }
  }
}
Export-ModuleMember -Function Get-IHIWmiServiceResultDescription
#endregion


#region Functions: Install-IHIWindowsNetService

<#
.SYNOPSIS
Installs a .NET windows service 
.DESCRIPTION
Installs a .NET windows service
.PARAMETER ServiceName
Name of service to Install
.PARAMETER Path
Filesystem path to service executable
.PARAMETER StartupType
Service startup type: either Automatic, Manual or Disabled
.PARAMETER DotNetVersionId
ID of .NET version; this is a value of a branch under $Ihi:Applications.DotNet,
i.e. V20 or V40
.PARAMETER DependOnService
Service(s) that this services depends on
.PARAMETER ProcessUserName
User account to run process as; if supplied, assume domain account; if not supplied
assume value of LOCALSYSTEM
.PARAMETER ProcessPassword
Password of ProcessUserName, if supplied
.EXAMPLE
Install-IHIWindowsNetService -ServiceName MyService -Path c:\temp\MyService.exe -StartupType Automatic -DependOnService MSMQ -DotNetVersionId V20
Uninstalls windows .NET service
#>
function Install-IHIWindowsNetService {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ServiceName,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateSet("Automatic","Manual","Disabled")]
    [string]$StartupType,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$DotNetVersionId,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$DependOnService,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$ProcessUserName,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$ProcessPassword
  )
  #endregion
  process {
    #region Parameter validation
    #region Make sure ServiceName NOT currently installed
    if ($null -ne (Get-Service | Where { $_.Name -eq $ServiceName })) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: service $ServiceName is already installed; uninstall first with Uninstall-IHIWindowsNetService"
      return
    }
    #endregion

    #region Make sure service Path is valid
    if ($false -eq (Test-Path -Path $Path)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: service Path does not exist: $($Path)"
      return
    }
    #endregion

    #region Make sure DotNetfVersionId is valid
    # The DotNetVersionId is a value of a branch under $Ihi:Applications.DotNet, i.e. V20 or 
    # V40.  This tells the function which version of the utility to use.
    # Make sure this value is correct
    if ($Ihi:Applications.DotNet.Keys -notcontains $DotNetVersionId) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: $DotNetVersionId is not valid; correct values are: $($Ihi:Applications.DotNet.Keys)"
      return
    }
    #endregion

    #region Get utility based on .NET version and confirm exists
    [string]$UtilityPath = $Ihi:Applications.DotNet.$DotNetVersionId.InstallUtil
    if ($UtilityPath -eq $null -or !(Test-Path -Path $UtilityPath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path for InstallUtil.exe is null or bad: $UtilityPath"
      return
    }
    #endregion

    #region Validate DependOnService values
    # if this services depends on other services, make sure they exist first
    if ($DependOnService -ne $null) {
      foreach ($DependService in $DependOnService) {
        $Exists = (Get-Service | Where-Object { $_.Name -eq $DependService }) -ne $null
        if ($false -eq $Exists) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: DependOnService $DependService not found on machine"
          return
        }
      }
    }
    #endregion

    #region If ProcessUserName specified and not LOCALSYSTEM, make sure ProcessPassword specified
    if (($ProcessUserName.Trim() -ne "") -and ($ProcessUserName.ToUpper() -ne "LOCALSYSTEM")) {
      if ($ProcessPassword -eq "") {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: process uername specified but password is blank"
        return
      }
    }
    #endregion
    #endregion

    #region Report information before installing service
    # rather than use PSBoundParameters, manually output for better formatting
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "ServiceName",$ServiceName)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Path",$Path)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "StartupType",$StartupType)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "DotNetVersionId","$DotNetVersionId")
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "DependOnService",$("$DependOnService"))
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "ProcessUserName",$ProcessUserName)
    # don't display password - ssshhh!
    Remove-IHILogIndentLevel
    #endregion

    #region Run utility and check for error
    # assembly name is path to assemly, log to console but don't log to file
    [string]$Cmd = $UtilityPath
    [string[]]$Params = $Path,"/LogToConsole=true","/LogFile="
    Write-Host "Installing $($ServiceName)..."
    $Results = & $Cmd $Params 2>&1
    if ($? -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred installing $ServiceName at $Path"
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Command: $("$Cmd $Params")"
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: $("$Results")"
      return
    } else {
      # the process only produces a small amount of text; just report it, no need for separate log file
      Add-IHILogIndentLevel
      $Results | Write-Host
      Remove-IHILogIndentLevel
      Write-Host "Service installed."
    }
    #endregion

    #region Set startup type of service
    Write-Host "Set startup type of $ServiceName to $StartupType"
    $Results = Set-Service -Name $ServiceName -StartupType $StartupType 2>&1
    if ($? -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error setting service $ServiceName startup type to $StartupType :: $($Results)"
      return
    }
    Add-IHILogIndentLevel
    Write-Host "Startup type set to $StartupType"
    Remove-IHILogIndentLevel
    #endregion

    #region Set DependOnService values
    if ($DependOnService -ne $null) {
      Write-Host "Setting other service dependencies"
      #registry key for service dependencies
      $ServerDependenciesRegKey = "HKLM:\SYSTEM\CurrentControlSet\Services\"
      $Results = Set-ItemProperty -LiteralPath $($ServerDependenciesRegKey + $ServiceName) -Name "DependOnService" -Value ([string[]]($DependOnService)) 2>&1
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error setting service dependencies for $ServiceName on $("$DependOnService") :: $($Results)"
        return
      }
      Add-IHILogIndentLevel
      Write-Host "Service dependencies set to $("$DependOnService")"
      Remove-IHILogIndentLevel
    }
    #endregion

    #region Change process account/identity, if necessary
    # if ProcessUserName not defined or defined as LOCALSYSTEM then do nothing the finance code, by default, is
    # set to run as the LOCALSYSTEM account
    # if ProcessUserName is something different, though, ASSUME IT IS A DOMAIN ACCOUNT (which requires password)
    # and change process to run as that
    if (($ProcessUserName.Trim() -ne "") -and ($ProcessUserName.ToUpper() -ne "LOCALSYSTEM")) {
      Write-Host "Changing process RunAs account to: $($ProcessUserName)"
      # get WMI service reference to our service
      $ServiceWmi = Get-WmiObject Win32_Service -Filter $("name = '" + $ServiceName + "'")
      # now attempt to change the username and password
      $Result = $ServiceWmi.Change($null,$null,$null,$null,$null,$null,$ProcessUserName,$ProcessPassword,$null,$null,$null)
      if ($Result.ReturnValue -eq 0) {
        Add-IHILogIndentLevel
        Write-Host "Service $ServiceName process id changed to account $ProcessUserName; change will take effect after service started (if currently stopped) or restarted (if currently running).  However, be aware that there could still be an error - if the password isn't correct this won't be known until the service is started or restarted."
        Remove-IHILogIndentLevel
      } else {
        [string]$WMIErrorMessage = Get-IHIWmiServiceResultDescription $Result.ReturnValue
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error setting username/password :: $($WMIErrorMessage)"
        return
      }
      Add-IHILogIndentLevel
      Write-Host "Service dependencies set."
      Remove-IHILogIndentLevel
    }
    #endregion

    #region Record end of processing information
    Write-Host "Service $ServiceName installation complete"
    #endregion
  }
}
Export-ModuleMember -Function Install-IHIWindowsNetService
#endregion


#region Functions: Uninstall-IHIWindowsNetService

<#
.SYNOPSIS
Uninstalls a .NET windows service 
.DESCRIPTION
Uninstalls a .NET windows service
.PARAMETER ServiceName
Name of service to uninstall
.PARAMETER Path
Filesystem path to service executable
.PARAMETER DotNetVersionId
ID of .NET version; this is a value of a branch under $Ihi:Applications.DotNet,
i.e. V20 or V40
.EXAMPLE
Uninstall-IHIWindowsNetService -ServiceName MyService -Path c:\temp\MyService.exe -DotNetVersionId V20
Uninstalls windows .NET service
#>
function Uninstall-IHIWindowsNetService {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ServiceName,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$DotNetVersionId
  )
  #endregion
  process {
    #region Parameter validation
    #region Make sure ServiceName currently installed
    if ($null -eq (Get-Service | Where { $_.Name -eq $ServiceName })) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: no service found installed with name: $($ServiceName)"
      return
    }
    #endregion

    #region Make sure service Path is valid
    if ($false -eq (Test-Path -Path $Path)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: service Path does not exist: $($Path)"
      return
    }
    #endregion

    #region Make sure DotNetfVersionId is valid
    # The DotNetVersionId is a value of a branch under $Ihi:Applications.DotNet, i.e. V20 or 
    # V40.  This tells the function which version of the utility to use.
    # Make sure this value is correct
    if ($Ihi:Applications.DotNet.Keys -notcontains $DotNetVersionId) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: $DotNetVersionId is not valid; correct values are: $($Ihi:Applications.DotNet.Keys)"
      return
    }
    #endregion

    #region Get utility based on .NET version and confirm exists
    [string]$UtilityPath = $Ihi:Applications.DotNet.$DotNetVersionId.InstallUtil
    if ($UtilityPath -eq $null -or !(Test-Path -Path $UtilityPath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path for InstallUtil.exe is null or bad: $UtilityPath"
      return
    }
    #endregion
    #endregion

    #region Report information before uninstalling service
    # rather than use PSBoundParameters, manually output for better formatting
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "ServiceName",$ServiceName)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Path",$Path)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "DotNetVersionId",$("$DotNetVersionId"))
    Remove-IHILogIndentLevel
    #endregion

    #region Run utility and check for error
    [string]$Cmd = $UtilityPath
    [string[]]$Params = "/u",$Path,"/LogToConsole=true","/LogFile="
    Write-Host "Uninstalling $($ServiceName)..."
    $Results = & $Cmd $Params 2>&1
    if ($? -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred uninstalling $ServiceName at $Path"
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Command: $("$Cmd $Params")"
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: $("$Results")"
      return
    } else {
      # the process only produces a small amount of text; just report it, no need for separate log file
      Add-IHILogIndentLevel
      $Results | Write-Host
      Remove-IHILogIndentLevel
      Write-Host "Service uninstalled."
    }
    #endregion
  }
}
Export-ModuleMember -Function Uninstall-IHIWindowsNetService
#endregion
