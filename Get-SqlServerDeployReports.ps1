function Get-SqlServerDeployReports { 
  param ([string]$ReportTree,[string]$ReportEnv)
  chdir "c:\Program Files\Microsoft SQL Server\110\Tools\binn\"
  rs.exe  /i c:\ihi_main\trunk\database\alldatabases\SSRS\DeployReports\scripts\DeployReports.rss /s http://$ReportEnv/reportserver  -v vssRoot="c:\ihi_main\trunk\" -v ReportEnv=$ReportEnv -v ReportTree=$ReportTree
  chdir c:\ihi_main\trunk\database\alldatabases\SSRS\DeployReports
}

#Set-Alias deployreports Get-SqlServerDeployReports -scope global