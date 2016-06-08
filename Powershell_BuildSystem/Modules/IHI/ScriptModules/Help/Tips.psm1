
#region Functions: Get-IHITip, Write-IHITip

<#
.SYNOPSIS
Gets a tip about the PowerShell module framework
.DESCRIPTION
Gets a tip about the PowerShell module framework. Specify -All to get all tips.
.PARAMETER All
If specified, returns all tips.
.EXAMPLE
Get-IHITip
Returns a tip
#>
function Get-IHITip {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $true)]
    [switch]$All
  )
  #endregion
  process {
    # get path to tip file; located in Help folder ScriptModules
    [string]$TipXmlFilePath = Join-Path -Path $Ihi:Folders.PowerShellModuleMainFolder -ChildPath "Modules\IHI\ScriptModules\Help\Tips.xml"
    # make sure file exists and is valid
    if ($false -eq (Test-Path -Path $TipXmlFilePath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: tips xml path not valid: $TipXmlFilePath"
      return
    }
    if ($false -eq (Test-Xml -LiteralPath $TipXmlFilePath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: tips xml content not valid xml; please fix: $TipXmlFilePath"
      return
    }
    # get the tips from the xml
    $Tips = ([xml](Get-Content $TipXmlFilePath)).Tips.Tip
    # if user wants all, return all else return a random one
    # write function like this so easy to add a count later
    $TipsToShow = $null
    if ($All) {
      $TipsToShow = $Tips
    } else {
      $TipsToShow = $Tips | Get-Random
    }
    # replace NEWLINE with actual new line character
    $TipsToShow = $TipsToShow | ForEach-Object { $_.Replace("NEWLINE","`n") }
    $TipsToShow
  }
}
Export-ModuleMember -Function Get-IHITip


<#
.SYNOPSIS
Displays a tip about the PowerShell module framework in the host
.DESCRIPTION
Displays a tip about the PowerShell module framework in the host.
Specify -All to get all tips.
.PARAMETER All
If specified, writes all tips
.EXAMPLE
Write-IHITip
Writes a random tip
.EXAMPLE
Write-IHITip -All
Writes all tips
#>
function Write-IHITip {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $true)]
    [switch]$All
  )
  #endregion
  process {
    # get the tip or tips
    $TipsToShow = Get-IHITip -All:$All
    # now display
    $TipsToShow | ForEach-Object {
      Write-Host ""
      Write-Host "Tip: $_" -ForegroundColor Yellow
      Write-Host ""
    }
  }
}
Export-ModuleMember -Function Write-IHITip
New-Alias -Name "tip" -Value Write-IHITip
Export-ModuleMember -Alias "tip"

#endregion

#region Function: Get-Excuse
<#
.SYNOPSIS
Displays an excuse from the BOFH Excuse Generator
.DESCRIPTION
Displays an excuse from the BOFH Excuse Generator
.EXAMPLE
Get-Excuse
Writes a random excuse from the BOFH Excuse Generator
.EXAMPLE
excuse
Writes a random excuse from the BOFH Excuse Generator
#>
function Get-Excuse
{
  $url = 'http://pages.cs.wisc.edu/~ballard/bofh/bofhserver.pl'
  $ProgressPreference = 'SilentlyContinue'
  $page = Invoke-WebRequest -Uri $url -UseBasicParsing
  $pattern = '<br><font size = "\+2">(.+)'

  if ($page.Content -match $pattern)
  {
    $matches[1]
  }
}
Export-ModuleMember -Function Get-Excuse
New-Alias -Name "excuse" -Value Get-Excuse
Export-ModuleMember -Alias "excuse"
#endregion

#region Function: Get-ModulesList
<#
.SYNOPSIS
Displays the installed modules in the local environment
.DESCRIPTION
Displays the installed modules in the local environment
.EXAMPLE
Get-Module -ListAvailable -Refresh
The original command, that the alias just calls
.EXAMPLE
modules
Displays the installed modules in the local environment
#>
function Get-ModulesList
{
   Get-Module -ListAvailable -Refresh
}
Export-ModuleMember -Function Get-ModulesList
New-Alias -Name "modules" -Value Get-ModulesList
Export-ModuleMember -Alias "modules"
#endregion