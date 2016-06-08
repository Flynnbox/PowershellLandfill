
#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
    # when writing external logfile (not main), use these default settings
    [hashtable]$script:OutFileSettings = @{ Encoding = "ascii"; Force = $true; Append = $true }
  }
}
# initialize/reset the module
Initialize
# ensure best practices for variable use, function calling, null property access, etc.
# must be done at module script level, not inside Initialize, or will only be function scoped
Set-StrictMode -Version 2
#endregion


#region Functions: Assert-IHIIsSenthilApproved

<#
.SYNOPSIS
Confirmation of ISO 9001 "Is Senthil Approved" compliance
.DESCRIPTION
Confirmation of ISO 9001 "Is Senthil Approved" compliance. This is the most
important function.
.EXAMPLE
Assert-IHIIsSenthilApproved
Opens IE to ISA image.
#>
function Assert-IHIIsSenthilApproved {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    $Err = $null
    Open-IHIInternetExplorer "http://app.ihi.org/senthil_approved.gif" -EV Err
    if ($Err -ne $null) {
      $Err | Write-Host
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred calling Open-IHIInternetExplorer"
      return
    }
  }
}
Export-ModuleMember -Function Assert-IHIIsSenthilApproved
New-Alias -Name "isa" -Value Assert-IHIIsSenthilApproved
Export-ModuleMember -Alias "isa"
#endregion


#region Functions: Compare-IHIAppWebConfigs, Get-IhiWebConfigSortOrder

<#
.SYNOPSIS
Opens app web.configs in diff windows, dev to production
.DESCRIPTION
Opens all the web.configs for an application in diff windows.  Configs
are opened in pairs, from developer copy through production.  This is 
handy for propogating changes through a web.config.  For RootPath, specify a
root path above all the configs, such as C:\IHI_MAIN\trunk\CSIConsole.
If RootPath not specified, uses current location.
SPRINGS web.configs are not supported, sorry.
.PARAMETER RootPath
Root path from which to search for web.configs
.EXAMPLE
Compare-IHIAppWebConfigs c:\IHI_MAIN\trunk\CSIConsole
<opens web.configs for Console>
.EXAMPLE
cd c:\IHI_MAIN\trunk\CSIConsole; Compare-IHIAppWebConfigs
<because no path explicitly given, grabs current path and uses that>
#>
function Compare-IHIAppWebConfigs {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    $RootPath
  )
  #endregion
  process {
    #region Application and path validation
    if ($Ihi:Applications.Editor.DiffViewer -eq $null -or !(Test-Path -Path $Ihi:Applications.Editor.DiffViewer)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path for diff viewer is null or bad: $($Ihi:Applications.Editor.DiffViewer)"
      return
    }
    # check to make sure path is valid
    if ($RootPath -ne $null -and (!(Test-Path -Path $RootPath))) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: rootPath does not exist: $RootPath"
      return
    }
    # if path not passed, get current location but make sure path is a filesystem first (not called from IHI: drive or registry...)
    if ($RootPath -eq $null) {
      if ((Get-Location).Provider.Name -ne "FileSystem") {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: cannot use from non-FileSystem drive"
        return
      } else {
        $RootPath = (Get-Location).Path
      }
    }

    # make sure path is a folders
    if ((Get-Item -Path $RootPath).PSIsContainer -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: you must supply a root folder, not a file"
      return
    }
    # make sure user is in repository folders
    if (!$RootPath.ToUpper().StartsWith($Ihi:BuildDeploy.SvnMain.LocalRootFolder.ToUpper())) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: sorry, only folders inside the local repository root $($Ihi:BuildDeploy.SvnMain.LocalRootFolder) are supported"
      return
    }
    # make sure user isn't in SPRINGS folder; multiple configs per environment not supported
    if ($RootPath -match "SPRINGS") {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: sorry, SPRINGS web.configs are not supported; the paths are too crazy - future enhancement"
      return
    }
    # make sure user isn't in repository root folders
    if ($RootPath.ToUpper().EndsWith("\IHI_MAIN") -or $RootPath.ToUpper().EndsWith("\IHI_MAIN\TRUNK")) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: sorry, you cannot search and open configs from the repository root, you need to be inside an application root folder"
      return
    }
    #endregion

    #region Find and open web.configs
    # get all web.configs for the source path
    $WebConfigs = Get-ChildItem $RootPath -Recurse -Include "web.config"
    # if no web.configs found, exit
    if ($WebConfigs -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: no web.configs found under: $RootPath"
      return
    }
    # for each web.config, get objects with just FullName and SortOrder for that web.config
    $WebConfigs = $WebConfigs | ForEach-Object { Select -InputObject $_ -Property FullName,@{ n = "SortOrder"; e = { $(Get-IhiWebConfigSortOrder $_.FullName) } } }
    # now sort them
    $WebConfigs = $WebConfigs | Sort SortOrder
    Write-Host ""
    # now open the files
    for ($i = 0; $i -lt ($WebConfigs.Count - 1); $i++) {
      Write-Host "Opening: $($WebConfigs[$i].FullName)"
      Write-Host "         $($WebConfigs[$i+1].FullName)"
      Write-Host ""
      Open-IHIDiffViewer $WebConfigs[$i].FullName $WebConfigs[$i + 1].FullName
      Start-Sleep -Seconds 3
    }
    #endregion
  }
}
Export-ModuleMember -Function Compare-IHIAppWebConfigs
New-Alias -Name "difconfigs" -Value Compare-IHIAppWebConfigs
Export-ModuleMember -Alias "difconfigs"


