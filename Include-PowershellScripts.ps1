function Global:Include-PowershellScripts {
    [CmdletBinding()] Param (
     [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [string]$Path
    )
    Write-Host ("Including PowerShell Scripts From " + $Path)
    Get-ChildItem  "${Path}\*.ps1" | ForEach {
        Write-Host "[Including $_]" -ForegroundColor Green
        .$_
    }
    Write-Host "PowerShell Scripts Included" 
}