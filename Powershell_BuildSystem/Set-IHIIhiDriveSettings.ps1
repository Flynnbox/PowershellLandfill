
#region Script help

<#
.SYNOPSIS
Populates the contents of the Ihi: drive with machine specific settings
.DESCRIPTION
Populates the contents of the Ihi: drive by filling in details under
each high-level hash-table container: Applications, BuildDeploy, Folders
and Network.  The values of the settings will be specific to the machine
it is run on.
All of the values stored in the IHIDrive should be valid or $null.  For 
example, if the function for setting value SqlIntegrationServicesExec
determines that this utility does not exist on the machine, the value should
be $null, not the 'appropriate' value where it should have been located.
Any function using Ihi: drive values should check to make sure the value is
not null and valid as well.

When determining paths, especially Application paths, this code should
attempt to never use Get-Command as that relies upon the path being set 
and there are instances of when the path will not be valid:
 - applications not configured for all users;
 - applications that don't modify path (user-modified = inconsistent);
 - Subversion post-commit hook scripts.
Also, when calling Get-Command with a application that doesn't exist
on the machine, an error is generated unnecessarily.  You can redirect 
the error to null and/or SilentlyContinue but the error will still be in
$Error and this is checked at the end for unhandled errors.  So if we do
generate an error and can't get around it, we need to see if any unhandled
exceptions exist before making the questionable call.  All in all it's a 
pain in the ass.  Doable, convenient where there are no errors, but a pain
in the ass when there might be.

This script runs AFTER the module framework has loaded so it can take
advantage of any functions to help determine the correct values.
.PARAMETER ShowModuleImportDetails
Show details about the import process including module names and load times
#>
#endregion

#region Script parameters
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
  [switch]$ShowLoadDetails,
  [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
  [string]$SSISVersion = 'latest'

)
#endregion

write-host $SSISVersion
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
#endregion

#region Variables
# name of current script
[string]$ScriptName = $null
# path of current script parent folder
[string]$ScriptFolder = $null
#endregion

#region Functions: Set Applications values

<#
# For all applications listed, value with be either a valid path or null
# Listing of applications with basic rules (see code for additional details)

Database
  SqlAnalysisServicesDeploy     - path to Microsoft.AnalysisServices.Deployment.exe
  SqlCmd                        - path to SqlCmd.exe
  SqlIntegrationServicesUtility - path to dtutil.exe
  SqlReportingServicesUtility   - path to rs.exe
DotNet
  V20                           - container for framework 2.0 version utilities
    AspNet_regiis               - path to aspnet_regiis.exe
    InstallUtil                 - path to InstallUtil.exe
    Mage                        - path to 32-bit Mage.exe (usually under SDKs)
    MSBuild                     - path to MSBuild.exe
  V40                           - container for framework 2.0 version utilities
    AspNet_regiis               - path to aspnet_regiis.exe
    InstallUtil                 - path to InstallUtil.exe
    Mage                        - path to 32-bit Mage.exe (usually under SDKs)
    MSBuild                     - path to MSBuild.exe
Editor
  DiffViewer                    - path to diff viewer (ExamDiff Pro or TortoiseMerge)
  PowerShellEditor              - path to PowerGUI script editor or PowerShell ISE
  TextEditor                    - path to default text editor; look for TextPad then Notepad++ then notepad if nothing else
FileSystem
  RoboCopy                      - path to robocopy.exe
  XCopy                         - path to xcopy.exe
  XxCopy                        - path to xxcopy.exe, if exists
Miscellaneous
  InternetExplorer              - path it iexplore.exe
  FireFox                       - path to firefox.exe
  Safari                        - path to safari.exe
  Chrome                        - path to chrome.exe
Repository
  SubversionUtility             - svn.exe
  SubversionLookUtility         - svnlook.exe
#>

#region Common functions

#endregion

#region Set Applications.Database hashtable
# set the Applications.Database hashtable container
function Set-IHIValue_Applications_Database {
  $Ihi:Applications.Database = @{}
}
#endregion

#region Set Applications.Database.SqlAnalysisServicesDeploy
# Set the Application.Database.SqlAnalysisServicesDeploy path for Microsoft.AnalysisServices.Deployment.exe
# if it exists on the machine.  Set to the 2012 version if it exists, otherwise, look for sql 2008
# If it is installed, it will be located under the USER DEFINED 100\Tools\Binn folder or 110\Tools\Binn.
# This folder isn't defined ANYWHERE under the standard SQL keys (unless you look in
# ugly registered classes keys, etc.)  However, it can be found where the PowerShell SQL 
# snap-ins or ShellId are defined, that is:
# For SQL2008 R2:
#   HKLM:\Software\Microsoft\PowerShell\1\PowerShellSnapIns\SqlServerCmdletSnapin100.ApplicationBase
# For SQL2012:
#   HKLM:\Software\Microsoft\PowerShell\1\Microsoft.SqlServer.Management.PowerShell.sqlps110.Path
#	though you need to strip SQLPS.exe off of that path
# For SQL2014:
#   HKLM:\Software\Microsoft\PowerShell\1\Microsoft.SqlServer.Management.PowerShell.sqlps120.Path
#	though you need to strip SQLPS.exe off of that path
# This path will always point to a 32-bit version, there is no 64-bit version.
# This is the "user specified" bin, under the installation path specified by the user
# during installation.
function Set-IHIValue_Applications_Database_SqlAnalysisServicesDeploy {
  # set default value in case not found
  $Ihi:Applications.Database.SqlAnalysisServicesDeploy = $null
  # attempt to get root SQL path for SQL 2014
    $Path = Get-IHIAppPathFromRegistryKey "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.SqlServer.Management.PowerShell.sqlps120" "Path"
    # if path returned and is valid
    if (($Path -ne $null) -and ($true -eq (Test-Path -Path $Path))) {
      # strip the SQLPS.exe and add command name to the end of the path
      $Path = Split-Path -Path $Path -Parent | Join-Path -ChildPath "\ManagementStudio\Microsoft.AnalysisServices.Deployment.exe"
      # if application exists at that path, set value
      if ($true -eq (Test-Path -Path $Path)) {
        $Ihi:Applications.Database.SqlAnalysisServicesDeploy = $Path
      }   
  }   
  # if path is null or does not exist, look for SQL 2012 path
  else {
  # attempt to get root SQL path for SQL 2012
    $Path = Get-IHIAppPathFromRegistryKey "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.SqlServer.Management.PowerShell.sqlps110" "Path"
    # if path returned and is valid
    if (($Path -ne $null) -and ($true -eq (Test-Path -Path $Path))) {
      # strip the SQLPS.exe and add command name to the end of the path
      $Path = Split-Path -Path $Path -Parent | Join-Path -ChildPath "\ManagementStudio\Microsoft.AnalysisServices.Deployment.exe"
      # if application exists at that path, set value
      if ($true -eq (Test-Path -Path $Path)) {
        $Ihi:Applications.Database.SqlAnalysisServicesDeploy = $Path
      }   
    }
  
  # if path is null or does not exist, look for SQL 2008 path
  else {
    # re-set default value
  	$Ihi:Applications.Database.SqlAnalysisServicesDeploy = $null
	# attempt to get root SQL 2008 path
	  $Path = Get-IHIAppPathFromRegistryKey "HKLM:\Software\Microsoft\PowerShell\1\PowerShellSnapIns\SqlServerCmdletSnapin100" "ApplicationBase"
	  # if path returned and is valid
	  if (($Path -ne $null) -and ($true -eq (Test-Path -Path $Path))) {
	    # add command name to the end of the path
	    $Path = Join-Path -Path $Path -ChildPath "VSShell\Common7\IDE\Microsoft.AnalysisServices.Deployment.exe"
	    # if application exists at that path, set value
	    if ($true -eq (Test-Path -Path $Path)) {
	      $Ihi:Applications.Database.SqlAnalysisServicesDeploy = $Path
	    }
    }
  }
  }
}
#endregion