<#
.SYNOPSIS
Gives relative sort order for config file, given parent path
.DESCRIPTION
Gives a relative sort order for a particular web.config file, given 
its path, from developer copy (lowest) to production server (highest).
This can be used to sort the configs - possibly for opening in order 
of environment.
.PARAMETER FullName
FullName of file
.EXAMPLE
Get-IhiWebConfigSortOrder DEVAPPWEB
Returns: 30
#>
function Get-IhiWebConfigSortOrder {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$FullName
  )
  #endregion
  process {
    [int]$SortOrder = 0
    switch ($FullName) {
      # match developer web.configs, these should be first
      { $FullName -match "UIWeb" } { $SortOrder = 0; break; }
      { $FullName -match ".Host" } { $SortOrder = 1; break; }
      { $FullName -match "DEVAPPWEB" } { $SortOrder = 30; break; }
      { $FullName -match "TESTAPPWEB" } { $SortOrder = 50; break; }
      { $FullName -match "TESTAPPWEB" } { $SortOrder = 60; break; }
      { $FullName -match "Production" } { $SortOrder = 80; break; }
      { $FullName -match "APP.IHI.ORG" } { $SortOrder = 90; break; }
    }
    $SortOrder
  }
}
# this does not need to be exported
#endregion


#region Functions: Compare-IHIProdSpringsConfigsLocal

