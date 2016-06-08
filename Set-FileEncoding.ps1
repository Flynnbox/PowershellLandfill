<#
.SYNOPSIS
Sets file encoding.
.DESCRIPTION
The Set-FileEncoding function 
#>
function Set-FileEncoding
{
    [CmdletBinding()] Param (
     [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [string]$Path,
     [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [string]$Encoding
    )
    $currentEncoding = Get-FileEncoding $Path

    #if $currentEncoding -eq $Encoding do nothing
    #else select encoding type
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)

    $content = Get-Content $Path
    [System.IO.File]::WriteAllLines($Path, $content, $Utf8NoBomEncoding)
}

<#
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)
foreach ($i in Get-ChildItem -Recurse) {
    if ($i.PSIsContainer) {
        continue
    }

    $dest = $i.Fullname.Replace($PWD, "some_folder")

    if (!(Test-Path $(Split-Path $dest -Parent))) {
        New-Item $(Split-Path $dest -Parent) -type Directory
    }

    $content = get-content $i 
    [System.IO.File]::WriteAllLines($dest, $content, $Utf8NoBomEncoding)
}
#>