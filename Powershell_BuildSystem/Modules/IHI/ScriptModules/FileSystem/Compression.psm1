
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


#region Functions: Expand-IHIArchive

<#
.SYNOPSIS
Expands a compressed file (zip)
.DESCRIPTION
Expands a compressed file (zip) using PSCX Expand-Archive.  If you need greater
control over process, use Expand-Archive and Read-Archive directly; this 
function only provides a subset of functionality with necessary error handling.
.PARAMETER Path
Path to archive file to expand
.PARAMETER OutputPath
Path to place contents of archive, must already exist
.PARAMETER FlattenPaths
Store all files in the archives in the root. If multiple files have the same
name, the last file in, wins
.EXAMPLE
Expand-IHIArchive c:\temp\file1.zip
Unzips file1.zip in CURRENT console location, NOT location of zip
.EXAMPLE
Expand-IHIArchive c:\temp\file1.zip c:\temp\unzip
Unzips file1.zip into c:\temp\unzip
.EXAMPLE
Expand-IHIArchive c:\temp\file1.zip c:\temp\unzip -FlattenPaths
Unzips file1.zip into c:\temp\unzip, putting all files directly in unzip WITHOUT
creating subfolders. If multiple files have the same name, the last file in, wins.
#>
function Expand-IHIArchive {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [Alias("FullName")]
    [string]$Path = $null,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$OutputPath,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$FlattenPaths
  )
  #endregion
  process {
    #region Parameter validation
    #region Make sure source Path exists
    if ($false -eq (Test-Path -Path $Path)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: source Path for archive does not exist: $($Path)"
      return
    }
    #endregion

    #region Make sure source Path is a file, not a folder
    if ((Get-Item -Path $Path).PSIsContainer) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: source Path for archive is a folder, not an archive: $($Path)"
      return
    }
    #endregion

    #region If OutputPath not specified, use current path
    if ($OutputPath -eq "") {
      $OutputPath = (Get-Location).Path
    }
    #endregion

    #region Make sure OutputPath exists
    if ($false -eq (Test-Path -Path $OutputPath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: results path OutputPath does not exist: $($OutputPath)"
      return
    }
    #endregion

    #region Make sure OutputPath is a filesystem drive
    # regardless of whether set or from Get-Location, make sure drive is a filesystem drive
    if ((Get-Item $OutputPath).PSProvider.Name -ne "FileSystem") {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: OutputPath is not a file system drive: $($OutputPath)"
      return
    }
    #endregion
    #endregion

    #region Report information before processing files
    # rather than use PSBoundParameters, manually output for better formatting
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Path",$Path)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "OutputPath",$OutputPath)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "FlattenPaths",$FlattenPaths)
    #endregion

    #region Expand files
    Write-Host "Expanding archive..."
    #region Initialize counters and log start time
    [datetime]$StartTime = Get-Date
    #endregion

    # specify PassThru so can capture and report number of files
    # adding Force to be able to overwrite if existing, since we often redeploy
    [hashtable]$Params = @{ LiteralPath = $Path; OutputPath = $OutputPath; FlattenPaths = $FlattenPaths; PassThru = $true; Force = $true }
    # redirection error stream 2>&1 doesn't work with Expand-Archive but error variable does
    # using Results to capture and (later) count files
    # if a user tries to expand an empty archive, Expand-Archive throws a very ugly error
    # and $Results -eq $null; test for that and add a separate error message
    $Err = $null
    $Results = $null
    $Results = Expand-Archive @Params -ErrorVariable Err
    # if ($? -eq $false -or $Results -eq $null) {
    # This will actually check and made sure that the archive is expanded
    if ($false -eq (Get-ChildItem $OutputPath -Recurse)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Expand-Archive with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Err")"
      Write-Error -Message "Is the archive empty?"
      Remove-IHILogIndentLevel
      return
    }
    #endregion

    #region Record end of processing information
    [datetime]$EndTime = Get-Date
    # get count of files; if multiple items returned, will be of type System.Object[] and if so get count
    # else if not equal to $null it's 1
    [string]$ResultsCountMsg = ""
    # if ($Results.GetType().FullName.ToUpper() -eq "SYSTEM.OBJECT[]") {
    if ($Results -eq $null) {
      # We're still stuck with an Expand-Archive cmdlet that returns nothing
      $ResultsCountMsg = "$(Get-ChildItem $OutputPath -Recurse | Where-Object {!$_.PSIsContainer} |Measure-Object) files"
    } elseif ($Results -ne $null) {
      # Since this part fails due to the null $Results need another way of checking
      $ResultsCountMsg = "1 file"
    }
    Add-IHILogIndentLevel
    Write-Host "Processing complete: $ResultsCountMsg in $(($EndTime - $StartTime).TotalSeconds) seconds"
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    #endregion
  }
}
Export-ModuleMember -Function Expand-IHIArchive
#endregion


#region Functions: Write-IHIZip

