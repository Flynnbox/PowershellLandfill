
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


#region Functions: Get-IHITerminalSessions, Get-IHISpringsTerminalSessions

<#
.SYNOPSIS
Gets opens terminal sessions & optionally closes them
.DESCRIPTION
For a list of servers, displays remote desktop terminal sessions and can close
disconnected ones (parameter StopDisconnectedSessions) or active ones
(parameter StopActiveSessions).
.PARAMETER Servers
List of servers to check for sessions
.PARAMETER StopDisconnectedSessions
Stops disconnected sessions if they exist
.PARAMETER StopActiveSessions
Stops active sessions if they exist
.EXAMPLE
Get-IHITerminalSessions -Servers DEVAPPWEB,TESTAPPWEB
Display active and disconnected sessions, if any, on those servers
.EXAMPLE
Get-IHITerminalSessions -Servers DEVAPPWEB -StopDisconnectedSessions
Gets listing of terminal sessions and stops disconnected sessions on DEVAPPWEB.
.EXAMPLE
Get-IHITerminalSessions -Servers DEVAPPWEB -StopDisconnectedSessions -StopActiveSessions
Gets listing of terminal sessions and stops disconnected & active sessions on 
DEVAPPWEB.
#>
function Get-IHITerminalSessions {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [string[]]$Servers,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$StopDisconnectedSessions,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$StopActiveSessions
  )
  #endregion
  process {
    #region Filter out servers that do not exist
    # filter out servers that don't exist - ping them
    $ServersToCheck = $null
    $ServersDoNotExist = $null
    $Servers | ForEach-Object {
      $Server = $_
      # to check if server exists use Ping-Host
      # $PingResults = Ping-Host -HostName $Server -Count 1 -Quiet
      $PingResults = Test-Connection -ComputerName $Server -Count 1 -Quiet
      # if ($PingResults -eq $null -or $PingResults.Received -eq 0) {
      if ($PingResults -eq $null -or $PingResults -eq $false) {
        # server does not exist
        $ServersDoNotExist +=,$Server
      } else {
        # server exists
        $ServersToCheck +=,$Server
      }
    }
    Write-Host ""
    if ($ServersDoNotExist -ne $null) {
      Write-Host "Servers not detected on network: $ServersDoNotExist"
    }
    # if no servers to check then exit
    if ($ServersToCheck -eq $null) {
      Write-Host "No valid servers detected.`n"
      return
    }
    #endregion

    #region Get terminal sessions on servers and filter out known junk entries
    Write-Host "Checking servers: $ServersToCheck"
    # get all terminal sessions on servers
    [hashtable]$Params = @{ ComputerName = $ServersToCheck }
    $Sessions = Get-TerminalSession @Params 2>&1
    if ($? -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Get-TerminalSession with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Sessions")"
      return
    }

    # filter out Listening sessions
    $Sessions = $Sessions | Where-Object { $_.State -ne [Pscx.TerminalServices.TerminalSessionState]::Listening }
    # filter out sessions where State is Disconnected or Connected but UserName -eq ""
    $Sessions = $Sessions | Where-Object { !(($_.State -eq [Pscx.TerminalServices.TerminalSessionState]::Disconnected -or
          $_.State -eq [Pscx.TerminalServices.TerminalSessionState]::Connected) -and ($_.UserName -eq "" -and $_.ClientAddress -eq "")) }
    if ($Sessions -eq $null) {
      Write-Host "No open sessions detected in servers: $ServersToCheck`n"
      return
    }
    #endregion

    #region Display terminal sessions
    # widths for colums
    [int]$ColServer = 15; [int]$ColId = 2; [int]$ColState = 12; [int]$ColUsername = 20; [int]$ColClientAddress = 15; [int]$ColLocalUsername = 20

    # for each ClientAddress, get logged in user (or at least attempt to)
    $Sessions | ForEach-Object {
      # if no client address, add blank else attempt to look up user
      if ($_.ClientAddress -eq $null -or $_.ClientAddress.Trim() -eq "") {
        $_ = Add-Member -MemberType NoteProperty -Name "LocalUsername" -Value "" -PassThru -InputObject $_
      } else {
        # attempt to look up user
        $_ = Add-Member -MemberType NoteProperty -Name "LocalUsername" -Value $(Get-IHILoggedOnUserOnMachine $_.ClientAddress) -PassThru -InputObject $_
      }
    }

    Write-Host "These sessions are open: `n"
    Write-Host $("{0,-$ColServer}  {1,$ColId}  {2,-$ColState}  {3,-$ColUsername}  {4,-$ColClientAddress}  {5,-$ColLocalUsername}" -f "Server","Id","State","Username","ClientAddress","LocalUsername")
    $Sessions | ForEach-Object {
      Write-Host $("{0,-$ColServer}  {1,$ColId}  {2,-$ColState}  {3,-$ColUsername}  {4,-$ColClientAddress}  {5,-$ColLocalUsername}" -f $_.Server,$_.Id,$_.State,$_.UserName,$_.ClientAddress,$_.LocalUsername)
    }
    Write-Host ""
    #endregion

    #region Stop disconnected and active sessions
    # stop disconnected sessions if specified
    if ($StopDisconnectedSessions) {
      $DisconnectedSessions = $Sessions | Where-Object { $_.State -eq [Pscx.TerminalServices.TerminalSessionState]::Disconnected }
      if ($DisconnectedSessions -eq $null) {
        Write-Host "There are no disconnected sessions to stop"
      } else {
        foreach ($Session in $DisconnectedSessions) {
          Write-Host "Stopping sessions:"
          Write-Host $("{0,-$ColServer}  {1,$ColId}  {2,-$ColState}  {3,-$ColUsername}  {4,-$ColClientAddress}  {5,-$ColLocalUsername}" -f $Session.Server,$Session.Id,$Session.State,$Session.UserName,$Session.ClientAddress,$Session.LocalUsername)
          [hashtable]$Params = @{ ComputerName = $Session.Server; Id = $Session.Id; Wait = $true; Force = $true }
          $Results = Stop-TerminalSession @Params 2>&1
          if ($? -eq $false) {
            Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Stop-TerminalSession with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Results")"
            return
          }
        }
      }
    }
    # stop active sessions if specified
    if ($StopActiveSessions) {
      $ActiveSessions = $Sessions | Where-Object { $_.State -eq [Pscx.TerminalServices.TerminalSessionState]::Active }
      if ($ActiveSessions -eq $null) {
        Write-Host "There are no active sessions to stop"
      } else {
        foreach ($Session in $ActiveSessions) {
          Write-Host "Stopping sessions:"
          Write-Host $("{0,-$ColServer}  {1,$ColId}  {2,-$ColState}  {3,-$ColUsername}  {4,-$ColClientAddress}  {5,-$ColLocalUsername}" -f $Session.Server,$Session.Id,$Session.State,$Session.UserName,$Session.ClientAddress,$Session.LocalUsername)
          [hashtable]$Params = @{ ComputerName = $Session.Server; Id = $Session.Id; Wait = $true; Force = $true }
          $Results = Stop-TerminalSession @Params 2>&1
          if ($? -eq $false) {
            Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Stop-TerminalSession with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Results")"
            return
          }
        }
      }
    }
    Write-Host ""
    #endregion
  }
}
Export-ModuleMember -Function Get-IHITerminalSessions


