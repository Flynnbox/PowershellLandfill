
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


#region Functions: Convert-IHIEncryptConfigSection

<#
.SYNOPSIS
Encrypts a config file section using the local machine key
.DESCRIPTION
Encrypts a config file section using the local machine key.  Use .NET 2.0
and RsaProtectedConfigurationProvider by default.
.PARAMETER Path
Path of application configuration file
.PARAMETER SectionName
Name of section to encrypt
.PARAMETER DotNetVersionId
ID of .NET version; this is a value of a branch under $Ihi:Applications.DotNet,
i.e. V20 or V40
.PARAMETER Provider
Encryption provider
.EXAMPLE
Convert-IHIEncryptConfigSection -Path c:\temp\web.config -SectionName appSettings -DotNetVersionId V20
Encrypts the appSettings section in c:\temp\web.config using the .NET 2.0 tool
.EXAMPLE
Convert-IHIEncryptConfigSection -Path c:\temp\web.config -SectionName appSettings -DotNetVersionId V20 -Provider RsaProtectedConfigurationProvider
Encrypts the appSettings section in c:\temp\web.config using the .NET 2.0 tool
#>
function Convert-IHIEncryptConfigSection {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [Alias("FullName")]
    [string]$Path,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string]$SectionName = $null,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$DotNetVersionId = "V20",
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$Provider = "RsaProtectedConfigurationProvider"
  )
  #endregion
  process {
    #region Parameter validation
    #region Make sure source Path exists
    if ($false -eq (Test-Path -Path $Path)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: source Path does not exist: $($Path)"
      return
    }
    #endregion

    #region Make sure DotNetfVersionId is valid
    # The DotNetVersionId is a value of a branch under $Ihi:Applications.DotNet, i.e. V20 or 
    # V40.  This tells the function which version of the utility to use.
    # Make sure this value is correct
    if ($Ihi:Applications.DotNet.Keys -notcontains $DotNetVersionId) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: $DotNetVersionId is not valid; correct values are: $($Ihi:Applications.DotNet.Keys)"
      return
    }
    #endregion

    #region Get utility based on .NET version and confirm exists
    [string]$UtilityPath = $Ihi:Applications.DotNet.$DotNetVersionId.AspNet_regiis
    if ($UtilityPath -eq $null -or !(Test-Path -Path $UtilityPath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path for AspNet_regiis.exe is null or bad: $UtilityPath"
      return
    }
    #endregion
    #endregion

    #region Report information before processing file
    # rather than use PSBoundParameters, manually output for better formatting
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Path",$Path)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "SectionName",$SectionName)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "DotNetVersionId",$DotNetVersionId)
    Remove-IHILogIndentLevel
    #endregion

    #region Run utility and check for error
    [string]$Cmd = $UtilityPath
    # Strangely, AspNet_regiis does not want the exact path to the file, but the parent folder
    # path.  That's pretty dumb if you ask me.
    [string]$ParentPath = Split-Path -Path $Path -Parent
    [string[]]$Params = "-pef",$SectionName,$ParentPath,"-prov",$Provider
    # unfortunately, AspNet_regiis -pef doesn't return an error exit code if it fails
    # need to parse result text looking for "Failed!"
    Write-Host "Encrypting configuration section..."
    $Results = & $Cmd $Params 2>&1
    if ($Results -match "Failed!") {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred encrypting section $SectionName in file $Path"
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Command: $("$Cmd $Params")"
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: $("$Results")"
      return
    } else {
      Write-Host "Processing complete."
    }
    #endregion
  }
}
Export-ModuleMember -Function Convert-IHIEncryptConfigSection
#endregion
