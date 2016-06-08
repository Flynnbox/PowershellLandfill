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


#region Functions: Install-IHIEmailDiffLink

<#
.SYNOPSIS
Makes registry changes to support email diff change links.
.DESCRIPTION
Makes registry changes to support email diff change links.  These are
one-time registry changes allow a user to click on a diff link that opens
a diff viewer (i.e. Exam Diff) between the old and new versions of a 
recently edited file.
.EXAMPLE
Install-IHIEmailDiffLink
<no output, creates registry settings>
#>
function Install-IHIEmailDiffLink {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    #region IHIDiff description
    # These registry changes add a IHIDiff hyperlink type to the developer's
    # machine.  Once installed, the user can receive an email that contains HTML like this:
    #  <a href="IHIDiff:@http://ENGBUILD.IHI.COM/svn/ihi_main/trunk/PowerShell3/Main/BuildDeploy/Configs/ServerSetup/PowerShell.xml@10669@END">Diff</a>
    # When this link is clicked, the IHIDiff registration causes a local batch file
    # to be run with the value after : to be passed to it.  The batch file that is run
    # is specified under IHIDiff\shell\open\command
    # The complete registry tree created by these commands looks like:
    # HKLM:\SOFTWARE\Classes\
    #   IHIDiff
    #     "default"      property value "URL:IHIDiff Protocol"
    #     "URL Protocol" property value ""
    #   IHIDiff\shell
    #   IHIDiff\shell\open
    #   IHIDiff\shell\open\command
    #     "default"      property value
    #       '"C:\IHI_MAIN\trunk\PowerShell\Main\BuildDeploy\Utilities\Diff-FileChangesInRepository.bat" "%1"'
    #endregion

    # only run these registry steps if not a server
    if (!(Test-IHIIsIHIServer)) {
      # not admin error message
      [string]$NotAdminErrorMessage = "The registry changes required for email diff links are not configured on this machine; please reopen PowerShell as an Administrator and they will be made."

      # check if base key IHIDiff exists
      if ($false -eq (Test-Path -Path "HKLM:\SOFTWARE\Classes\IHIDiff")) {
        if ($false -eq (Test-IHIIsShellAdministrator)) {
          Write-Host $NotAdminErrorMessage -ForegroundColor Cyan; return
        } else {
          New-Item -Path "Registry::HKEY_CLASSES_ROOT\IHIDiff" -Value "URL:IHIDiff Protocol" > $null
        }
      }

      # check if URL Protocol property exists on IHIDiff key
      $Key = Get-Item -Path "HKLM:\SOFTWARE\Classes\IHIDiff"
      if ((($Key.GetValue("URL Protocol")) -eq $null) -or
        (($Key.GetValue("URL Protocol")) -ne "")) {
        if ($false -eq (Test-IHIIsShellAdministrator)) {
          Write-Host $NotAdminErrorMessage -ForegroundColor Cyan; return
        } else {
          New-ItemProperty -Path Registry::HKEY_CLASSES_ROOT\IHIDiff -Name "URL Protocol" -PropertyType String -Value "" > $null
        }
      }

      # check if key IHIDiff\shell exists
      if ($false -eq (Test-Path -Path HKLM:\SOFTWARE\Classes\IHIDiff\shell)) {
        if ($false -eq (Test-IHIIsShellAdministrator)) {
          Write-Host $NotAdminErrorMessage -ForegroundColor Cyan; return
        } else {
          New-Item -Path "Registry::HKEY_CLASSES_ROOT\IHIDiff\shell" > $null
        }
      }

      # check if key IHIDiff\shell\open exists
      if ($false -eq (Test-Path -Path HKLM:\SOFTWARE\Classes\IHIDiff\shell\open)) {
        if ($false -eq (Test-IHIIsShellAdministrator)) {
          Write-Host $NotAdminErrorMessage -ForegroundColor Cyan; return
        } else {
          New-Item -Path "Registry::HKEY_CLASSES_ROOT\IHIDiff\shell\open" > $null
        }
      }

      # check if key IHIDiff\shell\open\command exists
      if ($false -eq (Test-Path -Path HKLM:\SOFTWARE\Classes\IHIDiff\shell\open\command)) {
        if ($false -eq (Test-IHIIsShellAdministrator)) {
          Write-Host $NotAdminErrorMessage -ForegroundColor Cyan; return
        } else {
          New-Item -Path "Registry::HKEY_CLASSES_ROOT\IHIDiff\shell\open\command" > $null
        }
      }

      # check if default property exists on key IHIDiff\shell\open\command
      [string]$OpenCommandRegValue = '"C:\IHI_MAIN\trunk\PowerShell\Main\BuildDeploy\Utilities\Diff-FileChangesInRepository.bat" "%1"'

      # this is real annoying; if checking the property value and the shell
      # is running as an administrator, you need to use .GetValue in order
      # to test the key value; if not running as admin, you need to use dot notation.
      # Otherwise it will not work.
      if ($true -eq (Test-IHIIsShellAdministrator)) {
        $Key = Get-Item -Path "HKLM:\SOFTWARE\Classes\IHIDiff\shell\open\command"
        if ((($Key.GetValue("(default)")) -eq $null) -or
          (($Key.GetValue("(default)")) -ne $OpenCommandRegValue)) {
          # does exist, set to new value
          Set-ItemProperty -Path "HKLM:\SOFTWARE\Classes\IHIDiff\shell\open\command" -Name "(default)" -Value $OpenCommandRegValue > $null
        }
      } else {
        $Key = Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\IHIDiff\shell\open\command"
        if ((($Key."(default)") -eq $null) -or
          (($Key."(default)") -ne $OpenCommandRegValue)) {
          Write-Host $NotAdminErrorMessage -ForegroundColor Cyan; return
        }
      }
    }
  }
}
Export-ModuleMember -Function Install-IHIEmailDiffLink
#endregion
