
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


#region Functions: Get-IHILoggedOnUserOnMachine

<#
.SYNOPSIS
Gets name of logged in user on MachineName
.DESCRIPTION
Gets name of logged in user on MachineName; ideal for checking user on a 
desktop machine.  This script will not work for machine at home on the VPN
or for machines the current user does not have access to.
.PARAMETER MachineName
Machine to check
.EXAMPLE
Get-IHILoggedOnUserOnMachine -MachineName DEVAPPWEB
#>
function Get-IHILoggedOnUserOnMachine {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [string]$MachineName
  )
  #endregion
  process {
    $UserName = ""
    # $PingResults = Ping-Host -HostName $MachineName -Count 1 -Quiet
    $PingResults = Test-Connection -ComputerName $MachineName -Count 1 -Quiet
    # if ($PingResults -eq $null -or $PingResults.Received -eq 0) {
    if ($PingResults -eq $null -or $PingResults -eq $false) {
      # server does not exist
      $UserName = "<host unreachable>"
    } else {
      try {
        $UserName = (Get-WmiObject Win32_ComputerSystem -ComputerName $MachineName).UserName
      } catch {
        $UserName = "<unable to access>"
      }
    }
    $UserName
  }
}
Export-ModuleMember -Function Get-IHILoggedOnUserOnMachine

#endregion


#region Functions: Get-IHIServerDriveInfo

<#
.SYNOPSIS
Gets hard drive space information for one or more servers
.DESCRIPTION
Gets hard drive space information for all drives for one or more servers
.PARAMETER MachineName
Machine or machines to check
.EXAMPLE
Get-IHIServerDriveInfo DEVAPPWEB
SystemName          DeviceID            Size_GB             FreeSpace_GB
----------          --------            --------            -------------
DEVAPPWEB           C:                  49.9                32.2
DEVAPPWEB           D:                  146.0               128.4
.EXAMPLE
Get-IHIServerDriveInfo DEVAPPWEB,TESTAPPWEB
<returns drive info for both servers>
.EXAMPLE
Get-IHIServerDriveInfo DEVAPPWEB,TESTAPPWEB | Where { ( $_.FreeSpace_GB / $_.Size_GB -lt .1) }
<shows drives with less than 10% free space, if any>
#>
function Get-IHIServerDriveInfo {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [string[]]$MachineName
  )
  #endregion
  process {
    $AllDriveInfo = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" -computer $MachineName | Select SystemName,DeviceID,VolumeName,@{ Name = "Size_GB"; Expression = { "{0:N1}" -f ($_.size / 1gb) } },@{ Name = "FreeSpace_GB"; Expression = { "{0:N1}" -f ($_.freespace / 1gb) } }
    $AllDriveInfo | Select SystemName,DeviceID,"Size_GB","FreeSpace_GB"
  }
}
Export-ModuleMember -Function Get-IHIServerDriveInfo
#endregion


#region Functions: Test-IHIIsIHIServer

<#
.SYNOPSIS
Determine if server is an IHI Server or not
.DESCRIPTION
Determine if server is an IHI Server or not.  MachineName, if passed, must be 
fully-qualified.  This function checks the against the server list in
$Ihi:Network.Servers.IhiServers.
.PARAMETER MachineName
Machine to check; if not passed uses current machine name
.EXAMPLE
Test-IHIIsIHIServer DEVAPPWEB
$False
Machine name is not fully-qualified so does not match DEVAPPWEB.IHI.COM in the list.
.EXAMPLE
Test-IHIIsIHIServer DEVAPPWEB.IHI.COM
$True
.EXAMPLE
Test-IHIIsIHIServer
$False
If no MachineName is passed, uses current machine (assume $False because run
on a developer machine).
#>
function Test-IHIIsIHIServer {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $true)]
    [string]$MachineName
  )
  #endregion
  process {
    # if no machine name passed, use current machine
    if ($MachineName -eq "") { $MachineName = Get-IHIFQMachineName }
    $Ihi:Network.Servers.IhiServers -contains $MachineName
  }
}
Export-ModuleMember -Function Test-IHIIsIHIServer
#endregion