#region Set Applications.Database.SqlCmd
# Set the Application.Database.SqlCmd path for SqlCmd.exe if it exists on the machine.
# If it is installed, 
#   For SQL 2008 R2 it will be located under the DEFAULT 100\Tools\Binn folder
#     which is defined at: 
#       HKLM:\Software\Microsoft\Microsoft SQL Server\100\Tools\ClientSetup.Path
#   For SQL 2012 it will be located under the DEFAULT 110\Tools\Binn folder
#     which is defined at: 
#       HKLM:\Software\Microsoft\Microsoft SQL Server\110\Tools\ClientSetup.Path
#   For SQL 2014 it will be located under the DEFAULT 120\Tools\Binn folder
#     which is defined at: 
#       HKLM:\Software\Microsoft\Microsoft SQL Server\120\Tools\ClientSetup.ODBCToolsPath
# This path will be where 64-bit utilities are installed, if it's a 64-bit OS,
# otherwise it will be the 32-bit path.
# This is the "default bin" path, as set by the installer itself, not to be confused with
# the installation path specified by the user during installation, which might be 
# different.
# We will default to SQL 2014  path if it exists, then SQL 2012, finally look for SQL 2008 R2
function Set-IHIValue_Applications_Database_SqlCmd {
  # set default value in case not found
  $Ihi:Applications.Database.SqlCmd = $null	
	# attempt to get root SQL path for SQL 2014
	$Path = Get-IHIAppPathFromRegistryKey "HKLM:\Software\Microsoft\Microsoft SQL Server\120\Tools\ClientSetup" "ODBCToolsPath"
	# if path returned and is valid
	if (($Path -ne $null) -and ($true -eq (Test-Path -Path $Path))) {
	  # add command name to the end of the path
	  $Path = Join-Path -Path $Path -ChildPath "SqlCmd.exe"
	  # if application exists at that path, set value
	  if ($true -eq (Test-Path -Path $Path)) {
	    $Ihi:Applications.Database.SqlCmd = $Path
	  }
  }
  
  # if path is null or does not exist, look for SQL 2012 path
  else {
  # set default value in case not found
  $Ihi:Applications.Database.SqlCmd = $null	
	# attempt to get root SQL path for SQL 2012
	$Path = Get-IHIAppPathFromRegistryKey "HKLM:\Software\Microsoft\Microsoft SQL Server\110\Tools\ClientSetup" "Path"
	# if path returned and is valid
	if (($Path -ne $null) -and ($true -eq (Test-Path -Path $Path))) {
	  # add command name to the end of the path
	  $Path = Join-Path -Path $Path -ChildPath "SqlCmd.exe"
	  # if application exists at that path, set value
	  if ($true -eq (Test-Path -Path $Path)) {
	    $Ihi:Applications.Database.SqlCmd = $Path
	  }
    }
  
  # if path is null or does not exist, look for SQL 2008 path
  else {
    # re-set default value
    $Ihi:Applications.Database.SqlCmd = $null
  # attempt to get root SQL path for SQL 2008 R2
  $Path = Get-IHIAppPathFromRegistryKey "HKLM:\Software\Microsoft\Microsoft SQL Server\100\Tools\ClientSetup" "Path"
  # if path returned and is valid
  if (($Path -ne $null) -and ($true -eq (Test-Path -Path $Path))) {
    # add command name to the end of the path
    $Path = Join-Path -Path $Path -ChildPath "SqlCmd.exe"
    # if application exists at that path, set value
    if ($true -eq (Test-Path -Path $Path)) {
      $Ihi:Applications.Database.SqlCmd = $Path
     }
    }
   }
  }
}
#endregion

#region Set Applications.Database.SqlIntegrationServicesUtility
# Set the Application.Database.SqlIntegrationServicesUtility path for dtutil.exe if it 
# exists on the machine. 
# If it is installed, 
#   For SQL 2008 R2 it will be located under the DEFAULT 100\DTS\Binn folder
#     which is defined at: 
#     HKLM:\Software\Microsoft\Microsoft SQL Server\100\SSIS\Setup\DTSPath.(Default)
#   For SQL 2012 it will be located under the DEFAULT 110\DTS\Binn folder
#     which is defined at: 
#    HKLM:\Software\Microsoft\Microsoft SQL Server\110\SSIS\Setup\DTSPath.(Default)
# This path will be where 64-bit utilities are installed, if it's a 64-bit OS,
# otherwise it will be the 32-bit path.  There are both 32 and 64-bit versions 
# of dtutil.exe, we want only the 64-bit version, if available.
# This is the "default bin", as set by the installer itself, not to be confused with
# the installation path specified by the user during installation, which might be 
# different.
# We will default to SQL 2014  path if it exists, then SQL 2012, finally look for SQL 2008 R2
function Set-IHIValue_Applications_Database_SqlIntegrationServicesUtility {
  # set default value in case not found
  $Ihi:Applications.Database.SqlIntegrationServicesUtility = $null
    # attempt to get root SQL path for SQL 2014
    $Path = Get-IHIAppPathFromRegistryKey "HKLM:\Software\Microsoft\Microsoft SQL Server\120\SSIS\Setup\DTSPath" "(Default)"
    # if path returned and is valid
    if (($Path -ne $null) -and ($true -eq (Test-Path -Path $Path)) -and (($SSISVersion -eq 'latest') -or ($SSISVersion -eq '2014'))) {
      # add command name to the end of the path
      $Path = Join-Path -Path $Path -ChildPath "Binn\dtutil.exe"
      # if application exists at that path, set value
      if ($true -eq (Test-Path -Path $Path)) {
        $Ihi:Applications.Database.SqlIntegrationServicesUtility = $Path
      }
  }
  
    # if path is null or does not exist, look for SQL 2012 path
  else {
  # set default value in case not found
  $Ihi:Applications.Database.SqlIntegrationServicesUtility = $null
    # attempt to get root SQL path for SQL 2012
    $Path = Get-IHIAppPathFromRegistryKey "HKLM:\Software\Microsoft\Microsoft SQL Server\110\SSIS\Setup\DTSPath" "(Default)"
    # if path returned and is valid
    if (($Path -ne $null) -and ($true -eq (Test-Path -Path $Path)) -and (($SSISVersion -eq 'latest') -or ($SSISVersion = '2012'))) {
      # add command name to the end of the path
      $Path = Join-Path -Path $Path -ChildPath "Binn\dtutil.exe"
      # if application exists at that path, set value
      if ($true -eq (Test-Path -Path $Path)) {
        $Ihi:Applications.Database.SqlIntegrationServicesUtility = $Path
      }
    }
  
  # if path is null or does not exist, look for SQL 2008 path
  else {
    # re-set default value
    $Ihi:Applications.Database.SqlIntegrationServicesUtility = $null
	  # attempt to get root SQL 2008 R2 path
	  $Path = Get-IHIAppPathFromRegistryKey "HKLM:\Software\Microsoft\Microsoft SQL Server\100\SSIS\Setup\DTSPath" "(Default)"
	  # if path returned and is valid
	  if (($Path -ne $null) -and ($true -eq (Test-Path -Path $Path)) -and (($SSISVersion -eq 'latest') -or ($SSISVersion = '2008'))) {
	    # add command name to the end of the path
	    $Path = Join-Path -Path $Path -ChildPath "Binn\dtutil.exe"
	    # if application exists at that path, set value
	    if ($true -eq (Test-Path -Path $Path)) {
	      $Ihi:Applications.Database.SqlIntegrationServicesUtility = $Path
	    }
	  }
    }
  }
}
#endregion

#region Set Applications.Database.SqlReportingServicesUtility
# Set the Application.Database.SqlReportingServicesUtility path for rs.exe if it 
# exists on the machine. 
# If it is installed, it will be located under the USER DEFINED 100\Tools\Binn folder.
# This folder isn't defined ANYWHERE under the standard SQL keys (unless you look in
# ugly registered classes keys, etc.)  However, it can be found where the PowerShell SQL 
# snap-ins or ShellId are defined, that is:
# For SQL2008 R2:
#   HKLM:\Software\Microsoft\PowerShell\1\PowerShellSnapIns\SqlServerCmdletSnapin100.ApplicationBase
# For SQL2012:
#   HKLM:\Software\Microsoft\PowerShell\1\Microsoft.SqlServer.Management.PowerShell.sqlps110.Path
#	though you need to strip SQLPS.exe off of that path
# For SQL2014:
#   HKLM:\Software\Microsoft\PowerShell\1\Microsoft.SqlServer.Management.PowerShell.sqlps120.Path
#	though you need to strip SQLPS.exe off of that path
# This path will always point to a 32-bit version, there is no 64-bit version.
# This is the "user specified" bin, under the installation path specified by the user
# during installation.
function Set-IHIValue_Applications_Database_SqlReportingServicesUtility {

  # set default value in case not found
  $Ihi:Applications.Database.SqlReportingServicesUtility = $null
    # attempt to get root SQL path for SQL 2012
    $Path = Get-IHIAppPathFromRegistryKey "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.SqlServer.Management.PowerShell.sqlps120" "Path"
    # if path returned and is valid
    if (($Path -ne $null) -and ($true -eq (Test-Path -Path $Path))) {
      # strip the SQLPS.exe and add command name to the end of the path
      $Path = Split-Path -Path $Path -Parent | Join-Path -ChildPath "rs.exe"
      # if application exists at that path, set value
      if ($true -eq (Test-Path -Path $Path)) {
        $Ihi:Applications.Database.SqlReportingServicesUtility = $Path
      }
    }

  # if path is null or does not exist, look for SQL 2012 path
  else {
  # set default value in case not found
  $Ihi:Applications.Database.SqlReportingServicesUtility = $null
    # attempt to get root SQL path for SQL 2012
    $Path = Get-IHIAppPathFromRegistryKey "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.SqlServer.Management.PowerShell.sqlps110" "Path"
    # if path returned and is valid
    if (($Path -ne $null) -and ($true -eq (Test-Path -Path $Path))) {
      # strip the SQLPS.exe and add command name to the end of the path
      $Path = Split-Path -Path $Path -Parent | Join-Path -ChildPath "rs.exe"
      # if application exists at that path, set value
      if ($true -eq (Test-Path -Path $Path)) {
        $Ihi:Applications.Database.SqlReportingServicesUtility = $Path
      }
    }
  
  # if path is null or does not exist, look for SQL 2012 path
  else {
    # re-set default value
  	$Ihi:Applications.Database.SqlReportingServicesUtility = $null
	  # attempt to get root SQL 2008 R2 path
	  $Path = Get-IHIAppPathFromRegistryKey "HKLM:\Software\Microsoft\PowerShell\1\PowerShellSnapIns\SqlServerCmdletSnapin100" "ApplicationBase"
	  # if path returned and is valid
	  if (($Path -ne $null) -and ($true -eq (Test-Path -Path $Path))) {
	    # add command name to the end of the path
	    $Path = Join-Path -Path $Path -ChildPath "rs.exe"
	    # if application exists at that path, set value
	    if ($true -eq (Test-Path -Path $Path)) {
	      $Ihi:Applications.Database.SqlReportingServicesUtility = $Path
	    }	
	  }
    }
  }
}
#endregion