<#
.SYNOPSIS
Opens diff between repo SPRINGS configs and WWW.IHI.ORG copy
.DESCRIPTION
Opens diff between repo SPRINGS configs and WWW.IHI.ORG copy
.EXAMPLE
Compare-IHIProdSpringsConfigsLocal
Opens diff windows to compare production SPRINGS configs with local working copy
#>
function Compare-IHIProdSpringsConfigsLocal {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    #region Application and path validation
    if ($Ihi:Applications.Editor.DiffViewer -eq $null -or !(Test-Path -Path $Ihi:Applications.Editor.DiffViewer)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path for diff viewer is null or bad: $($Ihi:Applications.Editor.DiffViewer)"
      return
    }
    #endregion

    #region Set values for web.config local repo and remote paths 
    $LocalRepoRoot = Join-Path -Path $Ihi:BuildDeploy.SvnMain.LocalRootFolder -ChildPath "\trunk\Springs\Springs\_Config\2013_PROD"
    $TotalCompares = 13
    $WebConfigs = New-Object 'object[,]' $TotalCompares,2

    $WebConfigs[0,0] = "$LocalRepoRoot\SPRINGS\GoLive_web.config"
    $WebConfigs[0,1] = "\\IHISPADM02.IHI.COM\d$\Inetpub\wwwroot\SPRINGS\web.config"

    $WebConfigs[1,0] = "$LocalRepoRoot\SPRINGS\GoLive_web.config"
    $WebConfigs[1,1] = "\\IHISPWEB03.IHI.COM\d$\Inetpub\wwwroot\SPRINGS\web.config"

    $WebConfigs[2,0] = "$LocalRepoRoot\SPRINGS\GoLive_web.config"
    $WebConfigs[2,1] = "\\IHISPWEB04.IHI.COM\d$\Inetpub\wwwroot\SPRINGS\web.config"

    $WebConfigs[3,0] = "$LocalRepoRoot\SPRINGS\GoLive_web.config"
    $WebConfigs[3,1] = "\\IHISPCRAWL02.IHI.COM\d$\Inetpub\wwwroot\SPRINGS\web.config"

    $WebConfigs[4,0] = "$LocalRepoRoot\CentralAdmin\web.config"
    $WebConfigs[4,1] = "\\IHISPADM02.IHI.COM\c$\Inetpub\wwwroot\wss\VirtualDirectories\28008\web.config"

    $WebConfigs[5,0] = "$LocalRepoRoot\15_WebServices_SecurityToken\web.config"
    $WebConfigs[5,1] = "\\IHISPADM02.IHI.COM\c$\Program Files\Common Files\Microsoft Shared\Web Server Extensions\15\WebServices\SecurityToken\web.config"

    $WebConfigs[6,0] = "$LocalRepoRoot\15_WebServices_SecurityToken\web.config"
    $WebConfigs[6,1] = "\\IHISPWEB03.IHI.COM\c$\Program Files\Common Files\Microsoft Shared\Web Server Extensions\15\WebServices\SecurityToken\web.config"

    $WebConfigs[7,0] = "$LocalRepoRoot\15_WebServices_SecurityToken\web.config"
    $WebConfigs[7,1] = "\\IHISPWEB04.IHI.COM\c$\Program Files\Common Files\Microsoft Shared\Web Server Extensions\15\WebServices\SecurityToken\web.config"

    $WebConfigs[8,0] = "$LocalRepoRoot\15_WebServices_SecurityToken\web.config"
    $WebConfigs[8,1] = "\\IHISPCRAWL02.IHI.COM\c$\Program Files\Common Files\Microsoft Shared\Web Server Extensions\15\WebServices\SecurityToken\web.config"

    $WebConfigs[9,0] = "$LocalRepoRoot\15_BIN\OWSTIMER.EXE.CONFIG"
    $WebConfigs[9,1] = "\\IHISPADM02.IHI.COM\c$\Program Files\Common Files\Microsoft Shared\Web Server Extensions\15\BIN\OWSTIMER.EXE.CONFIG"

    $WebConfigs[10,0] = "$LocalRepoRoot\15_BIN\OWSTIMER.EXE.CONFIG"
    $WebConfigs[10,1] = "\\IHISPWEB03.IHI.COM\c$\Program Files\Common Files\Microsoft Shared\Web Server Extensions\15\BIN\OWSTIMER.EXE.CONFIG"

    $WebConfigs[11,0] = "$LocalRepoRoot\15_BIN\OWSTIMER.EXE.CONFIG"
    $WebConfigs[11,1] = "\\IHISPWEB04.IHI.COM\c$\Program Files\Common Files\Microsoft Shared\Web Server Extensions\15\BIN\OWSTIMER.EXE.CONFIG"

    $WebConfigs[12,0] = "$LocalRepoRoot\15_BIN\OWSTIMER.EXE.CONFIG"
    $WebConfigs[12,1] = "\\IHISPCRAWL02.IHI.COM\c$\Program Files\Common Files\Microsoft Shared\Web Server Extensions\15\BIN\OWSTIMER.EXE.CONFIG"

    #endregion

    #region Loop through each web.config set and if files are accessible, open in diff
    for ($i = 0; $i -lt $TotalCompares; $i++) {
      if ($false -eq (Test-Path -Path $WebConfigs[$i,0])) {
        "Not found; skipping set: " + $WebConfigs[$i,0]
      } elseif ($false -eq (Test-Path -Path $WebConfigs[$i,1])) {
        "Not found; skipping set: " + $WebConfigs[$i,1]
      } else {
        # both files are accessible, open in diff viewer
        Open-IHIDiffViewer $WebConfigs[$i,0] $WebConfigs[$i,1]
        Start-Sleep -Seconds 3
      }
    }
    #endregion
  }
}
Export-ModuleMember -Function Compare-IHIProdSpringsConfigsLocal
#endregion


#region Functions: Compare-IHIProdWebConfigsLocal

