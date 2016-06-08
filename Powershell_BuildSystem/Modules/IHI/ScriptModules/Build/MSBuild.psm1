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


#region Functions: Invoke-IHIMSBuild

<#
.SYNOPSIS
Runs MSBuild on .csproj file
.DESCRIPTION
Runs MSBuild on .csproj file
.PARAMETER ProjectFilePath
Path to .NET .csproj file 
.PARAMETER MSBuildVersionId
ID of .NET MSBuild version to compile with; this is a value of a 
branch under $Ihi:Applications.DotNet, i.e. V20 or V40
.PARAMETER FrameworkVersion
Version of .NET to compile code to
.PARAMETER ReferencePath
Single path of a folder  
.PARAMETER Architecture
Architecture of result assembly - 32 or 64 (bit)
.PARAMETER Target
Project file configuration ID - typically Build
.PARAMETER Configuration
Project file section configuration ID - typically Release
.PARAMETER Platform
Project file section configuration ID - typically AnyCPU
.PARAMETER OutputPath
Relative path to store result assemblies and/or executables
.PARAMETER SignatureFilePath
If passed, sign assembly with this .snk file
.PARAMETER LogFile
Path to log file for storing MSBuild results
.PARAMETER ShowResults
Show full MSBuild results; by default Results not displayed in console
.EXAMPLE
Invoke-IHIMSBuild -ProjectFilePath [folder UIWeb]\UIWeb.csproj -MSBuildVersionId V40 -FrameworkVersion 3.5 -ReferencePath [path to Libraries]
Runs MSBuild on UIWeb.csproj, using MSBuild version 4.0, targeting .NET framework 3.5 and using a path for libraries files
#>
function Invoke-IHIMSBuild {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectFilePath,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$MSBuildVersionId,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateSet("2.0","3.5","4.0")]
    [string]$FrameworkVersion,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$ReferencePath,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [ValidateSet("32","64")]
    [int]$Architecture = 32,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$Target = "Build",
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$Configuration = "Release",
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$Platform = "AnyCPU",
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$OutputPath = "bin",
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$SignatureFilePath,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$LogFile,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$ShowResults
  )
  #endregion
  process {
    #region Parameter validation
    #region Make sure project file exists
    if ($false -eq (Test-Path -Path $ProjectFilePath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: project file not found: $ProjectFilePath"
      return
    }
    #endregion

    #region Make sure MSBuildVersionId is valid
    # The MSBuildVersionId is a value of a branch under $Ihi:Applications.DotNet, i.e. V20 or 
    # V40.  This tells the function which version of the utility to use.
    # Make sure this value is correct
    if ($Ihi:Applications.DotNet.Keys -notcontains $MSBuildVersionId) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: $MSBuildVersionId is not valid; correct values are: $($Ihi:Applications.DotNet.Keys)"
      return
    }
    #endregion

    #region ReferencePath must exist and must be folder
    # only check if passed
    if ($ReferencePath -ne "") {
      # make sure exists
      if ($false -eq (Test-Path -Path $ReferencePath)) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: ReferencePath folder does not exist: $ReferencePath"
        return
      }
      # if exists, make sure ReferencePath is a folder
      if ((Test-Path -Path $ReferencePath) -and (!(Get-Item -Path $ReferencePath).PSIsContainer)) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: ReferencePath must be a folder, not a file: $ReferencePath"
        return
      }
    }
    #endregion

    #region SignatureFilePath must exist and is a file, not be folder
    # only check if passed
    if ($SignatureFilePath -ne "") {
      # make sure exists
      if ($false -eq (Test-Path -Path $SignatureFilePath)) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: SignatureFilePath folder does not exist: $SignatureFilePath"
        return
      }
      # if exists, make sure SignatureFilePath is a file
      if ((Test-Path -Path $SignatureFilePath) -and ((Get-Item -Path $SignatureFilePath).PSIsContainer)) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: SignatureFilePath must be a file, not a folder: $SignatureFilePath"
        return
      }
    }
    #endregion

    #region LogFile parent must exist and LogFile must not be a folder
    # only check if passed
    if ($LogFile -ne "") {
      # make sure parent exists
      if ($false -eq (Test-Path -Path (Split-Path -Path $LogFile -Parent))) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: LogFile parent folder does not exist for LogFile: $LogFile"
        return
      }
      # if exists, make sure logfile is not a folder
      if ((Test-Path -Path $LogFile) -and (Get-Item -Path $LogFile).PSIsContainer) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: LogFile cannot be a folder, must be a filename: $LogFile"
        return
      }
    }
    #endregion

    #region Note about other parameters and validation
    <# Some of the parameters are validated using PowerShell's parameter utilities.  However many of
       the remaining parameters - Target, Configuration, Platform, OutputPath - are not.  These could
       be validated by opening the ProjectFilePath and confirming the appropriate values are, in fact, found
       but ultimately the error you would manually generate ('value' not found) would be the same as 
       the error you get run if you ran MSBuild with an incorrect value.  So there's no point in doing
       the extra work, which could introduce more errors.
    #>
    #endregion
    #endregion

    #region Get MSBuild based on .NET version and confirm exists
    [string]$MSBuildPath = $Ihi:Applications.DotNet.$MSBuildVersionId.MSBuild
    if ($MSBuildPath -eq $null -or !(Test-Path -Path $MSBuildPath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path for InstallUtil.exe is null or bad: $MSBuildPath"
      return
    }
    #endregion

    #region Report information before processing files
    # rather than use PSBoundParameters, manually output for better formatting
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "ProjectFilePath",$ProjectFilePath)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "MSBuildVersionId",$MSBuildVersionId)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "FrameworkVersion",$FrameworkVersion)
    if ($ReferencePath -ne "") {
      Write-Host $("{0,-$DefaultCol1Width} {1}" -f "ReferencePath",$ReferencePath)
    }
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Architecture",$Architecture)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Target",$Target)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Configuration",$Configuration)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Platform",$Platform)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "OutputPath",$OutputPath)
    if ($SignatureFilePath -ne "") {
      Write-Host $("{0,-$DefaultCol1Width} {1}" -f "SignatureFilePath",$SignatureFilePath)
    }
    if ($LogFile -ne "") {
      Write-Host $("{0,-$DefaultCol1Width} {1}" -f "LogFile",$LogFile)
    }
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "ShowResults",$ShowResults)
    Remove-IHILogIndentLevel
    #endregion

    #region Running build
    Add-IHILogIndentLevel
    Write-Host "Running MSBuild"
    #region Set Cmd and Params
    [string]$Cmd = $MSBuildPath
    $Params = "$ProjectFilePath","/T:$Target","`"/p:Configuration=$Configuration`"","`"/p:Platform=$Platform`"","`"/p:OutputPath=$OutputPath`""
    # add ReferencePath if passed
    if ($ReferencePath -ne "") {
      $Params +=,("`"/p:ReferencePath=$ReferencePath`"")
    }
    # add SignatureFilePath if passed
    if ($SignatureFilePath -ne "") {
      $Params +=,("`"/p:SignAssembly=true`"")
      $Params +=,("`"/p:AssemblyOriginatorKeyFile=$SignatureFilePath`"")
    }
    #endregion
    #region If logging enabled, record command in log file
    if ($LogFile -ne "") {
      [hashtable]$Params2 = @{ InputObject = "& $Cmd $Params"; FilePath = $LogFile } + $OutFileSettings
      $Err = $null
      Out-File @Params2 -ErrorVariable Err
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
        return
      }
    }
    #endregion
    #region Run MSBuild
    $LastExitCode = 0
    $Results = & $Cmd $Params 2>&1
    if ($? -eq $false -or $LastExitCode -ne 0) {
      # if error occurred, display command to console before error message
      Add-IHILogIndentLevel
      Write-Host "& $Cmd $Params"
      # MSBuild produces a LOT of content, most of it unnecessary, so just get the error text we want
      $BuildErrorText = $Results | Where-Object { $_.Contains(" error ") -or $_.Contains("Could not find file") -or $_.Contains("system cannot find the path specified") }
      [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: error occurred in MSBuild.exe with parameters: $("$Cmd $Params") :: $("$BuildErrorText")"
      #region If logging enabled, record error in log file
      if ($LogFile -ne "") {
        [hashtable]$Params2 = @{ InputObject = $($ErrorMessage + $Results); FilePath = $LogFile } + $OutFileSettings
        $Err = $null
        Out-File @Params2 -ErrorVariable Err
        if ($? -eq $false) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
          return
        }
      }
      #endregion
      Write-Error -Message $ErrorMessage
      Remove-IHILogIndentLevel; Remove-IHILogIndentLevel
      return
    } else {
      #region If no error but user specified LogFile, store results in it
      # If no error but user specified LogFile, store results it in
      if ($LogFile -ne "") {
        [hashtable]$Params2 = @{ InputObject = $Results; FilePath = $LogFile } + $OutFileSettings
        $Err = $null
        Out-File @Params2 -ErrorVariable Err
        if ($? -eq $false) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
          return
        }
      }
      #endregion
      #region Write results to console if $ShowResults
      # if user specified ShowResults and there were actual results
      # show command name and results to console window
      if ($ShowResults -eq $true -and $Results -ne $null) {
        Add-IHILogIndentLevel
        Write-Host "$Cmd $Params"
        $Results | ForEach-Object { $_.Replace("`r","`r`n") } | Write-Host
        Remove-IHILogIndentLevel
      }
      #endregion
      Add-IHILogIndentLevel
      Write-Host "Compilation complete"
      Remove-IHILogIndentLevel
    }
    Remove-IHILogIndentLevel
    #endregion
    #endregion
  }
}
Export-ModuleMember -Function Invoke-IHIMSBuild
#endregion
