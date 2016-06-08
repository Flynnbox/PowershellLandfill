#region Script help

<#
.SYNOPSIS
Imports standard IHI modules into PowerShell session.
.DESCRIPTION
Imports modules for IHI developer and server instances.  Imports standard modules 
such as PSCX and IHI, imports optional modules (SharePoint, WebAdministration, SQLPS),
imports IHI script modules, and initializes the settings load module.

Additional notes:
 - This script cannot have any external dependencies (functions, modules, global
   settings, etc.) - it must be standalone.  As a result certain items will have 
   have to be hard-coded or duplicated in this script.
 - This script is located in the local PowerShell3/Main folder.  As all modules to be
   imported are located under PowerShell3/Main/Modules, this folder will be added 
   to the $env:PSModulePath if necessary.
.PARAMETER ShowLoadDetails
Show details about the import process including module names and load times
.PARAMETER NoTip
Do not show a tip on startup
#>
#endregion

#region Script parameters
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
  [switch]$ShowLoadDetails,
  [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
  [switch]$NoTip,
  [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
  [string]$SSISVersion = 'latest'
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
# name of root modules folder
Set-Variable -Name ModulesFolderName -Value "Modules" -Option ReadOnly
# name of set IhiDrive settings file
Set-Variable -Name IhiDriveSettingsFileName -Value "Set-IHIIhiDriveSettings.ps1" -Option ReadOnly
#endregion

#region Variables
# name of current script
[string]$ScriptName = $null
# path of current script parent folder
[string]$ScriptFolder = $null
# path of module root folder
[string]$ModuleRootFolder = $null
# is shell open as administrator
[bool]$IsAdmin = $false
# width of column 1 (text; load time info is column 2)
[int]$Column1Width = 60
#endregion

#region Functions: Update-IHIPSModulePath
<#
.SYNOPSIS
Updates $env:PSModulePath - adds ModuleRootPath
.DESCRIPTION
Updates $env:PSModulePath by adding ModuleRootPath to the end if it
is not found currently.
.PARAMETER ModuleRootPath
Path of modules root folder to add.
.EXAMPLE
Update-IHIPSModulePath "C:\IHI_MAIN\trunk\PowerShell3\Main\Modules
#>
function Update-IHIPSModulePath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$ModuleRootPath
  )
  process {
    # make sure param passed and valid
    # only uncomment this if you are having issues
    # if ($ShowLoadDetails) { Write-Host "  $($MyInvocation.MyCommand.Name): testing ModuleRootPath parameter" }
    if ($ModuleRootPath -eq $null -or $ModuleRootPath.Trim() -eq "") {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: no value passed for ModuleRootPath"
      return
    } elseif ($false -eq (Test-Path -Path $ModuleRootPath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: ModuleRootPath value does not exist: $ModuleRootPath"
      return
    }
    # show current `$env:PSModulePath
    # only uncomment this if you are having issues
    # if ($ShowLoadDetails) { Write-Host "  $($MyInvocation.MyCommand.Name): current `$env:PSModulePath: $($env:PSModulePath)" }

    # ok, path is good, check to see if already in $env:PSModulePath
    # can't just do a simple contains because there could be a subfolder of the path and that would match
    # for example if your path was c:\temp and you were testing string ...;c:\temp\lowerfolder;... it would falsly match
    # so test for either contains folder followed by semi-colon or endswith path
    if ($env:PSModulePath.ToUpper().Contains($ModuleRootPath.ToUpper() + ";") -or
      $env:PSModulePath.ToUpper().EndsWith($ModuleRootPath.ToUpper())) {
      # this isn't an error condition but report it if showing details
      # only uncomment this if you are having issues
      # if ($ShowLoadDetails) { Write-Host "  $($MyInvocation.MyCommand.Name): `$env:PSModulePath: already contains $($ModuleRootPath)" }
    } else {
      # only uncomment this if you are having issues
      # if ($ShowLoadDetails) { Write-Host "  $($MyInvocation.MyCommand.Name): Adding $($ModuleRootPath) to `$env:PSModulePath" }
      $env:PSModulePath += ";" + $ModuleRootPath
    }
  }
}
#endregion

#region Functions: Add-IHISnapin, Import-IHIModule
<#
.SYNOPSIS
Adds a snapin to the shell.
.DESCRIPTION
Adds a snapin to the shell, timing the process and displaying results.  Displays
error information as necessary (for example, if no snapin exists with that name).
.PARAMETER SnapinName
Name of snapin to add.
#>
function Add-IHISnapin {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $true)]
    [string]$SnapinName
  )
  process {
    # first attempt to get snapin to make sure exists with that name
    # if you do it this way with a Where instead of -Name param, it won't throw an error if the snapin doesn't exist
    $Snapin = Get-PSSnapin -Registered | Where-Object { $_.Name -eq $SnapinName }
    if ($Snapin -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: snapin with name $SnapinName not registered on machine"
      return
    } else {
      # get time before 
      $StartTime = Get-Date
      # add snapin
      Add-PSSnapin -Name $SnapinName
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error importing snapin $SnapinName"
        return
      }
      $ElapsedTime = (Get-Date) - $StartTime
      if ($ShowLoadDetails) { Write-Host $("    {0,-$Column1Width} [ Loaded in {1:0.00} s ]" -f $SnapinName,$ElapsedTime.TotalSeconds) }
    }
  }
}


