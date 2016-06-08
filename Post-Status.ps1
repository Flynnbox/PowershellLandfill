function Parse-Status {
    [CmdletBinding()] Param (
     [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [string]$Path
    )

  $content = get-content $Path -Encoding UTF8 | where {$_ -notlike [char]0x0009 + '*'}
  $slicedContent = $content[0..($content.IndexOf("***** BACKLOG *****") - 1)]
  $parsedContent = $slicedContent -join "<br />" -replace "\t", "&emsp;"
  Write-Output $parsedContent
}

function Post-Status {
    [CmdletBinding()] Param (
     [Parameter(ValueFromPipelineByPropertyName = $True)] [string]$Path = "C:\IHI_MAIN\trunk\Sandbox\aflynn\Development\WeeklyStatus.txt",
     [Parameter(ValueFromPipelineByPropertyName = $True)] [string]$ListUrl = "http://rnet/departments/engineering/TWIE/_vti_bin/listdata.svc/Posts"
    )

    if(!(test-path $Path)){
        Write-Host -ForegroundColor Red ("Could not find file at path: " + $Path)
        return
    } else {
        Write-Host ("Posting " + $Path + " to " + $ListUrl)
    }

    $parsedContent = Parse-Status $Path
    $post = @{ "Title" = "AFlynn"; "Body" = $parsedContent; "Published" = get-date -format yyyy-MM-ddTHH:mm:ss }
    $json = ConvertTo-JSON $post
    Invoke-RestMethod -uri $ListUrl -credential $global:cred -method post -contentType "application/json;odata=verbose" -body $json
}