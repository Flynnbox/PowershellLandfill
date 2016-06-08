
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


#region Functions: Open-IHIDiffViewer

<#
.SYNOPSIS
Opens diff viewer for two files
.DESCRIPTION
Opens diff viewer for two files using application defined in
$Ihi:Applications.Editor.DiffViewer
.PARAMETER Path1
First file to open
.PARAMETER Path2
Second file to open
.EXAMPLE
Open-IHIDiffViewer -Path1 C:\file1.txt -Path2 C:\file2.txt
Opens diff viewer between file1.txt and file2.txt
#>
function Open-IHIDiffViewer {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Path1,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Path2
  )
  #endregion
  process {
    if ($Ihi:Applications.Editor.DiffViewer -eq $null -or !(Test-Path -Path $Ihi:Applications.Editor.DiffViewer)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path for diff viewer is null or bad: $($Ihi:Applications.Editor.DiffViewer)"
      return
    }
    if (!(Test-Path -Path $Path1)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path for File1 does not exist: $Path1"
      return
    }
    if (!(Test-Path -Path $Path2)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path for File2 does not exist: $Path2"
      return
    }
    # open diff viewer and check for error
    [string]$Cmd = $Ihi:Applications.Editor.DiffViewer
    [string[]]$Params = $Path1,$Path2
    $LastExitCode = 0
    $Results = & $Cmd $Params 2>&1
    if ($LastExitCode -ne 0) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred opening diff viewer"
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Command: $("$Cmd $Params")"
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: $("$Results")"
      return
    }
  }
}
Export-ModuleMember -Function Open-IHIDiffViewer
New-Alias -Name "dif" -Value Open-IHIDiffViewer
Export-ModuleMember -Alias "dif"
#endregion


#region Functions: Open-IHIInternetExplorer

<#
.SYNOPSIS
Opens Internet Explorer for the particular url(s)
.DESCRIPTION
Opens Internet Explorer for the particular url(s). IE path is defined in:
$Ihi:Applications.Miscellaneous.InternetExplorer
.PARAMETER Url
Url to open
.EXAMPLE
Open-IHIInternetExplorer http://www.ihi.org
Opens IE to http://www.ihi.org
#>
function Open-IHIInternetExplorer {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [Alias("FullName")]
    [string]$Url
  )
  #endregion
  process {
    if ($Ihi:Applications.Miscellaneous.InternetExplorer -eq $null -or !(Test-Path -Path $Ihi:Applications.Miscellaneous.InternetExplorer)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path for Internet Explorer is null or bad: $($Ihi:Applications.Miscellaneous.InternetExplorer)"
      return
    }
    # open IE and check for error
    [string]$Cmd = $Ihi:Applications.Miscellaneous.InternetExplorer
    $Params = $Url
    $LastExitCode = 0
    $Results = & $Cmd $Params 2>&1
    if ($LastExitCode -ne 0) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred opening IE"
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Command: $("$Cmd $Params")"
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: $("$Results")"
      return
    }
  }
}
Export-ModuleMember -Function Open-IHIInternetExplorer
New-Alias -Name "ie" -Value Open-IHIInternetExplorer
Export-ModuleMember -Alias "ie"
#endregion


#region Functions: Open-IHIPowerShellEditor

<#
.SYNOPSIS
Opens PowerShell editor for file specified in param or pipeline
.DESCRIPTION
Opens Powershell editor - accepts via param or pipeline.  If neither specified
will check contents of clipboard.  PowerShell editor is defined at 
$Ihi:Applications.Editor.PowerShellEditor
.PARAMETER Path
Path of file to open
.EXAMPLE
Open-IHIPowerShellEditor -Path c:\MyScript.ps1
Opens PowerShell editor (PowerGUI or ISE) for file c:\MyScript.ps1
.EXAMPLE
dir -Filter *.ps1 | Open-IHIPowerShellEditor
Opens all .ps1 files as current location in PowerShell editor (PowerGUI or ISE)
#>
function Open-IHIPowerShellEditor {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [Alias("FullName")]
    [string]$Path = $null
  )
  #endregion
  begin {
    # if PowerGUI isn't open when this runs, it's slow starting up the first time so
    # it needs an additional delay
    [bool]$StartUpDelay = $false
    if ((Get-Process | Where-Object { $_.Name -eq 'ScriptEditor' }) -eq $null) {
      $StartUpDelay = $true
    }
  }
  process {
    if ($Ihi:Applications.Editor.PowerShellEditor -eq $null -or !(Test-Path -Path $Ihi:Applications.Editor.PowerShellEditor)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path for PowerShell editor is null or bad: $($Ihi:Applications.Editor.PowerShellEditor)"
      return
    }
    if ($Path -eq $null -or ($Path -ne $null -and $Path.Trim() -eq "")) {
      $Clip = Get-Clipboard
      # if clipboard is a string array, re-run Open-IHIPowerShellEditor by 
      # passing in string array into pipeline (to process each string individually)
      [string]$ClipTypeName = $Clip.GetType().Name
      if ($ClipTypeName -eq "String[]") {
        $Clip | Open-IHIPowerShellEditor
        return
        # if clipboard is a string that contains new lines, convert to string array
        # and call Open-IHIPowerShellEditor again via pipeline like above
      } elseif ($ClipTypeName -eq "String") {
        $Clip.Replace("`r","").Split("`n") | Open-IHIPowerShellEditor
        return
        # else convert clipboard to string and set Path to be opened like normal below
      } else {
        # treat clipboard contents as string
        $Path = $Clip.ToString()
      }
    }
    # make sure file exists, if does, open, if not, display message
    if ($Path -ne $null -and $Path.Trim() -ne "") {
      if (Test-Path -Path $Path) {
        # open PowerShell editor and check for error
        [string]$Cmd = $Ihi:Applications.Editor.PowerShellEditor
        $Params = $Path
        $LastExitCode = 0
        $Results = & $Cmd $Params 2>&1
        if ($LastExitCode -ne 0) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred opening PowerShell editor"
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: Command: $("$Cmd $Params")"
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: $("$Results")"
          return
        }
        # if first opening editor, additional pause
        if ($StartUpDelay -eq $true) {
          Start-Sleep -Seconds 2
          # but no need to run again
          $StartUpDelay = $false
        }
        # always pause at least one second between files to catch up
        Start-Sleep -Seconds 1
      } else {
        Write-Host "File not found: $Path"
      }
    }
  }
}
Export-ModuleMember -Function Open-IHIPowerShellEditor
New-Alias -Name "pse" -Value Open-IHIPowerShellEditor
Export-ModuleMember -Alias "pse"
#endregion


