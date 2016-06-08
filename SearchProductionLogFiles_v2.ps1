function Get-ProductionLogFiles {
    param([String]$localFilePath, [String]$searchString,  [String]$logFilePrefix, [DateTime]$startDate, [DateTime]$endDate, [bool]$noDownload=$false)

    if ([string]::IsNullOrEmpty($localFilePath)){
      Write-Host "`nPlease specify a local file directory to work in" -ForegroundColor Cyan 
      break
    }

    if ([string]::IsNullOrEmpty($searchString)){
      Write-Host "`nPlease specify a search string" -ForegroundColor Cyan
      break
    }

    if ([string]::IsNullOrEmpty($logFilePrefix)){
      Write-Host "`nPlease specify a log file prefix" -ForegroundColor Cyan
      break
    }

    if($noDownload -eq $false){
        if ($startDate -eq $null){
            $startDate = Get-Date
            $startDateString = $startDate.ToString("yyyy-MM-dd")
            Write-Host "`nNo start date specified; defaulting to current date: $startDateString" -ForegroundColor Cyan
        } else {
            $startDateString = $startDate.ToString("yyyy-MM-dd")
        }

        if ($endDate -eq $null){
            $endDate = Get-Date
            $endDateString = $endDate.ToString("yyyy-MM-dd")
            Write-Host "`nNo end date specified; defaulting to current date: $endDateString" -ForegroundColor Cyan
        } else {
            $endDateString = $endDate.ToString("yyyy-MM-dd")
        }
    }

    #create a stopwatch to track script execution time
    $stopWatch = New-Object system.Diagnostics.Stopwatch 
    $stopWatch.Start() 

    if($noDownload -eq $false){
      #get log files from production
      $logFilePath = "\\IHIAPPWEB01\d$\Logfiles\IHILogs\"
      $logFileSuffix = ".0"
      [Int]$numberOfDays = ($endDate - $startDate).TotalDays
      $logFiles = new-object String[] ($numberOfDays + 1)
      for([Int]$i = 0; $i -lt $numberOfDays; $i++){
        $logFiles[$i] = $logFilePrefix + "_" + $startDate.AddDays($i).ToString("yyyy-MM-dd") + $logFileSuffix
      }
      if ($logFiles -eq $null -or $logFiles.Length -eq $null){
        Write-Host "`nNo logFiles were identified to search"
        break
      }
      Write-Host "`nTargeting log files in " $logFilePath ":"
      $logFiles
  
      Write-Host "`nCopying files to local directory..."
      foreach($logFile in $logFiles){
        Copy-Item -Path (join-path $logFilePath $logFile) -Destination (join-path $localFilePath $logFile)
      }
      Write-Host "`nCopy complete"
    } else {
      $logFiles = Get-Item (join-path $localFilePath "*.0") | Select -Expand Name
      Write-Host "`nTargeting log files in " $localFilePath ":"
      $logFiles
    }

    #find matches in log files and increment count in hashtable
    Write-Host "`nFinding matches in files..."
    $matchFound = @()
    foreach($logFile in $logFiles){
        Write-Host "`nSearching in log file" $logFile "..."
        $temp = Select-String $searchString (join-path $localFilePath $logFile) | Select -Expand Matches | Foreach { $_.Groups[1] } | Select -Expand Value | Sort-Object | Get-Unique
        Write-Host "Found the following matches in log file" $logFile 
        Write-Host ($temp -join ", ")
        $matchFound = $matchFound + $temp
    }

    #sort and unique and output to file
    $matchFound = $matchFound | Sort-Object | Get-Unique
    $matchFound | Out-File (join-path $localFilePath output.txt)
    $totalUniqueMatches = $matchFound | measure | select -ExpandProperty Count

    Write-Host "`nFound a total of" $totalUniqueMatches "matches across all log files:"
    Write-Host ($matchFound -join ", ")

    $stopWatch.Stop();  
    # Get the elapsed time as a TimeSpan value. 
    $ts = $stopWatch.Elapsed  
    # Format and display the TimeSpan value. 
    $ElapsedTime = [system.String]::Format("{0:00}:{1:00}:{2:00}.{3:00}", 
               $ts.Hours, $ts.Minutes, $ts.Seconds, 
                $ts.Milliseconds / 10); 
    "`nScript Elapsed Runtime = $elapsedTime"
}