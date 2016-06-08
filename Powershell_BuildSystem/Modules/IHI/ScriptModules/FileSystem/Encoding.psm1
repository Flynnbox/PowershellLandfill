
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


#region Functions: Get-IHIFileEncoding

<#
.SYNOPSIS
Returns the encoding type of the file
.DESCRIPTION
Returns the encoding type of the file.  It first attempts to determine the 
encoding by detecting the Byte Order Marker using Lee Holmes' algorithm
(http://poshcode.org/2153).  However, if the file does NOT have a BOM
it makes an attempt to determine the encoding by analyzing the file content
(does it 'appear' to be UNICODE, does it have characters outside the ASCII
range, etc.).  If it can't tell based on the content analyzed, then 
it assumes it's ASCII. I haven't checked all editors but PowerShell ISE and 
PowerGUI both create their default files as non-ASCII with a BOM (they use
Unicode Big Endian and UTF-8, respectively).  If your file doesn't have a 
BOM and 'doesn't appear to be Unicode' (based on my algorithm*) but contains 
non-ASCII characters after index ByteCountToCheck, the file will be incorrectly
identified as ASCII.  So put a BOM in there, would ya!

*For a full description of the algorithm used to analyze non-BOM files, 
see "Determine if Unicode/UTF8 with no BOM algorithm description".
.PARAMETER Path
Path to file
.PARAMETER ByteCountToCheck
Number of bytes to check, by default check first 10000 character.
Depending on the size of your file, this might be the entire content of your file.
.PARAMETER PercentageMatchUnicode
If pecentage of null 0 value characters found is greater than or equal to
PercentageMatchUnicode then this file is identified as Unicode.  Default value .5 (50%)
.EXAMPLE
Get-IHIFileEncoding -Path .\SomeFile.ps1 1000
Attempts to determine encoding using only first 1000 characters
BodyName          : unicodeFFFE
EncodingName      : Unicode (Big-Endian)
HeaderName        : unicodeFFFE
WebName           : unicodeFFFE
WindowsCodePage   : 1200
IsBrowserDisplay  : False
IsBrowserSave     : False
IsMailNewsDisplay : False
IsMailNewsSave    : False
IsSingleByte      : False
EncoderFallback   : System.Text.EncoderReplacementFallback
DecoderFallback   : System.Text.DecoderReplacementFallback
IsReadOnly        : True
CodePage          : 1201
#>
function Get-IHIFileEncoding {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [Alias("FullName")]
    [string]$Path,
    [Parameter(Mandatory = $false)]
    [int]$ByteCountToCheck = 10000,
    [Parameter(Mandatory = $false)]
    [decimal]$PercentageMatchUnicode = .5
  )
  #endregion
  process {
    # minimum number of characters to check if no BOM
    [int]$MinCharactersToCheck = 400
    #region Parameter validation
    #region SourcePath must exist; if not, exit
    if ($false -eq (Test-Path -Path $Path)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name) :: Path does not exist: $Path"
      return
    }
    #endregion
    #region ByteCountToCheck should be at least MinCharactersToCheck
    if ($ByteCountToCheck -lt $MinCharactersToCheck) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name) :: ByteCountToCheck should be at least $MinCharactersToCheck : $ByteCountToCheck"
      return
    }
    #endregion
    #endregion

    #region Determine file encoding based on BOM - if exists
    # the code in this section is mostly Lee Holmes' algorithm: http://poshcode.org/2153
    # until we determine the file encoding, assume it is unknown
    $Unknown = "UNKNOWN"
    $result = $Unknown

    # The hashtable used to store our mapping of encoding bytes to their
    # name. For example, "255-254 = Unicode"
    $encodings = @{}

    # Find all of the encodings understood by the .NET Framework. For each,
    # determine the bytes at the start of the file (the preamble) that the .NET
    # Framework uses to identify that encoding.
    $encodingMembers = [System.Text.Encoding] | Get-Member -Static -MemberType Property
    $encodingMembers | ForEach-Object {
      $encodingBytes = [System.Text.Encoding]::($_.Name).GetPreamble() -join '-'
      $encodings[$encodingBytes] = $_.Name
    }

    # Find out the lengths of all of the preambles.
    $encodingLengths = $encodings.Keys | Where-Object { $_ } | ForEach-Object { ($_ -split "-").Count }

    # Go through each of the possible preamble lengths, read that many
    # bytes from the file, and then see if it matches one of the encodings
    # we know about.
    foreach ($encodingLength in $encodingLengths | Sort-Object -Descending) {
      $byteArray = Get-Content -Path $Path -Encoding byte -ReadCount $encodingLength -TotalCount $encodingLength
      if ($null -eq $byteArray){
        Write-Host -ForegroundColor Red ("Could not identify file encoding as byte array is null for file: " + $Path)
        [System.Text.Encoding]::"ASCII"
        return
      }
      $bytes = $byteArray[0]
      $encoding = $encodings[$bytes -join '-']

      # If we found an encoding that had the same preamble bytes,
      # save that output and break.
      if ($encoding) {
        $result = $encoding
        break
      }
    }
    # if encoding determined from BOM, then return it
    if ($result -ne $Unknown) {
      [System.Text.Encoding]::$result
      return
    }
    #endregion

    #region No BOM on file, attempt to determine based on file content
    #region Determine if Unicode/UTF8 with no BOM algorithm description
    <#
       Looking at the content of many code files, most of it is code or
       spaces.  Sure, there are comments/descriptions and there are variable
       names (which could be double-byte characters) or strings but most of
       the content is code - represented as single-byte characters.  If the
       file is Unicode but the content is mostly code, the single byte
       characters will have a null/value 0 byte as either as the first or
       second byte in each group, depending on Endian type.
       My algorithm uses the existence of these 0s:
        - look at the first ByteCountToCheck bytes of the file
        - if any character is greater than 127, note it (if any are found, the 
          file is at least UTF8)
        - count the number of 0s found (in every other character)
          - if a certain percentage (compared to total # of characters) are 
            null/value 0, then assume it is Unicode
          - if the percentage of 0s is less than we identify as a Unicode
            file (less than PercentageMatchUnicode) BUT a character greater
            than 127 was found, assume it is UTF8.
          - Else assume it's ASCII.
       Yes, technically speaking, the BOM is really only for identifying the
       byte order of the file but c'mon already... if your file isn't ASCII
       and you don't want it's encoding to be confused just put the BOM in
       there for pete's sake.
       Note: if you have a huge amount of text at the beginning of your file which
       is not code and is not single-byte, this algorithm may fail.  Again, put a 
       BOM in.
    #>
    #endregion
    $Content = (Get-Content -Path $Path -Encoding byte -ReadCount $ByteCountToCheck -TotalCount $ByteCountToCheck)
    # get actual count of bytes (in case less than $ByteCountToCheck)
    $ByteCount = $Content.Count
    [bool]$NonAsciiFound = $false
    # yes, the big/little endian sections could be combined in one loop
    # sorry, crazy busy right now...

    #region Check if Big Endian
    # check if big endian Unicode first - even-numbered index bytes will be 0)
    $ZeroCount = 0
    for ($i = 0; $i -lt $ByteCount; $i += 2) {
      if ($Content[$i] -eq 0) { $ZeroCount++ }
      if ($Content[$i] -gt 127) { $NonAsciiFound = $true }
    }
    if (($ZeroCount / ($ByteCount / 2)) -ge $PercentageMatchUnicode) {
      # create big-endian Unicode with no BOM
      New-Object System.Text.UnicodeEncoding $true,$false
      return
    }
    #endregion

    #region Check if Little Endian
    # check if little endian Unicode next - odd-numbered index bytes will be 0)
    $ZeroCount = 0
    for ($i = 1; $i -lt $ByteCount; $i += 2) {
      if ($Content[$i] -eq 0) { $ZeroCount++ }
      if ($Content[$i] -gt 127) { $NonAsciiFound = $true }
    }
    if (($ZeroCount / ($ByteCount / 2)) -ge $PercentageMatchUnicode) {
      # create little-endian Unicode with no BOM
      New-Object System.Text.UnicodeEncoding $false,$false
      return
    }
    #endregion

    #region Doesn't appear to be Unicode; either UTF8 or ASCII
    # Ok, at this point, it's not a Unicode based on our percentage rules
    # if not Unicode but non-ASCII character found, call it UTF8 (no BOM, alas)
    if ($NonAsciiFound -eq $true) {
      New-Object System.Text.UTF8Encoding $false
      return
    } else {
      # if made it this far, I'm calling it ASCII; done deal pal
      [System.Text.Encoding]::"ASCII"
      return
    }
    #endregion
    #endregion
  }
}
Export-ModuleMember -Function Get-IHIFileEncoding
#endregion


