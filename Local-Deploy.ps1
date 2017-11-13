cls
$BasePath = $PSCommandPath.Substring(0, $PSCommandPath.IndexOf("\V1.0.0"))
$ENV:MIRTH_CHANNELS_PATH_INTERNAL = Join-Path $BasePath -ChildPath "V1.0.0/FMI.Billing.LimsDataService/Mirth/Channels/Internal"
$ENV:MIRTH_CHANNELS_PATH_EXTERNAL = Join-Path $BasePath -ChildPath "V1.0.0/FMI.Billing.LimsDataService/Mirth/Channels/External"
$ENV:TIMEOUT_SECONDS = 15
$ENV:MAX_RETRIES = 3
$ENV:RETRY_PAUSE_SECONDS = 5

try {

  Write-Host "`n***Loading Mirth-Deploy-Curl function***"
  $scriptPath = Join-Path $BasePath -ChildPath "\V1.0.0\FMI.Billing.LimsDataService\Mirth\Automation\Mirth-Deploy-Curl.ps1"
  . $scriptPath;
  Write-Host "***Loaded Mirth-Deploy-Curl function***"

  $ENV:MIRTH_API_SERVER = Read-Host -Prompt 'Input your Mirth server with port number (Example "appdev027:8443")'
  $ENV:MIRTH_USERNAME = Read-Host -Prompt 'Input your Mirth username'
  $secureResponse = Read-Host -Prompt 'Input your Mirth password' -AsSecureString
  $ENV:MIRTH_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureResponse))

  Write-Host "`n***Deploying Internal Mirth Channels***"
  Mirth-Deploy-Curl -MirthApiServer $ENV:MIRTH_API_SERVER -SourcePath $ENV:MIRTH_CHANNELS_PATH_INTERNAL -Username $ENV:MIRTH_USERNAME -Password $ENV:MIRTH_PASSWORD -TimeoutSeconds $ENV:TIMEOUT_SECONDS -MaxRetries $ENV:MAX_RETRIES -RetryPauseSeconds $ENV:RETRY_PAUSE_SECONDS;
  Write-Host "***Deployed Internal Mirth Channels***"

  Write-Host "`n***Deploying External Mirth Channels***"
  Mirth-Deploy-Curl -MirthApiServer $ENV:MIRTH_API_SERVER -SourcePath $ENV:MIRTH_CHANNELS_PATH_EXTERNAL -Username $ENV:MIRTH_USERNAME -Password $ENV:MIRTH_PASSWORD -TimeoutSeconds $ENV:TIMEOUT_SECONDS -MaxRetries $ENV:MAX_RETRIES -RetryPauseSeconds $ENV:RETRY_PAUSE_SECONDS;
  Write-Host "***Deployed External Mirth Channels***"

} catch {
  $ENV:MIRTH_PASSWORD = $null
  Write-Host "`nEXCEPTION:`n"
  Write-Error $_.Exception
}
