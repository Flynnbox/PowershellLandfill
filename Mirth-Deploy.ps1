function Mirth-Deploy {
    [CmdletBinding()] Param (
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$MirthApiServer,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$SourcePath,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$Username,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$Password,
      [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$TimeoutSeconds = 15,
      [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$MaxRetries = 5,
      [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$RetryPauseSeconds = 5,
	  [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$IsCodeTemplates = $False
    )
    
  #create a stopwatch to track script execution time
  $stopWatch = New-Object system.Diagnostics.Stopwatch 
  $stopWatch.Start()

  try {

    Write-Host "`nBegin Mirth-Deploy script..."

    if ((Test-Path $SourcePath) -eq $false){
      throw "Path [$SourcePath] does not exist. Exiting..."
    }

    #Authenticate to Mirth Server
    [Microsoft.PowerShell.Commands.WebRequestSession]$authenticatedSession = Get-MirthAuthenticatedSession -MirthApiServer $MirthApiServer -Username $Username -Password $Password

    #Deploy channels
    Write-Host "Deploying Xml files in path [$SourcePath]..."
    foreach ($file in Get-ChildItem -path $SourcePath -Filter "*.xml")
    { 
		if ($IsCodeTemplates -eq $False ){
			Mirth-DeployChannel -MirthApiServer $MirthApiServer -AuthenticatedSession $authenticatedSession -FilePath $file.FullName -TimeoutSeconds $TimeoutSeconds -MaxRetries $MaxRetries -RetryPauseSeconds $RetryPauseSeconds
		} Else {
			Mirth-DeployCodeTemplates -MirthApiServer $MirthApiServer -AuthenticatedSession $authenticatedSession -FilePath $file.FullName -TimeoutSeconds $TimeoutSeconds -MaxRetries $MaxRetries -RetryPauseSeconds $RetryPauseSeconds
		}
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

function Mirth-DeployChannel {
    [CmdletBinding()] Param (
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$MirthApiServer,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [Microsoft.PowerShell.Commands.WebRequestSession]$AuthenticatedSession,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$FilePath,
      [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$TimeoutSeconds = 15,
      [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$MaxRetries = 3,
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
		
		$updateChannelUrl = ("https://{0}/api/channels/{1}?override=true" -f $MirthApiServer, $channelId)
		$deployChannelUrl = ("https://{0}/api/channels/{1}/_deploy?returnErrors=true" -f $MirthApiServer, $channelId)
		
		$content = Get-Content -Path $FilePath | Out-String
		
        #Update the Channel - should also create channel if channel does not exist
        Write-Host "Updating Mirth channel..."
		[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
		[xml]$response = Invoke-RestMethod $updateChannelUrl -Method Put -Body $content -ContentType 'application/xml' -Header @{"Accept" = "application/xml"} -WebSession $AuthenticatedSession
		[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
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
		Write-Host "Invoking $($deployChannelUrl)"
		[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
		[xml]$response = Invoke-RestMethod $deployChannelUrl -Method POST -ContentType 'application/xml' -Header @{"Accept" = "*/*"} -WebSession $AuthenticatedSession
		[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
		if ($response -eq $null){
          throw "No response returned for Mirth Channel deploy"
        }
		Write-Host
		
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

function Mirth-DeployCodeTemplates {
    [CmdletBinding()] Param (
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$MirthApiServer,
	  [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [Microsoft.PowerShell.Commands.WebRequestSession]$AuthenticatedSession,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$FilePath,
      [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$TimeoutSeconds = 15,
      [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$MaxRetries = 5,
      [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$RetryPauseSeconds = 5
    )
    
    try {
        Write-Host "`nPerforming steps to update the Mirth code templates from file $FilePath..."

        #Get channel id from code template
        Write-Host "Getting the Mirth code template details from xml file..."
        [xml]$xmlDocument = get-content $FilePath
        $codeTemplateId = $xmlDocument.codeTemplate.id
        Write-Host "Code Template Name is [$($xmlDocument.codeTemplate.Name)]"
        Write-Host "Code Template Id is [$codeTemplateId]"

		$codeTemplateUrl = ("https://{0}/api/codeTemplates/{1}?override=true" -f $MirthApiServer, $codeTemplateId)
		Write-Host "Url is [$codeTemplateUrl]"

		$content = Get-Content -Path $FilePath | Out-String

        #Update the Code Template - should also create code template if code template does not exist
        Write-Host "Updating Mirth code template..."
		[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        [xml]$response = Invoke-RestMethod $codeTemplateUrl -Method Put -Body $content -ContentType 'application/xml' -Header @{"Accept" = "application/xml"} -WebSession $AuthenticatedSession
		[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
		if ($response -eq $null){
          throw "No response returned for Mirth Update"
        }

        #Check Mirth Update response
        if([bool]($response.PSobject.Properties.name -match "boolean") -eq $false){
          Write-Error "`nMirth Update returned a non-boolean response"
          throw $response.InnerXml
        } elseif($response.boolean -ne $true) {
          throw ("Mirth Code Template Update response status is [{0}]" -f $response.boolean)
        }
        Write-Host "Update successful"
    }
    catch [System.Net.WebException] {
      Write-Error "`nAttempt to update Mirth code template timed out."
      if ($MaxRetries -gt 0){
        Write-Warning "Retrying $MaxRetries more times...`n"
        Mirth-DeployCodeTemplates -MirthApiServer $MirthApiServer -AuthenticatedSession $AuthenticatedSession -FilePath $FilePath -TimeoutSeconds $TimeoutSeconds -MaxRetries ($MaxRetries - 1) -RetryPauseSeconds $RetryPauseSeconds
      } else {
        throw
      }
    }
    catch {
        Write-Error "`nAttempt to update Mirth code template failed with exception`n"
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

function Get-MirthAuthenticatedSession {
    [CmdletBinding()] Param (
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$MirthApiServer,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$Username,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$Password
    )

    try {
        Write-Host "`nLogging into Mirth server [$MirthApiServer] with Username [$Username]..."

		$loginUrl = ("https://{0}/api/users/_login" -f $MirthApiServer)
		$loginFields = @{username=$Username;password=$Password;}
		
		Write-Host "Invoking url $($loginUrl)"
		[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
		$response = Invoke-RestMethod $loginUrl -Method Post -Body $loginFields -ContentType 'application/x-www-form-urlencoded' -Header @{"Accept" = "application/xml"} -SessionVariable session
		[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
		
        if ($response -eq $null -or $response.'com.mirth.connect.model.LoginStatus' -eq $null){
          throw "No response returned for Mirth Login"
        }

        if($response.'com.mirth.connect.model.LoginStatus'.status -ne "SUCCESS") {
          throw ("Mirth Login response status is [{0}]" -f $response.'com.mirth.connect.model.LoginStatus'.status)
        }
        Write-Host "Login successful"
		
        return $session
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

function Mirth-VerifyChannelStatus {
    [CmdletBinding()] Param (
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$MirthApiServer,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [Microsoft.PowerShell.Commands.WebRequestSession]$AuthenticatedSession,
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$ChannelId,
      [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$TimeoutSeconds = 15,
      [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$MaxRetries = 5,
      [Parameter(ValueFromPipelineByPropertyName = $True)] [Int]$RetryPauseSeconds = 5
    )
    try {
        #Verify the Channel
        Write-Host "Verifying Mirth channel state..."
		
		$verifyUrl = ("https://{0}/api/channels/{1}/status" -f $MirthApiServer, $ChannelId)

        Write-Host "Invoking url $($verifyUrl)"
		[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
		[xml]$response = Invoke-RestMethod $verifyUrl -Method GET -ContentType 'application/xml' -Header @{"Accept" = "*/*"} -WebSession $AuthenticatedSession -TimeoutSec $TimeoutSeconds
		[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
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
      [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [Microsoft.PowerShell.Commands.WebRequestSession]$AuthenticatedSession
    )

    try {
        Write-Host "`nLogging out of Mirth server [$MirthApiServer]..."

		$logoutUrl = ("https://{0}/api/users/_logout" -f $MirthApiServer) 
		Write-Host "Invoking url $($logoutUrl)"
		
		[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
		[xml]$response = Invoke-RestMethod $logoutUrl -Method Post -ContentType 'application/x-www-form-urlencoded' -Header @{"Accept" = "application/xml"} -WebSession $AuthenticatedSession
		[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
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