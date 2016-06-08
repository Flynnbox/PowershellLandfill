function Get-ApplicationLogFileAbbreviationHash {
	@{"LMS"="LMS"; "LMSAPI"="LMSAPI"; "INSIGHT"="INSIGHT"; "CONSOLE"="ihi_CSIConsole_log"; "CERTIFICATECENTER"="certcenter_log"; "LEADRETRIEVAL"="ihi_LeadRetrieval_log"; "MOBILEEVENTS"="MOBILEEVENTSAPI"}
}

function Get-EnvironmentLogPathHash {
	@{"LOCAL"="C:\LogFiles\IhiLogs\"; "DEV"="\\DEVAPPWEB\d$\Logfiles\IHILogs\"; "TEST"="\\TESTAPPWEB\d$\Logfiles\IHILogs\"; "PROD"="\\IHIAPPWEB01\d$\Logfiles\IHILogs\"; "DR"="\\DRAPPWEB01\d$\Logfiles\IHILogs\"}
}

function Get-IhiLogFilePath {
	[CmdletBinding()]
	param (
		[String]$ApplicationName,
		[String]$EnvironmentName,
		[DateTime]$Date
	)
	
	if ($ApplicationName -eq $null -or $ApplicationName.Trim() -eq "") {
  	Write-Host "`nPlease specify an application name." -ForegroundColor Yellow
		break
	}
	
	if ($EnvironmentName -eq $null -or $EnvironmentName.Trim() -eq "") {
  	Write-Host "`nPlease specify an environment name." -ForegroundColor Yellow
		break
	}

	if ($Date -eq $null){
		$Date = Get-Date
		$DateString = $Date.ToString("yyyy-MM-dd")
		Write-Host "`nNo date specified; defaulting to current date: $DateString" -ForegroundColor Cyan
	} else {
		$DateString = $Date.ToString("yyyy-MM-dd")
	}
	
	$ApplicationHash = Get-ApplicationLogFileAbbreviationHash	
	if ($ApplicationHash.ContainsKey($ApplicationName) -eq $false){
		Write-Host "`nUnrecognized application name: $ApplicationName" -ForegroundColor Yellow
		break
	}
	$LogFilePrefix = $ApplicationHash[$ApplicationName]
		
	$EnvironmentHash = Get-EnvironmentLogPathHash
	if ($EnvironmentHash.ContainsKey($EnvironmentName) -eq $false){
		Write-Host "`nUnrecognized environment name: $Environment" -ForegroundColor Yellow
		break
	}
	$LogFolder = $EnvironmentHash[$EnvironmentName]
	
	$LogFilePath = $LogFolder + $LogFilePrefix + "_" + $DateString + ".0"
	if ((Test-Path $LogFilePath) -eq $false){
		Write-Host "`nLog File does not exist at: $LogFilePath" -ForegroundColor Yellow
		break
	}
	$LogFilePath
}