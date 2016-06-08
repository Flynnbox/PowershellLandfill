
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


#region Functions: Confirm-IHIClientMachineOnIhiNetwork

<#
.SYNOPSIS
Confirms client machine is on IHI network/vpn
.DESCRIPTION
Confirms client machine is on IHI network/vpn
.EXAMPLE
Confirm-IHIClientMachineOnIhiNetwork
Returns: $true
#>
function Confirm-IHIClientMachineOnIhiNetwork {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    $Success = $true
    # check if on IHI network by testing if $Ihi:BuildDeploy.CopyServer is available
    if ($false -eq (Test-Connection -ComputerName $($Ihi:BuildDeploy.CopyServer) -Count 1 -Quiet)) {
      Write-Host "`nYou are not on the IHI network - cannot complete action`n" -ForegroundColor Yellow
      $Success = $false
    }
    $Success
  }
}
Export-ModuleMember -Function Confirm-IHIClientMachineOnIhiNetwork
#endregion


#region Functions: Get-IHIFQMachineName

<#
.SYNOPSIS
Gets the fully qualified domain name of the current machine
.DESCRIPTION
Gets the fully qualified domain name of the current machine
.EXAMPLE
Get-IHIFQMachineName
Returns: DEVAPPWEB.IHI.COM
#>
function Get-IHIFQMachineName {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    $IpProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
    "{0}.{1}" -f $IpProperties.HostName.ToUpper(),$IpProperties.DomainName.ToUpper()
  }
}
Export-ModuleMember -Function Get-IHIFQMachineName
#endregion


#region Functions: Get-IHICredential

<#
.SYNOPSIS
Fetches credential data via Get-Credential - pre-filling domain/user
.DESCRIPTION
Fetches credential data via Get-Credential - pre-filling domain/user information,
and returns a System.Management.Automation.PSCredential object.  If you don't
want the domain/username information filled in, just use Get-Credential directly.
.PARAMETER NoDefaultDomainUserName
If specified, do not prepopulate domain and user name
.PARAMETER TestUntilValid
If specified, validate credentials and loop if bad credentials entered
.EXAMPLE
Get-IHICredential
Prompts user for credentials
#>
function Get-IHICredential {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$NoDefaultDomainUserName,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$TestUntilValid
  )
  #endregion
  process {
    $DefaultDomainUserName = $null
    #region Get default domain username if domain = IHI
    # only get default username if domain is ihi
    if ($env:UserDomain.ToUpper() -eq "IHI") {
      $DefaultDomainUserName = $env:UserDomain + "\" + $env:UserName
    }
    #endregion
    [Management.Automation.PSCredential]$MyCred = Get-Credential -Credential $DefaultDomainUserName
    # total number of time to ask for credentials
    [int]$TestTotal = 3
    [int]$TestIndex = 0
    # if test until valid, keep asking for credentials in loop until pass or too many fails
    if ($TestUntilValid) {
      while (!(Test-IHICredential -Credential $MyCred)) {
        # failed, so increment counter, make sure not over limit and if not, try again
        $TestIndex += 1
        # if hit limit, write error and return
        if ($TestIndex -eq $TestTotal) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: failed retrieving credentials $TestTotal times in a row"
          return
        }
        $MyCred = Get-Credential -Credential $DefaultDomainUserName
      }
    }
    $MyCred
  }
}
Export-ModuleMember -Function Get-IHICredential
#endregion


#region Functions: Select-IHIErrorObjects

<#
.SYNOPSIS
Filters out all objects except error objects
.DESCRIPTION
Filters out all objects except error objects, specifically PowerShell ErrorRecord objects
[System.Management.Automation.ErrorRecord] and exceptions [System.Exception].
.PARAMETER Objects
Objects to filter through
.EXAMPLE
(1,"2",(New-Object Exception "ABC"),"four") | Select-IHIErrorObjects
Returns only the object exception ABC
#>
function Select-IHIErrorObjects {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $true)]
    $Objects
  )
  #endregion
  process {
    # return only error objects
    $Objects | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] -or $_ -is [System.Exception] }
  }
}
Export-ModuleMember -Function Select-IHIErrorObjects
#endregion


#region Functions: Test-IHICredential

