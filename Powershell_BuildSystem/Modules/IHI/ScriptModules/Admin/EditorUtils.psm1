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


#region Functions: Get-IHITextPadSyntaxInfo

<#
.SYNOPSIS
Gets information to use TextPad IHI XML/PS syntax highlighting
.DESCRIPTION
Returns names of all IHI functions, all function parameters (IHI and PS)
and all variables defined in application configuration files to add to
TextPad syntax files.
.EXAMPLE
Get-IHITextPadSyntaxInfo
Outputs information about IHI modules framework for TextPad syntax file.
#>
function Get-IHITextPadSyntaxInfo {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {

    "`nThis information should be added TextPad syntax file located at:"
    "  /trunk/PowerShell/Development/Tools/TextPadSyntaxHighlight/IhiAppConfigXml.syn"

    "`n`nIHI functions"
    "In the syntax file, add this information to the section that begins with: ;;; ihifunctions"
    Get-Command -Module IHI -CommandType Function | Select -ExpandProperty Name 
	# Get-PropertyValue Name

    "`n`nIHI aliases"
    "In the syntax file, add this information to the section that begins with: ;;; aliases in ihifunctions"
    Get-Command -Module IHI -CommandType Alias | Select -ExpandProperty Name
	# Get-PropertyValue Name

    "`n`nParameters for all functions"
    "In the syntax file, add this information to the section that begins with: [Keywords 4] ;;; Cmdlet and function parameters"
    $Params = Get-Command -CommandType Function | ForEach-Object { $_.Parameters.Keys }
    $Params = $Params | Select-Object -Unique | Sort
    # output params with - in front
    $Params | ForEach-Object { "-" + $_ }

    "`n`nVariables used in IHI application configs"
    "In the syntax file, add this information to the section that begins with: ;;; IHI variables"
    # get all configuration files
    $Files = Get-ChildItem -Path $Ihi:BuildDeploy.ApplicationConfigsRootFolder -Include *.xml -Recurse
    # for each file, search through content for regular expression matching PowerShell variable notation
    # but no methods or properties off the object
    $MatchPS = $null
    $Files | ForEach-Object {
      $File = $_
      $Content = Get-Content $File
      $Content | ForEach-Object {
        $Line = $_
        if ($Line -match '(\$[^. =;"<\[\(]+)') {
          $MatchPS += $matches.Values
        }
      }
    }
    # clean out and sort duplicates
    $MatchPS = $MatchPS | Select-Object -Unique | Sort
    # dump out items that don't start with $script:
    $MatchPS | Where-Object { $_ -notmatch '\$script:' }
    # dump out items that start with $script:
    $MatchPS | Where-Object { $_ -match '\$script:' }
  }
}
Export-ModuleMember -Function Get-IHITextPadSyntaxInfo
#endregion
