
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


#region Functions: Get-IHIAppPathFromRegistryKey

<#
.SYNOPSIS
Retrieves an application path from a registry key/structure
.DESCRIPTION
Attempts to retrieve an application path from a registry key/structure.
This function can be used to briefly search a registry structure in 
search of a path for an executable.  As each application stores its 
information in the registry in a slightly different way (joy), we need a
simple way of trying to get the value.
Call Get-IHIAppPathFromRegistryKey with the registry path and the Value name
 - tests if registry path exists
 - if it exists, the ValueName value is checked (checks multiple values as necessary)
 - if there is a value for a path, check that it exists in the filesystem
 - if so, return file system path otherwise return $null
$null ultimately means it's not installed, not available, not usable...
.PARAMETER RegistryPath
Registry path to check
.PARAMETER ValueNames
Names of keys to check
.EXAMPLE
Get-IHIAppPathFromRegistryKey "HKCU:Software\PrestoSoft\ExamDiff Pro" "ExePath"
Returns exe file path for ExamDiff Pro, if installed
#>
function Get-IHIAppPathFromRegistryKey {
  [CmdletBinding()]
  param([string]$RegistryPath,[string[]]$ValueNames = ("(default)","ExePath"))
  process {
    # the path to the application - if it exists on machine; if it doesn't, return null
    $ApplicationPath = $null
    # only continue if key exists in registry
    if (Test-Path -Path $RegistryPath) {
      # loop through ValueNames, checking for a valid value; if there are multiple entries
      # in ValuesNames and multiple ones have values, it takes the first one
      $ValueNames | ForEach-Object {
        # only take value from Value if not set yet
        if ($ApplicationPath -eq $null) {
          # you have to be careful about how you check for properties on a registry key
          # if you try Get-ItemProperty and it doesn't exist, it throws an error
          # we can swallow this error with a try/catch but the error will still end up
          # in the $Error collection and we don't want that because we check $Error at
          # the end of the script, looking for unhandled exceptions
          # so a safer way to check if the property exists without throwing an error
          # is to 'get' the key, check if the Property NoteProperty exists - which contains
          # a string array of properties - and if that array contains the name itself
          $RegistryKey = Get-Item $RegistryPath
          if ($RegistryKey.Property -ne $null -and $RegistryKey.Property -contains $_) {
            $ApplicationPath = (Get-ItemProperty $RegistryPath).$_
          }
        }
      }
      # only attempt to get if ApplicationPath was found
      if ($ApplicationPath -ne $null) {
        #region Sanitize value of ApplicationPath
        # if value was actually an entry in Class\Applications\..\shell\edit\command path
        # such as the value of:
        #  "HKLM:\SOFTWARE\Classes\Applications\ScriptEditor.exe\shell\edit\command".(default)
        # which is: 
        #  "C:\Program Files (x86)\PowerGUI\ScriptEditor.exe" "%1"
        # we want just the first value, without the quotes
        if ($ApplicationPath.Contains(' "%1"')) {
          # ignore first quote, find .exe" and remove everything after 
          $ApplicationPath = $ApplicationPath.Substring(1,$ApplicationPath.IndexOf('.exe"') + 3)
        }
        #endregion

        # now expand the path to the full name - in case stored as 8.3 format (some are)
        $ApplicationPath = (Get-Item $ApplicationPath).FullName
        # last, confirm executable exists: if not found, reset $ApplicationPath to $null
        if (!(Test-Path -Path $ApplicationPath)) {
          $ApplicationPath = $null
        }
      }
    }
    # return value (or null)
    $ApplicationPath
  }
}
Export-ModuleMember -Function Get-IHIAppPathFromRegistryKey
#endregion