<#
.SYNOPSIS
Opens diff window between local web.config and prod (CBAPPWEB01) copy
.DESCRIPTION
Opens diff window between local web.config and prod (CBAPPWEB01) copy
.EXAMPLE
Compare-IHIProdWebConfigsLocal
Opens diff window between local web.config and prod (CBAPPWEB01) copy
#>
function Compare-IHIProdWebConfigsLocal {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    #region Application and path validation
    if ($Ihi:Applications.Editor.DiffViewer -eq $null -or !(Test-Path -Path $Ihi:Applications.Editor.DiffViewer)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path for diff viewer is null or bad: $($Ihi:Applications.Editor.DiffViewer)"
      return
    }
    #endregion

    #region Set values for web.config local repo and remote paths 
    $LocalRepoRoot = Join-Path -Path $Ihi:BuildDeploy.SvnMain.LocalRootFolder -ChildPath "\trunk"
    $ProdServerRoot = "\\IHIAPPWEB01.IHI.COM\d$\inetpub\Ihi.org"
    $TotalCompares = 19
    $WebConfigs = New-Object 'object[,]' $TotalCompares,2

    $WebConfigs[0,0] = "$LocalRepoRoot\Webroot\_Config_IHI\APP.IHI.ORG\web.config"
    $WebConfigs[0,1] = "$ProdServerRoot\web.config"

    $WebConfigs[1,0] = "$LocalRepoRoot\CertificateCenter\_Config_IHI\app.ihi.org\web.config"
    $WebConfigs[1,1] = "$ProdServerRoot\CertificateCenter\web.config"

    $WebConfigs[2,0] = "$LocalRepoRoot\Agility\Agility\_Config_IHI\APP.IHI.ORG\web.config"
    $WebConfigs[2,1] = "$ProdServerRoot\Code\Agility\web.config"

    $WebConfigs[3,0] = "$LocalRepoRoot\CsiConsole\_Config_IHI\APP.IHI.ORG\web.config"
    $WebConfigs[3,1] = "$ProdServerRoot\Console\web.config"

    $WebConfigs[4,0] = "$LocalRepoRoot\Offerings\EventManagement\_Config_IHI\APP.IHI.ORG\web.config"
    $WebConfigs[4,1] = "$ProdServerRoot\EventManagement\web.config"

    $WebConfigs[5,0] = "$LocalRepoRoot\Offerings\Events\_Config_IHI\APP.IHI.ORG\web.config"
    $WebConfigs[5,1] = "$ProdServerRoot\Events\web.config"

    $WebConfigs[6,0] = "$LocalRepoRoot\Extranet\_Config_IHI\app.ihi.org\web.config"
    $WebConfigs[6,1] = "$ProdServerRoot\ExtranetNG\web.config"

    $WebConfigs[7,0] = "$LocalRepoRoot\Faculty\_Config_IHI\APP.IHI.ORG\web.config"
    $WebConfigs[7,1] = "$ProdServerRoot\Faculty\web.config"

    $WebConfigs[8,0] = "$LocalRepoRoot\ImprovementMap\Admin\_Config_IHI\APP.IHI.ORG\web.config"
    $WebConfigs[8,1] = "$ProdServerRoot\IMAP\IMAPAdmin\web.config"

    $WebConfigs[9,0] = "$LocalRepoRoot\ImprovementMap\Tool\ImprovementMap.Host\_Config_IHI\APP.IHI.ORG\web.config"
    $WebConfigs[9,1] = "$ProdServerRoot\IMAP\Tool\web.config"

    $WebConfigs[10,0] = "$LocalRepoRoot\LeadRetrieval\_Config_LeadRetrievalWebServices_IHI\APP.IHI.ORG\web.config"
    $WebConfigs[10,1] = "$ProdServerRoot\LeadRetrieval\web.config"

    $WebConfigs[11,0] = "$LocalRepoRoot\LMS\_Config_IHI\APP.IHI.ORG\web.config"
    $WebConfigs[11,1] = "$ProdServerRoot\LMS\web.config"

    $WebConfigs[12,0] = "$LocalRepoRoot\ResourcePortal\_Config_IHI\app.ihi.org\web.config"
    $WebConfigs[12,1] = "$ProdServerRoot\ResourcePortal\web.config"

    $WebConfigs[13,0] = "$LocalRepoRoot\SecurityServices\_Config_IHI\APP.IHI.ORG\web.config"
    $WebConfigs[13,1] = "$ProdServerRoot\SecurityServices\web.config"

    $WebConfigs[14,0] = "$LocalRepoRoot\SurveyCenter\_Config_IHI\app.ihi.org\web.config"
    $WebConfigs[14,1] = "$ProdServerRoot\SurveyCenter\web.config"

    $WebConfigs[15,0] = "$LocalRepoRoot\TAD\TADApp.Host\_Config_IHI\APP.IHI.ORG\web.config"
    $WebConfigs[15,1] = "$ProdServerRoot\TAD\web.config"

    $WebConfigs[16,0] = "$LocalRepoRoot\Timesheet\_Config_IHI\app.ihi.org\web.config"
    $WebConfigs[16,1] = "$ProdServerRoot\Timesheet\web.config"

    $WebConfigs[17,0] = "$LocalRepoRoot\IHITV\Host\_Config_IHI\APP.IHI.ORG\web.config"
    $WebConfigs[17,1] = "$ProdServerRoot\TV\web.config"

    $WebConfigs[18,0] = "$LocalRepoRoot\Workspace\_Config_IHI\app.ihi.org\web.config"
    $WebConfigs[18,1] = "$ProdServerRoot\Workspace\web.config"
    #endregion

    #region Loop through each web.config set and if files are accessible, open in diff
    for ($i = 0; $i -lt $TotalCompares; $i++) {
      if ($false -eq (Test-Path -Path $WebConfigs[$i,0])) {
        "Not found; skipping set: " + $WebConfigs[$i,0]
      } elseif ($false -eq (Test-Path -Path $WebConfigs[$i,1])) {
        "Not found; skipping set: " + $WebConfigs[$i,1]
      } else {
        # both files are accessible, open in diff viewer
        Open-IHIDiffViewer $WebConfigs[$i,0] $WebConfigs[$i,1]
        Start-Sleep -Seconds 3
      }
    }
    #endregion
  }
}
Export-ModuleMember -Function Compare-IHIProdWebConfigsLocal
#endregion