<#
.SYNOPSIS
Creates a compressed file (zip) from source files/folders
.DESCRIPTION
Creates a compressed file (zip) from source files/folders.  Can take parameter
or pipeline input (if using pipeline input, make sure you specify -Append).
.PARAMETER Path
Path to source file or folder to zip
.PARAMETER OutputPath
Path to store result zip file
.PARAMETER FlattenPaths
Store all files in the archives in the root. If multiple files have the same
name they will not be added an warning is emitted.
.PARAMETER Append
If set, the input files will be added to, or updated in, the zip file specified by OutputPath.
If passing source files in via pipeline you must specify this.
.PARAMETER IncludeEmptyDirs
If set, empty directories will be added as entries into the archive
.PARAMETER Level
Level of compression 1-9 (9 = best compression rate but slowest)
.PARAMETER Quiet
Hide status bar output (Write-Progress content)
.EXAMPLE
Write-IHIZip -Path c:\temp -OutputPath c:\TempFiles.zip 
Zips c:\temp folder and its contents into c:\TempFiles.zip
.EXAMPLE
Write-IHIZip -Path c:\temp\* -OutputPath c:\TempFiles.zip 
Zips contents of c:\temp folder into c:\TempFiles.zip but not root temp folder
.EXAMPLE
Write-IHIZip -Path c:\temp\*.ps1 -OutputPath c:\TempFiles.zip 
Zips *.ps1 files in c:\temp folder into c:\TempFiles.zip
.EXAMPLE
dir c:\temp\*.ps1 | Write-IHIZip -OutputPath c:\TempFiles.zip -Append
Zips *.ps1 files in c:\temp folder into c:\TempFiles.zip
.EXAMPLE
Write-IHIZip -Path c:\temp -OutputPath c:\TempFiles.zip -Level 9
Zips c:\temp folder using most effective - but slowest - compression 
.EXAMPLE
Write-IHIZip -Path c:\temp -OutputPath c:\TempFiles.zip -Quiet
Zips c:\temp folder and hides progress bar
.EXAMPLE
Write-IHIZip -Path c:\temp -OutputPath c:\TempFiles.zip -Append
Zips c:\temp folder and flattens hierarchy, storing everything at root
#>
function Write-IHIZip {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [Alias("FullName")]
    [string[]]$Path = $null,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$FlattenPaths,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$Append,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$IncludeEmptyDirs,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [ValidateRange(1,9)]
    [int]$Level = 5,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$Quiet
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

    #region If OutputPath exists, make sure it is not a folder
    if (($true -eq (Test-Path -Path $OutputPath)) -and ($true -eq (Get-Item -Path $OutputPath).PSIsContainer)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: results path OutputPath is a folder, not a file: $($OutputPath)"
      return
    }
    #endregion

    #region If Append specified but OutputPath doesn't exist (yet), set Append=$false
    # In the event you want to use pipeline input and want to put all files in a single zip
    # i.e. dir c:\temp\*.txt | Write-Zip -OutputPath c:\tempfiles.txt -Append
    # you need to specify append or a single zip is created for each source file, but each new file
    # overwrites the last file.  In this case you want to specify append but if the file doesn't 
    # exist yet (first file in the pipeline), you'll get an error, so do this special check first
    # Need to use temp variable, can't set value of source param Append or changes for all in pipeline.
    if (($Append -eq $true) -and ($false -eq (Test-Path -Path $OutputPath))) {
      $ZipAppend = $false
    } else {
      $ZipAppend = $Append
    }
    #endregion
    #endregion

    #region Report information before processing files
    # rather than use PSBoundParameters, manually output for better formatting
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Path",$("$Path"))
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "OutputPath",$OutputPath)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "FlattenPaths",$FlattenPaths)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Append",$ZipAppend)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "IncludeEmptyDirs",$IncludeEmptyDirs)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Level",$Level)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Quiet",$Quiet)
    #endregion

    #region Create zip file
    Write-Host "Creating zip archive..."
    #region Initialize counters and log start time
    [datetime]$StartTime = Get-Date
    #endregion

    # set params for cmdlet
    [hashtable]$Params = @{ Path = $Path; OutputPath = $OutputPath; FlattenPaths = $FlattenPaths; Append = $ZipAppend; IncludeEmptyDirectories = $IncludeEmptyDirs; Level = $Level; Quiet = $Quiet }
    $Err = $null
    $Results = $null
    $Results = Write-Zip @Params -ErrorVariable Err
    # FYI, if creating a new zip, $Results will be a file reference
    # but if appending to an existing file, $Results will be $null even if it worked correctly!
    # so don't check $Results -eq $null to determine if an error
    if ($? -eq $false -or $Err -ne $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Write-Zip with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Err")"
      Remove-IHILogIndentLevel
      return
    }
    #endregion

    #region Record end of processing information
    [datetime]$EndTime = Get-Date
    Add-IHILogIndentLevel
    Write-Host "Processing complete: in $(($EndTime - $StartTime).TotalSeconds) seconds"
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    #endregion
  }
}
Export-ModuleMember -Function Write-IHIZip
#endregion
