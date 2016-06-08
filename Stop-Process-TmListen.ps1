#do not run this code on powershell startup
return

#run from batch file with %COMPUTERNAME%
#receive computer name as paramter

#check if the TmListen process is running
$TmListen = Get-Process -Name TmListen -ErrorAction SilentlyContinue
if($TmListen -ne $null){
    Write-Host "TmListen process is running.";
    Write-Host "Verifying script is running as administrator or relaunching as administrator...";

    # Get the ID and security principal of the current user account
    $myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent();
    $myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID);

    # Get the security principal for the administrator role
    $adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator;

    # Check to see if we are currently running as an administrator
    if($myWindowsPrincipal.IsInRole($adminRole))
    {
        Write-Host "Currently running as administrator"

        # We are running as an administrator, so change the title and background colour to indicate this
        $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)";
        $Host.UI.RawUI.BackgroundColor = "DarkBlue";
        Clear-Host;
    }else{
        Write-Host "Not running as an administrator, so relaunch script as administrator..."
        
        # Create a new process object that starts PowerShell
        $newProcess = New-Object System.Diagnostics.ProcessStartInfo
        
        $newProcess.FileName = "powerShell.exe";

        # Specify the current script path and name as a parameter with added scope and support for scripts with spaces in it's path
        $newProcess.Arguments = "-NoProfile" # & '" + $script:MyInvocation.MyCommand.Path + "'" #-CreateNoWindow 

        # Indicate that the process should be elevated
        $newProcess.Verb = "runas";

        # Start the new process
        [System.Diagnostics.Process]::Start($newProcess);

        # Exit from the current, unelevated, process
        Exit;
    }

  #stop the TmListen process
  Stop-Process -ProcessName TmListen -Force
  Write-Host "TmListen process has been stopped";
}
else {
  Write-Host "TmListen process is not currently running";
}

Write-Host "Press any key to continue...";
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown");


#ideas
#host PS on remote server and run on local machine via batch file
#$MyComputer = $env:computername