#region Functions: Get-IHIFileEncodingDetails

<#
.SYNOPSIS
Returns encoding, BOM, and endian information for a file or files
.DESCRIPTION
Returns encoding, BOM, and endian information for a file or files.
It can return the information as a formatted table (the default) or as 
PSObjects. It can filter based on file extension ("*.prc","*.viw" by 
default) and it hides ASCII files by default.

This function was originally devised to find non-ASCII files under the
IHI stored procedures folder.  (A non-ASCII file without a BOM might 
cause issues during deployment.)  So while this function can be used on
any generic set of files, the defaults are IHI stored procedure-specific.
.PARAMETER Path
Path to file or folder to check
.PARAMETER FileExtensions
List of file extensions to filter upon.  "*.prc","*.viw" by default
.PARAMETER ShowAsciiFiles
Shows details about all files including ASCII.  By default ASCII are hidden.
.PARAMETER ReturnPSObjects
Instead of returning a formatted table, return PSObjects - usuable if 
scripting with the results.  If specified, the file name will not be 
truncated (if processing IHI stored procedures).
.EXAMPLE
Get-IHIFileEncodingDetails
Gets file encoding information for files under \trunk\Database\IHI\StoredProcedures

FileName                                               Encoding        BomFound Endian
--------                                               --------        -------- ------
CSIConsole\dbo.csi_ConsoleEntEntitySetAllGet.prc       UTF8Encoding        True
CSIConsole\dbo.csi_ConsoleEntEntitySetGet.prc          UTF8Encoding        True
CSIConsole\dbo.csi_ConsoleEntEntitySetGetByParent.prc  UTF8Encoding        True
DataCleanup\dbo.dc_getUsersToArchiveOrInactivate.prc   UTF8Encoding       False
DataCleanup\dbo.dc_inactivateUsers.prc                 UnicodeEncoding     True Little
DataCleanup\dbo.dc_UpdateWithNCOAAddress.prc           UnicodeEncoding     True Little
.EXAMPLE
Get-IHIFileEncodingDetails -Path c:\temp -ShowAsciiFiles
Gets file encoding information for the files under c:\temp and shows the ASCII files
as well (which are hidden by default)
.EXAMPLE
Get-IHIFileEncodingDetails -Path c:\temp\File1.prc
Gets file encoding information for just one file
.EXAMPLE
Get-IHIFileEncodingDetails -FileExtensions ("*.viw")
Get file encoding information for just the *.viw files
.EXAMPLE
Get-IHIFileEncodingDetails -ReturnPSObjects
Returns the file encoding information as PSObjects rather than a formatted table
#>
function Get-IHIFileEncodingDetails {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [Alias("FullName")]
    [string]$Path,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$FileExtensions = ("*.prc","*.viw"),
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$ShowAsciiFiles,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$ReturnPSObjects
  )
  #endregion
  process {

    #region Parameter validation
    #region If no Path specified then use IHI Database stored procedures
    if ($Path -eq "") {
      $Path = Join-Path -Path ($IHI:BuildDeploy.SvnMain.LocalRootFolder) -ChildPath "trunk\Database\IHI\StoredProcedures"
    }
    #endregion

    #region Make sure Path exists
    if ($false -eq (Test-Path -Path $Path)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path not found: $Path"
      return
    }
    #endregion
    #endregion

    #region Get files to check
    # if this is just a file, set $Files to file at $Path else get files
    if (!(Get-Item -Path $Path).PSIsContainer) {
      $Files = Get-Item $Path
    } else {
      [hashtable]$Params = @{ Path = $Path; Recurse = $true }
      if ($null -ne $FileExtensions -and $FileExtensions.Count -gt 0) {
        $Params.Include = $FileExtensions
      }
      # get files, filter out folders
      $Files = Get-ChildItem @Params | Where-Object { $false -eq $_.PSIsContainer }
      # if no files, exit
      if ($null -eq $Files) { return }
    }
    #endregion

    #region Analyze files and create PSObjects
    $PSObjects = $Files | % {
      # create PSObject to store information
      $EncodingInfo = 1 | Select FileName,Encoding,BomFound,Endian

      #region Truncate FileName if not ReturnPSObjects and an IHI stored procedure
      # if we are returning PSObjects, we want the full name (to possibly use) so don't truncate
      # if user is checking encoding specifically on IHI stored procedure files, let's 
      # remove all path before and including "\StoredProcedures\"
      $RootFolderName = "\trunk\Database\IHI\StoredProcedures\"
      if ((!$ReturnPSObjects) -and $_.FullName.IndexOf($RootFolderName) -gt 0) {
        $RootFolderEnd = $_.FullName.IndexOf($RootFolderName) + $RootFolderName.Length
        $EncodingInfo.FileName = $_.FullName.Substring($RootFolderEnd)
      } else {
        $EncodingInfo.FileName = $_.FullName
      }
      #endregion

      # get full encoding object
      $Encoding = Get-IHIFileEncoding $_.FullName
      # store encoding type name
      $EncodingInfo.Encoding = $EncodingTypeName = $Encoding.ToString().Substring($Encoding.ToString().LastIndexOf(".") + 1)
      # store whether or not BOM found
      $EncodingInfo.BomFound = "$($Encoding.GetPreamble())" -ne ""
      $EncodingInfo.Endian = ""
      # if Unicode, get big or little endian
      if ($Encoding.GetType().FullName -eq ([System.Text.Encoding]::Unicode.GetType().FullName)) {
        if ($EncodingInfo.BomFound) {
          if ($Encoding.GetPreamble()[0] -eq 254) {
            $EncodingInfo.Endian = "Big"
          } else {
            $EncodingInfo.Endian = "Little"
          }
        } else {
          $FirstByte = Get-Content -Path $_.FullName -Encoding byte -ReadCount 1 -TotalCount 1
          if ($FirstByte -eq 0) {
            $EncodingInfo.Endian = "Big"
          } else {
            $EncodingInfo.Endian = "Little"
          }
        }
      }

      #region If didn't specify ShowAsciiFiles then filter out ASCIIEncoding items
      if ($false -eq $ShowAsciiFiles) {
        # only return if not ascii
        if ($EncodingInfo.Encoding -ne "ASCIIEncoding") {
          $EncodingInfo
        }
      } else {
        $EncodingInfo
      }
      #endregion
    }

    #region Return either formatted data or PSObjects
    if ($true -eq $ReturnPSObjects) {
      $PSObjects
    } else {
      $PSObjects | Format-Table -AutoSize
    }
  }
}
Export-ModuleMember -Function Get-IHIFileEncodingDetails
#endregion