#region Functions: Get-IHIFunctions

<#
.SYNOPSIS
Gets name/synopsis of IHI functions, grouped & with alias
.DESCRIPTION
Gets name and synopsis of all IHI functions, grouped and with alias.  
Function will not appear in this list if it does not have a synopsis defined.
.EXAMPLE
Get-IHIFunctions
Returns names and synopsis of all IHI functions
#>
function Get-IHIFunctions {
  [CmdletBinding()]
  param()
  process {
    ""
    $IhiModule = Get-Module IHI
    # Loop through all modules but skip Ihi.PowerShell.IhiDrive
    $IhiModule.NestedModules | Where-Object { $_.Name -ne "Ihi.PowerShell.IhiDrive" } | ForEach-Object {
      "`n" + $_.Name
      "-" * 20
      # get the commands to display
      $Commands = $_.ExportedCommands.Keys | Sort-Object
      $Commands | ForEach-Object {
        # create empty object
        $Cmd = 0 | Select Name,Alias,Description
        $Cmd.Name = $_
        # unfortunately, searching for aliases the fast, efficient way causes errors
        # so we have to suppress them and clear out errors afterwards
        $Alias = $null
        $Alias = Get-Alias -Definition $_ -ErrorAction SilentlyContinue
        if ($Alias -ne $null) {
          $Cmd.Alias = $Alias.Name
        }
        # because we have a function named Write-Host, we have to specify that we want the help from the
        # function, not the cmdlet, when we fetch the particular 'command' help
        if ($Cmd.Name -eq 'Write-Host') {
          $Cmd.Description = (Get-Help $Cmd.Name -Category Function).Synopsis
        } else {
          $Cmd.Description = (Get-Help $Cmd.Name).Synopsis
        }
        # return object to pipeline
        $Cmd
      }

    } | Format-Table -AutoSize -HideTableHeaders
    #clear out errors generated when looking for aliases
    $global:Error.Clear()
    "`nFor more information, type: Get-Help <function name>"
    ""
  }
}
Export-ModuleMember -Function Get-IHIFunctions
New-Alias -Name "ihifunctions" -Value Get-IHIFunctions
Export-ModuleMember -Alias "ihifunctions"
#endregion


#region Functions: Open-IHIReleasesFolder

