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


#region Functions: Compress-IHICodeReleasePackage

<#
.SYNOPSIS
Zips files and folders in source into CodeReleasePackage.zip
.DESCRIPTION
Zips files and folders in source into CodeReleasePackage.zip.  Zips contents
of SourceRootFolder but not the folder itself.  If no files to zip writes error.
If ZipFile already exists, writes an error - does not overwrite.
.PARAMETER SourceRootFolderPath
Source root path of files to get
.PARAMETER ZipFilePath
Path to write zip file to, must not exist before function is called
.EXAMPLE
Compress-IHICodeReleasePackage -SourceRootFolderPath c:\sourcecode -ZipFilePath c:\temp\ZipFile.zip
Zips files/folders under c:\sourcecode and stores in c:\temp\ZipFile.zip
#>
function Compress-IHICodeReleasePackage {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceRootFolderPath,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ZipFilePath
  )
  #endregion
  process {
    #region Parameter validation
    #region Make sure source folder exists, is in fact a folder and has contents
    if ($false -eq (Test-Path -Path $SourceRootFolderPath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: source folder SourceRootFolderPath does not exist: $SourceRootFolderPath"
      return
    }
    if (!(Get-Item -Path $SourceRootFolderPath).PSIsContainer) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: SourceRootFolderPath is not a folder: $SourceRootFolderPath"
      return
    }
    # get files and folders to zip
    $StuffToZip = Get-ChildItem -Path $SourceRootFolderPath
    if ($null -eq ($StuffToZip)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: SourceRootFolderPath has no files or folders to compress"
      return
    }
    #endregion

    #region Make sure ZipFilePath does not currrently exist
    if ($true -eq (Test-Path -Path $ZipFilePath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: ZipFilePath already exists, should not exist before calling: $ZipFilePath"
      return
    }
    #endregion
    #endregion

    # Write-IHIZip -Path -OutputPath
    #region Zip up stuff
    # get string array of paths to zip
    [string[]]$PathsToZip = $StuffToZip | Select -ExpandProperty FullName
    Write-Host "Creating package release zip"
    Add-IHILogIndentLevel
    [hashtable]$Params = @{ Path = $PathsToZip; OutputPath = $ZipFilePath; Quiet = $true }
    $Err = $null
    Write-IHIZip @Params -EV Err
    if ($? -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Write-IHIZip with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Err")"
      Remove-IHILogIndentLevel; return
    }
    Add-IHILogIndentLevel
    Write-Host "Package release zip created"
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    #endregion
  }
}
Export-ModuleMember -Function Compress-IHICodeReleasePackage
#endregion


#region Functions: Remove-IHIFilesPreCompile, Remove-IHIFilesPostCompile

<#
.SYNOPSIS
Removes files that shouldn't be a part of the project, pre-compile 
.DESCRIPTION
Removes files that shouldn't be a part of the project, pre-compile.  Calls
Remove-IHIFilesByPattern with standard set of patterns to use to match
and delete files.
.PARAMETER Path
Source folder under which to purge
.PARAMETER Recursive
Specify if you want to walk through all subfolders to find matches
.PARAMETER AdditionalPatterns
File path patterns to purge in addition to the standard ones
.PARAMETER LogFile
Path to log file to store files that match before purging
.EXAMPLE
Remove-IHIFilesPreCompile -Path c:\FilesToSearch
Purges files under c:\FilesToSearch
.EXAMPLE
Remove-IHIFilesPreCompile -Path c:\FilesToSearch -Recursive
Purges files under c:\FilesToSearch, search recursively
.EXAMPLE
Remove-IHIFilesPreCompile -Path c:\FilesToSearch -AdditionalParams ".badfile1",".badfile2"
Purges files under c:\FilesToSearch, including files matching .badfile1 and .badfile2
.EXAMPLE
Remove-IHIFilesPreCompile -Path c:\FilesToSearch -LogFile c:\temp\log1.txt
Purges files under c:\FilesToSearch and logs files purged in c:\temp\log1.txt
#>
function Remove-IHIFilesPreCompile {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$Recursive,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$AdditionalPatterns,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$LogFile
  )
  #endregion
  process {
    # no parameter validation is performed; Remove-IHIFilesByPattern does all validation
    # this is simple wrapper that provides a standard constant of pre-build purge patterns

    #region Get list of patterns
    #region Standard patterns
    [string[]]$Patterns = $null
    #region Description of patterns
    <# 
      These patterns delete these types of files:
       Subversion folders:          \.svn$
       VSS files:                   \.scc$ \.vspscc$ \.vssscc$
       .user files:                 \.csproj\.user$ \.dtproj\.user$ \.rptproj\.user$
       IHI 'template' files in SVN: \.orig$
       csproj source offline:       \.suo$
    #>
    #endregion
    $Patterns = "\.svn$","\.scc$","\.vspscc$","\.vssscc$","\.csproj\.user$","\.dtproj\.user$","\.rptproj\.user$","\.orig$","\.suo$"
    # asdf more here
    #endregion
    # if user passed some additional params, add them
    if ($null -ne $AdditionalPatterns) {
      $Patterns += $AdditionalPatterns
    }
    #endregion

    #region Purge files
    [hashtable]$Params = @{ Path = $Path; Recursive = $Recursive; Patterns = $Patterns }
    # if log file passed, add that
    if ($LogFile -ne "") {
      $Params.LogFile = $LogFile
    }
    Remove-IHIFilesByPattern @Params
    #endregion
  }
}
Export-ModuleMember -Function Remove-IHIFilesPreCompile


