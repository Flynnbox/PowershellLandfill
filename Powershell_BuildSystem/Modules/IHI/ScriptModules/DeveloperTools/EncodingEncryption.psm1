
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


#region Functions: Convert-IHIHtmlDecode, Convert-IHIHtmlEncode, Convert-IHIUrlDecode, Convert-IHIUrlEncode

# add System.Web if doesn't already exist
Add-Type -AssemblyName System.Web

<#
.SYNOPSIS
Decodes a value using html rules
.DESCRIPTION
Calls System.Web.HttpUtility.HtmlDecode with value.
http://msdn.microsoft.com/en-us/library/system.web.httputility.htmlencode.aspx
Also accepts values via pipeline.
.PARAMETER Value
Value to url encode
.EXAMPLE
Convert-IHIHtmlDecode "Some value &amp; another"
Some value & another
#>
function Convert-IHIHtmlDecode {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [string]$Value
  )
  #endregion
  process { [System.Web.HttpUtility]::HtmlDecode($Value) }
}
Export-ModuleMember -Function Convert-IHIHtmlDecode

<#
.SYNOPSIS
Encodes a value using html rules
.DESCRIPTION
Calls System.Web.HttpUtility.HtmlEncode with value.
http://msdn.microsoft.com/en-us/library/system.web.httputility.htmlencode.aspx
Also accepts values via pipeline.
.PARAMETER Value
Value to url encode
.EXAMPLE
Convert-IHIHtmlEncode "Some value & another"
Some value &amp; another
#>
function Convert-IHIHtmlEncode {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [string]$Value
  )
  #endregion
  process { [System.Web.HttpUtility]::HtmlEncode($Value) }
}
Export-ModuleMember -Function Convert-IHIHtmlEncode

<#
.SYNOPSIS
Decodes a value using url rules
.DESCRIPTION
Calls System.Web.HttpUtility.UrlDecode with value.
See: http://msdn.microsoft.com/en-us/library/system.web.httputility.urldecode.aspx
Also accepts values via pipeline.
.PARAMETER Value
Value to url encode
.EXAMPLE
Convert-IHIUrlDecode "Some%20value%20&%20another"
Some value & another
#>
function Convert-IHIUrlDecode {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [string]$Value
  )
  #endregion
  process { [System.Web.HttpUtility]::UrlDecode($Value) }
}
Export-ModuleMember -Function Convert-IHIUrlDecode

<#
.SYNOPSIS
Encodes a value using url rules
.DESCRIPTION
Calls System.Web.HttpUtility.UrlPathEncode with value.
See: http://msdn.microsoft.com/en-us/library/system.web.httputility.urlpathencode.aspx
Also accepts values via pipeline.
.PARAMETER Value
Value to url encode
.EXAMPLE
Convert-IHIUrlEncode "Some value & another"
Some%20value%20&%20another
#>
function Convert-IHIUrlEncode {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [string]$Value
  )
  #endregion
  process { [System.Web.HttpUtility]::UrlPathEncode($Value) }
}
Export-ModuleMember -Function Convert-IHIUrlEncode

#endregion


#region Functions: Convert-IHIDecryptPassword

<#
.SYNOPSIS
Decrypts encrypted text using same process as eDefine password API
.DESCRIPTION
Decrypts encrypted text using same process as eDefine password API but does not
use eDefine libraries directly - or we'd need all the dependencies of the Profiles DLL.
.PARAMETER Value
Value to decrypt
.EXAMPLE
Convert-IHIDecryptPassword 1vfZISjSjgfmbHo+Tb826g==
password
#>
function Convert-IHIDecryptPassword {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [string]$Value
  )
  #endregion
  process {
    Add-Type -AssemblyName System.Security
    try {
      [string]$keyString = "fp5ust7w"
      [string]$initVectorString = "18fna0z8"
      [string]$strResult = $null
      [byte[]]$dataToDecryptRevertedAsByteArray = $null
      $dataToDecryptRevertedAsByteArray = [System.Convert]::FromBase64String($Value)
      [System.Security.Cryptography.DESCryptoServiceProvider]$decryptionProvider = New-Object -TypeName System.Security.Cryptography.DESCryptoServiceProvider
      $decryptionProvider.Key = [System.Text.ASCIIEncoding]::ASCII.GetBytes($keyString)
      $decryptionProvider.Key = [System.Text.ASCIIEncoding]::ASCII.GetBytes($keyString)
      $decryptionProvider.IV = [System.Text.ASCIIEncoding]::ASCII.GetBytes($initVectorString)
      $decrypter = $decryptionProvider.CreateDecryptor()
      [System.IO.MemoryStream]$memoryStream = New-Object -TypeName System.IO.MemoryStream
      [System.Security.Cryptography.CryptoStreamMode]$modeWrite = [System.Security.Cryptography.CryptoStreamMode]::Write
      [System.Security.Cryptography.CryptoStream]$cryptoStream = New-Object -TypeName System.Security.Cryptography.CryptoStream -ArgumentList $memoryStream,$decrypter,$modeWrite
      $cryptoStream.Write($dataToDecryptRevertedAsByteArray,0,$dataToDecryptRevertedAsByteArray.Length)
      $cryptoStream.FlushFinalBlock()
      $strResult = [System.Text.ASCIIEncoding]::ASCII.GetString($memoryStream.ToArray())
      $memoryStream.Close()
      $cryptoStream.Close()
      $strResult
    } catch {
      Write-Error -Message $("$_")
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred decrypting text: $Value"
      return

    }
  }
}
Export-ModuleMember -Function Convert-IHIDecryptPassword
New-Alias -Name "decrypt" -Value Convert-IHIDecryptPassword
Export-ModuleMember -Alias "decrypt"
#endregion