<#
.SYNOPSIS
Opens the build releases folder in Explorer
.DESCRIPTION
Opens the build releases folder in Explorer
.EXAMPLE
Open-IHIReleasesFolder
Open releases folder \\ENGBUILD.IHI.COM\Releases in Explorer
#>
function Open-IHIReleasesFolder {
  [CmdletBinding()]
  param()
  process {
    # need to make sure user is on a FileSystem provider drive or Invoke-Item may not work; 
    # so store current location, change, invoke then return to location
    Push-Location -Path .
    Set-Location c:\
    Invoke-Item $Ihi:BuildDeploy.ReleasesFolder
    Pop-Location
  }
}
Export-ModuleMember -Function Open-IHIReleasesFolder
New-Alias -Name "rel" -Value Open-IHIReleasesFolder
Export-ModuleMember -Alias "rel"
#endregion


#region Functions: Search-IHIModuleFunctions

<#
.SYNOPSIS
Search IHI functions for text
.DESCRIPTION
No-frills function so search IHI module exported functions for text.
.PARAMETER SearchTerm
Term to search for
.PARAMETER DisplayLineRange
Surrounding line range to show (plus or minus DisplayLineRange)
.EXAMPLE
Search-IHIModuleFunctions asdf
Search IHI module functions in memory for text asdf
#>
function Search-IHIModuleFunctions {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SearchTerm,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [ValidateRange(0,5)]
    [int]$DisplayLineRange = 0
  )
  #endregion
  process {
    # escape basic regular expression values when doing high-level file match
    [string]$SearchTermRegEx = $SearchTerm.Replace("$","\$").Replace("?","\?")
    # need to filter for items where module named IHI (all function not in this file) or
    # where module named Shortcuts (current module name, doesn't appear as IHI from inside module)
    $Functions = Get-ChildItem function: | Where-Object { $_.ModuleName -eq 'IHI' -or $_.ModuleName -eq 'Shortcuts' }
    foreach ($Function in $Functions) {
      if ((Get-Content function:$Function) -match $SearchTermRegEx) {
        Write-Host ""
        $FunctionName = $Function.Name
        Write-Host $FunctionName -ForegroundColor Green
        #region Store function content in temp file
        # must be in file so can use Select-String
        $TempFile = Join-Path -Path $Ihi:Folders.TempFolder -ChildPath $(("{0:yyyyMMdd_HHmmss}" -f (Get-Date)) + ".txt")
        [hashtable]$Params2 = @{ InputObject = $((Get-Content function:$FunctionName).ToString()); FilePath = $TempFile } + $OutFileSettings
        $Err = $null
        Out-File @Params2 -ErrorVariable Err
        if ($? -eq $false) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
          return
        }
        #endregion
        #region Search temp file content and output
        [string[]]$Content = [string[]](Get-Content $TempFile)
        Select-String -Path $TempFile -Pattern $SearchTerm -SimpleMatch | ForEach-Object {
          $MatchingLineIndex = $_.LineNumber - 1
          #region Output lines before match
          for ($i = $DisplayLineRange; $i -gt 0; $i --) {
            $LineIndex = $MatchingLineIndex - $i
            # make sure index is valid before attempting to display
            if ($LineIndex -ge 0) { Write-Host $Content[$LineIndex].Trim() }
          }
          #endregion
          #region Output matching line
          # only match/highlight first instance of term; keep this simple
          $Line = $Content[$MatchingLineIndex].Trim()
          # get index of start of matching text (need ToUpper so not case-sensitive)
          $MatchIndex = $Line.ToUpper().IndexOf($SearchTerm.ToUpper())
          Write-Host $($Line.Substring(0,$MatchIndex)) -NoNewline
          Write-Host $($Line.Substring(($MatchIndex),$SearchTerm.Length)) -ForegroundColor Yellow -NoNewline
          Write-Host $($Line.Substring($MatchIndex + $SearchTerm.Length))
          #endregion
          #region Output lines after match
          for ($i = 1; $i -le $DisplayLineRange; $i++) {
            $LineIndex = $MatchingLineIndex + $i
            # make sure index is valid before attempting to display
            if ($LineIndex -lt ($Content.Length - 1)) { Write-Host $Content[$LineIndex].Trim() }
          }
          #endregion

          Write-Host ""
        }
        #endregion
        # remove temp file
        Remove-Item -Path $TempFile
      }
    }
  }
}
Export-ModuleMember -Function Search-IHIModuleFunctions
New-Alias -Name "sf" -Value Search-IHIModuleFunctions
Export-ModuleMember -Alias "sf"
#endregion


#region Functions: Set-IHIIEHomePage

