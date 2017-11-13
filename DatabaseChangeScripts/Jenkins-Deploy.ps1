function Jenkins-Deploy
{
  [CmdletBinding()] Param (
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$ServerA,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$ServerB,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$DatabaseName,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$Workspace
    )

  Write-Host "`nBegin Jenkins-Deploy script..."
  $dbServer = $ServerA

  try {
    #create a stopwatch to track script execution time
    $stopWatch = New-Object system.Diagnostics.Stopwatch 
    $stopWatch.Start()

    Write-Host "Verifying if Server [$dbServer] State is Online..."
    $isOnline = invoke-sqlcmd -ServerInstance $dbServer -Database $DatabaseName -Verbose -AbortOnError -OutputSqlErrors $True -Query "set nocount on; select State from sys.databases where name = '$DatabaseName';"
    if ($isOnline.State -ne 0){
      Write-Warning "Server [$dbServer] State is not Online."
      $dbServer = $ServerB
   
      Write-Host "Verifying if Alternate Server [$dbServer] State is Online..."
      $isOnline = invoke-sqlcmd -ServerInstance $dbServer -Database $DatabaseName -Verbose -AbortOnError -OutputSqlErrors $True -Query "set nocount on; select State from sys.databases where name = '$DatabaseName';"
      if ($isOnline.State -ne 0){
        throw "Both Configured Database Servers' States are Offline."
      }
    }
    Write-Host "Server [$dbServer] State is Online."

    $mirroring = invoke-sqlcmd -ServerInstance $dbServer -Database $DatabaseName -Verbose -AbortOnError -OutputSqlErrors $True -Query "set nocount on; select case when B.mirroring_state is not null then 1 else 0 end as [MirroringEnabled], mirroring_state as [MirroringState] from sys.databases A inner join sys.database_mirroring B on A.database_id=B.database_id where a.name = '$DatabaseName'"
    if ($mirroring.MirroringEnabled -eq 1 -and $mirroring.MirroringState -ne 0){
      Write-Host "Mirroring on Database [$DatabaseName]: Pausing..."
      invoke-sqlcmd -ServerInstance $dbServer -Database $DatabaseName -Verbose -AbortOnError -OutputSqlErrors $True -Query "set nocount on; alter database $DatabaseName set partner suspend;"
      Write-Host "Mirroring on Database [$DatabaseName]: Paused"
    }

    . $Workspace\V1.0.0\FMI.Billing.Database\Powershell\Execute-SqlFromPath.ps1
    Execute-SqlFromPath -ServerName $dbServer -DatabaseName $DatabaseName -SourcePath "$Workspace\V1.0.0\FMI.Billing.Database\dbo\ChangeScripts_PostCompile"
    Execute-SqlFromPath -ServerName $dbServer -DatabaseName $DatabaseName -SourcePath "$Workspace\V1.0.0\FMI.Billing.Database\dbo\Triggers"
    Execute-SqlFromPath -ServerName $dbServer -DatabaseName $DatabaseName -SourcePath "$Workspace\V1.0.0\FMI.Billing.Database\dbo\Views"
    Execute-SqlFromPath -ServerName $dbServer -DatabaseName $DatabaseName -SourcePath "$Workspace\V1.0.0\FMI.Billing.Database\dbo\Functions"
    Execute-SqlFromPath -ServerName $dbServer -DatabaseName $DatabaseName -SourcePath "$Workspace\V1.0.0\FMI.Billing.Database\dbo\Stored Procedures"    
    Execute-SqlFromPath -ServerName $dbServer -DatabaseName $DatabaseName -SourcePath "$Workspace\V1.0.0\FMI.Billing.Database\dbo\Jobs"

    Write-Host "`nJenkins-Deploy completed successfully"

    $stopWatch.Stop();  
    # Get the elapsed time as a TimeSpan value. 
    $ts = $stopWatch.Elapsed  
    # Format and display the TimeSpan value. 
    $ElapsedTime = [system.String]::Format("{0:00}:{1:00}:{2:00}.{3:00}", $ts.Hours, $ts.Minutes, $ts.Seconds, $ts.Milliseconds / 10); 
    "Total Elapsed Execution Time: $elapsedTime"
  }
  catch {
    Write-Error "`nJenkins-Deploy failed with exception`n"
    Write-Error $_.Exception
    throw
  }
  finally {
    $mirroring = invoke-sqlcmd -ServerInstance $dbServer -Database $DatabaseName -Verbose -AbortOnError -OutputSqlErrors $True -Query "set nocount on; select case when B.mirroring_state is not null then 1 else 0 end as [MirroringEnabled], mirroring_state as [MirroringState] from sys.databases A inner join sys.database_mirroring B on A.database_id=B.database_id where a.name = '$DatabaseName'"
    if ($mirroring.MirroringEnabled -eq 1 -and $mirroring.MirroringState -eq 0){
      Write-Host "Mirroring on Database [$DatabaseName]: Resuming..."
      invoke-sqlcmd -ServerInstance $dbServer -Database $DatabaseName -Verbose -AbortOnError -OutputSqlErrors $True -Query "set nocount on; alter database $DatabaseName set partner resume;"
      Write-Host "Mirroring on Database [$DatabaseName]: Resumed"
    }
  }
}

try {
  . "$ENV:WORKSPACE\V1.0.0\FMI.Billing.Database\Powershell\Compile-ChangeScriptFromTemplate.ps1"
  Jenkins-Deploy -ServerA $ENV:DBSERVERA -ServerB $ENV:DBSERVERB -DatabaseName $ENV:DB -Workspace $ENV:WORKSPACE
} catch {
  Write-Error "`nJenkins-Deploy failed with exception`n"
  Write-Error $_.Exception
  throw
}