<#
.SYNOPSIS
Imports a module into the shell.
.DESCRIPTION
Imports a module into the shell, timing the process and displaying results.  Displays
error information as necessary (for example, if no module exists with that name).
.PARAMETER ModuleName
Name of module to import.
#>
function Import-IHIModule {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $true)]
    [string]$ModuleName
  )
  process {
    # first attempt to get module to make sure exists with that name
    # if you do it this way with a Where instead of -Name param, it won't throw an error if the module doesn't exist
    
    $Module = Get-Module $ModuleName -ListAvailable | Where-Object { $_.Name -eq $ModuleName }
    if ($Module -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: module with name $ModuleName not found"
      return
    } else {
      # get time before 
      $StartTime = Get-Date
      # import module
      if ($ShowLoadDetails) {Write-Host "    Import-Module -ModuleInfo $Module -DisableNameChecking"}
      Import-Module -ModuleInfo $Module -DisableNameChecking
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error importing module $ModuleName"
        return
      }
      $ElapsedTime = (Get-Date) - $StartTime
      if ($ShowLoadDetails) { Write-Host $("    {0,-$Column1Width} [ Loaded in {1:0.00} s ]" -f $ModuleName,$ElapsedTime.TotalSeconds) }
    }
  }
}
#endregion

#region Functions: Import-IHIRequiredModules, Import-IHIOptionalModules
<#
.SYNOPSIS
Adds required snapins and imports required modules.
.DESCRIPTION
Adds required snapins and imports required modules into shell.  If a particular
snapin or module is specified but not found on the machine, an error is thrown.
.PARAMETER SnapinNames
Name of required snapins to add.
.PARAMETER ModuleNames
Name of required modules to import.
#>
function Import-IHIRequiredModules {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$SnapinNames,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$ModuleNames
  )
  process {
    # add required snapins then import required modules
    # first add required snapins
    # if snapin doesn't exist on machine, Import-IHIModule generates an error
    if ($SnapinNames -ne $null) {
      foreach ($SnapinName in $SnapinNames) {
        $Err = $null
        Add-IHISnapin $SnapinName -EV Err
        if ($Err -ne $null) {
          $Err | Write-Host
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error adding snapin $SnapinName"
          return
        }
      }
    }

    # next import required modules
    # if module doesn't exist on machine, Import-IHIModule generates an error
    if ($ModuleNames -ne $null) {
      foreach ($ModuleName in $ModuleNames) {
        $Err = $null
        Import-IHIModule $ModuleName -EV Err
        if ($Err -ne $null) {
          $Err | Write-Host
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error importing module $ModuleName"
          return
        }
      }
    }
  }
}