<#
.SYNOPSIS
Removes files that shouldn't be a part of the project, post-compile 
.DESCRIPTION
Removes files that shouldn't be a part of the project, post-compile.  Calls
Remove-IHIFilesByPattern with standard set of patterns to use to match
and delete files.
.PARAMETER Path
Source folder under which to purge
.PARAMETER Recursive
Specify if you want to walk through all subfolders to find matches
.PARAMETER AdditionalPatterns
File path patterns to purge in addition to the standard ones
.PARAMETER LogFile
Path to log file to store files that match before purging
.EXAMPLE
Remove-IHIFilesPostCompile -Path c:\FilesToSearch
Purges files under c:\FilesToSearch
.EXAMPLE
Remove-IHIFilesPostCompile -Path c:\FilesToSearch -Recursive
Purges files under c:\FilesToSearch, search recursively
.EXAMPLE
Remove-IHIFilesPostCompile -Path c:\FilesToSearch -AdditionalParams ".badfile1",".badfile2"
Purges files under c:\FilesToSearch, including files matching .badfile1 and .badfile2
.EXAMPLE
Remove-IHIFilesPostCompile -Path c:\FilesToSearch -LogFile c:\temp\log1.txt
Purges files under c:\FilesToSearch and logs files purged in c:\temp\log1.txt
#>
function Remove-IHIFilesPostCompile {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$Recursive,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$AdditionalPatterns,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$LogFile
  )
  #endregion
  process {
    # no parameter validation is performed; Remove-IHIFilesByPattern does all validation
    # this is simple wrapper that provides a standard constant of pre-build purge patterns

    #region Get list of patterns
    #region Standard patterns
    [string[]]$Patterns = $null
    #region Description of patterns
    <# 
      These patterns delete these types of files:
       Solution/project files:          \.sln$ \.ssmssln$ \.csproj$ \.dtproj$ \.rptproj$ \.ssmssqlproj$
       c# source files:                 \.cs$
       resource files:                  \.resources$ \.resx$
       compiled website copy(?):        \\bin\\_PublishedWebsites$
       obj folder:                      \\obj$
       debug/release configs under bin: \\bin\.debug\.config$ \\bin\.release\.config$
       developer web.configs            \\UIWeb\\web\.config$ \\UIWeb\\web\.debug\.config$ \\UIWeb\\web\.release\.config$
    #>
    #endregion
    $Patterns = "\.sln$","\.ssmssln$","\.csproj$","\.dtproj$","\.rptproj$","\.ssmssqlproj$","\.cs$","\.resources$","\.resx$","\\bin\\_PublishedWebsites$","\\obj$","\\bin\.debug\.config$","\\bin\.release\.config$","\\UIWeb\\web\.config$","\\UIWeb\\web\.debug\.config$","\\UIWeb\\web\.release\.config$"
    # asdf more here
    #endregion
    # if user passed some additional params, add them
    if ($null -ne $AdditionalPatterns) {
      $Patterns += $AdditionalPatterns
    }
    #endregion

    #region Purge files
    [hashtable]$Params = @{ Path = $Path; Recursive = $Recursive; Patterns = $Patterns }
    # if log file passed, add that
    if ($LogFile -ne "") {
      $Params.LogFile = $LogFile
    }
    Remove-IHIFilesByPattern @Params
    #endregion
  }
}
Export-ModuleMember -Function Remove-IHIFilesPostCompile
#endregion


#region Functions: Call-SubversionWorkingCopyRevision
<#
.SYNOPSIS
Adds Subversion Build Number to assembly file prior to the build
.DESCRIPTION
Adds Subversion Build Number to assembly file prior to the build
.PARAMETER -AssemblyDir
Directory of the Assembly file 
.PARAMETER -AssemblyFilePath
Source folder where the Assembly File resides
.PARAMETER -AssemblyFileTemplate
Source folder where the template file resides
.EXAMPLE
Call-SubversionWorkingCopyRevison DIR TEMPLATE INFO
Base call with directory, path to template file and path to cs file
.EXAMPLE
Call-SubversionWorkingCopyRevison \BizTier\Properties Assembly.cs.template Assembly.cs
This will add the Subversion Build Number to the Assembly file under BizTier\Properties
#>
function Call-SubversionWorkingCopyRevision
{
  #region functionParameters
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
    [string]$AssemblyDir,
    [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
    [string]$AssemblyFilePath,
    [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
    [string]$AssemblyFileTemplate
  )
  #endregion

  #region Report information before processing
  $DefaultCollWidth = 1
  Write-Host "$($MyInvocation.MyCommand.Name) called with:"
  Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCollWidth} {1}" -f "Assembly Directory ",$AssemblyDir)
    Write-Host $("{0,-$DefaultCollWidth} {1}" -f "Assembly Template file located in ",$AssemblyFileTemplate)
    Write-Host $("{0,-$DefaultCollWidth} {1}" -f "Assembly File located in ",$AssemblyFilePath)
  Remove-IHILogIndentLevel
  #endregion
  
  process {
    # Command line is:
    # SubWCRev $ProjectDir $ProjectDir\Properties\AssemblyInfo.cs.template $ProjectDir\Properties\AssemblyInfo.cs
    # SubWCRev $AssemblyDir $AssemblyFileTemplate $AssemblyFilePath
    $Command = "SubWCRev"
    $Values = $AssemblyDir,$AssemblyFileTemplate,$AssemblyFilePath
    $results = (& $Command $Values )
    if ($results -ge 1) {
      Write-Host "SubWCRev failed to update the Assembly file due to :: ("$results")"
    }
  }
}
Export-ModuleMember -Function Call-SubversionWorkingCopyRevision
#endregion

