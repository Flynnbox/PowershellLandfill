
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


#region Functions: Confirm-IHIIISModuleLoaded

<#
.SYNOPSIS
Returns $true is IIS module loaded; if not $false and writes error
.DESCRIPTION
Returns $true is IIS module loaded; if not $false and writes error
.EXAMPLE
Confirm-IHIIISModuleLoaded
Confirms IIS module loaded, if not, writes error message to stream
#>
function Confirm-IHIIISModuleLoaded {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    # There are a number of ways of checking if the IIS module is loaded (Get-Module WedAdministration)
    # but because we are going to make a good deal of use out of the IIS: drive for our administration,
    # might as well make sure that path exists (which wouldn't if the module isn't loaded).
    $Success = $true
    if ($false -eq (Test-Path -Path IIS:)) {
      $Success = $false
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: WebAdministration module not loaded (IIS: drive not found)"
      # Also, if WebAdmin not loaded, check if shell running as administrator - that would be why not loaded  
      if ($false -eq (Test-IHIIsShellAdministrator)) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: PowerShell needs to be running as Administrator in order to load WebAdministration module"
      }
    }
    $Success
  }
}
Export-ModuleMember -Function Confirm-IHIIISModuleLoaded
#endregion


#region Functions: Restart-IHIIISWebAppPool

<#
.SYNOPSIS
Restarts an IIS 7+ application pool by name
.DESCRIPTION
Restarts an IIS 7+ application pool by name.  If running, Recycles application pool; if 
not running Starts.
.PARAMETER AppPoolName
Name of application pool to restart
.EXAMPLE
Restart-IHIIISWebAppPool -AppPoolName Extranet2
Restarts IIS application pool named Extranet2, if found
#>
function Restart-IHIIISWebAppPool {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [string]$AppPoolName
  )
  #endregion
  process {
    #region Parameter validation
    #region Make sure WebAdministration module loaded
    # this code only works with IIS 7/WebAdmin module
    if ($false -eq (Confirm-IHIIISModuleLoaded)) {
      # error message written in function, no need for me, just return
      return
    }
    #endregion

    #region Make sure AppPool with that name exists
    [string]$AppPoolPath = Join-Path -Path "IIS:\AppPools" -ChildPath $AppPoolName
    if ($false -eq (Test-Path -Path $AppPoolPath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: AppPool not found: $($AppPoolName)"
      return
    }
    #endregion
    #endregion

    #region Get AppPool and stop/start it
    $AppPool = Get-Item -Path $AppPoolPath
    # use Stop/Start or Recycle?
    # if State is Started, use Recycle; if State is Stopped, use Start else throw error
    if ($AppPool.State -eq "Started") {
      Write-Host "Recycling app pool: $AppPoolName"
      $AppPool.Recycle()
    } elseif ($AppPool.State -eq "Stopped") {
      Write-Host "Starting app pool: $AppPoolName"
      $AppPool.Start()
    } else {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: AppPool $($AppPoolName) in state that is neither Started nor Stopped: $($AppPool.State)"
      return
    }

    # pause shortly then make sure State is Started
    Start-Sleep -Seconds 2
    # get fresh reference to AppPool just in case
    $AppPool = Get-Item -Path $AppPoolPath
    if ($AppPool.State -ne "Started") {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: after restart, AppPool $($AppPoolName) state is not Started: $($AppPool.State)"
      return
    } else {
      Write-Host "Processing complete."
    }
  }
}
Export-ModuleMember -Function Restart-IHIIISWebAppPool
#endregion