<#
.SYNOPSIS
Tests a PSCredential object to make sure data valid
.DESCRIPTION
Tests a PSCredential object to see if contained username and password data valid.
Idea/code borrowed from: http://poshcode.org/2924
.PARAMETER Credential
Credentials to test
.EXAMPLE
Test-IHICredential -Credential (Get-Credential)
Gets credentials then tests them
#>
function Test-IHICredential {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    [Management.Automation.PSCredential]$Credential
  )
  #endregion
  process {
    [System.Reflection.Assembly]::LoadWithPartialName('System.DirectoryServices.AccountManagement') > $null
    $System = Get-WmiObject -Class Win32_ComputerSystem
    # don't use current domain; need to extract domain from credential passed
    $PrincipalContext = New-Object -TypeName System.DirectoryServices.AccountManagement.PrincipalContext 'Domain',$Credential.GetNetworkCredential().Domain
    #returns $true if valid, $false otherwise
    $PrincipalContext.ValidateCredentials($Credential.GetNetworkCredential().UserName,$Credential.GetNetworkCredential().Password)
  }
}
Export-ModuleMember -Function Test-IHICredential
#endregion


#region Functions: Test-IHIIsAdministrator

<#
.SYNOPSIS
Returns true if current shell is running as Administrator
.DESCRIPTION
Returns true if current shell is running as Administrator
.EXAMPLE
Test-IHIIsShellAdministrator
Returns $true (because running as admin)
#>
function Test-IHIIsShellAdministrator {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    $WindowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $WindowsPrincipal = New-Object "System.Security.Principal.WindowsPrincipal" $WindowsIdentity
    $WindowsPrincipal.IsInRole("Administrators")
  }
}
Export-ModuleMember -Function Test-IHIIsShellAdministrator
#endregion


#region Functions: Test-IHIServerCredentialCache

<#
.SYNOPSIS
Tests for possible cached credential issues with IHI databases
.DESCRIPTION
Tests for possible cached credential issues with IHI databases.  Tests different
environments - DEV, TEST and PROD - continuously.  Time between tests (in minutes)
can be specified using MinutesBetweenTests parameter.  Otherwise the only way to stop
the endless loop is to hit CTRL-C.
.PARAMETER MinutesBetweenTests
Amount of time between tests (default 30)
.EXAMPLE
Test-IHIServerCredentialCache
Runs credential tests every 30 minutes
.EXAMPLE
Test-IHIServerCredentialCache 10
Runs credential tests every 10 minutes
#>
function Test-IHIServerCredentialCache {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [int]$MinutesBetweenTests = 30
  )
  #endregion
  process {
    $Cred = Get-IHICredential -TestUntilValid
    # Add paths to the SQL Client installs here
    $SQL2008 = "D:\Program Files\Microsoft SQL Server\100\Tools\Binn"
    $SQL2012 = "D:\Program Files\Microsoft SQL Server\110\Tools\Binn"
    # Updated version testing SQL 2008 and SQL 2012
    while ($true) {
      Write-Host ("`n{0:MM/dd HH:mm:ss} : This will loop until you type CTRL-C " -f (Get-Date))
      $SqlTestSB = { param([string]$SqlServer,[string]$Database,[string]$SqlClient) cd $SqlClient; .\SqlCmd.exe -E -b -S $SqlServer -d $Database -q 'select suser_name()' }
      $TestServerSB = {
        param([string]$WS,[string]$Sql,[string]$DB, [string]$SCP)
        $Err = $null
        $Results = Invoke-Command -ComputerName $WS -Authentication CredSSP -Credential $Cred -Command $SqlTestSB -ArgumentList $Sql,$DB,$SCP -EV Err 2>&1
        if ("" -eq $Err) {
          # if successful, should be object array with third element being user name
          if ($Cred.UserName -eq $Results[2].Trim()) {
            Write-Host "$WS - success"
          } else {
            Write-Host "$WS - call did NOT return user name!"
            Add-IHILogIndentLevel
            $Results | Write-Host
            Remove-IHILogIndentLevel
            Write-Host ""
          }
        } else {
          Write-Host "$WS - error occurred"
          Add-IHILogIndentLevel
          $Results | Write-Host
          Remove-IHILogIndentLevel
        }
      }
      # Configurations for the previous command
      # These point to the SQL 2008 installed client
      & $TestServerSB "DEVAPPWEB.IHI.COM" "DEVSQL.IHI.COM" "DEV_IHIDB" $SQL2008
      & $TestServerSB "TESTAPPWEB.IHI.COM" "TESTAPPSQL01.IHI.COM" "TEST_IHIDB" $SQL2008
      # This points to the SQL 2012 installed client
      & $TestServerSB "IHIAPPWEB01.IHI.COM" "IHIAPPSQL01.IHI.COM" "PROD_IHIDB" $SQL2012
      & $TestServerSB "DRAPPWEB01.IHI.COM" "DRAPPSQL01.IHI.COM" "PROD_IHIDB" $SQL2012
      Start-Sleep -Seconds ($MinutesBetweenTests * 60)
    }
  }
}
Export-ModuleMember -Function Test-IHIServerCredentialCache
New-Alias -Name "testcred" -Value Test-IHIServerCredentialCache
Export-ModuleMember -Alias "testcred"
#endregion
