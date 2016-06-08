function CreateItems {
  param($SqlFilesToProcess)
  $SqlFilesToProcess | foreach {
    $DbObjectName = $_.FullName
    [string]$Cmd = "& $SqlCmd -S $DatabaseServer -d $DatabaseInstance -E -b -i $DbObjectName"

    # echo command
    $Cmd
  
    # add $? to return last command success/failure value (true or false)
    # need to add with single quote so not expanded
    $Cmd = $Cmd + '; $?'
    [bool]$Result = Invoke-Expression -command $Cmd
    if ($Result -eq $false) {
      # error occurred; terminate script
      "`nERROR: Error occurred creating database object while running this command:"
      "`n$Cmd"
      exit
    }
  }
}  

# This script recreates UDFs, Views and Stored Procedures

# It searches the current directory and below, looking for 
# files that have extensions .UDF, .VIW and .PRC.

# It run the files using sqlcmd and targets the database
# server and instance defined in the $DatabaseServer
# and $DatabaseInstance variables.

# It uses integrated security (current user) when connecting to
# the database.
function Create-UdfViewsAndProcs {

    $SqlCmd = "sqlcmd"
    $DatabaseServer = "LOCALHOST"
    $DatabaseInstance = "LOCAL_IHIDB"

    Write-Host "Deploying UDFs, views and procs to $DatabaseServer : $DatabaseInstance"
    Write-Host "If this isn't the database you want to deploy to, kill"
    Write-Host "this script now and edit the variables at the top."
    Write-Host "Otherwise, press the space bar."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host ""

    # DON'T run .SQL files - .SQL files contain table drop/create scripts

    # get all UDFs in current directory and below
    $Files = dir -recurse | Where {$_.Extension.ToLower() -eq '.udf' }
    "`n`nUDFs to process:"
    $Files
    # run the files
    Sql-CreateItems $Files

    # get all VIEWS in current directory and below
    $Files = dir -recurse | Where {$_.Extension.ToLower() -eq '.viw' }
    "`n`nVIEWS to process:"
    $Files
    # run the files
    Sql-CreateItems $Files

    # get all PRCs in current directory and below
    $Files = dir -recurse | Where {$_.Extension.ToLower() -eq '.prc' }
    "`n`nPRCs to process:"
    $Files
    # run the files
    Sql-CreateItems $Files
}