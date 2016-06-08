#region Script help

<#
.SYNOPSIS
Updates developer machine PowerShell framework from repository.
.DESCRIPTION
This script updates the local PowerShell framework Main folder from the repository.
It should only be run on developer machines - it should only work on developer 
machines as it requires the Subversion client.  This script should be the first
line in a profile - typically the machine profile so that it is run for all users.

Additional notes:
 - This script cannot have any external dependencies (functions, modules, global
   settings, etc.) - it must be standalone.  As a result certain items will have 
   have to be hard-coded or duplicated in this script.
 - There is one dependency - the Subversion command line client - but this should
   be in the path and will be checked before using.
 - This script is located in the local PowerShell/Main folder.  The Main folder 
   maps to the Subversion folder /trunk/PowerShell/Main.
.PARAMETER ShowLoadDetails
Show details about the import process including module names and load times
#>
#endregion

#region Script parameters
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
  [switch]$ShowLoadDetails
)
#endregion

#region Standard script initialization, constants and variables
# ONLY standard initialization code and standard constant / variable definitions
# used across all scripts go here!

# ensure best practices for variable use, function calling, null property access, etc.
Set-StrictMode -Version 2
# reset error count
$Error.Clear()
# default error variable used for all function calls
$Err = $null
#endregion

#region Constants
# username and password of repository account that only has read-only access 
Set-Variable -Name RepoReadOnlyUserName -Value "engtest1" -Option ReadOnly
Set-Variable -Name RepoReadOnlyPassword -Value "group@ccess1" -Option ReadOnly
#endregion

#region Variables
# name of current script
[string]$ScriptName = $null
# path of current script parent folder
[string]$ScriptFolder = $null
# message to display to user
[string]$UpdateMessage = $null
# width of column 1 (text; load time info is column 2)
[int]$Column1Width = 60
#endregion

#region Get current script name and parent folder
$ScriptName = Split-Path $MyInvocation.MyCommand.Path -Leaf
$ScriptFolder = Split-Path $MyInvocation.MyCommand.Path -Parent
#endregion

#region Confirm machine is on IHI network
# make sure can see the machine hosting the repository - ENGBUILD.IHI.COM
if ($false -eq (Test-Connection -ComputerName ENGBUILD.IHI.COM -Count 1 -Quiet)) {
  Write-Host "Machine is not on the IHI network, unable to update local code with $ScriptName." -ForegroundColor Red
  exit 1
}
#endregion

#region Get reference to svn.exe; exit if not found
# Most of the time the Subversion utilities will be in the path so at first we can just 
# run Get-Command to get it; however, Subversion post-commit scripts have *no path value set*
# Also, searching the path without generating an error into $Errors is slow - you have to run
# Get-Command for ALL applications (return all apps in path) then look through - wasteful.
# Also, a user may have multiple copies of svn.exe installed, so Get-Command would return 
# multiple copies. So instead we try to find svn.exe by looking through "known locations" 
# to try to find it.  This is not pretty code and may have to be tweaked as time goes on.
$PossiblePaths = "C:\Program Files\CollabNet\Subversion Client\svn.exe",
"C:\Program Files (x86)\CollabNet\Subversion Client\svn.exe",
"D:\Program Files\CollabNet\Subversion Client\svn.exe",
"D:\Program Files (x86)\CollabNet\Subversion Client\svn.exe",
"C:\Program Files\Subversion\bin\svn.exe",
"C:\Program Files (x86)\Subversion\bin\svn.exe",
"D:\Program Files\Subversion\bin\svn.exe",
"D:\Program Files (x86)\Subversion\bin\svn.exe"
$SvnExe = $null
# loop through possible paths and grab last one that is valid
# we don't care about multiple installations and using whatever install is latest
# we are doing a simple update, this should work for any version
$PossiblePaths | ForEach-Object {
  # if path is valid, store it
  if (Test-Path -Path $_) {
    $SvnExe = $_
  }
}

# if not found, exit
if ($SvnExe -eq $null) {
  Write-Host "Subversion client svn.exe not installed on this machine; exiting update script." -ForegroundColor Red
  exit 1
}
#endregion

#region Run svn update for $ScriptFolder
# run SVN update, depth infinity, for ScriptFolder with readonly user and don't cache this user's authentication details
$UpdateMessage = "$ScriptName`n  Running svn update for: $ScriptFolder`n"
# get time before 
$StartTime = Get-Date
[string]$Cmd = $SvnExe
[string[]]$Params = "update",$ScriptFolder,"--username",$RepoReadOnlyUserName,"--password",$RepoReadOnlyPassword,"--depth","infinity","--no-auth-cache"
$LastExitCode = 0
$Results = & $Cmd $Params 2>&1
# for each line of result from the command, add to $UpdateMessage with prefix
$Results | ForEach-Object { $UpdateMessage += "  " + $_ }
$ElapsedTime = (Get-Date) - $StartTime
# if ShowLoadDetails specified, or if error occured, display results
if ($ShowLoadDetails -or ($LastExitCode -ne 0)) {
  $UpdateMessage
  Write-Host $("    {0,-$Column1Width} [ Loaded in {1:0.00} s ]" -f "Update complete",$ElapsedTime.TotalSeconds)
}
#endregion

#region Exit script
# exit with error or 0, depending on if error occurred running Subversion command
if ($LastExitCode -ne 0) {
  exit 1
} else {
  # if there was an error before now but it was handled, the script would've exited before now
  # check if any unhandled errors by checking $Error object
  if ($Error.Count -gt 0) {
    Write-Host "An unhandled error has been detected in $ScriptName." -ForegroundColor Red
    $Error | Write-Host -ForegroundColor Red
    exit 1
  } else {
    # no errors occured
    exit 0
  }
}
#endregion