<#
.SYNOPSIS
Adds optional snapins and imports optional modules - if they exist.  If not, no error.
.DESCRIPTION
Adds optional snapins and imports optional modules - if they exist.  If they do
not, no error is throw but the snapin and modules names will be listed.
.PARAMETER SnapinNames
Name of required snapins to add.
.PARAMETER ModuleNames
Name of required modules to import.
#>
function Import-IHIOptionalModules {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$SnapinNames,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$ModuleNames
  )
  process {
    # if snapin list passed, process it
    if ($SnapinNames -ne $null) {
      # get list of all the actual modules available
      $AvailableSnapinNames = Get-PSSnapin -Registered | % { $_.Name }
      # get lists of actual modules found and not found
      $FoundSnapinNames = $SnapinNames | Where-Object { $AvailableSnapinNames -contains $_ }
      $NotFoundSnapinNames = $SnapinNames | Where-Object { $AvailableSnapinNames -notcontains $_ }
      # report modules not found
      if ($NotFoundSnapinNames -ne $null) { if ($ShowLoadDetails) { Write-Host "    Snapins not found: $NotFoundSnapinNames" } }
      # now import the modules found
      if ($FoundSnapinNames -ne $null) {
        foreach ($FoundSnapinName in $FoundSnapinNames) {
          $Err = $null
          Add-IHISnapin -SnapinName $FoundSnapinName -EV Err
          if ($Err -ne $null) {
            $Err | Write-Host
            Write-Error -Message "$($MyInvocation.MyCommand.Name):: error adding snapin $FoundSnapinName"
            return
          }
        }
      }
    }

    # if module list passed, process it
    if ($ModuleNames -ne $null) {
      # get list of all the actual modules available
      $AvailableModuleNames = Get-Module -ListAvailable | % { $_.Name }
      # get lists of actual modules found and not found
      $FoundModuleNames = $ModuleNames | Where-Object { $AvailableModuleNames -contains $_ }
      $NotFoundModuleNames = $ModuleNames | Where-Object { $AvailableModuleNames -notcontains $_ }
      # report modules not found
      if ($NotFoundModuleNames -ne $null) { if ($ShowLoadDetails) { Write-Host "    Modules not found: $NotFoundModuleNames" } }
      # now import the modules found
      if ($FoundModuleNames -ne $null) {
        foreach ($FoundModuleName in $FoundModuleNames) {
          $Err = $null
          Import-IHIModule -ModuleName $FoundModuleName -EV Err
          if ($Err -ne $null) {
            $Err | Write-Host
            Write-Error -Message "$($MyInvocation.MyCommand.Name):: error importing module $FoundModuleName"
            return
          }
        }
      }
    }
  }
}
#endregion

#region "main"

#region Set Current Path
# We'll want to reset the path to this path at the end of this script
$CurrentPath = Get-Location
#endregion

if ($ShowLoadDetails) { Write-Host "$(Split-Path $MyInvocation.MyCommand.Path -Leaf)" }

#region Get current script name and parent folder
$ScriptName = Split-Path $MyInvocation.MyCommand.Path -Leaf
$ScriptFolder = Split-Path $MyInvocation.MyCommand.Path -Parent
#endregion

#region Determine if shell running as an administrator
$WindowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$WindowsPrincipal = New-Object "System.Security.Principal.WindowsPrincipal" $WindowsIdentity
$IsAdmin = $WindowsPrincipal.IsInRole("Administrators")
#endregion

#region Update $env:PSModulePath
# module root folder is "Modules" folder under current script parent folder 
$ModuleRootFolder = Join-Path -Path $ScriptFolder -ChildPath $ModulesFolderName
# update PS module path if necessary
$Err = $null
Update-IHIPSModulePath $ModuleRootFolder -EV Err
if ($Err -ne $null) {
  $Err | Write-Host
  Write-Error -Message "$($MyInvocation.MyCommand.Name):: Error updating `$env:PSModulePath failed; exiting $ScriptName"
  exit 1
}
#endregion

#region Import required snapins and modules
# import snapins and modules that are required on all machines for all scripts
if ($ShowLoadDetails) { Write-Host "  Import required snapins/modules" }

# list of required snapins, in order of load
[string[]]$RequiredSnapinNames = $null # no snapins required at this time

# list of required snapins modules, in order of load
# The version of PSCX varies with the PowerShell version
if ($PSVersionTable.PSVersion.Major -eq 2) {
        Write-Host "Looks like we are running PowerShell $($PSVersionTable.PSVersion.Major), so we need PSCX2.1.1. `n"
        [string[]]$RequiredModuleNames = "PSCX2.1.1"
    }elseif ($PSVersionTable.PSVersion.Major -ge 4) {
        Write-Host "Looks like we are running PowerShell $($PSVersionTable.PSVersion.Major), so we need PSCX3.1.0. `n"
        [string[]]$RequiredModuleNames = "PSCX3.1.0"
    } else {    
        Write-Host "Looks like we are running PowerShell $($PSVersionTable.PSVersion.Major), so we need PSCX3.0.0. `n"
        [string[]]$RequiredModuleNames = "PSCX"
    }
$RequiredModuleNames +=,"IHI"
# PSCX is the PowerShell Community Extensions - lots of handy utilities
# IHI is the main module; it references utilities in PSCX, so it must load second

$Err = $null
Import-IHIRequiredModules -SnapinNames $RequiredSnapinNames -ModuleNames $RequiredModuleNames -EV Err
if ($Err -ne $null) {
  $Err | Write-Host
  Write-Error -Message "$($MyInvocation.MyCommand.Name):: error importing required modules; exiting $ScriptName"
  exit 1
}
#endregion

