function Get-OrderIdsInLogFiles {
    param([String]$localFilePath, [String]$orderIdFileName, [DateTime]$startDate, [DateTime]$endDate, [bool]$noDownload=$false)

    if ([string]::IsNullOrEmpty($localFilePath)){
      Write-Host "`nPlease specify a local file directory to work in" -ForegroundColor Cyan 
      break
    }

    if ([string]::IsNullOrEmpty($orderIdFileName)){
      $orderIdFileName = "orderIds.txt"
      Write-Host "`nNo order id file name specified; defaulting to file name: $orderIdFileName" -ForegroundColor Cyan
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

    #read all order ids from file
    $orderIds = Get-Content (join-path $localFilePath $orderIdFileName)

    if($orderIds -eq $null -or $orderIds.Length -eq 0){
      Write-Host "`nNo order ids were found in file:" (join-path $localFilePath $orderIdFileName)
      break
    }
    $totalOrderIdsToFind = $orderIds | measure | Select -Expand Count
    Write-Host "`nIdentified a total of" $totalOrderIdsToFind  "order ids within file:"
    Write-Host ($orderIds -join ", ")

    if($noDownload -eq $false){
      #get log files from production
      $logFilePath = "\\IHIAPPWEB01\d$\Logfiles\IHILogs\"
      $logFilePrefix = "MOBILEEVENTSAPI_"
      $logFileSuffix = ".0"
      [Int]$numberOfDays = ($endDate - $startDate).TotalDays
      $logFiles = new-object String[] ($numberOfDays + 1)
      for([Int]$i = 0; $i -le $numberOfDays; $i++){
        $logFiles[$i] = $logFilePrefix + $startDate.AddDays($i).ToString("yyyy-MM-dd") + $logFileSuffix
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

    #create regex of order ids
    $orderIdRegexString = $orderIds -join '|'
    #$regex = "\/api\/events\/order\/(" + $orderIdRegexString + ")" #too restrictive, misses some data
    $regex = "Validating order id (" + $orderIdRegexString + ")"

    #find matches of order ids in log files and increment count in hashtable
    Write-Host "`nFinding order id matches in files..."
    $orderIdsFound = @()
    foreach($logFile in $logFiles){
        Write-Host "`nSearching in log file" $logFile "..."
        $temp = Select-String $regex (join-path $localFilePath $logFile) | Select -Expand Matches | Foreach { $_.Groups[1] } | Select -Expand Value | Sort-Object | Get-Unique
        Write-Host "Found the following order ids in log file" $logFile 
        Write-Host ($temp -join ", ")
        $orderIdsFound = $orderIdsFound + $temp
    }

    #sort and unique and output to file
    $orderIdsFound = $orderIdsFound | Sort-Object | Get-Unique
    $orderIdsFound | Out-File (join-path $localFilePath output.txt)
    $totalUniqueOrderIds = $orderIdsFound | measure | select -ExpandProperty Count

    Write-Host "`nFound a total of" $totalUniqueOrderIds "order ids across all log files:"
    Write-Host ($orderIdsFound -join ", ")

    $stopWatch.Stop();  
    # Get the elapsed time as a TimeSpan value. 
    $ts = $stopWatch.Elapsed  
    # Format and display the TimeSpan value. 
    $ElapsedTime = [system.String]::Format("{0:00}:{1:00}:{2:00}.{3:00}", 
               $ts.Hours, $ts.Minutes, $ts.Seconds, 
                $ts.Milliseconds / 10); 
    "`nScript Elapsed Runtime = $elapsedTime"
}