#region Set Applications.DotNet hashtable
# set the Applications.DotNet hashtable container
function Set-IHIValue_Applications_DotNet {
  $Ihi:Applications.DotNet = @{}
}
#endregion

#region Set Applications.DotNet.V20 hashtable
# set the Applications.DotNet.V20 hashtable container
function Set-IHIValue_Applications_DotNet_V20 {
  $Ihi:Applications.DotNet.V20 = @{}
}
#endregion

#region Set Applications.DotNet.V20.AspNet_regiis
# sets the value of $Ihi:Applications.DotNet.V20.AspNet_regiis
function Set-IHIValue_Applications_DotNet_V20_AspNet_regiis {
  # utility exists at \Windows\Microsoft.NET\Framework\v2.0.50727 - it's the only place it should exist
  # note: we only care about the 32-bit version of the utility even if a 64 bit may exist
  $Ihi:Applications.DotNet.V20.AspNet_regiis = Join-Path -Path $env:SystemRoot -ChildPath "Microsoft.NET\Framework\v2.0.50727\aspnet_regiis.exe"
  # check path to make sure
  if (!(Test-Path -Path $Ihi:Applications.DotNet.V20.AspNet_regiis)) {
    $Ihi:Applications.DotNet.V20.AspNet_regiis = $null
  }
}
#endregion

#region Set Applications.DotNet.V20.InstallUtil
# sets the value of $Ihi:Applications.DotNet.V20.InstallUtil
function Set-IHIValue_Applications_DotNet_V20_InstallUtil {
  # utility exists at \Windows\Microsoft.NET\Framework\v2.0.50727 - it's the only place it should exist
  # note: we only care about the 32-bit version of the utility even if a 64 bit may exist
  $Ihi:Applications.DotNet.V20.InstallUtil = Join-Path -Path $env:SystemRoot -ChildPath "Microsoft.NET\Framework\v2.0.50727\InstallUtil.exe"
  # check path to make sure
  if (!(Test-Path -Path $Ihi:Applications.DotNet.V20.InstallUtil)) {
    $Ihi:Applications.DotNet.V20.InstallUtil = $null
  }
}
#endregion

#region Set Applications.DotNet.V20.Mage
# sets the value of $Ihi:Applications.DotNet.V20.Mage
function Set-IHIValue_Applications_DotNet_V20_Mage {
  # utility exists under \Program Files\ attempt to only use the 32 bit version of utility, that 
  # is, use c:\Program Files\ on 32-bit machines or c:\Program Files (x86)\ on 64-bit machines
  # also, only attempt to find version v7.0A of utility at
  # Microsoft SDKs\Windows\v7.0A\Bin\mage.exe
  [string]$ProgramFilesRoot = $null
  # look for 32-bit on a 64-bit machine; safe way of checking for environment variable that
  # may not exist without throwing error
  if ($null -ne (Get-ChildItem env: | Where-Object { $_.Name -eq 'ProgramFiles(x86)' })) {
    $ProgramFilesRoot = ${Env:ProgramFiles(x86)}
  } else {
    $ProgramFilesRoot = $Env:ProgramFiles
  }
  $Ihi:Applications.DotNet.V20.Mage = Join-Path -Path $ProgramFilesRoot -ChildPath "Microsoft SDKs\Windows\v7.0A\Bin\mage.exe"
  # check path to make sure
  if (!(Test-Path -Path $Ihi:Applications.DotNet.V20.Mage)) {
    $Ihi:Applications.DotNet.V20.Mage = $null
  }
}
#endregion

#region Set Applications.DotNet.V20.MSBuild
# sets the value of $Ihi:Applications.DotNet.V20.MSBuild
function Set-IHIValue_Applications_DotNet_V20_MSBuild {
  # utility exists at \Windows\Microsoft.NET\Framework\v2.0.50727 - it's the only place it should exist
  # note: we only care about the 32-bit version of the utility even if a 64 bit may exist
  $Ihi:Applications.DotNet.V20.MSBuild = Join-Path -Path $env:SystemRoot -ChildPath "Microsoft.NET\Framework\v2.0.50727\MSBuild.exe"
  # check path to make sure
  if (!(Test-Path -Path $Ihi:Applications.DotNet.V20.MSBuild)) {
    $Ihi:Applications.DotNet.V20.MSBuild = $null
  }
}
#endregion

#region Set Applications.DotNet.V40 hashtable
# set the Applications.DotNet.V40 hashtable container
function Set-IHIValue_Applications_DotNet_V40 {
  $Ihi:Applications.DotNet.V40 = @{}
}
#endregion

#region Set Applications.DotNet.V40.AspNet_regiis
# sets the value of $Ihi:Applications.DotNet.V40.AspNet_regiis
function Set-IHIValue_Applications_DotNet_V40_AspNet_regiis {
  # utility exists at \Windows\Microsoft.NET\Framework\v4.0.30319 - it's the only place it should exist
  # note: we only care about the 32-bit version of the utility even if a 64 bit may exist
  $Ihi:Applications.DotNet.V40.AspNet_regiis = Join-Path -Path $env:SystemRoot -ChildPath "Microsoft.NET\Framework\v4.0.30319\aspnet_regiis.exe"
  # check path to make sure
  if (!(Test-Path -Path $Ihi:Applications.DotNet.V40.AspNet_regiis)) {
    $Ihi:Applications.DotNet.V40.AspNet_regiis = $null
  }
}
#endregion

#region Set Applications.DotNet.V40.InstallUtil
# sets the value of $Ihi:Applications.DotNet.V40.InstallUtil
function Set-IHIValue_Applications_DotNet_V40_InstallUtil {
  # utility exists at \Windows\Microsoft.NET\Framework\v4.0.30319 - it's the only place it should exist
  # note: we only care about the 32-bit version of the utility even if a 64 bit may exist
  $Ihi:Applications.DotNet.V40.InstallUtil = Join-Path -Path $env:SystemRoot -ChildPath "Microsoft.NET\Framework\v4.0.30319\InstallUtil.exe"
  # check path to make sure
  if (!(Test-Path -Path $Ihi:Applications.DotNet.V40.InstallUtil)) {
    $Ihi:Applications.DotNet.V40.InstallUtil = $null
  }
}
#endregion

#region Set Applications.DotNet.V40.Mage
# sets the value of $Ihi:Applications.DotNet.V40.Mage
function Set-IHIValue_Applications_DotNet_V40_Mage {
  # utility exists under \Program Files\ attempt to only use the 32 bit version of utility, that 
  # is, use c:\Program Files\ on 32-bit machines or c:\Program Files (x86)\ on 64-bit machines
  # also, only attempt to find version v7.0A of utility at
  # Microsoft SDKs\Windows\v7.0A\Bin\NETFX 4.0 Tools\mage.exe
  [string]$ProgramFilesRoot = $null
  # look for 32-bit on a 64-bit machine; safe way of checking for environment variable that
  # may not exist without throwing error
  if ($null -ne (Get-ChildItem env: | Where-Object { $_.Name -eq 'ProgramFiles(x86)' })) {
    $ProgramFilesRoot = ${Env:ProgramFiles(x86)}
  } else {
    $ProgramFilesRoot = $Env:ProgramFiles
  }
  $Ihi:Applications.DotNet.V40.Mage = Join-Path -Path $ProgramFilesRoot -ChildPath "Microsoft SDKs\Windows\v7.0A\Bin\NETFX 4.0 Tools\mage.exe"
  # check path to make sure
  if (!(Test-Path -Path $Ihi:Applications.DotNet.V40.Mage)) {
    $Ihi:Applications.DotNet.V40.Mage = $null
  }
}
#endregion