<#
.SYNOPSIS
Gets SPRINGS servers terminal sessions & optionally closes
.DESCRIPTION
For SPRINGS servers, displays remote desktop terminal sessions and can close
disconnected ones (parameter StopDisconnectedSessions) or active ones
(parameter StopActiveSessions). Calls Get-IHITerminalSessions with value of 
$Ihi:Network.Servers.SpringsServers.
.PARAMETER StopDisconnectedSessions
Stops disconnected sessions if they exist
.PARAMETER StopActiveSessions
Stops active sessions if they exist
.EXAMPLE
Get-IHISpringsTerminalSessions
Display active and disconnected sessions, if any, on SPRINGS servers
.EXAMPLE
Get-IHISpringsTerminalSessions -StopDisconnectedSessions
Gets listing of terminal sessions and stops disconnected sessions
.EXAMPLE
Get-IHISpringsTerminalSessions -StopDisconnectedSessions -StopActiveSessions
Gets listing of terminal sessions and stops disconnected & active sessions
.EXAMPLE
getout -now -imeanit # getout instead of Get-IHISpringsTerminalSessions
Does same thing as previous example but with fun aliases
#>
function Get-IHISpringsTerminalSessions {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [Alias("now")]
    [switch]$StopDisconnectedSessions,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [Alias("imeanit")]
    [switch]$StopActiveSessions
  )
  #endregion
  process {
    # get terminal sessions for springs servers
    Get-IHITerminalSessions $Ihi:Network.Servers.SpringsServers -StopDisconnectedSessions:$StopDisconnectedSessions -StopActiveSessions:$StopActiveSessions

    # if user didn't specify other parms, they may not know about them (because they saw abbreviated tip)
    # so show info now
    if ((-not $StopDisconnectedSessions) -and (-not $StopActiveSessions)) {
      Write-Host "To shut down disconnect sessions, add parameter: -now"
      Write-Host "To shut down active sessions, add parameter: -imeanit"
      Write-Host ""
    }
  }
}
Export-ModuleMember -Function Get-IHISpringsTerminalSessions
New-Alias -Name "getout" -Value Get-IHISpringsTerminalSessions
Export-ModuleMember -Alias "getout"
#endregion
