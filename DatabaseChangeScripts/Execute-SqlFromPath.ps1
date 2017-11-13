Write-Host "`nLoading Function: Execute-SqlFromPath"

function Execute-SqlFromPath
{
    [CmdletBinding()] Param (
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$ServerName,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$DatabaseName,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$SourcePath, 
      [Parameter(Mandatory = $False, ValueFromPipelineByPropertyName = $True)] [String]$Filter = "*.sql",
      [Parameter(Mandatory = $False, ValueFromPipelineByPropertyName = $True)] [String]$Username,
      [Parameter(Mandatory = $False, ValueFromPipelineByPropertyName = $True)] [String]$Password
    )

    try{
      Write-Host "`nTrying to execute SQL files on Server [$ServerName] and Database [$DatabaseName] from Path [$SourcePath] with Extension [$Filter]..."

      #create a stopwatch to track script execution time
      $stopWatch = New-Object system.Diagnostics.Stopwatch 
      $stopWatch.Start()
       
      if ((Test-Path $SourcePath) -eq $false){
        throw "Path [$SourcePath] does not exist. Exiting..."
      }

      $credentials = @{'Username'=$Username;'Password'=$Password}
      if(($PSBoundParameters.ContainsKey('Username') -eq $False) -or ($PSBoundParameters.ContainsKey('Password') -eq $False)){
        Write-Host "SQL Server Account Username and Password not specified - using current Windows Authentication user credentials"
        $credentials = @{}
      }

      $result = invoke-sqlcmd -ServerInstance $ServerName -Database $DatabaseName -Verbose -AbortOnError -OutputSqlErrors $True -Query "select 1 as Result;" @credentials
      if($result.Result -ne 1){
        throw "Could not connect to Server [$ServerName] and Database [$DatabaseName] for Username [$(if($Username){$Username}else{$env:username})]";
      }
      Write-host "SQL Connection Confirmed to Server [$ServerName] and Database [$DatabaseName] for Username [$(if($Username){$Username}else{$env:username})]"

      Write-Host "Executing files..."        
      foreach ($file in Get-ChildItem -path $SourcePath -Filter $Filter | sort-object )
      { 
        write-host "Executing $file..."
        invoke-sqlcmd -ServerInstance $ServerName -Database $DatabaseName -Verbose -AbortOnError -OutputSqlErrors $True -InputFile $file.fullname @credentials
      }
      Write-Host "Executed all files successfully"

      $stopWatch.Stop();  
      # Get the elapsed time as a TimeSpan value. 
      $ts = $stopWatch.Elapsed  
      # Format and display the TimeSpan value. 
      $ElapsedTime = [system.String]::Format("{0:00}:{1:00}:{2:00}.{3:00}", $ts.Hours, $ts.Minutes, $ts.Seconds, $ts.Milliseconds / 10); 
      "Elapsed Execution Time: $elapsedTime"       
    }
    catch {
      Write-Error "`nSQL Exception failed with exception`n"
      Write-Error $_.Exception
      throw
    }
}

Write-Host "Function Loaded: Execute-SqlFromPath"

#Examples of how to invoke this code
#Execute-SqlFromPath -ServerName "localhost" -DatabaseName "Billing" -SourcePath "C:\Repositories\FMI\FMI-Billing\V1.0.0\FMI.Billing.Database\dbo\InvalidPath"
#Execute-SqlFromPath -ServerName "localhost" -DatabaseName "Billing" -SourcePath "C:\Repositories\FMI\FMI-Billing\V1.0.0\FMI.Billing.Database\dbo\Functions"
#Execute-SqlFromPath -ServerName "localhost" -DatabaseName "Billing" -Username "app_user" -Password "nv3VH6BXjLJy" -SourcePath "C:\Repositories\FMI\FMI-Billing\V1.0.0\FMI.Billing.Database\dbo\Functions"