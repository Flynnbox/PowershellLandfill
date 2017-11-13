function Get-TRFsInHL7Files {
    param([String]$localFilePath, [String]$trfListFileName, [DateTime]$startDate, [DateTime]$endDate, [bool]$noDownload=$true)

    if ([string]::IsNullOrEmpty($localFilePath)){
      Write-Host "`nPlease specify a local file directory to work in" -ForegroundColor Cyan 
      break
    }

    if ([string]::IsNullOrEmpty($trfListFileName)){
      $trfListFileName = "TRFs.txt"
      Write-Host "`nNo TRF list file name specified; defaulting to file name: $trfListFileName" -ForegroundColor Cyan
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

    #read all TRF lists from file
    $TRFs = Get-Content (join-path $localFilePath $trfListFileName)

    if($TRFs -eq $null -or $TRFs.Length -eq 0){
      Write-Host "`nNo TRFs were found in file:" (join-path $localFilePath $trfListFileName)
      break
    }
    $totalTRFsToFind = $TRFs | measure | Select -Expand Count
    Write-Host "`nIdentified a total of" $totalTRFsToFind  "TRFs within file:"
    Write-Host ($TRFs -join ", ")

    if($noDownload -eq $false){
      #get log files from production
      $targetFilePath = "\\fm-150sec-nas01-smb01\Mirth\Billing\PROD\archive\final"
      $targetFilePrefix = "LDFMCHG."
       $targetFileSuffix = "*.hl7"
      [Int]$numberOfDays = ($endDate - $startDate).TotalDays
      $targetFiles = new-object String[] ($numberOfDays + 1)
      for([Int]$i = 0; $i -le $numberOfDays; $i++){
        $targetFiles[$i] = $targetFilePrefix + $startDate.AddDays($i).ToString("yyyyMM-dd") + $targetFileSuffix
      }
      if ($targetFiles -eq $null -or $targetFiles.Length -eq $null){
        Write-Host "`nNo targetFiles were identified to search"
        break
      }
      Write-Host "`nTargeting log files in " $targetFilePath ":"
      $targetFiles
  
      Write-Host "`nCopying files to local directory..."
      foreach($targetFile in $targetFiles){
        #Copy-Item -Path (join-path $targetFilePath $targetFile) -Destination (join-path $localFilePath $targetFile)
      }
      Write-Host "`nCopy complete"
    } else {
      $targetFiles = Get-Item (join-path $localFilePath "*.hl7") | Select -Expand Name
      Write-Host "`nTargeting log files in " $localFilePath ":"
      $targetFiles
    }

    #create regex of TRF lists
    $trfsRegexString = $TRFs -join '|'
    #$regex = "PID\|1\|(" + $trfsRegexString + ")"
    #$regex = "PID\|1\|(" + $trfsRegexString + ")"
    #$regex = "(?s)PID\|1\|(" + $trfsRegexString + ").+?(FT1\|.+?)"
    $regex = "(?s)PID\|1\|(" + $trfsRegexString + ").+?FT1\|(?:[^\|]*\|){19}(\d)\|(?:[^\|]*\|){11}(\d)"

    #find matches of TRF lists in log files and increment count in hashtable
    Write-Host "`nFinding TRF matches in files..."
    $TRFsFound = @()
    foreach($targetFile in $targetFiles){
        Write-Host "`nSearching in file" $targetFile "..."        
        #$temp = Select-String -InputObject $text -Pattern $regex | Select -Expand Matches | Foreach { $_.Groups[1] } | Select -Expand Value | Sort-Object | Get-Unique
        #$temp = Select-String $regex $(join-path $localFilePath $targetFile) | Select -Expand Matches | Foreach { "{0}|{2}" -f $_.Groups[1].Value, $_.Groups[2].Value }
        [String]$text = Get-Content $(join-path $localFilePath $targetFile)
        #$temp = Select-String -InputObject $text -Pattern $regex -AllMatches | Select -Expand Matches | Foreach { "-File:{0} -Sample:{1} -AnalysisCode:{2} -PreparationCode:{3}" -f $targetFile, $_.Groups[1].Value, $_.Groups[2].Value, $_.Groups[3].Value }
        $temp = Select-String -InputObject $text -Pattern $regex -AllMatches | Select -Expand Matches | Foreach { "{0}`t{1}`t{2}`t{3}" -f $targetFile, $_.Groups[1].Value, $_.Groups[2].Value, $_.Groups[3].Value }
        Write-Host "Found the following TRFs in file" $targetFile 
        Write-Host ($temp -join "`n")
        $TRFsFound = $TRFsFound + $temp
    }

    #sort and unique and output to file
    $TRFsFound = $TRFsFound | Sort-Object | Get-Unique
    $TRFsFound | Out-File (join-path $localFilePath output.txt)
    $totalUniqueTRFs = $TRFsFound | measure | select -ExpandProperty Count

    Write-Host "`nFound a total of" $totalUniqueTRFs "TRFs across all log files:"
    Write-Host ($TRFsFound -join "`n")

    $stopWatch.Stop();  
    # Get the elapsed time as a TimeSpan value. 
    $ts = $stopWatch.Elapsed  
    # Format and display the TimeSpan value. 
    $ElapsedTime = [system.String]::Format("{0:00}:{1:00}:{2:00}.{3:00}", 
               $ts.Hours, $ts.Minutes, $ts.Seconds, 
                $ts.Milliseconds / 10); 
    "`nScript Elapsed Runtime = $elapsedTime"
}