#region Functions: Open-IHITextEditor

<#
.SYNOPSIS
Opens text editor for file specified in param or pipeline
.DESCRIPTION
Opens text editor - accepts via param or pipeline.  If neither specified
will check contents of clipboard.  Text editor is defined at 
$Ihi:Applications.Editor.TextEditor
.PARAMETER Path
Path of file to open
.EXAMPLE
Open-IHITextEditor -Path c:\temp\file1.txt
Opens file c:\temp\file1.txt in text editor
#>
function Open-IHITextEditor {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [Alias("FullName")]
    [string]$Path = $null
  )
  #endregion

  begin {
    # if texteditor isn't open when this runs, it's slow starting up the first time so
    # it needs an additional delay
    [bool]$StartUpDelay = $false
    if ($Ihi:Applications.Editor.TextEditor -ne $null -and (Test-Path -Path $Ihi:Applications.Editor.TextEditor)) {
      # get application name
      [string]$AppName = Split-Path $Ihi:Applications.Editor.TextEditor -Leaf
      # remove extension
      $AppName = $AppName.Substring(0,$AppName.IndexOf("."))
      if ((Get-Process | Where-Object { $_.Name -eq $AppName }) -eq $null) {
        $StartUpDelay = $true
      }
    }
  }
  process {
    if ($Ihi:Applications.Editor.TextEditor -eq $null -or !(Test-Path -Path $Ihi:Applications.Editor.TextEditor)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path for text editor is null or bad: $($Ihi:Applications.Editor.TextEditor)"
      return
    }
    if ($Path -eq $null -or ($Path -ne $null -and $Path.Trim() -eq "")) {
      $Clip = Get-Clipboard
      # if clipboard is a string array, re-run Open-IHITextEditor by 
      # passing in string array into pipeline (to process each string individually)
      [string]$ClipTypeName = $Clip.GetType().Name
      if ($ClipTypeName -eq "String[]") {
        $Clip | Open-IHITextEditor
        return
        # if clipboard is a string that contains new lines, convert to string array
        # and call Open-IHITextEditor again via pipeline like above
      } elseif ($ClipTypeName -eq "String") {
        $Clip.Replace("`r","").Split("`n") | Open-IHITextEditor
        return
        # else convert clipboard to string and set Path to be opened like normal below
      } else {
        # treat clipboard contents as string
        $Path = $Clip.ToString()
      }
    }
    # make sure file exists, if does, open, if not, display message
    if ($Path -ne $null -and $Path.Trim() -ne "") {
      if (Test-Path -Path $Path) {
        # open text editor and check for error
        [string]$Cmd = $Ihi:Applications.Editor.TextEditor
        $Params = $Path
        $LastExitCode = 0
        $Results = & $Cmd $Params 2>&1
        if ($LastExitCode -ne 0) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred opening text editor"
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: Command: $("$Cmd $Params")"
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: $("$Results")"
          return
        }
        # if first opening editor, additional pause
        if ($StartUpDelay -eq $true) {
          Start-Sleep -Seconds 3
          # but no need to run again
          $StartUpDelay = $false
        }
        # always pause at least one second between files to catch up
        Start-Sleep -Seconds 1
      } else {
        Write-Host "File not found: $Path"
      }
    }
  }
}
Export-ModuleMember -Function Open-IHITextEditor
New-Alias -Name "t" -Value Open-IHITextEditor
Export-ModuleMember -Alias "t"
#endregion
