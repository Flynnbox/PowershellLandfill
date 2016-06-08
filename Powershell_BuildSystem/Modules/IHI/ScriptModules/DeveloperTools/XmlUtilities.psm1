
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


#region Functions: Format-IHIXml, Format-IHIXmlFilesInFolder

<#
.SYNOPSIS
Formats an xml file using PSCX:Format-Xml and writes to file
.DESCRIPTION
Formats an xml file using PSCX:Format-Xml but instead of just producing
content to pipeline this allows you to overwrite the source file in place 
or create a new file and maintain the correct file encoding.  Also takes 
files via pipeline; in this case, files are updated in place and 
OutputPath is ignored.
.PARAMETER Path
Path to input file
.PARAMETER OutputPath
Location where to write output file, if specified
.PARAMETER AttributesOnNewLine
Write attributes on a new line
.PARAMETER ConformanceLevel
Conformance level for XML
.PARAMETER EnableDtd
Enables document type definition (DTD) processing
.PARAMETER IndentString
The string to use for indenting; default 4 spaces
.PARAMETER OmitXmlDeclaration
Omit the XML declaration element
.EXAMPLE
Format-IHIXml c:\temp\File1.xml -IndentString "  "
Formats the file content in place using 2 spaces for indent
.EXAMPLE
Format-IHIXml c:\temp\File1.xml c:\temp\File2.xml
Gets the content from File1.xml, formats then creates/overwrites File2.xml
.EXAMPLE
dir c:\temp -filter *.xml | Format-IHIXml 
Reformats all the Xml files in c:\temp in place
#>
function Format-IHIXml {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [Alias("FullName")]
    [string]$Path,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    $OutputPath = $null,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$AttributesOnNewLine,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [System.Xml.ConformanceLevel]$ConformanceLevel,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$EnableDtd,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$IndentString = "  ",
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$OmitXmlDeclaration
  )
  #endregion
  process {
    #region File validation
    # make sure file exists
    if (!(Test-Path -Path $Path)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: file does not exist at path: $Path"
      return
    }
    # make sure file is a valid XML file
    if (!(Test-Xml -Path $Path)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: file is not a valid XML file: $Path"
      return
    }
    #endregion

    #region Get file encoding, formatted content
    [System.Text.Encoding]$Encoding = Get-IHIFileEncoding -Path $Path
    # build up hashtable with parameters to pass via splatting
    [hashtable]$Params = @{ Path = $Path;
      AttributesOnNewLine = $AttributesOnNewLine;
      EnableDtd = $EnableDtd;
      IndentString = $IndentString
      OmitXmlDeclaration = $OmitXmlDeclaration
    }
    if ($ConformanceLevel -ne $null) { $Params.ConformanceLevel = $ConformanceLevel }
    # get the formatted content
    $Results = Format-Xml @Params 2>&1
    if ($? -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Format-Xml with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Results")"
      return
    }
    #endregion

    #region Output file
    # now save to file
    [string]$OutFile = $null
    # no outfile, save over original
    if ($OutputPath -eq $null) {
      $OutFile = $Path
    } else {
      $OutFile = $OutputPath
    }
    # map encoding type to Out-File encoding string
    [string]$OutFileEncoding = Get-IHIFileEncodingFromTextEncoding $Encoding
    # write file, overwrite file if exists
    [hashtable]$Params2 = @{ FilePath = $OutFile; Encoding = $OutFileEncoding; InputObject = $Results; Force = $true }
    # Out-File has a bug; errors aren't going into the stdout from stderr when using 2>&1
    # so use ErrorVariable instead
    $Err = $null
    Out-File @Params2 -ErrorVariable Err
    if ($? -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Out-File with parameters: $(Convert-IHIFlattenHashtable $Params2) :: $("$Err")"
      return
    }
    #endregion
  }
}
Export-ModuleMember -Function Format-IHIXml


<#
.SYNOPSIS
Reformats all XML files under a folder
.DESCRIPTION
Find all XML files (based on file extension) under a folder and passes
them into Format-IHIXml.  Maintains existing file format.  List of file 
extensions can be overridden; default list: .build .config .xml .xsl .xslt
.PARAMETER FolderPath
Path to input file
.PARAMETER Extensions
Location where to write output file, if specified
.EXAMPLE
Format-IhiXmlFilesInFolder C:\IHI_MAIN\trunk\Extranet
Reformats all XML files under Extranet.
.EXAMPLE
Format-IhiXmlFilesInFolder C:\IHI_MAIN\trunk\Extranet .config
Reformats all .config files (web.configs) under Extranet.
#>
function Format-IHIXmlFilesInFolder {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [string]$FolderPath,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$Extensions = (".build",".config",".xml",".xsl",".xslt")
  )
  #endregion
  process {
    #region Identify folder to process from param or pipeline
    # either process from $FolderPath or pipeline but not both
    [string]$FolderToProcess = $null
    if ($_ -ne $null) {
      $FolderToProcess = $_
    } elseif ($FolderPath -ne $null) {
      $FolderToProcess = $FolderPath
    } else {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: specify a folder to process"
      return
    }
    #endregion

    #region Folder validation
    # make sure folder exists
    if (!(Test-Path -Path $FolderToProcess)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: folder does not exist at path: $FolderToProcess"
      return
    }
    # make sure it's a folder
    if ((Get-Item -Path $FolderToProcess).PSIsContainer -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: specified folder is not an actual folder: $FolderToProcess"
      return
    }
    #endregion

    #region Get files and process
    # get all files under $FolderToProcess
    $Files = Get-ChildItem -Path $FolderToProcess -Recurse | Where-Object { $Extensions -contains $_.Extension }
    if ($Files -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: no files found under $FolderToProcess with extension: $Extensions"
      return
    }
    # files found; process them
    $Files | Format-IHIXml
    #endregion
  }
}
Export-ModuleMember -Function Format-IHIXmlFilesInFolder
New-Alias -Name "cleanxml" -Value Format-IHIXmlFilesInFolder
Export-ModuleMember -Alias "cleanxml"
#endregion