#region Set Applications.DotNet.V40.MSBuild
# sets the value of $Ihi:Applications.DotNet.V40.MSBuild
function Set-IHIValue_Applications_DotNet_V40_MSBuild {
  # attempt to look for the 64-bit version of the utility first; if not, then look for the 32-bit one
  $Ihi:Applications.DotNet.V40.MSBuild = Join-Path -Path $env:SystemRoot -ChildPath "Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe"
  if (!(Test-Path -Path $Ihi:Applications.DotNet.V40.MSBuild)) {
    # no 64-bit, look for 32-bit
    $Ihi:Applications.DotNet.V40.MSBuild = Join-Path -Path $env:SystemRoot -ChildPath "Microsoft.NET\Framework\v4.0.30319\MSBuild.exe"
    if (!(Test-Path -Path $Ihi:Applications.DotNet.V40.MSBuild)) {
      $Ihi:Applications.DotNet.V40.MSBuild = $null
    }
  }
}
#endregion

#region Set Applications.Editor hashtable
# set the Applications.Editor hashtable container
function Set-IHIValue_Applications_Editor {
  $Ihi:Applications.Editor = @{}
}
#endregion

#region Set Applications.Editor.DiffViewer
# looks for ExamDiff Pro otherwise returns $null
function Get-IHIExamDiffProPath {
  # this App Paths registry key works for ExamDiff Pro
  # return the value directly (will be valid path or null)
  Get-IHIAppPathFromRegistryKey "HKCU:Software\PrestoSoft\ExamDiff Pro" "ExePath"
}

# looks for TortoiseSVN TortoiseMerge utility
function Get-IHITortoiseMergePath {
  # return the value directly (will be valid path or null)
  Get-IHIAppPathFromRegistryKey "HKLM:Software\TortoiseSVN" "TMergePath"
}

# sets the value of $Ihi:Applications.Editor.DiffViewer
function Set-IHIValue_Applications_Editor_DiffViewer {
  # first try to find ExamDiff Pro then TortoiseMerge else null
  $Ihi:Applications.Editor.DiffViewer = $null
  switch ($Ihi:Applications.Editor.DiffViewer) {
    # first look for ExamDiff Pro
    { $Ihi:Applications.Editor.DiffViewer -eq $null } { $Ihi:Applications.Editor.DiffViewer = Get-IHIExamDiffProPath }
    # if no TextPad look for TortoiseSVN TortoiseMerge
    { $Ihi:Applications.Editor.DiffViewer -eq $null } { $Ihi:Applications.Editor.DiffViewer = Get-IHITortoiseMergePath }
  }
}
#endregion

#region Set Applications.Editor.PowerShellEditor
# if PowerGUI Script Editor 2.0 installed on machine, returns path to .exe otherwise returns $null
function Get-IHIPowerGUIScriptEditorPath {
  # this App Paths registry key works for PowerGUI Script Editor 2.0 
  # return the value directly (will be valid path or null)
  Get-IHIAppPathFromRegistryKey "HKLM:\SOFTWARE\Classes\Applications\ScriptEditor.exe\shell\edit\command"
}

# if PowerShell ISE installed on machine, returns path to .exe otherwise returns $null
function Get-IHIPowerShellISEPath {
  # build path then test if it exists
  $AppPath = Join-Path -Path $env:SystemRoot -ChildPath ("system32\WindowsPowerShell\v1.0\PowerShell_ISE.exe")
  if ($false -eq (Test-Path -Path $AppPath)) {
    $AppPath = $null
  }
  # return correct value or $null
  $AppPath
}

# sets the value of $Ihi:Applications.Editor.PowerShellEditor
function Set-IHIValue_Applications_Editor_PowerShellEditor {
  # first try to find PowerGUI Script Editor if not then PowerShell ISE
  $Ihi:Applications.Editor.PowerShellEditor = $null
  switch ($Ihi:Applications.Editor.PowerShellEditor) {
    # first look for PowerGUI Script Editor
    { $Ihi:Applications.Editor.PowerShellEditor -eq $null } { $Ihi:Applications.Editor.PowerShellEditor = Get-IHIPowerGUIScriptEditorPath }
    # if no PowerGUI Script Editor look for PowerShell ISE
    { $Ihi:Applications.Editor.PowerShellEditor -eq $null } { $Ihi:Applications.Editor.PowerShellEditor = Get-IHIPowerShellISEPath }
    # if nothing found, use notepad
    { $Ihi:Applications.Editor.PowerShellEditor -eq $null } { $Ihi:Applications.Editor.PowerShellEditor = Join-Path -Path $env:SystemRoot -ChildPath "system32\notepad.exe" }
  }
}
#endregion

#region Set Applications.Editor.TextEditor
# if Sublime Text installed on machine, returns path to .exe otherwise returns $null
function Get-IHISublimeTextPath {
  # can't find a clean/easy registry key to use and in a rush; just try obvious paths
  # try 32-bit and 64-bit on C: and D:; keep testing paths, if found return else return $null
  $AppPath = "C:\Program Files\Sublime Text 3\sublime_text.exe"
  if ($false -eq (Test-Path -Path $AppPath)) { $AppPath = "C:\Program Files (x86)\Sublime Text 3\sublime_text.exe" }
  if ($false -eq (Test-Path -Path $AppPath)) { $AppPath = "C:\Program Files\Sublime Text 2\sublime_text.exe" }
  if ($false -eq (Test-Path -Path $AppPath)) { $AppPath = "C:\Program Files (x86)\Sublime Text 2\sublime_text.exe" }
  if ($false -eq (Test-Path -Path $AppPath)) { $AppPath = "D:\Program Files\Sublime Text 3\sublime_text.exe" }
  if ($false -eq (Test-Path -Path $AppPath)) { $AppPath = "D:\Program Files (x86)\Sublime Text 3\sublime_text.exe" }
  if ($false -eq (Test-Path -Path $AppPath)) { $AppPath = "D:\Program Files\Sublime Text 2\sublime_text.exe" }
  if ($false -eq (Test-Path -Path $AppPath)) { $AppPath = "D:\Program Files (x86)\Sublime Text 2\sublime_text.exe" }
  if ($false -eq (Test-Path -Path $AppPath)) { $AppPath = $null }
  $AppPath
}

# if TextPad 4 or 5 installed on machine, returns path to .exe otherwise returns $null
function Get-IHITextPadPath {
  # the first registry key works for both TextPad 4 or 5 on almost all machines
  $AppPath = Get-IHIAppPathFromRegistryKey "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\TextPad.exe"
  # in case not found at that location, try this key (needed for DEVSQL/TESTSQL 2008 SP2)
  if ($AppPath -eq $null) {
    $AppPath = Get-IHIAppPathFromRegistryKey "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\App Paths\TextPad.exe"
  }
  # return AppPath; will be valid path or null
  $AppPath
}

# if NotePad++ installed on machine, returns path to .exe otherwise returns $null
function Get-IHINotepadPlusPlusPath {
  # return the value directly (will be valid path or null)
  Get-IHIAppPathFromRegistryKey "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\notepad++.exe"
}

# sets the value of $Ihi:Applications.Editor.TextEditor
function Set-IHIValue_Applications_Editor_TextEditor {
  # first try to find Sublime, then TextPad, then Notepad++ else use notepad
  $Ihi:Applications.Editor.TextEditor = $null
  switch ($Ihi:Applications.Editor.TextEditor) {
    # first look for Sublime Text
    { $Ihi:Applications.Editor.TextEditor -eq $null } { $Ihi:Applications.Editor.TextEditor = Get-IHISublimeTextPath }
    # if no Sublime look for TextPad
    { $Ihi:Applications.Editor.TextEditor -eq $null } { $Ihi:Applications.Editor.TextEditor = Get-IHITextPadPath }
    # if no TextPad look for Notepad++
    { $Ihi:Applications.Editor.TextEditor -eq $null } { $Ihi:Applications.Editor.TextEditor = Get-IHINotepadPlusPlusPath }
    # if nothing found then default to notepad
    { $Ihi:Applications.Editor.TextEditor -eq $null } { $Ihi:Applications.Editor.TextEditor = Join-Path -Path $env:SystemRoot -ChildPath "system32\notepad.exe" }
  }
}
#endregion

#region Set Applications.FileSystem hashtable
# set the Applications.FileSystem hashtable container
function Set-IHIValue_Applications_FileSystem {
  $Ihi:Applications.FileSystem = @{}
}
#endregion