<#
.SYNOPSIS
Sets the home page for IE; convenient to reset from RNET page
.DESCRIPTION
Sets the home page for IE; convenient to reset from RNET page
.PARAMETER HomePageUri
Path to URL or file
.EXAMPLE
Set-IHIIEHomePage http://www.ihi.org
Sets IE home page to http://www.ihi.org
#>
function Set-IHIIEHomePage {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$HomePageUri
  )
  #endregion
  process {
    Set-ItemProperty "HKCU:\Software\Microsoft\Internet Explorer\Main" -Name "Default_Page_URL" -Value $HomePageUri
    Set-ItemProperty "HKCU:\Software\Microsoft\Internet Explorer\Main" -Name "Start Page" -Value $HomePageUri
  }
}
Export-ModuleMember -Function Set-IHIIEHomePage
#endregion


#region Functions: Show-IHIDriveValues

<#
.SYNOPSIS
Displays all values in Ihi: drive with nice format
.DESCRIPTION
Displays all values in Ihi: drive - walks through all sub-'folders' (hash tables)
to get all values.
.EXAMPLE
Show-IHIDriveValues
Shows values on the ihidrive
#>
function Show-IHIDriveValues {
  [CmdletBinding()]
  param()
  process {
    # get each high-level item in Ihi and process individually
    # high-level items have values that are hash tables but themselves
    # are PSVariables, so can't start at Ihi: root itself

    # also, we want the column 1 width to be the same across all the individual
    # hashtables, so we need to pre-determine what the column 1 width should be
    # (Write-IHIHashtableToHost does this for an individual table with nested tables
    # but we need to determin for several separate - not nested - hashtables)

    # first, determine longest key name across all hash tables
    $MaxKeyNameLength = (Get-ChildItem IHI: | ForEach-Object { $_.value } | Get-IHIHashtableMaxKeyLength | Measure-Object -Maximum).Maximum
    # next, determine maximum depth
    $MaxTableDepth = (Get-ChildItem IHI: | ForEach-Object { $_.value } | Get-IHIHashtableMaxDepth | Measure-Object -Maximum).Maximum
    # assume one level deeper because these hashtables are already down a level
    $MaxTableDepth += 1
    # figure out column1 width
    # - need to know the indent level (which is the max depth)
    # - assume prefix padding is 2 spaces (thus the * 2)
    # - then add the length of the longest entry
    # - then add 2 more as space between the value and the next column
    $Column1Width = $MaxKeyNameLength + (($MaxTableDepth) * 2) + 2
    Get-ChildItem Ihi: | Sort Name | ForEach-Object {
      Write-Host $_.Name
      Write-IHIHashtableToHost -Object $_.value -Indent 1 -KeyColumnWidthMax $Column1Width
    }
  }
}
Export-ModuleMember -Function Show-IHIDriveValues
New-Alias -Name "ihidrive" -Value Show-IHIDriveValues
Export-ModuleMember -Alias "ihidrive"
#endregion

#region Functions: Show-WindowsUpdates
<#
.SYNOPSIS
Displays the most recent installed Windows Updates
.DESCRIPTION
Displays the most recent successfully installed Windows Updates, 
it checks the install log on the local server and displays the recent 
updates to be able to check updates between servers
.EXAMPLE
Show-WindowsUpdates
Shows recent Windows updates
#>
Function Show-WindowsUpdates {
  [CmdletBinding()]
  param()
  process {
    Get-Content $env:windir\windowsupdate.log -encoding utf8 |
      Where-Object { $_ -like '*successfully installed*'} |
        Foreach-Object {
          $infos = $_.Split("`t");
          $result = @{};
          $result.Date = [DateTime]$infos[6].Remove($infos[6].LastIndexOf(":"));
          $result.Product = $infos[-1].SubString($infos[-1].LastIndexOf(":")+2);
          New-Object PSobject -property $result
        }
  }
}
Export-ModuleMember -Function Show-WindowsUpdates
New-Alias -Name "winupdates" -Value Show-WindowsUpdates
Export-ModuleMember -Alias "winupdates"
#endregion

#region Functions: Show-TestBrowsers
<#
.SYNOPSIS
Displays a list of servers and their available browsers 
.DESCRIPTION
Displays a list of servers that can be used for testing different browsers
on different environments
.EXAMPLE
Show-TestBrowsers
#>
Function Show-TestBrowsers {
}
#endregion