function Execute-SqlFromPath
{
    [CmdletBinding()] Param (
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$ServerName,
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$DatabaseName,
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$Username,
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$Password,
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$SourcePath, 
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$FilterExtension,
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$ResultFilePath
    )

    try{
        $result = invoke-sqlcmd -ServerInstance $ServerName -Database $DatabaseName -Username $Username -Password $Password -Verbose -AbortOnError -OutputSqlErrors $True -Query "select 1 as Result;"

        if($result.Result -ne 1){
            throw "Could not connect to Server [$ServerName] and Database [$DatabaseName] for Username [$Username]";
        }
        write-host "SQL Connection Confirmed to Server [$ServerName] and Database [$DatabaseName] for Username [$Username]"


        if ((Test-Path $ResultFilePath) -eq $false){
            Write-Host "Creating result file at path: $resultFilePath"
            New-Item $ResultFilePath -Type file -Force
        }

        Write-Host "Executing files at [$SourcePath] with Extension [$FilterExtension]..."

        #create a stopwatch to track script execution time
        $stopWatch = New-Object system.Diagnostics.Stopwatch 
        $stopWatch.Start()
        
        foreach ($file in Get-ChildItem -path $SourcePath -Filter $FilterExtension | sort-object )
        { 
            write-host "Executing $file..."
            invoke-sqlcmd -ServerInstance $ServerName -Database $DatabaseName -Username $Username -Password $Password -Verbose -AbortOnError -OutputSqlErrors $True -InputFile $file.fullname | format-table | out-file -filePath $ResultFilePath -Append 
        }
        Write-Host "Executed all files at [$SourcePath] with Extension [$FilterExtension]"

        $stopWatch.Stop();  
        # Get the elapsed time as a TimeSpan value. 
        $ts = $stopWatch.Elapsed  
        # Format and display the TimeSpan value. 
        $ElapsedTime = [system.String]::Format("{0:00}:{1:00}:{2:00}.{3:00}", $ts.Hours, $ts.Minutes, $ts.Seconds, $ts.Milliseconds / 10); 
        "`nTotal Elapsed Execution Time = $elapsedTime"        
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host $_.Exception
    }
}

Execute-SqlFromPath -ServerName "" -DatabaseName "" -Username "" -Password "" -SourcePath "" -FilterExtension "*.sql" -ResultFilePath "C:\Temp\SqlResults.txt"