#region Set Applications.FileSystem.RoboCopy
# sets the value of $Ihi:Applications.FileSystem.RoboCopy
function Set-IHIValue_Applications_FileSystem_RoboCopy {
  # RoboCopy might be in any number of locations - or might not be available at all
  #  - C:\Windows\system32 - all Win 7, Vista and Server 2008 machines
  #    from the Resource Kit; note: these machines are all 32 bit so no need to check (x86)
  #  - C:\Window - copied here manually on some machines including 1.4.36.12
  $CmdName = "robocopy.exe"
  # first test Windows\system32 folder
  $Ihi:Applications.FileSystem.RoboCopy = Join-Path -Path $env:SystemRoot -ChildPath ("system32\" + $CmdName)
  # if not try Windows folder only
  if (!(Test-Path -Path $Ihi:Applications.FileSystem.RoboCopy)) {
    $Ihi:Applications.FileSystem.RoboCopy = Join-Path -Path $env:SystemRoot -ChildPath $CmdName
  }
  # if not try Program Files\Windows Resource Kits\Tools
  if (!(Test-Path -Path $Ihi:Applications.FileSystem.RoboCopy)) {
    $Ihi:Applications.FileSystem.RoboCopy = Join-Path -Path $env:ProgramFiles -ChildPath ("Windows Resource Kits\Tools\" + $CmdName)
  }
  # if not found, set to $null
  if (!(Test-Path -Path $Ihi:Applications.FileSystem.RoboCopy)) {
    $Ihi:Applications.FileSystem.RoboCopy = $null
  }
}
#endregion

#region Set Applications.FileSystem.XCopy
# sets the value of $Ihi:Applications.FileSystem.XCopy
function Set-IHIValue_Applications_FileSystem_XCopy {
  # XCopy exists as \Windows\System32\xcopy.exe - it's the only place it should exist
  $Ihi:Applications.FileSystem.XCopy = Join-Path -Path $env:SystemRoot -ChildPath "system32\xcopy.exe"
  # check path to make sure
  if (!(Test-Path -Path $Ihi:Applications.FileSystem.XCopy)) {
    $Ihi:Applications.FileSystem.XCopy = $null
  }
}
#endregion

#region Set Applications.FileSystem.XxCopy
# sets the value of $Ihi:Applications.FileSystem.XxCopy
function Set-IHIValue_Applications_FileSystem_XxCopy {
  # xxcopy should only be installed to \Windows\System32\xcopy.exe - it's the only place it should exist
  $Ihi:Applications.FileSystem.XxCopy = Join-Path -Path $env:SystemRoot -ChildPath "system32\xxcopy.exe"
  # check path to make sure
  if (!(Test-Path -Path $Ihi:Applications.FileSystem.XxCopy)) {
    $Ihi:Applications.FileSystem.XxCopy = $null
  }
}
#endregion

#region Set Applications.Miscellaneous hashtable
# set the Applications.Miscellaneous hashtable container
function Set-IHIValue_Applications_Miscellaneous {
  $Ihi:Applications.Miscellaneous = @{}
}
#endregion

#region Set Applications.Miscellaneous.InternetExplorer
# set the Application.Miscellaneous.InternetExplorer path for IE on the machine
function Set-IHIValue_Applications_Miscellaneous_InternetExplorer {
  $Ihi:Applications.Miscellaneous.InternetExplorer = Get-IHIAppPathFromRegistryKey "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\IEXPLORE.EXE"
}
#endregion

#region Set Applications.Miscellaneous.FireFox
# set the Application.Miscellaneous.FireFox path for FF on the machine
function Set-IHIValue_Applications_Miscellaneous_FireFox {
  $Ihi:Applications.Miscellaneous.FireFox = Get-IHIAppPathFromRegistryKey "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\firefox.exe"
}
#endregion

#region Set Applications.Miscellaneous.Chrome
# set the Application.Miscellaneous.Chrome path for Chrome on the machine
function Set-IHIValue_Applications_Miscellaneous_Chrome {
  $Ihi:Applications.Miscellaneous.Chrome = Get-IHIAppPathFromRegistryKey "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe"
}
#endregion

#region Set Applications.Miscellaneous.Safari
# set the Application.Miscellaneous.Safari path for Safari on the machine
function Set-IHIValue_Applications_Miscellaneous_Safari {
  $Ihi:Applications.Miscellaneous.Safari = Get-IHIAppPathFromRegistryKey "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Safari.exe"
}
#endregion

#region Set Applications.Repository hashtable
# set the Applications.Repository hashtable container
function Set-IHIValue_Applications_Repository {
  $Ihi:Applications.Repository = @{}
}
#endregion

#region Set Applications.Repository.SubversionUtility, SubversionLookUtility
# Subversion does not have good, consistent information in the registry that can be used
# to find svn.exe - not consistent, that is, when you look across svn client installs only vs.
# server installs and 32 vs. 64 machines.  So we'll have to find the utilities in another way.

# sets the value of $Ihi:Applications.Repository.SubversionUtility
function Set-IHIValue_Applications_Repository_SubversionUtility {
  # Most of the time the Subversion utilities will be in the path so at first we can just 
  # run Get-Command to get it; however, Subversion post-commit scripts have *no path value set*
  # Also, searching the path without generating an error into $Errors is slow - you have to run
  # Get-Command for ALL applications (return all apps in path) then look through - wasteful.
  # Also, a user may have multiple copies of svn.exe installed, so Get-Command would return 
  # multiple copies. So instead we try to find svn.exe by looking through "known locations" 
  # to try to find it.  This is not pretty code and may have to be tweaked as time goes on.
  $Ihi:Applications.Repository.SubversionUtility = $null
  # not pretty and definately not good but I don't have time for a more elegant solution right now
  $PossiblePaths = "C:\Program Files\CollabNet\Subversion Client\svn.exe",
  "C:\Program Files (x86)\CollabNet\Subversion Client\svn.exe",
  "D:\Program Files\CollabNet\Subversion Client\svn.exe",
  "D:\Program Files (x86)\CollabNet\Subversion Client\svn.exe",
  "C:\Program Files\Subversion\bin\svn.exe",
  "C:\Program Files (x86)\Subversion\bin\svn.exe",
  "D:\Program Files\Subversion\bin\svn.exe",
  "D:\Program Files (x86)\Subversion\bin\svn.exe"
  # loop through possible paths and grab last one that is valid
  # we don't care about multiple installations and using whatever install is latest
  # we are doing a simple update, this should work for any version
  $PossiblePaths | ForEach-Object {
    # if path is valid, store it
    if (Test-Path -Path $_) {
      $Ihi:Applications.Repository.SubversionUtility = $_
    }
  }
  # PSTODO: this is too slow; disable for now
  <#
  # if still not found, check path without generating an error
  if ($Ihi:Applications.Repository.SubversionUtility -eq $null) {
    $Command = Get-Command -CommandType Application | Where-Object { $_.Name -eq "svn.exe" }
    # if svn.exe found in path then set
    if ($Command -ne $null -and (Test-Path -Path $Command.Definition)) {
      $Ihi:Applications.Repository.SubversionUtility = $Command.Definition
    }
  }
  #>
}

# sets the value of $Ihi:Applications.Repository.SubversionLookUtility
function Set-IHIValue_Applications_Repository_SubversionLookUtility {
  # Most of the time the Subversion utilities will be in the path so at first we can just 
  # run Get-Command to get it; however, Subversion post-commit scripts have *no path value set*
  # Also, searching the path without generating an error into $Errors is slow - you have to run
  # Get-Command for ALL applications (return all apps in path) then look through - wasteful.
  # So try to find first by looking through "known locations" to try to find it.
  # This is not pretty code and may have to be tweaked as time goes on.
  $Ihi:Applications.Repository.SubversionLookUtility = $null
  $PossiblePaths = "C:\Program Files\CollabNet\Subversion Client\svnlook.exe",
  "C:\Program Files (x86)\CollabNet\Subversion Client\svnlook.exe",
  "D:\Program Files\CollabNet\Subversion Client\svnlook.exe",
  "D:\Program Files (x86)\CollabNet\Subversion Client\svnlook.exe",
  "C:\Program Files\Subversion\bin\svnlook.exe",
  "C:\Program Files (x86)\Subversion\bin\svnlook.exe",
  "D:\Program Files\Subversion\bin\svnlook.exe",
  "D:\Program Files (x86)\Subversion\bin\svnlook.exe",
  "C:\Program Files\CollabNetEdge\bin\svnlook.exe",
  "C:\Program Files (x86)\CollabNetEdge\bin\svnlook.exe",
  "D:\Program Files\CollabNetEdge\bin\svnlook.exe",
  "D:\Program Files (x86)\CollabNetEdge\bin\svnlook.exe"
  $PossiblePaths | ForEach-Object {
    # if path is valid, store it
    if (Test-Path -Path $_) {
      $Ihi:Applications.Repository.SubversionLookUtility = $_
    }
  }
  # PSTODO: this is too slow; disable for now
  <#
  # if still not found, check path without generating an error
  if ($Ihi:Applications.Repository.SubversionLookUtility -eq $null) {
    $Command = Get-Command -CommandType Application | Where-Object { $_.Name -eq "svnlook.exe" }
    # if svnlook.exe found in path then set
    if ($Command -ne $null -and (Test-Path -Path $Command.Definition)) {
      $Ihi:Applications.Repository.SubversionLookUtility = $Command.Definition
    }
  }
  #>
}
#endregion

#region Set Applications - calls all individual set functions
function Set-IHIValues_Applications {
  Set-IHIValue_Applications_Database
  Set-IHIValue_Applications_Database_SqlAnalysisServicesDeploy
  Set-IHIValue_Applications_Database_SqlCmd
  Set-IHIValue_Applications_Database_SqlIntegrationServicesUtility
  Set-IHIValue_Applications_Database_SqlReportingServicesUtility
  Set-IHIValue_Applications_DotNet
  Set-IHIValue_Applications_DotNet_V20
  Set-IHIValue_Applications_DotNet_V20_AspNet_regiis
  Set-IHIValue_Applications_DotNet_V20_InstallUtil
  Set-IHIValue_Applications_DotNet_V20_Mage
  Set-IHIValue_Applications_DotNet_V20_MSBuild
  Set-IHIValue_Applications_DotNet_V40
  Set-IHIValue_Applications_DotNet_V40_AspNet_regiis
  Set-IHIValue_Applications_DotNet_V40_InstallUtil
  Set-IHIValue_Applications_DotNet_V40_Mage
  Set-IHIValue_Applications_DotNet_V40_MSBuild
  Set-IHIValue_Applications_Editor
  Set-IHIValue_Applications_Editor_DiffViewer
  Set-IHIValue_Applications_Editor_PowerShellEditor
  Set-IHIValue_Applications_Editor_TextEditor
  Set-IHIValue_Applications_FileSystem
  Set-IHIValue_Applications_FileSystem_RoboCopy
  Set-IHIValue_Applications_FileSystem_XCopy
  Set-IHIValue_Applications_FileSystem_XxCopy
  Set-IHIValue_Applications_Miscellaneous
  Set-IHIValue_Applications_Miscellaneous_InternetExplorer
  Set-IHIValue_Applications_Miscellaneous_FireFox
  Set-IHIValue_Applications_Miscellaneous_Chrome
  Set-IHIValue_Applications_Miscellaneous_Safari
  Set-IHIValue_Applications_Repository
  Set-IHIValue_Applications_Repository_SubversionUtility
  Set-IHIValue_Applications_Repository_SubversionLookUtility
}
#endregion
#endregion

#region Functions: Set BuildDeploy values

#region Set BuildDeploy.ApplicationConfigsRootFolder
# set the BuildDeploy.ApplicationConfigsRootFolder list
# this is under the ScriptFolder, the Configs folder under BuildDeploy
# that is, <$ScriptFolder>\BuildDeploy\Configs
function Set-IHIValue_BuildDeploy_ApplicationConfigsRootFolder {
  [string]$Ihi:BuildDeploy.ApplicationConfigsRootFolder = Join-Path -Path $ScriptFolder -ChildPath "BuildDeploy\Configs"
}
#endregion

#region Set BuildDeploy.ApplicationConfigsRootUrlPath
# set the BuildDeploy.ApplicationConfigsRootFolder list
# this is under the ScriptFolder, the Configs folder under BuildDeploy
# that is, <$ScriptFolder>\BuildDeploy\Configs
function Set-IHIValue_BuildDeploy_ApplicationConfigsRootUrlPath {
  [string]$Ihi:BuildDeploy.ApplicationConfigsRootUrlPath = "/trunk/PowerShell3/Main/BuildDeploy/Configs"
}
#endregion

#region Set BuildDeploy.BuildServer
# Server used for building packages.  This server must be on
# the local IHI network and "always on".
function Set-IHIValue_BuildDeploy_BuildServer {
  [string]$Ihi:BuildDeploy.BuildServer = "ENGBUILD.IHI.COM"
}
#endregion

#region Set BuildDeploy.CopyServer
# Server used for remote copying of files/folders.  This server must be on
# the local IHI network, "always on" and must be running Server 2008
# with WinRM/CredSSP configured.
function Set-IHIValue_BuildDeploy_CopyServer {
  [string]$Ihi:BuildDeploy.CopyServer = "TESTAPPWEB.IHI.COM"
}
#endregion

#region Set BuildDeploy.DeployFolders
# set the BuildDeploy.DeployFolders hash table container
function Set-IHIValue_BuildDeploy_DeployFolders {
  $Ihi:BuildDeploy.DeployFolders = @{}
}
#endregion

#region Set BuildDeploy.DeployFolders.DeployRootFolder
# set the BuildDeploy.DeployFolders DeployRootFolder path
# if server has a D: drive, folder is located there
# otherwise it is on C: drive
function Set-IHIValue_BuildDeploy_DeployFolders_DeployRootFolder {
  $FolderName = "Deploys"
  if ($true -eq (Test-Path -Path "D:\")) {
    $Ihi:BuildDeploy.DeployFolders.DeployRootFolder = Join-Path -Path "D:\" -ChildPath $FolderName
  } else {
    $Ihi:BuildDeploy.DeployFolders.DeployRootFolder = Join-Path -Path "C:\" -ChildPath $FolderName
  }
}
#endregion

#region Set BuildDeploy.DeployFolders.CurrentVersions
# This folder is directly under BuildDeploy.DeployFolders.DeployRootFolder
function Set-IHIValue_BuildDeploy_DeployFolders_CurrentVersions {
  $Ihi:BuildDeploy.DeployFolders.CurrentVersions = Join-Path -Path $Ihi:BuildDeploy.DeployFolders.DeployRootFolder -ChildPath "CurrentVersions"
}
#endregion

#region Set BuildDeploy.DeployFolders.DeployLogsArchive
# This folder is directly under BuildDeploy.DeployFolders.DeployRootFolder
function Set-IHIValue_BuildDeploy_DeployFolders_DeployLogsArchive {
  $Ihi:BuildDeploy.DeployFolders.DeployLogsArchive = Join-Path -Path $Ihi:BuildDeploy.DeployFolders.DeployRootFolder -ChildPath "DeployLogsArchive"
}
#endregion

#region Set BuildDeploy.DeployFolders.Packages
# This folder is directly under BuildDeploy.DeployFolders.DeployRootFolder
function Set-IHIValue_BuildDeploy_DeployFolders_Packages {
  $Ihi:BuildDeploy.DeployFolders.Packages = Join-Path -Path $Ihi:BuildDeploy.DeployFolders.DeployRootFolder -ChildPath "Packages"
}
#endregion

#region Set BuildDeploy.DeployFolders.DeployHistoryFile
# This file is directly under BuildDeploy.DeployFolders.DeployRootFolder
function Set-IHIValue_BuildDeploy_DeployFolders_DeployHistoryFile {
  $Ihi:BuildDeploy.DeployFolders.DeployHistoryFile = Join-Path -Path $Ihi:BuildDeploy.DeployFolders.DeployRootFolder -ChildPath "DeployHistory.txt"
}
#endregion

#region Set BuildDeploy.DeployShare
# This folder is directly under BuildDeploy.DeployShare
function Set-IHIValue_BuildDeploy_DeployShare {
  $Ihi:BuildDeploy.DeployShare = '\\' + (Get-IHIFQMachineName) + '\Deploys'
}
#endregion

#region Set BuildDeploy.ReleasesFolder
# set the BuildDeploy ReleasesFolder path
function Set-IHIValue_BuildDeploy_ReleasesFolder {
  $Ihi:BuildDeploy.ReleasesFolder = "\\ENGBUILD.IHI.COM\Releases"
}
#endregion

#region Set BuildDeploy.ErrorNotificationEmails
# set the BuildDeploy.ErrorNotificationEmails list
function Set-IHIValue_BuildDeploy_ErrorNotificationEmails {
  [string[]]$Ihi:BuildDeploy.ErrorNotificationEmails = "hlattanzio@ihi.org"
}
#endregion

#region Set BuildDeploy.DeployFolders.IHIScriptsFolder
# set the BuildDeploy.DeployFolders IHIScriptsFolder path
# if server has a D: drive, folder is located there
# otherwise it is on C: drive
function Set-IHIValue_BuildDeploy_IHIScriptsFolder {
  $FolderName = "IHI_Scripts"
  if ($true -eq (Test-Path -Path "D:\")) {
    $Ihi:BuildDeploy.IHIScriptsFolder = Join-Path -Path "D:\" -ChildPath $FolderName
  } else {
    $Ihi:BuildDeploy.IHIScriptsFolder = Join-Path -Path "C:\" -ChildPath $FolderName
  }
}
#endregion

#region Set BuildDeploy.SvnMain
# set the BuildDeploy.SvnMain hash table container
function Set-IHIValue_BuildDeploy_SvnMain {
  $Ihi:BuildDeploy.SvnMain = @{}
}
#endregion

#region Set BuildDeploy.SvnMain.FishEye
# set the BuildDeploy.SvnMain.FishEye hashtable container
function Set-IHIValue_BuildDeploy_SvnMain_FishEye {
  $Ihi:BuildDeploy.SvnMain.FishEye = @{}
}
#endregion

#region Set BuildDeploy.SvnMain.FishEye.AdministrationUrl
# set the BuildDeploy.SvnMain.FishEye.AdministrationUrl url
function Set-IHIValue_BuildDeploy_SvnMain_FishEye_AdministrationUrl {
  $Ihi:BuildDeploy.SvnMain.FishEye.AdministrationUrl = "http://ENGBUILD.IHI.COM:8060/admin"
}
#endregion

#region Set BuildDeploy.SvnMain.FishEye.ReadOnlyAccount
# set the BuildDeploy.SvnMain.FishEye.ReadOnlyAccount hashtable container
function Set-IHIValue_BuildDeploy_SvnMain_FishEye_ReadOnlyAccount {
  $Ihi:BuildDeploy.SvnMain.FishEye.ReadOnlyAccount = @{}
}
#endregion

#region Set BuildDeploy.SvnMain.FishEye.ReadOnlyAccount.UserName
# set the BuildDeploy.SvnMain.FishEye.ReadOnlyAccount.UserName value
function Set-IHIValue_BuildDeploy_SvnMain_FishEye_ReadOnlyAccount_UserName {
  $Ihi:BuildDeploy.SvnMain.FishEye.ReadOnlyAccount.UserName = "ReadOnly"
}
#endregion

#region Set BuildDeploy.SvnMain.FishEye.ReadOnlyAccount.Password
# set the BuildDeploy.SvnMain.FishEye.ReadOnlyAccount.Password value
function Set-IHIValue_BuildDeploy_SvnMain_FishEye_ReadOnlyAccount_Password {
  $Ihi:BuildDeploy.SvnMain.FishEye.ReadOnlyAccount.Password = "readonly"
}
#endregion

#region Set BuildDeploy.SvnMain.FishEye.SearchRepositoryUrl
# set the BuildDeploy.SvnMain.FishEye.SearchRepositoryUrl url
function Set-IHIValue_BuildDeploy_SvnMain_FishEye_SearchRepositoryUrl {
  $Ihi:BuildDeploy.SvnMain.FishEye.SearchRepositoryUrl = "http://ENGBUILD.IHI.COM:8060/rest-service-fe/search-v1/query/IHI_MAIN?query=select%20revisions%20where%20content%20matches%20`"[[ENCODED_SEARCH_TERM]]`"%20group%20by%20changeset"
}
#endregion

#region Set BuildDeploy.SvnMain.LocalRootFolder
# set the BuildDeploy.SvnMain.LocalRootFolder
# path to local root IHI_MAIN folder which is 3 levels up from current script 
function Set-IHIValue_BuildDeploy_SvnMain_LocalRootFolder {
  $Ihi:BuildDeploy.SvnMain.LocalRootFolder = Split-Path -Parent -Path (Split-Path -Parent -Path (Split-Path -Parent -Path $ScriptFolder))
}
#endregion

#region Set BuildDeploy.SvnMain.ReadOnlyAccount
# set the BuildDeploy.SvnMain.ReadOnlyAccount hashtable container
function Set-IHIValue_BuildDeploy_SvnMain_ReadOnlyAccount {
  $Ihi:BuildDeploy.SvnMain.ReadOnlyAccount = @{}
}
#endregion

#region Set BuildDeploy.SvnMain.ReadOnlyAccount.UserName
# set the BuildDeploy.SvnMain.ReadOnlyAccount.UserName value
function Set-IHIValue_BuildDeploy_SvnMain_ReadOnlyAccount_UserName {
  $Ihi:BuildDeploy.SvnMain.ReadOnlyAccount.UserName = "engtest1"
}
#endregion

#region Set BuildDeploy.SvnMain.ReadOnlyAccount.Password
# set the BuildDeploy.SvnMain.ReadOnlyAccount.Password value
function Set-IHIValue_BuildDeploy_SvnMain_ReadOnlyAccount_Password {
  $Ihi:BuildDeploy.SvnMain.ReadOnlyAccount.Password = "group@ccess1"
}
#endregion

#region Set BuildDeploy.SvnMain.RepositoryRootUrl
# set the BuildDeploy.SvnMain.RepositoryRootUrl url
function Set-IHIValue_BuildDeploy_SvnMain_RepositoryRootUrl {
  $Ihi:BuildDeploy.SvnMain.RepositoryRootUrl = "http://ENGBUILD.IHI.COM/svn/ihi_main"
}
#endregion

#region Set BuildDeploy.SvnMain.RepositoryRootFolder
# set the BuildDeploy.SvnMain.RepositoryRootFolder
function Set-IHIValue_BuildDeploy_SvnMain_RepositoryRootFolder {
  $Ihi:BuildDeploy.SvnMain.RepositoryRootFolder = "D:\SourceControl\SVN\Repositories\IHI_MAIN"
}
#endregion

#region Set BuildDeploy.SvnMain.Server
# set the BuildDeploy.SvnMain.Server name
function Set-IHIValue_BuildDeploy_SvnMain_Server {
  $Ihi:BuildDeploy.SvnMain.Server = "ENGBUILD.IHI.COM"
}
#endregion

#region Set BuildDeploy - calls all individual set functions
function Set-IHIValues_BuildDeploy {
  Set-IHIValue_BuildDeploy_ApplicationConfigsRootFolder
  Set-IHIValue_BuildDeploy_ApplicationConfigsRootUrlPath
  Set-IHIValue_BuildDeploy_BuildServer
  Set-IHIValue_BuildDeploy_CopyServer
  Set-IHIValue_BuildDeploy_DeployFolders
  # DeployFolders must be done in this order because of DeployRootFolder dependency
  Set-IHIValue_BuildDeploy_DeployFolders_DeployRootFolder
  Set-IHIValue_BuildDeploy_DeployFolders_CurrentVersions
  Set-IHIValue_BuildDeploy_DeployFolders_DeployLogsArchive
  Set-IHIValue_BuildDeploy_DeployFolders_Packages
  Set-IHIValue_BuildDeploy_DeployFolders_DeployHistoryFile
  Set-IHIValue_BuildDeploy_DeployShare
  Set-IHIValue_BuildDeploy_ErrorNotificationEmails
  Set-IHIValue_BuildDeploy_IHIScriptsFolder
  Set-IHIValue_BuildDeploy_ReleasesFolder
  Set-IHIValue_BuildDeploy_SvnMain
  Set-IHIValue_BuildDeploy_SvnMain_FishEye
  Set-IHIValue_BuildDeploy_SvnMain_FishEye_AdministrationUrl
  Set-IHIValue_BuildDeploy_SvnMain_FishEye_ReadOnlyAccount
  Set-IHIValue_BuildDeploy_SvnMain_FishEye_ReadOnlyAccount_UserName
  Set-IHIValue_BuildDeploy_SvnMain_FishEye_ReadOnlyAccount_Password
  Set-IHIValue_BuildDeploy_SvnMain_FishEye_SearchRepositoryUrl
  Set-IHIValue_BuildDeploy_SvnMain_LocalRootFolder
  Set-IHIValue_BuildDeploy_SvnMain_ReadOnlyAccount
  Set-IHIValue_BuildDeploy_SvnMain_ReadOnlyAccount_UserName
  Set-IHIValue_BuildDeploy_SvnMain_ReadOnlyAccount_Password
  Set-IHIValue_BuildDeploy_SvnMain_RepositoryRootUrl
  Set-IHIValue_BuildDeploy_SvnMain_RepositoryRootFolder
  Set-IHIValue_BuildDeploy_SvnMain_Server
}
#endregion

#endregion

#region Functions: Set Folders values

#region Set Folders.PowerShellModuleMainFolder
# set the Folders PowerShellModuleMainFolder path
# this is the folder that the current script is located in
function Set-IHIValue_Folders_PowerShellModuleMainFolder {
  $Ihi:Folders.PowerShellModuleMainFolder = $ScriptFolder
}
#endregion

#region Set Folders.TempFolder
# set the Folders TempFolder path
# try paths in this order: d:\temp (servers), c:\temp, c:\Windows\temp
function Set-IHIValue_Folders_TempFolder {
  if (Test-Path -Path "d:\temp") {
    $Ihi:Folders.TempFolder = "d:\temp"
  } elseif (Test-Path -Path "c:\temp") {
    $Ihi:Folders.TempFolder = "c:\temp"
  } else {
    $Ihi:Folders.TempFolder = "c:\Windows\temp"
  }
}

#endregion

#region Set Folders.LogfilesFolder
# set the Folders LogfilesFolder path
# Check if D:\Logfiles exists, it should on the Servers
# Otherwise, just set it to C:\Logfiles without checking for existance
function Set-IHIValue_Folders_LogfilesFolder {
  if (Test-Path -Path "D:\Logfiles") {
    $Ihi:Folders.LogfilesFolder = "d:\Logfiles"
  } else {
    $Ihi:Folders.LogfilesFolder = "C:\Logfiles"
  } 
}
#endregion

#region Set Folders - calls all individual set functions
function Set-IHIValues_Folders {
  Set-IHIValue_Folders_PowerShellModuleMainFolder
  Set-IHIValue_Folders_TempFolder
  Set-IHIValue_Folders_LogfilesFolder
}
#endregion

#endregion

#region Functions: Set Network values

#region Set Network.Email
# set the Network.Email hash table container
function Set-IHIValue_Network_Email {
  $Ihi:Network.Email = @{}
}
#endregion

#region Set Network.Email.DefaultFromAddress
# set the Network.Email.DefaultFromAddress hash table container
function Set-IHIValue_Network_Email_DefaultFromAddress {
  $Ihi:Network.Email.DefaultFromAddress = "PS_" + (Get-IHIFQMachineName) + "@ihi.org"
}
#endregion

#region Set Network.Email.MailRelay
# set the Network.Email.MailRelay hash table container
function Set-IHIValue_Network_Email_MailRelay {
  $Ihi:Network.Email.MailRelay = @{}
}
#endregion

#region Set Network.Email.MailRelay.DomainFilters
# set the Network.Email.MailRelay.DomainFilters used for filtering recipients by email address
function Set-IHIValue_Network_Email_MailRelay_DomainFilters {
  # if this is an Expedient machine, no domain filter
  # else it's an IHI machine so only send @ihi.org emails
  if ($Ihi:Network.Servers.ExpedientServers -contains (Get-IHIFQMachineName)) {
    [string[]]$Ihi:Network.Email.MailRelay.DomainFilters = $null
  } else {
    [string[]]$Ihi:Network.Email.MailRelay.DomainFilters = "@ihi.org"
  }

}
#endregion

#region Set Network.Email.MailRelay.Enabled
# set the Network.Email.MailRelay.Enabled hash table container
function Set-IHIValue_Network_Email_MailRelay_Enabled {
  $Ihi:Network.Email.MailRelay.Enabled = $true
}
#endregion

#region Set Network.Email.MailRelay.RelayServer
# set the Network.Email.MailRelay.RelayServer hash table container
function Set-IHIValue_Network_Email_MailRelay_RelayServer {
  # if this is a Terremark machine, relay is relay.datareturn.com
  # else it's an IHI machine so relay is mail.ihi.org
  if ($Ihi:Network.Servers.ExpedientServers -contains (Get-IHIFQMachineName)) {
    $Ihi:Network.Email.MailRelay.RelayServer = "prodsmtp.ihi.com"
  }else {
    $Ihi:Network.Email.MailRelay.RelayServer = "smtp.ihi.com"
  }
}
#endregion

#region Set Network.Servers
# set the Network.Servers hash table container
function Set-IHIValue_Network_Servers {
  $Ihi:Network.Servers = @{}
}
#endregion

#region Set Network.Servers.IhiServers
# set the Network.Servers IhiServers
function Set-IHIValue_Network_Servers_IhiServers {
  $Ihi:Network.Servers.IhiServers = "ENGBUILD.IHI.COM","DEVAPPWEB.IHI.COM","DEVSPWEB01.IHI.COM","DEVSPADM01.IHI.COM","DEVSPCRAWL01.IHI.COM","DEVSQL.IHI.COM","DEVSPSQL01.IHI.COM","DEVAPPSQL01.IHI.COM","DEVGP01.IHI.COM","DEVDW.IHI.COM","DEVDW01.IHI.COM","TESTAPPWEB.IHI.COM","TESTSPADM01.IHI.COM","TESTSPWEB01.IHI.COM","TESTSPWEB02.IHI.COM","TESTSPCRAWL01.IHI.COM","TESTSPSQL01.IHI.COM","TESTSQL.IHI.COM","TESTAPPSQL01.IHI.COM","TESTGP01.IHI.COM","TESTDW.IHI.COM","TESTDW01.IHI.COM","GP01.IHI.COM","IHIGP01.IHI.COM","DATAWAREHOUSE.IHI.COM","DW2.IHI.COM","PRODDW01.IHI.COM","IHILM01.IHI.COM","IHIAPPWEB01.IHI.COM","IHISPWEB01.IHI.COM","IHISPWEB02.IHI.COM","IHISPADM01.IHI.COM","IHISPCRAWL01.IHI.COM","IHISPSQL01.IHI.COM","IHIAPPSQL01.IHI.COM","IHISPWEB03.IHI.COM","IHISPWEB04.IHI.COM","IHISPCRAWL02.IHI.COM","IHISPADM02.IHI.COM","IHISPSQL02.IHI.COM","ENGIIS01.IHI.COM","DRAPPWEB01.IHI.COM","DRSPWEB01.IHI.COM","DRSPADM01.IHI.COM","DRSPCRAWL01.IHI.COM","DRAPPSQL01.IHI.COM","DRSPADM02.IHI.COM","DRSPWEB03.IHI.COM","DRSPCRAWL02.IHI.COM","DRSPSQL02.IHI.COM","ENGIIS01.IHI.COM","LOCALBI02.IHI.COM","LOCAL03.IHI.COM","LOCAL06.IHI.COM"
}
#endregion

#region Set Network.Servers.SpringsServers
# set the Network.Servers SpringsServers
function Set-IHIValue_Network_Servers_SpringsServers {
  $Ihi:Network.Servers.SpringsServers = "DEVSPWEB01.IHI.COM","DEVSPADM01.IHI.COM","DEVSPCRAWL01.IHI.COM","DEVAPPWEB.IHI.COM","TESTSPADM01.IHI.COM","TESTSPADM01.IHI.COM","TESTSPWEB01.IHI.COM","TESTSPWEB02.IHI.COM","TESTSPSQL01.IHI.COM","TESTSPCRAWL01.IHI.COM","TESTAPPWEB.IHI.COM","DRSPWEB01.IHI.COM","DRSPADM01.IHI.COM","DRSPCRAWL01.IHI.COM","DRAPPSQL01.IHI.COM","DRSPADM02.IHI.COM","DRSPWEB03.IHI.COM","DRSPCRAWL02.IHI.COM","DRSPSQL02.IHI.COM","IHIAPPWEB01.IHI.COM","IHISPWEB01.IHI.COM","IHISPWEB02.IHI.COM","IHISPADM01.IHI.COM","IHISPCRAWL01.IHI.COM","IHISPSQL01.IHI.COM","IHIAPPSQL01.IHI.COM","IHISPWEB02.IHI.COM","IHISPWEB03.IHI.COM","IHISPWEB04.IHI.COM","IHISPCRAWL02.IHI.COM","IHISPADM02.IHI.COM","IHISPSQL02.IHI.COM"
}
#endregion

#region Set Network.Servers.DRServers
# set the Network.Servers DReyondServers
function Set-IHIValue_Network_Servers_DRServers {
  $Ihi:Network.Servers.DRServers = "DRAPPWEB01.IHI.COM","DRSPWEB01.IHI.COM","DRSPADM01.IHI.COM","DRSPCRAWL01.IHI.COM","DRAPPSQL01.IHI.COM","DRSPADM02.IHI.COM","DRSPWEB03.IHI.COM","DRSPCRAWL02.IHI.COM","DRSPSQL02.IHI.COM"
}
#endregion

#region Set Network.Servers.ExpedientServers
# set the Network.Servers ExpedientServers
function Set-IHIValue_Network_Servers_ExpedientServers {
  $Ihi:Network.Servers.ExpedientServers = "IHILM01.IHI.COM","IHIAPPWEB01.IHI.COM","IHISPWEB01.IHI.COM","IHISPWEB02.IHI.COM","IHISPADM01.IHI.COM","IHISPCRAWL01.IHI.COM","IHISPSQL01.IHI.COM","IHIAPPSQL01.IHI.COM","IHISPWEB02.IHI.COM","IHISPWEB03.IHI.COM","IHISPWEB04.IHI.COM","IHISPCRAWL02.IHI.COM","IHISPADM02.IHI.COM","IHISPSQL02.IHI.COM"
}
#endregion

#region Set Network.Servers.DevServers
# set the Network.Servers.DevServers
function Set-Network.Servers.DevServers {
  $Ihi:Network.Servers.DevServers = ""
}
#endregion

#region Set Network - calls all individual set functions
function Set-IHIValues_Network {
  # note: the server values need to be set before Email values
  # as the values are set based on whether or not the current server is a Production server
  Set-IHIValue_Network_Servers
  Set-IHIValue_Network_Servers_IhiServers
  Set-IHIValue_Network_Servers_SpringsServers
  Set-IHIValue_Network_Servers_DRServers
  Set-IHIValue_Network_Servers_ExpedientServers

  # note: the server values need to be set before Email values
  # as the values are set based on whether or not the current server is a Production server
  Set-IHIValue_Network_Email
  Set-IHIValue_Network_Email_DefaultFromAddress
  Set-IHIValue_Network_Email_MailRelay
  Set-IHIValue_Network_Email_MailRelay_DomainFilters
  Set-IHIValue_Network_Email_MailRelay_Enabled
  Set-IHIValue_Network_Email_MailRelay_RelayServer
}
#endregion

#endregion

#region "main"

if ($ShowLoadDetails) { Write-Host "$(Split-Path $MyInvocation.MyCommand.Path -Leaf)`n  entering main" }

#region Get current script name and parent folder
$ScriptName = Split-Path $MyInvocation.MyCommand.Path -Leaf
$ScriptFolder = Split-Path $MyInvocation.MyCommand.Path -Parent
#endregion

# set values for Applications 
Set-IHIValues_Applications
# set values for BuildDeploy
Set-IHIValues_BuildDeploy
# set values for Folders
Set-IHIValues_Folders
# set values for Network
Set-IHIValues_Network

#endregion

#region Exit script
# if there was an error before now but it was handled, the script would've exited before now
# check if any unhandled errors by checking $Error object
# If looping through Error collection, can't use Write-Error to 'display' errors as that modifies
# the $Error collection.
if ($Error.Count -gt 0) {
  Write-Host "An unhandled error has been detected in $ScriptName." -ForegroundColor Red
  $Error | ForEach-Object {
    Write-Host $_ -ForegroundColor Red
  }
  exit 1
} else {
  exit 0
}
#endregion
