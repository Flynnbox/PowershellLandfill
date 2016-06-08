function Get-RepositoryFileEncodings
{
    [CmdletBinding()] Param (
     [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [string]$Path,
     [Parameter(ValueFromPipelineByPropertyName = $True)] [string[]]$EncodingsToIgnore = @("us-ascii", "utf-8")
    )

    #export the repo to the path if it does not exist
    if (!(Test-Path -Path $Path)){
        Write-Output "Path does not exist so exporting repository to: " $Path
        $headVersion = Get-IHIRepositoryHeadVersion
        Export-IHIRepositoryContent -UrlPath /trunk -LocalPath $Path -Version $headVersion
    }

    #recurse the repo and append all non ascii files
    Write-Output "Ignore file encodings: " $EncodingsToIgnore
    Write-Output "Checking encoding of files..." 
    
    $foundFiles = @()
    foreach ($file in Get-ChildItem -Path $Path -File -Recurse) {
        Write-Output $file.FullName
        $encoding = Get-IHIFileEncoding $file.FullName
        #if ($encoding.BodyName -ne "us-ascii"){
        if(!($EncodingsToIgnore -contains $encoding.BodyName)) {
            $foundFiles += @{ File = $file; Encoding = $encoding }
        }
    }
    Write-Output "*******************************"
    Write-Output "Non-Ignored Files Found: " $foundFiles.Length
    Write-Output "*******************************"
    Write-Output $foundFiles
    Write-Output "*******************************"
    Write-Output "Non-Ignored Files Found: " $foundFiles.Length
    Write-Output "*******************************"
}