#region Functions: Get-IHIFileEncodingFromTextEncoding

<#
.SYNOPSIS
Gets encoding name for Out-File given a System.Text.Encoding type
.DESCRIPTION
Returns the string name value for encoding to use used with Out-File
given an actual System.Text.Encoding type.  There doesn't appear to be a
single property on the actual System.Text.Encoding static instance type 
that maps to the necessary string values used by Out-File.  The name of 
the static instances DOES map to the Out-File name so we could rewrite
this to be more elegant and loop through all the static members on the 
Encoding type itself to compare with the $Encoding parameter, but this
switch is good enough for now.
.PARAMETER Encoding
System.Text.Encoding
.EXAMPLE
Get-IHIFileEncodingFromTextEncoding [System.Text.Encoding]::ASCII
ascii
.EXAMPLE
Get-IHIFileEncodingFromTextEncoding [System.Text.Encoding]::Unicode
unicode
.EXAMPLE
Get-IHIFileEncodingFromTextEncoding [System.Text.Encoding]::UTF8
utf32
#>
function Get-IHIFileEncodingFromTextEncoding {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [System.Text.Encoding]$Encoding
  )
  #endregion
  process {
    [string]$OutFileEncoding = $null
    switch ($Encoding.BodyName) {
      "utf-7" { $OutFileEncoding = "utf7" }
      "utf-8" { $OutFileEncoding = "utf8" }
      "utf-16" { $OutFileEncoding = "unicode" }
      "utf-32" { $OutFileEncoding = "utf32" }
      "unicodeFFFE" { $OutFileEncoding = "bigendianunicode" }
      "us-ascii" { $OutFileEncoding = "ascii" }
      "iso-8859-1" { $OutFileEncoding = "default" }
    }
    $OutFileEncoding
  }
}
Export-ModuleMember -Function Get-IHIFileEncodingFromTextEncoding
#endregion