#region Import optional snapins and modules - if the snapin or module is found, load it otherwise skip it
# if it exists, add or import it attempt import snapins and modules that are optional on all machines
if ($ShowLoadDetails) { Write-Host "  Import optional snapins/modules" }
# list of required snapins and modules, in order of load
[string[]]$OptionalSnapinNames = "Microsoft.SharePoint.PowerShell"
[string[]]$OptionalModuleNames = "SQLPS","SQLASCMDLETS"
# only load WebAdministration is user/shell is an admin, otherwise don't load
if ($IsAdmin -eq $true) {
  $OptionalModuleNames +=,"WebAdministration"
}
$Err = $null
Import-IHIOptionalModules -SnapinNames $OptionalSnapinNames -ModuleNames $OptionalModuleNames -EV Err
if ($Err -ne $null) {
  $Err | Write-Host
  Write-Error -Message "$($MyInvocation.MyCommand.Name):: error importing optional modules; exiting $ScriptName"
  exit 1
}
#endregion

# After this point assume the modules are loaded correctly.  Any code invoked after this point
# can use IHI functions for carrying out its work.

#region Make any post-module-load environment settings changes
# after loading modules, make any settings changes here
if ($ShowLoadDetails) { Write-Host "  Post-module-load environment settings changes" }

#region reset Current Path in case anything above reset it inadvertantly
cd $CurrentPath
#endregion

#region Load IhiDrive Settings
if ($ShowLoadDetails) { Write-Host "  Load IhiDrive settings" }
# module root folder is "Modules" folder under current script parent folder 
$IhiDriveSettingsFile = Join-Path -Path $ScriptFolder -ChildPath $IhiDriveSettingsFileName

# get time before 
$StartTime = Get-Date
& $IhiDriveSettingsFile $SSISVersion
$ElapsedTime = (Get-Date) - $StartTime
if ($ShowLoadDetails) { Write-Host $("    {0,-$Column1Width} [ Loaded in {1:0.00} s ]" -f "IhiDrive loaded",$ElapsedTime.TotalSeconds) }

#endregion

#region Define prompt
# There are two changes from the standard PowerShell prompt:
#  - remove the "PS " at the beginning to save space
#  - if current path is a UNC path (\\IHIDEV\Upload\....) PowerShell will prefix the 
#    location with "Microsoft.PowerShell.Core\FileSystem::" this is really long so let's remove it
function global:prompt {
  # original return value: "$(Get-Location)> " 
  # if current path is a UNC path (\\ihitest\e$\....) PowerShell will prefix the 
  # location with Microsoft.PowerShell.Core\FileSystem::
  # don't display this long value in the prompt!
  $CurrentPath = Get-Location
  if ($CurrentPath.Path.StartsWith("Microsoft.PowerShell.Core\FileSystem::")) {
    "$($CurrentPath.Path.SubString(38))> "
  } else {
    "$($CurrentPath.Path)> "
  }
}
#endregion

#region Show tip
# if NoTip not specified, then display a tip
if (!$NoTip) { Write-IHITip }
#endregion

#region Update PSCX settings
# turn off PSCX cd echo of location
$Pscx:Preferences['CD/EchoNewLocation'] = $false
$Pscx:Preferences['CD_EchoNewLocation'] = $false
#endregion

#region Ensure email diff registry changes present on developer machine
# only do this run on developer machines (not a server)
if (!(Test-IHIIsIHIServer)) { Install-IHIEmailDiffLink }
#endregion

#region Make sure developer machine is using correct SVN server
# only do this run on developer machines (not a server)
if (!(Test-IHIIsIHIServer)) {
  # we know only one copy of svn.exe in path as 
  # Update-IHIDeveloperMachinePsFramework checks for this so this should be safe to run
  $RootUrl = ([xml](svn info $Ihi:BuildDeploy.SvnMain.LocalRootFolder --xml)).info.entry.url
  if ($RootUrl -match "engvss") {
    Write-Host "`nYour local Subversion working copy is pointing to the OLD repository server!" -ForegroundColor Green
    Start-Sleep -Seconds 2
    Write-Host "You need to change this; run " -ForegroundColor Green -NoNewline
    Write-Host "switchrepo" -ForegroundColor Magenta
    Start-Sleep -Seconds 4
    Write-Host "`nSeriously, you should run " -ForegroundColor Green -NoNewline
    Write-Host "switchrepo" -ForegroundColor Magenta -NoNewline
    Start-Sleep -Seconds 2
    Write-Host " right now.`n`n" -ForegroundColor Green -NoNewline
  }
}
#endregion

#endregion

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

