#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
    # when writing name/value pairs, width of first column
    [int]$script:DefaultCol1Width = 20
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


#region Functions: Invoke-IHIClickOnceMapFileExtensions

<#
.SYNOPSIS
Updates ClickOnce deployment to rename files and alters manifect
.DESCRIPTION
Updates ClickOnce deployment to rename files with a .deploy extension and alters
the application manifect to map file extensions
.PARAMETER ManifestFolder
Path to folder containing files to ClickOnce deploy
.PARAMETER ApplicationFile
ClickOnce Application XML file
.EXAMPLE
Invoke-IHIClickOnceMapFileExtensions -ManifestFolder c:\bin -ApplicationFile Ihi.LeadRetrieval.Client.application
Gives files .deploy extension, alters ApplicationFile
#>
function Invoke-IHIClickOnceMapFileExtensions {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ManifestFolder,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationFile
  )
  #endregion
  process {
    #region Parameter validation
    #region Make sure ManifestFolder is valid and a folder
    if ($false -eq (Test-Path -Path $ManifestFolder)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: ManifestFolder not valid: $ManifestFolder"
      return
    }
    if (!(Get-Item -Path $ManifestFolder).PSIsContainer) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: ManifestFolder is not a folder: $ManifestFolder"
      return
    }
    #endregion

    #region Make sure ApplicationFile is valid and a file and XML format
    if ($false -eq (Test-Path -Path $ApplicationFile)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: ApplicationFile not valid: $ApplicationFile"
      return
    }
    if ((Get-Item -Path $ApplicationFile).PSIsContainer) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: ApplicationFile is not a file: $ApplicationFile"
      return
    }
    if ($false -eq (Test-Xml -Path $ApplicationFile)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: ApplicationFile is not valid XML: $ApplicationFile"
      return
    }
    #endregion
    #endregion

    #region Report information before processing files
    # rather than use PSBoundParameters, manually output for better formatting
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "ManifestFolder",$ManifestFolder)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "ApplicationFile",$ApplicationFile)
    Remove-IHILogIndentLevel
    #endregion

    #region Rename all non-manifest files to have ".deploy" extension
    Add-IHILogIndentLevel
    Write-Host "Rename all non-manifest files to have '.deploy' extension"
    $Results = Get-ChildItem -Path $ManifestFolder -Exclude *.manifest | Rename-Item -NewName { $_.Name + '.deploy' } 2>&1
    if ($? -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred renaming non-manifest files in folder $ManifestFolder :: $("$Results")"
      Remove-IHILogIndentLevel
      return
    }
    Add-IHILogIndentLevel
    Write-Host "File rename complete"
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    #endregion

    #region Modify deployment manifest to map '.deploy' file names
    Add-IHILogIndentLevel
    Write-Host "Modify deployment manifest to map '.deploy' file names"
    try {
      # modify deployment manifest to map ".deploy" file names
      $xml = [xml](Get-Content -Path $ApplicationFile)
      $mapFiles = $xml.CreateAttribute("mapFileExtensions")
      $mapFiles.psbase.value = "true"
      $null = $xml.assembly.deployment.SetAttributeNode($mapFiles)
      $xml.Save($ApplicationFile)
    } catch {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred modify deployment manifest $ApplicationFile to map '.deploy' :: $("$_")"
      Remove-IHILogIndentLevel
      return
    }
    Add-IHILogIndentLevel
    Write-Host "Modify deployment manifest complete"
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    #endregion
  }
}
Export-ModuleMember -Function Invoke-IHIClickOnceMapFileExtensions
#endregion


#region Functions: Invoke-IHIMage

