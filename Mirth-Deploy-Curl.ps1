function Mirth-Deploy-Curl {
    [CmdletBinding()] Param (
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$MirthApiServer,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$SourcePath,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$Username,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$Password,
      [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$TimeoutSeconds = 15,
      [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$MaxRetries = 5,
      [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$RetryPauseSeconds = 5
    )
    
  #create a stopwatch to track script execution time
  $stopWatch = New-Object system.Diagnostics.Stopwatch 
  $stopWatch.Start()

  try {

    Write-Host "`nBegin Mirth-Deploy-Curl script..."

    $curlFilePath = (Get-Command curl.exe).Definition
    Write-Host "Curl.exe Path: $curlFilePath"

    if ((Test-Path $SourcePath) -eq $false){
      throw "Path [$SourcePath] does not exist. Exiting..."
    }

    #Authenticate to Mirth Server
    $session = Get-MirthAuthenticatedSession -MirthApiServer $MirthApiServer -Username $Username -Password $Password

    #Deploy channels
    Write-Host "Deploying channels in path [$SourcePath]..."
    foreach ($file in Get-ChildItem -path $SourcePath -Filter "*.xml")
    { 
      Mirth-DeployChannel -MirthApiServer $MirthApiServer -AuthenticatedSession $session -FilePath $file.FullName -TimeoutSeconds $TimeoutSeconds -MaxRetries $MaxRetries -RetryPauseSeconds $RetryPauseSeconds
    }
    
    Write-Host "`nMirth-Deploy completed successfully"
  }
  catch {
    Write-Error "`nMirth-Deploy failed with exception`n"
    Write-Error $_.Exception
    throw
  }
  finally {
    if ($session -ne $null){
        Logout-MirthAuthenticatedSession -MirthApiServer $MirthApiServer -AuthenticatedSession $session
    }
  }

  $stopWatch.Stop();  
  # Get the elapsed time as a TimeSpan value. 
  $ts = $stopWatch.Elapsed  
  # Format and display the TimeSpan value. 
  $ElapsedTime = [system.String]::Format("{0:00}:{1:00}:{2:00}.{3:00}", $ts.Hours, $ts.Minutes, $ts.Seconds, $ts.Milliseconds / 10); 
  "Total Elapsed Execution Time: $elapsedTime"
}

function Get-MirthAuthenticatedSession {
    [CmdletBinding()] Param (
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$MirthApiServer,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$Username,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$Password
    )

    try {
        Write-Host "`nLogging into Mirth server [$MirthApiServer] with Username [$Username]..."

        $curlFilePath = (Get-Command curl.exe).Definition
        $mirthAuthenticationCookie = "mirthAuthenticationCookie"
        [xml]$response = .$curlFilePath -X POST -H 'Content-Type:application/x-www-form-urlencoded' -H 'Accept:application/xml' -c $mirthAuthenticationCookie -d "username=$Username&password=$Password" --max-time 1200 "https://$MirthApiServer/api/users/_login" -k -s

        if ($response -eq $null -or $response.'com.mirth.connect.model.LoginStatus' -eq $null){
          throw "No response returned for Mirth Login"
        }

        if($response.'com.mirth.connect.model.LoginStatus'.status -ne "SUCCESS") {
          throw ("Mirth Login response status is [{0}]" -f $response.'com.mirth.connect.model.LoginStatus'.status)
        }
        Write-Host "Login successful"
        return $mirthAuthenticationCookie
    }
    catch {
        Write-Error "`nLogging into Mirth server failed with exception`n"
        Write-Error $_.Exception
        if ($_.Exception.Response -ne $null){
            $result = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
            Write-Host "`nERROR RESPONSE BODY" -ForegroundColor DarkYellow
            Write-Host $responseBody -ForegroundColor DarkYellow
        }
        throw
    }
}

function Mirth-DeployChannel {
    [CmdletBinding()] Param (
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$MirthApiServer,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$AuthenticatedSession,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$FilePath,
      [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$TimeoutSeconds = 15,
      [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$MaxRetries = 5,
      [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$RetryPauseSeconds = 5
    )
    
    try {
        Write-Host "`nPerforming steps to update the Mirth channel from file $FilePath..."

        #Get channel id from file
        Write-Host "Getting the Mirth channel details from xml file..."
        [xml]$xmlDocument = get-content $FilePath
        $channelId = $xmlDocument.channel.id
        Write-Host "Channel Name is [$($xmlDocument.channel.Name)]"
        Write-Host "Channel Id is [$channelId]"
        
        $curlFilePath = (Get-Command curl.exe).Definition

        #Update the Channel - should also create channel if channel does not exist
        Write-Host "Updating Mirth channel..."
        [xml]$response = .$curlFilePath -X PUT -H "Content-Type:application/xml" -H 'Accept:application/xml' --data-binary @$FilePath --max-time $TimeoutSeconds ("https://{0}/api/channels/{1}?override=true" -f $MirthApiServer, $channelId) -k -s --cookie $AuthenticatedSession
        if ($response -eq $null){
          throw "No response returned for Mirth Update"
        }

        #Check Mirth Update response
        if([bool]($response.PSobject.Properties.name -match "boolean") -eq $false){
          Write-Error "`nMirth Update returned a non-boolean response"
          throw $response.InnerXml
        } elseif($response.boolean -ne $true) {
          throw ("Mirth Update response status is [{0}]" -f $response.boolean)
        }
        Write-Host "Update successful"

        #Deploy the Channel - should also stop channel first if channel is running and start channel after deploy
        Write-Host "Deploying Mirth channel..."
        [xml]$response = .$curlFilePath -X POST -H "Content-Type:application/xml" -H 'Accept:application/xml' --max-time $TimeoutSeconds ("https://{0}/api/channels/{1}/_deploy?returnErrors=true" -f $MirthApiServer, $channelId) -k -s --cookie $AuthenticatedSession
        if ($response -ne $null){
          Write-Error $response
          throw "Mirth deploy failed with error"
        }
        Write-Host "Deploy successful"

        #Verify the Channel
        Mirth-VerifyChannelStatus -MirthApiServer $MirthApiServer -AuthenticatedSession $AuthenticatedSession -ChannelId $channelId -TimeoutSeconds $TimeoutSeconds -MaxRetries $MaxRetries -RetryPauseSeconds $RetryPauseSeconds
    }
    catch [System.Net.WebException] {
      Write-Error "`nAttempt to update Mirth channel timed out."
      if ($MaxRetries -gt 0){
        Write-Warning "Retrying $MaxRetries more times...`n"
        Mirth-DeployChannel -MirthApiServer $MirthApiServer -AuthenticatedSession $AuthenticatedSession -FilePath $FilePath -TimeoutSeconds $TimeoutSeconds -MaxRetries ($MaxRetries - 1) -RetryPauseSeconds $RetryPauseSeconds
      } else {
        throw
      }
    }
    catch {
        Write-Error "`nAttempt to update Mirth channel failed with exception`n"
        Write-Error $_.Exception
        if ($_.Exception.Response -ne $null){
            $result = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
            Write-Host "`nERROR RESPONSE BODY" -ForegroundColor DarkYellow
            Write-Host $responseBody -ForegroundColor DarkYellow
        }
        throw
    }
}

function Mirth-VerifyChannelStatus {
    [CmdletBinding()] Param (
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$MirthApiServer,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$AuthenticatedSession,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$ChannelId,
      [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$TimeoutSeconds = 15,
      [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$MaxRetries = 5,
      [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$RetryPauseSeconds = 5
    )
    try {
        #Verify the Channel
        Write-Host "Verifying Mirth channel state..."
        [xml]$response = .$curlFilePath -X GET -H "Content-Type:application/xml" -H 'Accept:application/xml' --max-time $TimeoutSeconds ("https://{0}/api/channels/{1}/status" -f $MirthApiServer, $ChannelId) -k -s --cookie $AuthenticatedSession
          
        if ($response -eq $null -or $response.dashBoardStatus -eq $null){
            Write-Warning "No response returned for Mirth Channel"
            throw "Could not verify Mirth Channel state"
        }

        if($response.dashBoardStatus.state -ne "STARTED") {
            Write-Warning ("Mirth Channel state is [{0}]" -f $response.dashBoardStatus.state)
            $exception = New-Object -TypeName System.InvalidOperationException -ArgumentList ("Verification failed: Mirth Channel state should be [STARTED] but is [{0}]" -f $response.dashBoardStatus.state)
            throw $exception
        }
        Write-Host "Verification successful"
    }
    catch [System.InvalidOperationException] {
      Write-Error "`nAttempt to verify Mirth channel status failed."
      if ($MaxRetries -gt 0){
        Write-Warning "Pausing $RetryPauseSeconds seconds...`n"
        Start-Sleep -Seconds $RetryPauseSeconds
        Write-Warning "Retrying $MaxRetries more times...`n"
        Mirth-VerifyChannelStatus -MirthApiServer $MirthApiServer -AuthenticatedSession $AuthenticatedSession -ChannelId $ChannelId -TimeoutSeconds $TimeoutSeconds -MaxRetries ($MaxRetries - 1) -RetryPauseSeconds $RetryPauseSeconds
      } else {
        throw
      }
    }
    catch {
        Write-Error "`nAttempt to update Mirth channel failed with exception`n"
        Write-Error $_.Exception
        if ($_.Exception.Response -ne $null){
            $result = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
            Write-Host "`nERROR RESPONSE BODY" -ForegroundColor DarkYellow
            Write-Host $responseBody -ForegroundColor DarkYellow
        }
        throw
    }
}

function Logout-MirthAuthenticatedSession {
    [CmdletBinding()] Param (
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$MirthApiServer,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [string]$AuthenticatedSession
    )

    try {
        Write-Host "`nLogging out of Mirth server [$MirthApiServer]..."

        $curlFilePath = (Get-Command curl.exe).Definition
        [xml]$response = .$curlFilePath -X POST -H 'Content-Type:application/x-www-form-urlencoded' -H 'Accept:application/xml' --max-time 1200 ("https://{0}/api/users/_logout" -f $MirthApiServer) -k -s
        Write-Host "Logout successful"

        if ((Test-Path $AuthenticatedSession) -eq $true){
          Write-Host "Deleting cookie file..."
          Remove-Item $AuthenticatedSession
          if ((Test-Path $AuthenticatedSession) -eq $true){
            throw "Failed to remove cookie file [$AuthenticatedSession]"
          }
          Write-Host "Delete successful"
        }
    }
    catch {
        Write-Error "`nLogging out of Mirth server failed with exception`n"
        Write-Error $_.Exception
        if ($_.Exception.Response -ne $null){
            $result = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
            Write-Host "`nERROR RESPONSE BODY" -ForegroundColor DarkYellow
            Write-Host $responseBody -ForegroundColor DarkYellow
        }
        throw
    }
}