#region Functions: Get-IHIFileNonAsciiCharcters

<#
.SYNOPSIS
Reports code, character, context and index of non-ASCII characters.
.DESCRIPTION
Reports code, character, context and index of non-ASCII characters.
.PARAMETER Path
Path to file
.EXAMPLE
Get-IHIFileNonAsciiCharcters c:\temp\file1.txt
Code Character Context     FileIndex
---- --------- -------     ---------
 212         Ô funkyÔchara        38
#>
function Get-IHIFileNonAsciiCharcters {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [Alias("FullName")]
    [string]$Path
  )
  #endregion
  process {
    #region Parameter validation
    #region Make sure Path exists
    if ($false -eq (Test-Path -Path $Path)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: path not found: $Path"
      return
    }
    #endregion
    #endregion

    #region Get content as byte array for analyzing characters
    $Content = (Get-Content -Path $Path -Encoding byte -ReadCount 100000 -TotalCount 100000)
    # get actual count of bytes (in case less than $ByteCountToCheck)
    $ByteCount = $Content.Count
    #endregion

    #region Loop through all characters, looking for non ASCII, return info if found
    # we want to skip the BOM, as it will have characters with a value over 127
    [int]$StartIndex = (Get-IHIFileEncoding $Path).GetPreamble().Length
    # initialize line and character counters
    [int]$LineNumber = 1
    [int]$CharacterNumber = 1
    $BadCharacters = for ($i = $StartIndex; $i -lt $ByteCount; $i += 1) {
      if ($Content[$i] -gt 127) {
        # create PSObject to store information
        $CharacterInfo = 1 | Select Code,Character,Context,LineNumber,CharacterNumber,FileIndex
        $CharacterInfo.Code = $Content[$i]
        $CharacterInfo.Character = [char]$Content[$i]
        #region Get surrounding index range
        $LowerIndex = $i - 5
        if ($LowerIndex -lt 0) { $LowerIndex = 0 }
        $UpperIndex = $i + 5
        if ($UpperIndex -gt ($ByteCount - 1)) { $UpperIndex = $ByteCount - 1 }
        #endregion
        $CharacterInfo.Context = -join [char[]]$Content[$LowerIndex..$UpperIndex]
        $CharacterInfo.LineNumber = $LineNumber
        $CharacterInfo.CharacterNumber = $CharacterNumber
        $CharacterInfo.FileIndex = $i
        # return info object
        $CharacterInfo
      }
      # check if new line; support any combo of (13 10), (13), (10) used for new line
      # handle both characters first
      if ($Content[$i] -eq 13 -and ($i -lt $ByteCount -and $Content[$i + 1] -eq 10)) {
        # found a newline, increment line number counter and reset character number counter
        $LineNumber += 1
        $CharacterNumber = 1
        # because we know the next character is 10, there's no need to check if it's greater
        # than 127 and we don't want it to match the 10 only check, so increate $i to skip this character
        $i += 1
      } elseif ($Content[$i] -eq 13) {
        # it's just 13, no 10; increment/reset counters
        $LineNumber += 1
        $CharacterNumber = 1
      } elseif ($Content[$i] -eq 10) {
        # it's just 10, no preceeding 13; increment/reset counters
        $LineNumber += 1
        $CharacterNumber = 1
      } else {
        # it's a non-newline character, increment character counter
        $CharacterNumber += 1
      }
    }
    $BadCharacters | Format-Table -AutoSize
    #endregion
  }
}
Export-ModuleMember -Function Get-IHIFileNonAsciiCharcters
#endregion