<#
.SYNOPSIS
Runs Mage on .csproj file
.DESCRIPTION
Runs Mage on .csproj file
.PARAMETER MageVersionId
ID of .NET MSBuild version to compile with; this is a value of a 
branch under $Ihi:Applications.DotNet, i.e. V20 or V40
.PARAMETER MageParams
Additional parameters to pass to Mage
.EXAMPLE
Invoke-IHIMage -MageVersionId V20 -MageParams @{ New="Application"; ToFile="c:\LeadRetrievalClient\bin\Ihi.LeadRetrieval.Client.exe.manifest"; Name="Ihi.LeadRetrieval.Client.exe"; Version="1.1.0.0"; Processor="x86"; FromDirectory="c:\LeadRetrievalClient\bin" }
Runs mage.exe using params in MageParams
#>
function Invoke-IHIMage {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$MageVersionId,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [hashtable]$MageParams
  )
  #endregion
  process {
    #region Parameter validation
    #region Make sure MageVersionId is valid
    # The MageVersionId is a value of a branch under $Ihi:Applications.DotNet, i.e. V20 or 
    # V40.  This tells the function which version of the utility to use.
    # Make sure this value is correct
    if ($Ihi:Applications.DotNet.Keys -notcontains $MageVersionId) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: $MageVersionId is not valid; correct values are: $($Ihi:Applications.DotNet.Keys)"
      return
    }
    #endregion
    #endregion

    #region Get Mage based on .NET version and confirm exists
    [string]$MagePath = $Ihi:Applications.DotNet.$MageVersionId.Mage
    if ($MagePath -eq $null -or !(Test-Path -Path $MagePath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path for Mage.exe is null or bad: $MagePath"
      return
    }
    #endregion

    #region Report information before processing files
    # rather than use PSBoundParameters, manually output for better formatting
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "MageVersionId",$MageVersionId)
    if ($MageParams -ne $null -and $($MageParams.Keys.Count) -gt 0) {
      $MageParamInfo = ""
      $MageParams.Keys | Sort | ForEach-Object { $MageParamInfo += ($_ + "=" + $MageParams[$_]) + " " }
      Write-Host $("{0,-$DefaultCol1Width} {1}" -f "MageParams",$MageParamInfo)
    }
    Remove-IHILogIndentLevel
    #endregion

    #region Running mage
    Add-IHILogIndentLevel
    Write-Host "Running Mage"
    #region Set Cmd and Params
    [string]$Cmd = $MagePath
    # build up cmdline params from hash table
    $Params = @()
    # Mage, annoyingly, expects it's first param to be a specific type
    # and all following params can be any order.  The first param must
    # be of type New, Update, Sign, ClearApplicationCache or Help.
    # So, we need to look through params for a particular value and if
    # find it, add it first to $Params then remove it from the hash table
    # so it's not picked up again.
    if ($MageParams.Keys -contains "New") {
      $Params += "-New",$MageParams."New"
      $MageParams.Remove("New")
    } elseif ($MageParams.Keys -contains "Update") {
      $Params += "-Update",$MageParams."Update"
      $MageParams.Remove("Update")
    } elseif ($MageParams.Keys -contains "Sign") {
      $Params += "-Sign",$MageParams."Sign"
      $MageParams.Remove("Sign")
    } elseif ($MageParams.Keys -contains "ClearApplicationCache") {
      $Params += "-ClearApplicationCache"
      $MageParams.Remove("ClearApplicationCache")
    } elseif ($MageParams.Keys -contains "Help") {
      $Params += "-Help"
      $MageParams.Remove("Help")
    } else {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: MageParams does not contain one of required initial params: New, Update, Sign, ClearApplicationCache or Help"
      Remove-IHILogIndentLevel
      return
    }
    # add remaining params to command
    $MageParams.Keys | ForEach-Object { $Params += "-$_",$MageParams[$_] }
    #endregion

    #region Run Mage
    $LastExitCode = 0
    $Results = & $Cmd $Params 2>&1
    if ($? -eq $false -or $LastExitCode -ne 0) {
      # if error occurred, display command to console before error message
      Add-IHILogIndentLevel
      Write-Host "& $Cmd $Params"
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Mage.exe with parameters: $("$Cmd $Params") :: $("$Results")"
      # get rid of indents if need to exit
      Remove-IHILogIndentLevel; Remove-IHILogIndentLevel
      return
    }
    # write mage results to console
    Add-IHILogIndentLevel
    $Results | Write-Host
    Write-Host "Processing complete"
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    #endregion
    #endregion
  }
}
Export-ModuleMember -Function Invoke-IHIMage
#endregion
